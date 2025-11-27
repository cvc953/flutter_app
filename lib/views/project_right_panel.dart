import 'package:flutter/material.dart';
// dart:io is not available on web; avoid using it directly in this file.

import 'package:provider/provider.dart';
import '../controllers/selected_project_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';
import '../theme.dart';

class ProjectRightPanel extends StatefulWidget {
  final int proyectoId;
  const ProjectRightPanel({super.key, required this.proyectoId});

  @override
  State<ProjectRightPanel> createState() => _ProjectRightPanelState();
}

class _ProjectRightPanelState extends State<ProjectRightPanel> {
  Map<String, dynamic>? proyecto;
  List<dynamic> versiones = [];
  List<dynamic> calificaciones = [];
  bool loading = false;
  bool esEstudianteAsignado = false;
  final TextEditingController _commentCtl = TextEditingController();
  // staging area for selected file before sending
  PlatformFile? _stagedFile;
  final TextEditingController _stagedDescCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // load initial data
    _loadAll();
    // subscribe to selection changes so we reload even when the same id is
    // selected again (SelectedProjectController may notify listeners with the
    // same id). This ensures the panel refreshes after actions like grading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final sel =
            Provider.of<SelectedProjectController>(context, listen: false);
        sel.addListener(_onSelectionChanged);
      } catch (_) {}
    });
  }

  void _onSelectionChanged() {
    try {
      final sel =
          Provider.of<SelectedProjectController>(context, listen: false);
      final id = sel.selectedId;
      // If the controller reports selection of the same project id as this
      // panel, reload contents. If a different id was selected, the parent
      // will recreate/didUpdateWidget will handle it.
      if (id != null && id == widget.proyectoId) {
        _loadAll();
      }
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    // Debug: indicate which proyectoId we're loading
    // ignore: avoid_print
    print('[ProjectRightPanel] _loadAll start proyectoId=${widget.proyectoId}');
    setState(() => loading = true);
    try {
      proyecto = await ApiService.obtenerProyecto(widget.proyectoId);
      versiones = await ApiService.obtenerVersiones(widget.proyectoId);
      calificaciones =
          await ApiService.obtenerCalificacionesProyecto(widget.proyectoId);
      // Determinar si el estudiante está asignado
      // CONFIAR COMPLETAMENTE EN EL FLAG DEL SERVIDOR
      final auth = Provider.of<AuthController>(context, listen: false);
      final userId = auth.user?.id ?? 0;
      bool assigned = false;

      if (proyecto != null && auth.user?.role == 'estudiante') {
        // El servidor SIEMPRE devuelve es_estudiante_asignado cuando hay token
        // Si es true -> el estudiante puede subir
        // Si es false -> el estudiante NO puede subir
        // Si es null -> no hay token o no es estudiante (no debería pasar)
        final flagServidor = proyecto?['es_estudiante_asignado'];
        print(
            '[DEBUG FRONTEND] proyecto.es_estudiante_asignado = $flagServidor');
        print('[DEBUG FRONTEND] proyecto.curso_id = ${proyecto?['curso_id']}');
        print(
            '[DEBUG FRONTEND] proyecto.estudiante_id = ${proyecto?['estudiante_id']}');

        if (flagServidor != null) {
          assigned = flagServidor == true;
        }
        print('[DEBUG FRONTEND] assigned = $assigned');
      }
      // Profesores siempre pueden (aunque aquí no controla eso)
      esEstudianteAsignado = assigned;
    } catch (e) {
      // keep empty, show message in UI
    } finally {
      setState(() => loading = false);
      // ignore: avoid_print
      print(
          '[ProjectRightPanel] _loadAll done proyectoId=${widget.proyectoId} - proyecto=${proyecto?['id'] ?? 'null'}');
    }
  }

  Future<void> _downloadUrl(String url) async {
    final uri = Uri.parse(url);
    // Use url_launcher
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _selectFile() async {
    // just pick and stage the file, do not upload yet
    try {
      // Ensure we request file bytes on web by using withData: true
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) return; // cancelled
      setState(() {
        _stagedFile = result.files.single;
        _stagedDescCtl.text = '';
      });
      // show quick confirmation so user sees the file was picked
      final f = result.files.single;
      int size = f.size;
      if (size == 0) size = f.bytes?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Archivo seleccionado: ${f.name} • $size bytes')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error seleccionando: $e')));
    }
  }

  Future<void> _uploadStaged() async {
    if (_stagedFile == null) return;
    setState(() => loading = true);
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Subiendo entrega...')));

      // Usar el nuevo endpoint de entregas (Moodle-style)
      final resp = await ApiService.entregarAsignacion(
          widget.proyectoId,
          _stagedDescCtl.text.trim().isEmpty
              ? 'Nueva entrega'
              : _stagedDescCtl.text.trim(),
          _stagedFile);

      await _loadAll();
      setState(() {
        _stagedFile = null;
        _stagedDescCtl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Entrega enviada (v${resp['numero_version'] ?? '?'})')));
    } catch (e) {
      // ignore: avoid_print
      print('Error uploading staged file: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error enviando entrega: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  void _cancelStaged() {
    setState(() {
      _stagedFile = null;
      _stagedDescCtl.clear();
    });
  }

  Future<void> _sendComment() async {
    final text = _commentCtl.text.trim();
    if (text.isEmpty) return;
    // For now append as a pseudo-comment locally. In the future we can post to an endpoint.
    setState(() {
      calificaciones.insert(0, {
        'puntaje': '',
        'comentarios': text,
        'fecha_calificacion': DateTime.now().toIso8601String(),
        'autor': 'Profesor'
      });
      _commentCtl.clear();
    });
  }

  @override
  void didUpdateWidget(covariant ProjectRightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proyectoId != widget.proyectoId) {
      // the parent passed a new proyectoId -> clear view and reload
      setState(() {
        proyecto = null;
        versiones = [];
        calificaciones = [];
        esEstudianteAsignado = false;
        _stagedFile = null;
      });
      // ignore: avoid_print
      print(
          '[ProjectRightPanel] proyectoId changed ${oldWidget.proyectoId} -> ${widget.proyectoId}');
      _loadAll();
    }
  }

  @override
  void dispose() {
    try {
      final sel =
          Provider.of<SelectedProjectController>(context, listen: false);
      sel.removeListener(_onSelectionChanged);
    } catch (_) {}
    _commentCtl.dispose();
    _stagedDescCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final role = auth.user?.role?.toLowerCase() ?? '';

    return Container(
      decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
      padding: const EdgeInsets.all(12),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : proyecto == null
              ? const Center(
                  child: Text('Seleccione un proyecto para ver detalles'))
              : SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + status badge
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(proyecto!['titulo'] ?? 'Proyecto',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(proyecto!['descripcion'] ?? '',
                                        style: const TextStyle(
                                            color: AppColors.muted))
                                  ])),
                              const SizedBox(width: 8),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                      color: AppColors.accent600,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: const Text('En revisión',
                                      style: TextStyle(color: Colors.white)))
                            ]),
                        const SizedBox(height: 12),
                        // Preview box
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                              child: Icon(Icons.insert_drive_file,
                                  color: Colors.white70, size: 48)),
                        ),
                        const SizedBox(height: 18),
                        const Text('Historial de versiones',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Column(
                          children: versiones.map<Widget>((v) {
                            final path =
                                v['archivo_path'] ?? v['archivo'] ?? '';
                            final name = path.toString().split('/').last;
                            final date = (v['fecha_subida'] ?? v['fecha'] ?? '')
                                .toString()
                                .split('T')
                                .first;
                            return ListTile(
                              dense: true,
                              title: Row(children: [
                                Text('v${v['numero_version']} — ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Expanded(child: Text(name))
                              ]),
                              trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(date,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted)),
                                    IconButton(
                                        onPressed: () {
                                          final url =
                                              '${ApiService.baseUrl}/proyectos/${widget.proyectoId}/versiones/${v['id']}/archivo';
                                          _downloadUrl(url);
                                        },
                                        icon: const Icon(Icons.download))
                                  ]),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        // Upload drop area or button (always available to students)
                        if (role == 'estudiante') ...[
                          // If no staged file, show picker prompt
                          if (_stagedFile == null)
                            GestureDetector(
                              onTap: _selectFile,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.muted,
                                        style: BorderStyle.solid,
                                        width: 1),
                                    color: AppColors.bg),
                                child: Column(children: const [
                                  Text(
                                      'Arrastra y suelta el archivo aquí o clic para seleccionar.',
                                      textAlign: TextAlign.center),
                                  SizedBox(height: 6),
                                  Text('Soporta: pdf, docx, zip — Máx 50MB',
                                      style: TextStyle(
                                          fontSize: 12, color: AppColors.muted))
                                ]),
                              ),
                            )
                          else
                            // Show staged file with description and send/cancel
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(children: [
                                      Row(children: [
                                        const Icon(Icons.insert_drive_file),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                '${_stagedFile?.name ?? ''} • ${_stagedFile?.size ?? 0} bytes'))
                                      ]),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _stagedDescCtl,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Descripción de la versión (opcional)'),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                                onPressed: _cancelStaged,
                                                child: const Text('Cancelar')),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                                onPressed: _uploadStaged,
                                                child: const Text('Enviar'))
                                          ])
                                    ]))),
                          const SizedBox(height: 12)
                        ],
                        const Text('Comentarios',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: _commentCtl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      hintText: 'Escribe un comentario...'))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _sendComment,
                              child: const Text('Enviar'))
                        ]),
                        const SizedBox(height: 12),
                        const Text('Últimos comentarios:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Column(
                            children: calificaciones.map<Widget>((c) {
                          final autor = c['autor'] ??
                              (c['profesor_id'] != null
                                  ? 'Profesor'
                                  : 'Estudiante');
                          final fecha =
                              (c['fecha_calificacion'] ?? c['fecha'] ?? '')
                                  .toString()
                                  .split('T')
                                  .first;
                          return ListTile(
                              leading: const Icon(Icons.comment),
                              title: Text(autor),
                              subtitle:
                                  Text('${c['comentarios'] ?? ''} • $fecha'));
                        }).toList())
                      ]),
                ),
    );
  }
}
