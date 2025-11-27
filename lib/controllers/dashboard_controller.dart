import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/project.dart';

class DashboardController extends ChangeNotifier {
  bool loading = false;
  Map<String, dynamic>? desempeno;
  List<Project> proyectos = [];
  List<dynamic> proximasEntregas = [];
  List<dynamic> comentariosRecientes = [];
  // Map curso_id -> nombre
  Map<int, String> cursoNames = {};
  // Map proyecto_id -> ultima version info
  Map<int, dynamic> ultimaVersion = {};

  /// Reset dashboard state (used on logout)
  void clear() {
    loading = false;
    desempeno = null;
    proyectos = [];
    proximasEntregas = [];
    comentariosRecientes = [];
    notifyListeners();
  }

  Future<void> loadForStudent(int studentId) async {
    loading = true;
    notifyListeners();
    try {
      desempeno = await ApiService.obtenerReporteDesempeno(studentId);
      final projs = await ApiService.proyectosEstudiante(studentId);
      // Map JSON -> Project
      final mapped = projs.map<Project>((j) => Project.fromJson(j)).toList();
      // Defensive filtering: if the server doesn't provide esEstudianteAsignado
      // or estudianteId, consult the curso->estudiantes endpoint to verify
      // enrollment. Cache curso responses to avoid duplicate requests.
      final Map<int, List<dynamic>> _cursoCache = {};
      final List<Project> confirmed = [];
      for (var p in mapped) {
        if (p.esEstudianteAsignado) {
          confirmed.add(p);
          continue;
        }
        if (p.estudianteId != null && p.estudianteId == studentId) {
          confirmed.add(p);
          continue;
        }
        // If cursoId is available, check enrollment
        if (p.cursoId != null) {
          try {
            final cid = p.cursoId!;
            if (!_cursoCache.containsKey(cid)) {
              final lista = await ApiService.cursoEstudiantes(cid);
              _cursoCache[cid] = lista;
            }
            final lista = _cursoCache[cid]!;
            final enrolled = lista.any((e) =>
                (e['estudiante_id'] ?? e['id'] ?? e['estudianteId']) ==
                studentId);
            if (enrolled) confirmed.add(p);
          } catch (_) {
            // If the curso lookup fails, be conservative and skip this project
          }
        }
      }
      proyectos = confirmed;
      // próximas entregas: tomar fecha_entrega de proyectos con fecha
      proximasEntregas = proyectos
          .where((p) => p.fechaEntrega != null)
          .map((p) => {
                'titulo': p.titulo,
                'fecha_entrega': p.fechaEntrega,
              })
          .toList();
      // comentarios recientes: usar calificaciones del estudiante
      comentariosRecientes =
          await ApiService.obtenerCalificacionesEstudiante(studentId);

      // If the backend did not provide a promedio_calificaciones, compute it
      // locally from the student's califications. We assume puntaje is on a
      // 0.0-5.0 scale; convert to percentage (0-100).
      try {
        if (desempeno == null ||
            desempeno?['promedio_calificaciones'] == null) {
          final califs = comentariosRecientes;
          double sum = 0.0;
          int count = 0;
          for (var c in califs) {
            // puntaje might come as number or string
            final raw =
                c['puntaje'] ?? c['score'] ?? c['puntaje_val'] ?? c['valor'];
            if (raw == null) continue;
            double? val;
            if (raw is num)
              val = raw.toDouble();
            else {
              val = double.tryParse(raw.toString().replaceAll(',', '.'));
            }
            if (val == null) continue;
            sum += val;
            count += 1;
          }
          if (count > 0) {
            final avg = sum / count; // average on 0-5 scale
            final percent = ((avg / 5.0) * 100).round();
            desempeno = {'promedio_calificaciones': percent};
          } else {
            desempeno ??= {'promedio_calificaciones': 0};
          }
        }
      } catch (_) {}
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForProfessor(int professorId) async {
    loading = true;
    notifyListeners();
    try {
      // Load professor courses to map cursoId -> nombre
      try {
        final cursos = await ApiService.cursosProfesor(professorId);
        cursoNames = {
          for (var c in cursos) (c['id'] as int): (c['nombre'] ?? '') as String
        };
      } catch (_) {
        cursoNames = {};
      }

      final projs = await ApiService.proyectosProfesor(professorId);
      proyectos = projs.map<Project>((j) => Project.fromJson(j)).toList();
      // derive comments from project califications and fetch latest version per project
      comentariosRecientes = [];
      ultimaVersion = {};
      for (var p in proyectos) {
        final cals = await ApiService.obtenerCalificacionesProyecto(p.id);
        comentariosRecientes.addAll(cals);
        try {
          final vers = await ApiService.obtenerVersiones(p.id);
          if (vers.isNotEmpty) {
            // prefer es_version_actual, otherwise take highest numero_version
            var actual = vers.firstWhere((v) => v['es_version_actual'] == true,
                orElse: () => null);
            if (actual == null) {
              vers.sort((a, b) => (b['numero_version'] ?? 0)
                  .compareTo(a['numero_version'] ?? 0));
              actual = vers.first;
            }
            ultimaVersion[p.id] = actual;
          }
        } catch (_) {
          // ignore per-project version fetch errors
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
