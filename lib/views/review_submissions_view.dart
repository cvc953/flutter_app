import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';
import '../theme.dart';

/// Vista para que los profesores revisen y califiquen entregas de estudiantes
class ReviewSubmissionsView extends StatefulWidget {
  const ReviewSubmissionsView({super.key});

  @override
  State<ReviewSubmissionsView> createState() => _ReviewSubmissionsViewState();
}

class _ReviewSubmissionsViewState extends State<ReviewSubmissionsView> {
  List<dynamic> _cursos = [];
  int? _selectedCursoId;
  Map<String, dynamic>? _entregasData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  Future<void> _loadCursos() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final profesorId = auth.user?.id;
    if (profesorId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cursos = await ApiService.cursosProfesor(profesorId);
      setState(() {
        _cursos = cursos;
        if (cursos.isNotEmpty) {
          _selectedCursoId = cursos[0]['id'] as int?;
        }
        _loading = false;
      });
      if (_selectedCursoId != null) {
        await _loadEntregas();
      }
    } catch (e) {
      setState(() {
        _error = 'Error cargando cursos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadEntregas() async {
    if (_selectedCursoId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.obtenerEntregasCurso(_selectedCursoId!);
      setState(() {
        _entregasData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando entregas: $e';
        _loading = false;
      });
    }
  }

  Future<void> _mostrarDialogoCalificar(
      int proyectoId, String tituloProyecto, String? nombreEstudiante) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final profesorId = auth.user?.id;
    if (profesorId == null) return;

    final puntajeCtl = TextEditingController();
    final comentariosCtl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Calificar: $tituloProyecto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nombreEstudiante != null)
                  Text('Estudiante: $nombreEstudiante',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: puntajeCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Puntaje (0.0 - 5.0)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comentariosCtl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Comentarios (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final puntajeText = puntajeCtl.text.trim();
                if (puntajeText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un puntaje')),
                  );
                  return;
                }
                final puntaje = double.tryParse(puntajeText);
                if (puntaje == null || puntaje < 0 || puntaje > 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Puntaje debe estar entre 0.0 y 5.0')),
                  );
                  return;
                }

                try {
                  await ApiService.calificarProyecto(
                    proyectoId: proyectoId,
                    profesorId: profesorId,
                    puntaje: puntaje,
                    comentarios: comentariosCtl.text.trim().isNotEmpty
                        ? comentariosCtl.text.trim()
                        : null,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Proyecto calificado')),
                  );
                  await _loadEntregas();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al calificar: $e')),
                  );
                }
              },
              child: const Text('Calificar'),
            ),
          ],
        );
      },
    );
  }

  void _descargarArchivo(int proyectoId, int versionId) {
    final url = ApiService.urlDescargarVersion(proyectoId, versionId);
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Entregas'),
        backgroundColor: AppColors.accent,
      ),
      body: Column(
        children: [
          // Selector de curso
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text('Curso: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: _cursos.isEmpty
                      ? const Text('No hay cursos disponibles')
                      : DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedCursoId,
                          items: _cursos.map((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'] as int?,
                              child: Text(c['nombre'] ?? 'Sin nombre'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCursoId = val;
                            });
                            _loadEntregas();
                          },
                        ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadEntregas,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadEntregas,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _entregasData == null
                        ? const Center(
                            child:
                                Text('Selecciona un curso para ver entregas'))
                        : _buildEntregasContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEntregasContent() {
    if (_entregasData == null) return const SizedBox.shrink();

    final entregas = _entregasData!['entregas'] as List<dynamic>? ?? [];
    if (entregas.isEmpty) {
      return const Center(
        child: Text('No hay entregas para este curso'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entregas.length,
      itemBuilder: (context, index) {
        final entrega = entregas[index] as Map<String, dynamic>;
        return _buildEntregaCard(entrega);
      },
    );
  }

  Widget _buildEntregaCard(Map<String, dynamic> entrega) {
    final proyectoId = entrega['proyecto_id'] as int?;
    final titulo = entrega['titulo'] as String? ?? 'Sin título';
    final estudiante = entrega['estudiante'] as Map<String, dynamic>?;
    final nombreEstudiante = estudiante != null
        ? estudiante['nombre_completo'] as String? ?? 'Desconocido'
        : 'Sin asignar';
    final emailEstudiante = estudiante?['email'] as String?;
    final calificacion = entrega['calificacion'] as Map<String, dynamic>?;
    final versiones = entrega['versiones'] as List<dynamic>? ?? [];
    final totalVersiones = entrega['total_versiones'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Estudiante: $nombreEstudiante'),
            if (emailEstudiante != null) Text('Email: $emailEstudiante'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  calificacion != null ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: calificacion != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  calificacion != null
                      ? 'Calificado: ${calificacion['puntaje']}/5.0'
                      : 'Sin calificar',
                  style: TextStyle(
                    color: calificacion != null ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text('Versiones: $totalVersiones'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (calificacion != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calificación: ${calificacion['puntaje']}/5.0',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        if (calificacion['comentarios'] != null)
                          Text('Comentarios: ${calificacion['comentarios']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Versiones subidas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (versiones.isEmpty)
                  const Text('No hay versiones subidas aún')
                else
                  ...versiones.map((v) {
                    final versionId = v['id'] as int?;
                    final numeroVersion = v['numero_version'] as int? ?? 0;
                    final descripcion = v['descripcion'] as String?;
                    final fechaSubida = v['fecha_subida'] as String?;
                    final esActual = v['es_version_actual'] as bool? ?? false;
                    final tieneArchivo = v['tiene_archivo'] as bool? ?? false;

                    return Card(
                      color: esActual ? Colors.blue[50] : null,
                      child: ListTile(
                        leading: Icon(
                          esActual ? Icons.star : Icons.folder,
                          color: esActual ? Colors.blue : null,
                        ),
                        title: Text('Versión $numeroVersion'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (descripcion != null)
                              Text('Descripción: $descripcion'),
                            if (fechaSubida != null)
                              Text('Fecha: ${fechaSubida.split('T')[0]}'),
                          ],
                        ),
                        trailing: tieneArchivo && versionId != null
                            ? IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: 'Descargar',
                                onPressed: () =>
                                    _descargarArchivo(proyectoId!, versionId),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: proyectoId != null
                      ? () => _mostrarDialogoCalificar(
                          proyectoId, titulo, nombreEstudiante)
                      : null,
                  icon: const Icon(Icons.grade),
                  label: Text(calificacion != null
                      ? 'Actualizar Calificación'
                      : 'Calificar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
