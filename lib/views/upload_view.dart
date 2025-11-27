import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/project_controller.dart';

class UploadView extends StatefulWidget {
  const UploadView({super.key});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  File? _file;
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  List<dynamic> _courses = [];
  int? _selectedCourseId;
  bool _loading = false;
  String? _coursesFetchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCourses());
  }

  Future<void> _loadCourses() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    try {
      final cursos = await ApiService.cursosProfesor(user.id);
      setState(() => _courses = cursos);
      if (_courses.isNotEmpty) {
        setState(() => _selectedCourseId = _courses[0]['id'] as int?);
      }
    } catch (e) {
      setState(() => _coursesFetchError = e.toString());
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
              controller: _titulo,
              decoration: const InputDecoration(labelText: 'Título')),
          TextField(
              controller: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción')),
          const SizedBox(height: 8),
          // If professor, show a dropdown to choose a course (or create one)
          Builder(builder: (ctx) {
            final auth = Provider.of<AuthController>(ctx);
            final role = auth.user?.role?.toLowerCase();
            if (role == 'profesor') {
              if (_courses.isEmpty) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_coursesFetchError != null
                      ? 'Error al cargar cursos: $_coursesFetchError'
                      : 'No hay cursos cargados'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                      onPressed: () async {
                        final nombreCtl = TextEditingController();
                        await showDialog<void>(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                title: const Text('Crear curso'),
                                content: TextField(
                                    controller: nombreCtl,
                                    decoration: const InputDecoration(
                                        labelText: 'Nombre del curso')),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () async {
                                        final nombre = nombreCtl.text.trim();
                                        if (nombre.isEmpty) return;
                                        try {
                                          final auth =
                                              Provider.of<AuthController>(
                                                  context,
                                                  listen: false);
                                          final profesorId = auth.user?.id;
                                          if (profesorId == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'No se pudo obtener el ID del profesor')));
                                            return;
                                          }
                                          await ApiService.crearCurso(nombre,
                                              profesorId: profesorId);
                                          Navigator.pop(context);
                                          await _loadCourses();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('Curso creado')));
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Error creando curso: $e')));
                                        }
                                      },
                                      child: const Text('Crear'))
                                ],
                              );
                            });
                      },
                      child: const Text('Crear curso')),
                ]);
              }
              return DropdownButtonFormField<int>(
                value: _selectedCourseId,
                items: _courses
                    .map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(
                        value: c['id'] as int?,
                        child: Text(c['nombre'] ?? 'curso')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCourseId = v),
                decoration: const InputDecoration(labelText: 'Curso'),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: pickFile, child: const Text('Seleccionar archivo')),
          if (_file != null) Text('Archivo: ${_file!.path.split('/').last}'),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        final auth =
                            Provider.of<AuthController>(context, listen: false);
                        final pc = Provider.of<ProjectController>(context,
                            listen: false);
                        final user = auth.user;
                        if (user == null)
                          throw Exception('Debes iniciar sesión');
                        final role = user.role?.toLowerCase();
                        if (role == 'profesor') {
                          // Profesor puede crear/ asignar proyecto a un curso
                          final cid = _selectedCourseId ?? 0;
                          if (cid == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Selecciona un curso')));
                            setState(() => _loading = false);
                            return;
                          }
                          final created = await ApiService.crearProyecto(
                              _titulo.text,
                              _descripcion.text,
                              cid,
                              user.id,
                              null,
                              _file,
                              'Primera versión');
                          // cargar de nuevo proyectos del profesor
                          await pc.loadProjectsForProfessor(user.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Creado: ${created['id']}')));
                          Navigator.of(context).pop();
                        } else if (role == 'estudiante') {
                          // Estudiantes no deben crear proyectos desde aquí; indicar uso de la vista de proyecto asignado
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Los estudiantes solo pueden subir versiones en proyectos que les hayan sido asignados. Usa la vista de proyecto.')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Acción no permitida para este rol')));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      } finally {
                        setState(() => _loading = false);
                      }
                    },
              child: _loading
                  ? const CircularProgressIndicator.adaptive()
                  : const Text('Subir'))
        ]),
      ),
    );
  }
}
