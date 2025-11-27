import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ProjectDetailView extends StatefulWidget {
  final int proyectoId;
  const ProjectDetailView({super.key, required this.proyectoId});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  List<dynamic> versiones = [];
  List<dynamic> calificaciones = [];
  Map<String, dynamic>? proyecto;
  bool loading = false;
  bool esEstudianteAsignado = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      proyecto = await ApiService.obtenerProyecto(widget.proyectoId);
      versiones = await ApiService.obtenerVersiones(widget.proyectoId);
      calificaciones =
          await ApiService.obtenerCalificacionesProyecto(widget.proyectoId);
      // Determine if the current user (student) is assigned to this project
      final auth = Provider.of<AuthController>(context, listen: false);
      final userId = auth.user?.id ?? 0;
      bool assigned = false;
      if (proyecto != null) {
        // SIEMPRE usar el flag del servidor si existe
        if (proyecto!['es_estudiante_asignado'] != null) {
          assigned = proyecto!['es_estudiante_asignado'] == true;
        }
        // Fallback si no hay flag del servidor
        else if (proyecto!['curso_id'] != null) {
          try {
            final lista =
                await ApiService.cursoEstudiantes(proyecto!['curso_id']);
            assigned = lista.any(
                (e) => (e['estudiante_id'] ?? e['estudianteId']) == userId);
          } catch (_) {
            assigned = false;
          }
        } else if (proyecto!['estudiante_id'] != null) {
          assigned = proyecto!['estudiante_id'] == userId;
        }
      }
      esEstudianteAsignado = assigned;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error cargando: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final f = File(result.files.single.path!);
      // ask for description
      final desc = await showDialog<String?>(
          context: context,
          builder: (_) {
            final ctl = TextEditingController();
            return AlertDialog(
              title: const Text('Descripción de la versión'),
              content: TextField(controller: ctl),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(context, ctl.text.trim()),
                    child: const Text('OK'))
              ],
            );
          });
      try {
        await ApiService.subirVersion(
            widget.proyectoId, desc ?? 'Nueva versión', f);
        await _loadAll();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Versión subida')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error subiendo: $e')));
      }
    }
  }

  Future<void> _downloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo abrir URL')));
    }
  }

  Future<void> _showGradeDialog(int proyectoId, int profesorId) async {
    final puntCtl = TextEditingController();
    final comCtl = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Calificar proyecto'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: puntCtl,
                  decoration:
                      const InputDecoration(labelText: 'Puntaje (0.0 - 5.0)')),
              TextField(
                  controller: comCtl,
                  decoration: const InputDecoration(labelText: 'Comentarios')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () async {
                    final p = double.tryParse(puntCtl.text) ?? 0.0;
                    try {
                      await ApiService.calificar(
                          proyectoId, profesorId, p, comCtl.text.trim());
                      Navigator.pop(context);
                      await _loadAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proyecto calificado')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al calificar: $e')));
                    }
                  },
                  child: const Text('Enviar'))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final role = auth.user?.role?.toLowerCase() ?? 'estudiante';
    final userId = auth.user?.id ?? 0;
    // esEstudianteAsignado computed during _loadAll (covers curso membership)
    return Scaffold(
      appBar: AppBar(
          title: Text(proyecto != null
              ? proyecto!['titulo'] ?? 'Proyecto'
              : 'Proyecto'),
          actions: [
            if (role == 'profesor')
              IconButton(
                  tooltip: 'Descargar versión actual',
                  onPressed: () {
                    final url =
                        '${ApiService.baseUrl}/proyectos/${widget.proyectoId}/archivo';
                    _downloadUrl(url);
                  },
                  icon: const Icon(Icons.download))
          ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (proyecto != null) ...[
                      Text(proyecto!['descripcion'] ?? '',
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                    ],
                    const Text('Versiones',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (var v in versiones)
                      Card(
                        child: ListTile(
                          title: Text(
                              'v${v['numero_version']} — ${v['descripcion'] ?? ''}'),
                          subtitle: Text('${v['fecha_subida'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              final url =
                                  '${ApiService.baseUrl}/proyectos/${widget.proyectoId}/versiones/${v['id']}/archivo';
                              _downloadUrl(url);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text('Calificaciones',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (calificaciones.isEmpty)
                      const Text('Sin calificaciones aún'),
                    for (var c in calificaciones)
                      Card(
                        child: ListTile(
                          title:
                              Text('Puntaje: ${c['puntaje'] ?? c['puntaje']}'),
                          subtitle: Text(
                              '${c['comentarios'] ?? ''} — ${c['fecha'] ?? c['fecha_calificacion'] ?? ''}'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (role == 'estudiante')
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir nueva versión'),
                          onPressed: _pickAndUpload,
                        ),
                      ),
                    if (role == 'profesor')
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.rate_review),
                          label: const Text('Calificar proyecto'),
                          onPressed: () =>
                              _showGradeDialog(widget.proyectoId, userId),
                        ),
                      ),
                  ]),
            ),
    );
  }
}
