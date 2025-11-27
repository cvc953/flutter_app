import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Assumimos que la API corre en localhost:8000
  static const String baseUrl = 'http://172.200.176.171:8000';
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Login: retorna token
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(uri, body: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Login failed: ${response.statusCode} ${response.body}');
  }

  // Obtener proyectos de estudiante
  static Future<List<dynamic>> proyectosEstudiante(int estudianteId) async {
    final uri = Uri.parse('$baseUrl/proyectos/estudiante/$estudianteId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching projects: ${r.statusCode}');
  }

  // Crear proyecto (multipart)
  static Future<Map<String, dynamic>> crearProyecto(
      String titulo,
      String descripcion,
      int cursoId,
      int profesorId,
      DateTime? fechaEntrega,
      File? archivo,
      String? comentariosVersion) async {
    final uri = Uri.parse('$baseUrl/proyectos');
    var request = http.MultipartRequest('POST', uri);
    request.fields['titulo'] = titulo;
    request.fields['descripcion'] = descripcion;
    // El backend ahora espera que el proyecto se asigne a un curso
    request.fields['curso_id'] = cursoId.toString();
    request.fields['profesor_id'] = profesorId.toString();
    if (fechaEntrega != null) {
      request.fields['fecha_entrega'] = fechaEntrega.toIso8601String();
    }
    if (comentariosVersion != null)
      request.fields['comentarios_version'] = comentariosVersion;

    if (archivo != null) {
      request.files
          .add(await http.MultipartFile.fromPath('file', archivo.path));
    }

    if (_token != null && _token!.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $_token';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
        'Error creating project: ${response.statusCode} ${response.body}');
  }

  // ========== ASIGNACIONES (Moodle-style) ==========

  // Crear asignación (profesor asigna tarea a curso)
  static Future<Map<String, dynamic>> crearAsignacion(
      String titulo,
      String descripcion,
      int cursoId,
      int profesorId,
      DateTime? fechaEntrega,
      File? archivo,
      String? comentariosVersion) async {
    final uri = Uri.parse('$baseUrl/asignaciones');
    var request = http.MultipartRequest('POST', uri);
    request.fields['titulo'] = titulo;
    request.fields['descripcion'] = descripcion;
    request.fields['curso_id'] = cursoId.toString();
    request.fields['profesor_id'] = profesorId.toString();
    if (fechaEntrega != null) {
      request.fields['fecha_entrega'] = fechaEntrega.toIso8601String();
    }
    if (comentariosVersion != null)
      request.fields['comentarios_version'] = comentariosVersion;

    if (archivo != null) {
      request.files
          .add(await http.MultipartFile.fromPath('file', archivo.path));
    }

    if (_token != null && _token!.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $_token';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
        'Error creating assignment: ${response.statusCode} ${response.body}');
  }

  // Entregar asignación (estudiante entrega su trabajo)
  static Future<Map<String, dynamic>> entregarAsignacion(
      int asignacionId, String descripcion, dynamic archivo) async {
    final uri = Uri.parse('$baseUrl/asignaciones/$asignacionId/entregas');
    var request = http.MultipartRequest('POST', uri);
    request.fields['descripcion'] = descripcion;
    if (archivo != null) {
      try {
        if (archivo is File) {
          request.files
              .add(await http.MultipartFile.fromPath('file', archivo.path));
        } else if (archivo is List<int>) {
          request.files.add(http.MultipartFile.fromBytes('file', archivo,
              filename: 'upload'));
        } else if (archivo is Map && archivo['bytes'] != null) {
          final bytes = archivo['bytes'] as List<int>;
          final name = archivo['name'] ?? 'upload';
          request.files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: name));
        } else if (archivo.bytes != null) {
          final bytes = archivo.bytes as List<int>;
          final name = archivo.name ?? 'upload';
          request.files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: name));
        }
      } catch (e) {
        try {
          request.files
              .add(await http.MultipartFile.fromPath('file', archivo.path));
        } catch (_) {}
      }
    }

    if (_token != null && _token!.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $_token';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
        'Error submitting assignment: ${response.statusCode} ${response.body}');
  }

  // Obtener entregas de una asignación (profesor revisa entregas)
  static Future<Map<String, dynamic>> obtenerEntregasAsignacion(
      int asignacionId) async {
    final uri = Uri.parse('$baseUrl/asignaciones/$asignacionId/entregas');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception(
        'Error fetching assignment submissions: ${r.statusCode} ${r.body}');
  }

  // Subir nueva versión
  static Future<Map<String, dynamic>> subirVersion(
      int proyectoId, String descripcion, dynamic archivo) async {
    final uri = Uri.parse('$baseUrl/proyectos/$proyectoId/versiones');
    var request = http.MultipartRequest('POST', uri);
    request.fields['descripcion'] = descripcion;
    if (archivo != null) {
      // archivo can be a dart:io File (desktop/mobile) or a PlatformFile (web)
      try {
        if (archivo is File) {
          request.files
              .add(await http.MultipartFile.fromPath('file', archivo.path));
        } else if (archivo is List<int>) {
          // raw bytes
          request.files.add(http.MultipartFile.fromBytes('file', archivo,
              filename: 'upload'));
        } else if (archivo is Map && archivo['bytes'] != null) {
          // some callers may pass a Map with bytes and name
          final bytes = archivo['bytes'] as List<int>;
          final name = archivo['name'] ?? 'upload';
          request.files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: name));
        } else if (archivo.bytes != null) {
          // PlatformFile from file_picker has .bytes and .name
          final bytes = archivo.bytes as List<int>;
          final name = archivo.name ?? 'upload';
          request.files
              .add(http.MultipartFile.fromBytes('file', bytes, filename: name));
        }
      } catch (e) {
        // fallback: try to treat as pathable File
        try {
          request.files
              .add(await http.MultipartFile.fromPath('file', archivo.path));
        } catch (_) {}
      }
    }

    if (_token != null && _token!.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $_token';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
        'Error uploading version: ${response.statusCode} ${response.body}');
  }

  static Future<List<dynamic>> obtenerVersiones(int proyectoId) async {
    final uri = Uri.parse('$baseUrl/proyectos/$proyectoId/versiones');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching versions: ${r.statusCode}');
  }

  static Future<List<dynamic>> obtenerCalificacionesProyecto(
      int proyectoId) async {
    final uri = Uri.parse('$baseUrl/calificaciones/proyecto/$proyectoId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching grades: ${r.statusCode}');
  }

  // Registro de usuario (form-data)
  static Future<Map<String, dynamic>> registro(
      String email, String password, String nombre, String apellido,
      {String rol = 'estudiante'}) async {
    final uri = Uri.parse('$baseUrl/auth/registro');
    // La API acepta form-data; usamos MultipartRequest para flexibilidad
    var request = http.MultipartRequest('POST', uri);
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['nombre'] = nombre;
    request.fields['apellido'] = apellido;
    request.fields['rol'] = rol;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
        'Registro fallido: ${response.statusCode} ${response.body}');
  }

  // Obtener perfil de usuario
  static Future<Map<String, dynamic>> obtenerPerfil(int usuarioId) async {
    final uri = Uri.parse('$baseUrl/usuarios/$usuarioId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching perfil: ${r.statusCode} ${r.body}');
  }

  /// Obtener perfil del usuario autenticado (si el backend expone /usuarios/me).
  /// Esto se usa para validar que el token aún es válido cuando restauramos
  /// la sesión desde almacenamiento local.
  static Future<Map<String, dynamic>> obtenerPerfilMe() async {
    final uri = Uri.parse('$baseUrl/usuarios/me');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching perfil me: ${r.statusCode} ${r.body}');
  }

  // Obtener proyectos de profesor
  static Future<List<dynamic>> proyectosProfesor(int profesorId) async {
    final uri = Uri.parse('$baseUrl/proyectos/profesor/$profesorId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching projects for professor: ${r.statusCode}');
  }

  // Obtener detalle de proyecto
  static Future<Map<String, dynamic>> obtenerProyecto(int proyectoId) async {
    final uri = Uri.parse('$baseUrl/proyectos/$proyectoId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching project: ${r.statusCode}');
  }

  // Calificar proyecto (profesor)
  // Si estudianteId y versionId son null, califica el proyecto completo
  // Si se proporcionan, califica la entrega específica de ese estudiante
  static Future<Map<String, dynamic>> calificar(
      int proyectoId, int profesorId, double puntaje, String? comentarios,
      {int? estudianteId, int? versionId}) async {
    final uri = Uri.parse('$baseUrl/calificaciones');
    final body = json.encode({
      'proyecto_id': proyectoId,
      'profesor_id': profesorId,
      'puntaje': puntaje,
      'comentarios': comentarios,
      if (estudianteId != null) 'estudiante_id': estudianteId,
      if (versionId != null) 'version_id': versionId,
    });
    final r = await http.post(uri,
        headers: {..._headers(), 'Content-Type': 'application/json'},
        body: body);
    if (r.statusCode == 200 || r.statusCode == 201) return json.decode(r.body);
    throw Exception('Error calificar proyecto: ${r.statusCode} ${r.body}');
  }

  // Obtener reporte de desempeño de un estudiante
  static Future<Map<String, dynamic>> obtenerReporteDesempeno(
      int estudianteId) async {
    final uri =
        Uri.parse('$baseUrl/reportes/desempeño/estudiante/$estudianteId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching desempeño: ${r.statusCode}');
  }

  // Obtener calificaciones de un estudiante
  static Future<List<dynamic>> obtenerCalificacionesEstudiante(
      int estudianteId) async {
    final uri = Uri.parse('$baseUrl/calificaciones/estudiante/$estudianteId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching student grades: ${r.statusCode}');
  }

  // Cursos (nota: el backend puede no tener estos endpoints; se capturan errores)
  static Future<Map<String, dynamic>> crearCurso(String nombre,
      {String? descripcion, required int profesorId}) async {
    final uri = Uri.parse('$baseUrl/cursos');
    final body = json.encode({
      'nombre': nombre,
      'descripcion': descripcion,
      'profesor_id': profesorId
    });
    final r = await http.post(uri,
        headers: {..._headers(), 'Content-Type': 'application/json'},
        body: body);
    if (r.statusCode == 200 || r.statusCode == 201) return json.decode(r.body);
    throw Exception('Error crear curso: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> agregarEstudianteACurso(
      int cursoId, int estudianteId) async {
    final uri = Uri.parse('$baseUrl/cursos/$cursoId/estudiantes');
    // The backend expects both curso_id and estudiante_id in the JSON body
    // because the Pydantic DTO includes curso_id. Include both to avoid 422.
    final body =
        json.encode({'curso_id': cursoId, 'estudiante_id': estudianteId});
    final r = await http.post(uri,
        headers: {..._headers(), 'Content-Type': 'application/json'},
        body: body);
    if (r.statusCode == 200 || r.statusCode == 201) return json.decode(r.body);
    throw Exception(
        'Error agregar estudiante al curso: ${r.statusCode} ${r.body}');
  }

  /// Listar cursos de un profesor (GET /cursos/profesor/{profesor_id})
  static Future<List<dynamic>> cursosProfesor(int profesorId) async {
    final uri = Uri.parse('$baseUrl/cursos/profesor/$profesorId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching cursos: ${r.statusCode} ${r.body}');
  }

  // Listar estudiantes de un curso
  static Future<List<dynamic>> cursoEstudiantes(int cursoId) async {
    final uri = Uri.parse('$baseUrl/cursos/$cursoId/estudiantes');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception(
        'Error fetching curso estudiantes: ${r.statusCode} ${r.body}');
  }

  // List all registered students
  static Future<List<dynamic>> obtenerEstudiantes() async {
    final uri = Uri.parse('$baseUrl/estudiantes');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching estudiantes: ${r.statusCode} ${r.body}');
  }

  // Eliminar estudiante de un curso (cliente intentará DELETE /cursos/{cursoId}/estudiantes/{estudianteId})
  static Future<void> eliminarEstudianteACurso(
      int cursoId, int estudianteId) async {
    final uri = Uri.parse('$baseUrl/cursos/$cursoId/estudiantes/$estudianteId');
    final r = await http.delete(uri, headers: _headers());
    if (r.statusCode == 200 || r.statusCode == 204) return;
    // Fallback: si el backend no implementa DELETE por path, retornar error claro
    throw Exception(
        'Error eliminar estudiante del curso: ${r.statusCode} ${r.body}');
  }

  // ==================== ENTREGAS Y CALIFICACIÓN ====================

  /// Obtener todas las entregas de un curso (GET /cursos/{cursoId}/entregas)
  static Future<Map<String, dynamic>> obtenerEntregasCurso(int cursoId) async {
    final uri = Uri.parse('$baseUrl/cursos/$cursoId/entregas');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching entregas curso: ${r.statusCode} ${r.body}');
  }

  /// Obtener entregas de estudiantes para un proyecto (GET /proyectos/{proyectoId}/entregas-estudiantes)
  static Future<Map<String, dynamic>> obtenerEntregasEstudiantesProyecto(
      int proyectoId) async {
    final uri =
        Uri.parse('$baseUrl/proyectos/$proyectoId/entregas-estudiantes');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception(
        'Error fetching entregas estudiantes: ${r.statusCode} ${r.body}');
  }

  /// Obtener versiones de un proyecto con info del estudiante (GET /proyectos/{proyectoId}/versiones)
  static Future<Map<String, dynamic>> obtenerVersionesProyectoDetalle(
      int proyectoId) async {
    final uri = Uri.parse('$baseUrl/proyectos/$proyectoId/versiones');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Error fetching versiones: ${r.statusCode} ${r.body}');
  }

  /// Calificar un proyecto (POST /calificaciones)
  static Future<Map<String, dynamic>> calificarProyecto({
    required int proyectoId,
    required int profesorId,
    required double puntaje,
    String? comentarios,
  }) async {
    final uri = Uri.parse('$baseUrl/calificaciones');
    final body = json.encode({
      'proyecto_id': proyectoId,
      'profesor_id': profesorId,
      'puntaje': puntaje,
      'comentarios': comentarios,
    });
    final r = await http.post(uri,
        headers: {..._headers(), 'Content-Type': 'application/json'},
        body: body);
    if (r.statusCode == 200 || r.statusCode == 201) return json.decode(r.body);
    throw Exception('Error calificar proyecto: ${r.statusCode} ${r.body}');
  }

  /// Descargar archivo de una versión específica
  /// Devuelve la URL para descargar (el cliente debe abrir en navegador o descargar)
  static String urlDescargarVersion(int proyectoId, int versionId) {
    return '$baseUrl/proyectos/$proyectoId/versiones/$versionId/archivo';
  }

  /// Descargar archivo de la versión actual del proyecto
  static String urlDescargarProyectoActual(int proyectoId) {
    return '$baseUrl/proyectos/$proyectoId/archivo';
  }
}
