import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';

class CoursesView extends StatefulWidget {
  const CoursesView({super.key});

  @override
  State<CoursesView> createState() => _CoursesViewState();
}

class _CoursesViewState extends State<CoursesView> {
  List<dynamic> _courses = [];
  Map<int, List<dynamic>> _students = {};
  Map<int, bool> _loadingStudents = {};
  Map<int, String> _studentQuery = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCourses());
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;
    if (user == null || user.role != 'profesor') {
      setState(() {
        _loading = false;
        _courses = [];
      });
      return;
    }
    try {
      final cursos = await ApiService.cursosProfesor(user.id);
      setState(() {
        _courses = cursos;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadStudentsForCourse(int cursoId) async {
    setState(() {
      _loadingStudents[cursoId] = true;
      _error = null;
    });
    try {
      final studs = await ApiService.cursoEstudiantes(cursoId);
      setState(() {
        _students[cursoId] = studs;
        _studentQuery[cursoId] = '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingStudents[cursoId] = false;
      });
    }
  }

  Future<void> _addStudent(int cursoId) async {
    // Fetch all students and let user pick from dropdown
    List<dynamic> studs = [];
    try {
      studs = await ApiService.obtenerEstudiantes();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching estudiantes: $e')));
      return;
    }

    int? sel = studs.isNotEmpty ? (studs[0]['id'] as int?) : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return AlertDialog(
              title: const Text('Agregar estudiante'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Curso seleccionado: #$cursoId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (studs.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: sel,
                      items:
                          studs.map<DropdownMenuItem<int>>((s) {
                            final id = s['id'] ?? s['estudiante_id'];
                            final nombre =
                                '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}';
                            final email = s['email'] ?? '';
                            return DropdownMenuItem<int>(
                              value: id as int?,
                              child: Text('$nombre • $email • #${id}'),
                            );
                          }).toList(),
                      onChanged: (v) => setState(() => sel = v),
                      decoration: const InputDecoration(
                        labelText: 'Estudiante',
                      ),
                    )
                  else
                    const Text('No hay estudiantes registrados'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (sel == null) return;
                    try {
                      await ApiService.agregarEstudianteACurso(cursoId, sel!);
                      Navigator.pop(ctx2);
                      await _loadStudentsForCourse(cursoId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Estudiante agregado correctamente'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeStudent(int cursoId, int estudianteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Eliminar estudiante'),
          content: const Text('¿Confirmas eliminar al estudiante del curso?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await ApiService.eliminarEstudianteACurso(cursoId, estudianteId);
      await _loadStudentsForCourse(cursoId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estudiante eliminado')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.user;

    if (user == null) {
      return const Center(child: Text('Debes iniciar sesión'));
    }

    if (user.role != 'profesor') {
      return const Center(child: Text('Esta vista es solo para profesores'));
    }

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mis cursos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final auth = Provider.of<AuthController>(
                    context,
                    listen: false,
                  );
                  final user = auth.user;
                  if (user == null) return;
                  if (_courses.isEmpty) await _loadCourses();
                  List<dynamic> studs = [];
                  try {
                    studs = await ApiService.obtenerEstudiantes();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error fetching estudiantes: $e')),
                    );
                    return;
                  }

                  int? selCurso =
                      _courses.isNotEmpty ? _courses[0]['id'] as int? : null;
                  int? selEst =
                      studs.isNotEmpty ? (studs[0]['id'] as int?) : null;

                  await showDialog<void>(
                    context: context,
                    builder: (ctx) {
                      return StatefulBuilder(
                        builder: (ctx2, setState) {
                          return AlertDialog(
                            title: const Text('Agregar estudiante a curso'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_courses.isNotEmpty)
                                  DropdownButtonFormField<int>(
                                    value: selCurso,
                                    items:
                                        _courses
                                            .map<DropdownMenuItem<int>>(
                                              (c) => DropdownMenuItem<int>(
                                                value: c['id'] as int?,
                                                child: Text(
                                                  c['nombre'] ?? 'Curso',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(() => selCurso = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Curso',
                                    ),
                                  )
                                else
                                  const Text('No hay cursos disponibles'),
                                const SizedBox(height: 8),
                                if (studs.isNotEmpty)
                                  DropdownButtonFormField<int>(
                                    value: selEst,
                                    items:
                                        studs.map<DropdownMenuItem<int>>((s) {
                                          final id =
                                              s['id'] ?? s['estudiante_id'];
                                          final nombre =
                                              '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}';
                                          final email = s['email'] ?? '';
                                          return DropdownMenuItem<int>(
                                            value: id as int?,
                                            child: Text(
                                              '$nombre • $email • #${id}',
                                            ),
                                          );
                                        }).toList(),
                                    onChanged:
                                        (v) => setState(() => selEst = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Estudiante',
                                    ),
                                  )
                                else
                                  const Text('No hay estudiantes registrados'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx2),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (selCurso == null || selEst == null)
                                    return;
                                  try {
                                    await ApiService.agregarEstudianteACurso(
                                      selCurso!,
                                      selEst!,
                                    );
                                    Navigator.pop(ctx2);
                                    await _loadStudentsForCourse(selCurso!);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Estudiante agregado'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error agregando estudiante: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar estudiante'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const Center(child: CircularProgressIndicator()),
          _error != null ? Text('Error: ${_error}') : const SizedBox.shrink(),
          Expanded(
            child:
                _courses.isEmpty
                    ? const Center(
                      child: Text(
                        'No tienes cursos. Crea uno desde tu perfil.',
                      ),
                    )
                    : ListView.builder(
                      itemCount: _courses.length,
                      itemBuilder: (ctx, i) {
                        final c = _courses[i];
                        final cid = c['id'] as int;
                        final nombre = c['nombre'] ?? 'Curso';
                        final desc = c['descripcion'] ?? '';
                        final fecha = c['fecha_creacion'] ?? '';
                        final studs = _students[cid];
                        final loadingStud = _loadingStudents[cid] ?? false;
                        // Students list and actions per course
                        final query = _studentQuery[cid] ?? '';
                        List<dynamic> displayed = studs ?? [];
                        if (query.isNotEmpty) {
                          final q = query.toLowerCase();
                          displayed =
                              displayed.where((s) {
                                final n =
                                    (s['nombre'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final a =
                                    (s['apellido'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final e =
                                    (s['email'] ?? '').toString().toLowerCase();
                                return n.contains(q) ||
                                    a.contains(q) ||
                                    e.contains(q) ||
                                    s['estudiante_id'].toString().contains(q);
                              }).toList();
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ExpansionTile(
                            title: Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(desc),
                            childrenPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Creado: $fecha',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed:
                                            () => _loadStudentsForCourse(cid),
                                        icon: const Icon(Icons.group),
                                        label: const Text('Cargar estudiantes'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _addStudent(cid),
                                        icon: const Icon(Icons.person_add),
                                        label: const Text('Agregar estudiante'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Search field for students in this course
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: TextField(
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText:
                                        'Buscar por nombre, apellido, email o ID',
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _studentQuery[cid] = v.trim();
                                    });
                                  },
                                ),
                              ),
                              if (loadingStud)
                                const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (studs != null && studs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text('El curso no tiene estudiantes'),
                                ),
                              if (studs != null && displayed.isNotEmpty)
                                ...displayed.map<Widget>((s) {
                                  final sid =
                                      s['estudiante_id'] ?? s['id'] ?? 0;
                                  final nombre = s['nombre'] ?? '';
                                  final apellido = s['apellido'] ?? '';
                                  final email = s['email'] ?? '';
                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text('$nombre $apellido'),
                                    subtitle: Text('ID: $sid • $email'),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _removeStudent(cid, sid),
                                    ),
                                  );
                                }).toList(),
                              if (studs != null && displayed.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text(
                                    'No hay estudiantes que coincidan con la búsqueda',
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
