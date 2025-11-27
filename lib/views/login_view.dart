import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 800;
        return SafeArea(
          child: SingleChildScrollView(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 40),
                          color: Colors.white,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: _buildLoginForm(auth),
                            ),
                          ),
                        ),
                      ),
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
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    color: Colors.white,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildLoginForm(auth),
                      ),
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildLoginForm(AuthController auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ready to start your success story?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Ingresa para ver tus proyectos, subir versiones y recibir retroalimentación de tus profesores.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true),
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
                    setState(() => _loading = true);
                    try {
                      await auth.login(
                          _email.text.trim(), _password.text.trim());
                      if (auth.isLoggedIn) {
                        Navigator.of(context)
                            .pushReplacementNamed('/dashboard');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Login failed: $e')));
                    } finally {
                      setState(() => _loading = false);
                    }
                  },
            child: _loading
                ? const CircularProgressIndicator.adaptive()
                : const Text('Entrar',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterView()));
            },
            child: const Text('Registrarse'),
          ),
        )
      ],
    );
  }
}
