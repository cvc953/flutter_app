import 'package:flutter/material.dart';
import 'dart:io';
import '../models/project.dart';
import '../services/api_service.dart';

class ProjectController extends ChangeNotifier {
  List<Project> _projects = [];
  List<Project> get projects => _projects;

  bool loading = false;

  /// Clear cached projects and reset state (used on logout)
  void clear() {
    _projects = [];
    loading = false;
    notifyListeners();
  }

  Future<void> loadProjectsForStudent(int studentId) async {
    loading = true;
    notifyListeners();
    final resp = await ApiService.proyectosEstudiante(studentId);
    // Map JSON to Project and defensively filter to only projects
    // that the current student is assigned to. The backend SHOULD
    // already return assigned projects, but this protects the UI
    // in case the server returns extra items.
    final mapped = resp.map<Project>((j) => Project.fromJson(j)).toList();
    _projects = mapped.where((p) {
      if (p.esEstudianteAsignado) return true;
      if (p.estudianteId != null && p.estudianteId == studentId) return true;
      return false;
    }).toList();
    loading = false;
    notifyListeners();
  }

  Future<void> loadProjectsForProfessor(int professorId) async {
    loading = true;
    notifyListeners();
    final resp = await ApiService.proyectosProfesor(professorId);
    _projects = resp.map<Project>((j) => Project.fromJson(j)).toList();
    loading = false;
    notifyListeners();
  }

  Future<List<dynamic>> getVersions(int proyectoId) async {
    return await ApiService.obtenerVersiones(proyectoId);
  }

  Future<List<dynamic>> getGrades(int proyectoId) async {
    return await ApiService.obtenerCalificacionesProyecto(proyectoId);
  }

  Future<Map<String, dynamic>> submitGrade(int proyectoId, int profesorId,
      double puntaje, String? comentarios) async {
    return await ApiService.calificar(
        proyectoId, profesorId, puntaje, comentarios);
  }

  Future<Map<String, dynamic>> uploadVersion(
      int proyectoId, String descripcion, File? archivo) async {
    return await ApiService.subirVersion(proyectoId, descripcion, archivo);
  }
}
