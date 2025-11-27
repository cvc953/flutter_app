import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';
import '../theme.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? report;

  // profesor mode
  List<dynamic> cursos = [];
  int? selectedCursoId;
  List<dynamic> estudiantes = [];
  int? selectedEstudianteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      final user = auth.user;
      if (user == null) throw Exception('Usuario no autenticado');

      final role = user.role?.toLowerCase() ?? 'estudiante';
      if (role == 'estudiante') {
        await _loadReportFor(user.id);
      } else if (role == 'profesor') {
        // load cursos
        cursos = await ApiService.cursosProfesor(user.id);
        if (cursos.isNotEmpty) {
          selectedCursoId = cursos[0]['id'] as int?;
          await _loadEstudiantesForCurso(selectedCursoId!);
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _loadReportFor(int estudianteId) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ApiService.obtenerReporteDesempeno(estudianteId);
      report = r;
    } catch (e) {
      error = e.toString();
      report = null;
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _loadEstudiantesForCurso(int cursoId) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      estudiantes = await ApiService.cursoEstudiantes(cursoId);
      // The API returns elements with estudiante_id or estudianteId; normalize
      if (estudiantes.isNotEmpty) {
        selectedEstudianteId = (estudiantes[0]['estudiante_id'] ??
            estudiantes[0]['estudianteId']) as int?;
        if (selectedEstudianteId != null)
          await _loadReportFor(selectedEstudianteId!);
      }
    } catch (e) {
      error = e.toString();
      estudiantes = [];
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _summaryCard(String title, String value, {String? subtitle}) {
    return Expanded(
        child: Card(
            child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.muted))
        ]
      ]),
    )));
  }

  Widget _barForScore(String label, double score) {
    final pct = (score / 5.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
            width: 140, child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(
            child: Stack(children: [
          Container(
              height: 20,
              decoration: BoxDecoration(
                  color: AppColors.bg, borderRadius: BorderRadius.circular(6))),
          FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6))))
        ])),
        const SizedBox(width: 8),
        SizedBox(
            width: 48,
            child: Text(score.toStringAsFixed(1), textAlign: TextAlign.right))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.user;
    final role = user?.role?.toLowerCase() ?? 'estudiante';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reportes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $error'))),
        if (!loading && role == 'profesor') ...[
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Seleccionar curso y estudiante',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                            value: selectedCursoId,
                            items: cursos
                                .map<DropdownMenuItem<int>>((c) =>
                                    DropdownMenuItem<int>(
                                        value: c['id'] as int?,
                                        child: Text(c['nombre'] ?? 'Curso')))
                                .toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              selectedCursoId = v;
                              await _loadEstudiantesForCurso(v);
                            },
                            decoration:
                                const InputDecoration(labelText: 'Curso'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: DropdownButtonFormField<int>(
                            value: selectedEstudianteId,
                            items: estudiantes.map<DropdownMenuItem<int>>((e) {
                              final id =
                                  e['estudiante_id'] ?? e['estudianteId'];
                              final nombre = e['nombre'] ??
                                  '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}';
                              return DropdownMenuItem<int>(
                                  value: id as int?,
                                  child: Text(nombre ?? 'Estudiante'));
                            }).toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              selectedEstudianteId = v;
                              await _loadReportFor(v);
                            },
                            decoration:
                                const InputDecoration(labelText: 'Estudiante'),
                          ))
                        ])
                      ]))),
          const SizedBox(height: 12)
        ],
        if (!loading && report != null) ...[
          // Summary cards
          Row(children: [
            _summaryCard(
                'Promedio', report!['promedio_calificaciones'].toString(),
                subtitle: 'media de calificaciones'),
            const SizedBox(width: 12),
            _summaryCard('Proyectos', report!['total_proyectos'].toString(),
                subtitle: 'total')
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _summaryCard('Aprobados', report!['proyectos_aprobados'].toString(),
                subtitle: '${report!['tasa_aprobacion']}% tasa'),
            const SizedBox(width: 12),
            _summaryCard('Versiones', report!['total_versiones'].toString(),
                subtitle: 'total versiones')
          ]),
          const SizedBox(height: 18),
          const Text('Detalle de proyectos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    if (report!['detalle_proyectos'] != null &&
                        (report!['detalle_proyectos'] as List).isNotEmpty)
                      ...((report!['detalle_proyectos'] as List)
                          .map<Widget>((d) {
                        final titulo =
                            d['titulo_proyecto'] ?? d['titulo'] ?? 'Proyecto';
                        final cal = (d['calificacion'] ?? 0).toDouble();
                        return _barForScore(titulo, cal);
                      }).toList())
                    else
                      const Text('No hay proyectos con calificación aún')
                  ])))
        ] else if (!loading && report == null) ...[
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No hay datos de reporte')))
        ]
      ]),
    );
  }
}
