import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme.dart';
import '../controllers/project_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../controllers/selected_project_controller.dart';

class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key});

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  Map<int, String> _lastFileName = {};
  Map<int, String> _lastFileDate = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthController>(context, listen: false);
      final pc = Provider.of<ProjectController>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        final role = user.role?.toLowerCase();
        if (role == 'estudiante') {
          await pc.loadProjectsForStudent(user.id);
        } else if (role == 'profesor') {
          await pc.loadProjectsForProfessor(user.id);
        }
      }
    });
  }

  Future<void> _createProjectDialog(
      BuildContext context, int profesorId) async {
    final tituloCtl = TextEditingController();
    final descCtl = TextEditingController();
    DateTime? fechaEntrega;
    File? archivo;

    Future<void> _pickFile() async {
      final res = await FilePicker.platform.pickFiles();
      if (res != null && res.files.single.path != null) {
        archivo = File(res.files.single.path!);
      }
    }

    // Fetch cursos del profesor antes de mostrar el dialog
    List<dynamic> cursos = [];
    String? fetchError;
    try {
      cursos = await ApiService.cursosProfesor(profesorId);
    } catch (e) {
      cursos = [];
      fetchError = e.toString();
    }

    int? selectedCursoId =
        cursos.isNotEmpty ? (cursos[0]['id'] as int?) ?? null : null;

    await showDialog<void>(
        context: context,
        builder: (_) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text('Asignar nuevo proyecto'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: tituloCtl,
                      decoration: const InputDecoration(labelText: 'Titulo')),
                  TextField(
                      controller: descCtl,
                      decoration:
                          const InputDecoration(labelText: 'Descripcion')),
                  const SizedBox(height: 8),
                  if (cursos.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedCursoId,
                      items: cursos
                          .map<DropdownMenuItem<int>>((c) =>
                              DropdownMenuItem<int>(
                                  value: c['id'] as int?,
                                  child: Text(c['nombre'] ?? 'curso')))
                          .toList(),
                      onChanged: (v) => setState(() => selectedCursoId = v),
                      decoration: const InputDecoration(labelText: 'Curso'),
                    )
                  else
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(fetchError != null
                          ? 'Error al cargar cursos: $fetchError'
                          : 'No se encontraron cursos para este profesor'),
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
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancelar')),
                                      TextButton(
                                          onPressed: () async {
                                            final nombre =
                                                nombreCtl.text.trim();
                                            if (nombre.isEmpty) return;
                                            try {
                                              await ApiService.crearCurso(
                                                  nombre,
                                                  profesorId: profesorId);
                                              Navigator.pop(context);
                                              final nuevos = await ApiService
                                                  .cursosProfesor(profesorId);
                                              setState(() {
                                                cursos = nuevos;
                                                selectedCursoId = (nuevos
                                                        .isNotEmpty
                                                    ? nuevos[0]['id'] as int?
                                                    : null);
                                              });
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Curso creado')));
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
                          child: const Text('Crear curso'))
                    ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(
                        onPressed: _pickFile,
                        child: const Text('Adjuntar archivo (opcional)')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          fechaEntrega = DateTime(now.year, now.month, now.day)
                              .add(const Duration(days: 7));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Fecha entrega predeterminada: +7 días')));
                        },
                        child: const Text('Fijar +7d'))
                  ])
                ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () async {
                      final titulo = tituloCtl.text.trim();
                      final desc = descCtl.text.trim();
                      final cid = selectedCursoId ?? 0;
                      if (titulo.isEmpty || cid == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Titulo y Curso obligatorios')));
                        return;
                      }
                      try {
                        // Usar el nuevo endpoint de asignaciones (Moodle-style)
                        await ApiService.crearAsignacion(titulo, desc, cid,
                            profesorId, fechaEntrega, archivo, null);
                        Navigator.pop(context);
                        final pc = Provider.of<ProjectController>(context,
                            listen: false);
                        await pc.loadProjectsForProfessor(profesorId);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Asignación creada al estilo Moodle')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error creando asignación: $e')));
                      }
                    },
                    child: const Text('Asignar'))
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final pc = Provider.of<ProjectController>(context);
    final auth = Provider.of<AuthController>(context);
    final user = auth.user;
    final role = user?.role?.toLowerCase() ?? 'estudiante';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Proyectos activos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Row(children: [
            if (role == 'profesor')
              ElevatedButton(
                  onPressed: () => _createProjectDialog(context, user!.id),
                  child: const Text('+ Nuevo Proyecto')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () {}, child: const Text('Exportar'))
          ])
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: pc.loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          // header row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(children: [
                              const Expanded(flex: 3, child: Text('Proyecto')),
                              Expanded(
                                  flex: 2,
                                  child: Text('Materia',
                                      style:
                                          TextStyle(color: AppColors.muted))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Última entrega',
                                      style:
                                          TextStyle(color: AppColors.muted))),
                              Expanded(
                                  flex: 1,
                                  child: Text('Estado',
                                      style:
                                          TextStyle(color: AppColors.muted))),
                              SizedBox(
                                  width: 140,
                                  child: Text('Acciones',
                                      style: TextStyle(color: AppColors.muted)))
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                              child: ListView.builder(
                                  itemCount: pc.projects.length,
                                  itemBuilder: (ctx, i) {
                                    final p = pc.projects[i];
                                    final materia = p.descripcion ?? '-';
                                    final lastName = _lastFileName[p.id] ?? '';
                                    final lastDate = _lastFileDate[p.id] ?? '';

                                    // lazy load last file info
                                    if (!_lastFileName.containsKey(p.id)) {
                                      pc.getVersions(p.id).then((vers) {
                                        if (vers.isNotEmpty) {
                                          final actual = vers.firstWhere(
                                              (v) =>
                                                  v['es_version_actual'] ==
                                                  true,
                                              orElse: () => vers.first);
                                          final path = actual['archivo_path'] ??
                                              actual['archivo'] ??
                                              '';
                                          final name =
                                              path.toString().split('/').last;
                                          final date = actual['fecha_subida'] ??
                                              actual['fecha'] ??
                                              '';
                                          setState(() {
                                            _lastFileName[p.id] = name;
                                            _lastFileDate[p.id] = date != null
                                                ? date
                                                    .toString()
                                                    .split('T')
                                                    .first
                                                : '';
                                          });
                                        }
                                      }).catchError((_) {});
                                      _lastFileName[p.id] = '';
                                    }

                                    final estado = 'Pendiente';

                                    return InkWell(
                                      onTap: () => Provider.of<
                                                  SelectedProjectController>(
                                              context,
                                              listen: false)
                                          .select(p.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 8),
                                        decoration: const BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: Colors.grey,
                                                    width: 0.12))),
                                        child: Row(children: [
                                          Expanded(
                                              flex: 3,
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(p.titulo,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                        'v${p.versionActual} • ${p.id}',
                                                        style: TextStyle(
                                                            color:
                                                                AppColors.muted,
                                                            fontSize: 12))
                                                  ])),
                                          Expanded(
                                              flex: 2, child: Text(materia)),
                                          Expanded(
                                              flex: 2,
                                              child: Text(lastName.isNotEmpty
                                                  ? '$lastName • $lastDate'
                                                  : '-')),
                                          Expanded(
                                              flex: 1,
                                              child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 6,
                                                      horizontal: 8),
                                                  decoration: BoxDecoration(
                                                      color: Colors
                                                          .orangeAccent,
                                                      borderRadius: BorderRadius
                                                          .circular(12)),
                                                  child: Center(
                                                      child: Text(estado,
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      12))))),
                                          SizedBox(
                                              width: 140,
                                              child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    if (role == 'profesor')
                                                      IconButton(
                                                          tooltip: 'Calificar',
                                                          onPressed: () async {
                                                            final scoreCtl =
                                                                TextEditingController();
                                                            final commentCtl =
                                                                TextEditingController();
                                                            await showDialog<
                                                                    void>(
                                                                context:
                                                                    context,
                                                                builder: (ctx) {
                                                                  return AlertDialog(
                                                                    title: const Text(
                                                                        'Calificar proyecto'),
                                                                    content: Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          TextField(
                                                                              controller: scoreCtl,
                                                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                                              decoration: const InputDecoration(labelText: 'Puntaje (0.0 - 5.0)')),
                                                                          TextField(
                                                                              controller: commentCtl,
                                                                              decoration: const InputDecoration(labelText: 'Comentarios (opcional)'))
                                                                        ]),
                                                                    actions: [
                                                                      TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              ctx),
                                                                          child:
                                                                              const Text('Cancelar')),
                                                                      TextButton(
                                                                          onPressed:
                                                                              () async {
                                                                            final raw =
                                                                                scoreCtl.text.trim();
                                                                            final val =
                                                                                double.tryParse(raw.replaceAll(',', '.'));
                                                                            if (val == null ||
                                                                                val < 0 ||
                                                                                val > 5) {
                                                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puntaje inválido (0.0 - 5.0)')));
                                                                              return;
                                                                            }
                                                                            Navigator.pop(ctx);
                                                                            try {
                                                                              await pc.submitGrade(p.id, user!.id, val, commentCtl.text.trim());
                                                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proyecto calificado')));
                                                                              // refresh right panel
                                                                              Provider.of<SelectedProjectController>(context, listen: false).select(p.id);
                                                                            } catch (e) {
                                                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al calificar: $e')));
                                                                            }
                                                                          },
                                                                          child:
                                                                              const Text('Enviar'))
                                                                    ],
                                                                  );
                                                                });
                                                          },
                                                          icon: const Icon(Icons
                                                              .how_to_reg)),
                                                    IconButton(
                                                        onPressed: () => Provider
                                                                .of<SelectedProjectController>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                            .select(p.id),
                                                        icon: const Icon(
                                                            Icons.visibility)),
                                                    IconButton(
                                                        onPressed: () async {
                                                          final url =
                                                              '${ApiService.baseUrl}/proyectos/${p.id}/archivo';
                                                          await launchUrlString(
                                                              url);
                                                        },
                                                        icon: const Icon(
                                                            Icons.download))
                                                  ]))
                                        ]),
                                      ),
                                    );
                                  }))
                        ]))))
      ]),
    );
  }
}
