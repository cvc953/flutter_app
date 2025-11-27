import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _rol = 'estudiante';
  bool _loading = false;
  String? _passwordError;
  String? _confirmError;
  String _passwordStrengthLabel = '';

  String? _validatePassword(String pwd) {
    if (pwd.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(pwd))
      return 'Debe contener al menos una letra mayúscula';
    if (!RegExp(r'[a-z]').hasMatch(pwd))
      return 'Debe contener al menos una letra minúscula';
    if (!RegExp(r'\d').hasMatch(pwd)) return 'Debe contener al menos un dígito';
    // special character: any non-alphanumeric
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pwd))
      return 'Debe contener al menos un carácter especial';
    return null;
  }

  String _computePasswordStrengthLabel(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd)) score++;
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score++;
    if (score >= 5) return 'Fuerte';
    if (score >= 3) return 'Media';
    if (score > 0) return 'Débil';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 800;
        return Row(children: [
          Expanded(
            flex: wide ? 5 : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ready to start your success story?',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          'Crea una cuenta para subir proyectos y recibir retroalimentación.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 24),
                      TextField(
                          controller: _nombre,
                          decoration:
                              const InputDecoration(labelText: 'Nombre')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _apellido,
                          decoration:
                              const InputDecoration(labelText: 'Apellido')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _email,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _password,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          onChanged: (v) {
                            // live-validate password strength
                            final label = _computePasswordStrengthLabel(v);
                            setState(() {
                              _passwordStrengthLabel = label;
                              _passwordError = null;
                            });
                          }),
                      const SizedBox(height: 6),
                      if (_passwordStrengthLabel.isNotEmpty)
                        Text('Fortaleza: $_passwordStrengthLabel',
                            style: TextStyle(
                                color: _passwordStrengthLabel == 'Fuerte'
                                    ? Colors.green
                                    : (_passwordStrengthLabel == 'Media'
                                        ? Colors.orange
                                        : Colors.red))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _confirm,
                          decoration: const InputDecoration(
                              labelText: 'Confirmar password'),
                          obscureText: true,
                          onChanged: (v) {
                            setState(() {
                              _confirmError = null;
                            });
                          }),
                      if (_passwordError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_passwordError!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      if (_confirmError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_confirmError!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _rol,
                        items: const [
                          DropdownMenuItem(
                              value: 'estudiante', child: Text('Estudiante')),
                          DropdownMenuItem(
                              value: 'profesor', child: Text('Profesor')),
                          DropdownMenuItem(
                              value: 'padre', child: Text('Padre')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _rol = v);
                        },
                        decoration: const InputDecoration(labelText: 'Rol'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue[200],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            elevation: 6,
                          ),
                          onPressed: _loading
                              ? null
                              : () async {
                                  // validate password and confirmation
                                  final pwd = _password.text.trim();
                                  final conf = _confirm.text.trim();
                                  final pwdErr = _validatePassword(pwd);
                                  String? confErr;
                                  if (conf != pwd)
                                    confErr = 'Las contraseñas no coinciden';
                                  if (pwdErr != null || confErr != null) {
                                    setState(() {
                                      _passwordError = pwdErr;
                                      _confirmError = confErr;
                                    });
                                    return;
                                  }

                                  setState(() => _loading = true);
                                  try {
                                    final resp = await ApiService.registro(
                                      _email.text.trim(),
                                      pwd,
                                      _nombre.text.trim(),
                                      _apellido.text.trim(),
                                      rol: _rol,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Registrado: ${resp['email'] ?? ''}')));
                                    Navigator.of(context).pop();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error registro: $e')));
                                  } finally {
                                    setState(() => _loading = false);
                                  }
                                },
                          child: _loading
                              ? const CircularProgressIndicator.adaptive()
                              : const Text('Crear cuenta',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (wide)
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.grey[50],
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Image.asset('assets/illustration.png',
                        fit: BoxFit.contain),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ]);
      }),
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }
}
