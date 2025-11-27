import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool loading = false;
  int proyectosCount = 0;

  Future<void> _loadCounts() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    setState(() => loading = true);
    try {
      if (user.role?.toLowerCase() == 'estudiante') {
        final projs = await ApiService.proyectosEstudiante(user.id);
        proyectosCount = projs.length;
      } else if (user.role?.toLowerCase() == 'profesor') {
        final projs = await ApiService.proyectosProfesor(user.id);
        proyectosCount = projs.length;
      } else {
        proyectosCount = 0;
      }
    } catch (_) {
      proyectosCount = 0;
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _createCourseDialog() async {
    final ctl = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Crear curso'),
            content: TextField(
                controller: ctl,
                decoration:
                    const InputDecoration(labelText: 'Nombre del curso')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () async {
                    final nombre = ctl.text.trim();
                    if (nombre.isEmpty) return;
                    try {
                      final auth =
                          Provider.of<AuthController>(context, listen: false);
                      final profesorId = auth.user?.id;
                      if (profesorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No se pudo obtener el ID del profesor')));
                        return;
                      }
                      final resp = await ApiService.crearCurso(nombre,
                          profesorId: profesorId);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Curso creado: ${resp['id'] ?? ''}')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creando curso: $e')));
                    }
                  },
                  child: const Text('Crear'))
            ],
          );
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.user;
    final role = user?.role?.toLowerCase() ?? 'usuario';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(
                  'https://api.dicebear.com/6.x/bottts/svg?seed=${user?.email ?? 'me'}')),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${user?.email ?? 'Usuario'}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(role[0].toUpperCase() + role.substring(1),
                style: const TextStyle(color: Color(0xFF6B7280)))
          ])
        ]),
        const SizedBox(height: 24),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  ListTile(
                      title: const Text('ID'),
                      subtitle: Text('${user?.id ?? ''}')),
                  ListTile(
                      title: const Text('Correo'),
                      subtitle: Text(user?.email ?? '')),
                  ListTile(
                      title: const Text('Proyectos asignados'),
                      subtitle: Text('$proyectosCount')),
                  Row(children: [
                    ElevatedButton(
                        onPressed: () {},
                        child: const Text('Editar perfil',
                            style: TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () {},
                        child: const Text('Cambiar contraseña'))
                  ])
                ]))),
        const SizedBox(height: 16),
        if (role == 'profesor')
          ElevatedButton(
              onPressed: () => _createCourseDialog(),
              child: const Text('Crear curso',
                  style: TextStyle(color: Colors.white)))
      ]),
    );
  }
}
