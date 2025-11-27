import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  User? _user;
  String? _token;
  bool get isLoggedIn => _user != null;
  User? get user => _user;

  Future<void> login(String email, String password) async {
    Map<String, dynamic> resp;
    try {
      resp = await ApiService.login(email, password);
    } catch (e) {
      // Log and rethrow so UI can show a clearer message
      // ignore: avoid_print
      print('[AuthController] login error: $e');
      rethrow;
    }
    // resp expected: {"access_token": "...", "token_type": "bearer", "usuario_id": id}
    if (resp['access_token'] == null) {
      // Unexpected response from server
      // ignore: avoid_print
      print('[AuthController] login unexpected response: $resp');
      throw Exception('Respuesta inválida del servidor al iniciar sesión');
    }
    _token = resp['access_token'];
    ApiService.setToken(_token);
    // persist token for session restore
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token ?? '');
      // also persist basic user info returned by API
      final uidTemp = resp['usuario_id'] ?? resp['user_id'] ?? resp['id'] ?? 0;
      final uid =
          (uidTemp is int) ? uidTemp : int.tryParse(uidTemp.toString()) ?? 0;
      await prefs.setInt('user_id', uid);
      if (resp['email'] != null)
        await prefs.setString('user_email', resp['email']);
      if (resp['rol'] != null) await prefs.setString('user_role', resp['rol']);
      if (resp['role'] != null)
        await prefs.setString('user_role', resp['role']);
      if (resp['nombre'] != null)
        await prefs.setString('user_nombre', resp['nombre']);
      if (resp['apellido'] != null)
        await prefs.setString('user_apellido', resp['apellido']);
      if (resp['nombre_completo'] != null)
        await prefs.setString('user_nombre_completo', resp['nombre_completo']);
    } catch (e) {
      // ignore but log
      // ignore: avoid_print
      print('[AuthController] prefs write error: $e');
    }
    final uid = resp['usuario_id'] ?? resp['user_id'] ?? resp['id'] ?? 0;
    // Prefer role returned by the API (campo 'rol' o 'role'). Fall back to probing endpoints if missing.
    String? roleFromResp = resp['rol'] ?? resp['role'];
    String? finalRole = roleFromResp;
    if (finalRole == null) {
      // backward-compat heuristic: try to infer role by calling endpoints
      try {
        final studs = await ApiService.proyectosEstudiante(uid);
        if (studs.isNotEmpty) finalRole = 'estudiante';
      } catch (_) {}
      if (finalRole == null) {
        try {
          final profs = await ApiService.proyectosProfesor(uid);
          if (profs.isNotEmpty) finalRole = 'profesor';
        } catch (_) {}
      }
    }
    if (finalRole == null) finalRole = 'padre';
    // Use name fields returned by the API when available
    final nombre = resp['nombre'] as String?;
    final apellido = resp['apellido'] as String?;
    final nombreCompleto = resp['nombre_completo'] as String?;
    _user = User(
        id: uid,
        email: resp['email'] ?? email,
        role: finalRole,
        nombre: nombre,
        apellido: apellido,
        nombreCompleto: nombreCompleto);
    notifyListeners();
  }

  /// Restore session from persistent storage (if any). Should be called on app startup.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return;
      _token = token;
      ApiService.setToken(_token);

      // Prefer validating token by asking the backend for the current profile
      // (GET /usuarios/me). If the backend doesn't expose that endpoint or
      // it fails, fall back to using stored user_id and requesting
      // /usuarios/{id}. If validation fails, clear persisted session.
      Map<String, dynamic>? profile;
      try {
        profile = await ApiService.obtenerPerfilMe();
      } catch (_) {
        // fallback: try obtenerPerfil by stored id
        final uid = prefs.getInt('user_id') ?? 0;
        if (uid > 0) {
          try {
            profile = await ApiService.obtenerPerfil(uid);
          } catch (_) {
            profile = null;
          }
        }
      }

      if (profile == null) {
        // token invalid or profile couldn't be fetched -> clear session
        try {
          await prefs.remove('auth_token');
          await prefs.remove('user_id');
        } catch (_) {}
        _token = null;
        ApiService.setToken(null);
        return;
      }

      // Use profile returned by server to populate user (more authoritative)
      final uidServer =
          profile['id'] ?? profile['usuario_id'] ?? profile['user_id'] ?? 0;
      final email = profile['email'] ?? prefs.getString('user_email');
      final role = profile['rol'] ??
          profile['role'] ??
          prefs.getString('user_role') ??
          'estudiante';
      final nombre = profile['nombre'] ?? prefs.getString('user_nombre');
      final apellido = profile['apellido'] ?? prefs.getString('user_apellido');
      final nombreCompleto =
          profile['nombre_completo'] ?? prefs.getString('user_nombre_completo');

      // persist authoritative values
      try {
        await prefs.setInt('user_id', (uidServer as int?) ?? 0);
        if (email != null) await prefs.setString('user_email', email);
        if (role != null) await prefs.setString('user_role', role);
        if (nombre != null) await prefs.setString('user_nombre', nombre);
        if (apellido != null) await prefs.setString('user_apellido', apellido);
        if (nombreCompleto != null)
          await prefs.setString('user_nombre_completo', nombreCompleto);
      } catch (_) {}

      _user = User(
          id: (uidServer as int?) ?? 0,
          email: email ?? '',
          role: role,
          nombre: nombre,
          apellido: apellido,
          nombreCompleto: nombreCompleto);
      notifyListeners();
    } catch (_) {}
  }

  void logout() {
    _user = null;
    _token = null;
    ApiService.setToken(null);
    // clear persisted session
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('auth_token');
        prefs.remove('user_id');
        prefs.remove('user_email');
        prefs.remove('user_role');
        prefs.remove('user_nombre');
        prefs.remove('user_apellido');
        prefs.remove('user_nombre_completo');
      });
    } catch (_) {}
    notifyListeners();
  }

  String? get token => _token;
}
