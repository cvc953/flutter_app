class Project {
  final int id;
  final String titulo;
  final String? descripcion;
  final int? estudianteId;
  final int? cursoId;
  final bool esEstudianteAsignado;
  final int profesorId;
  final int versionActual;
  final String? fechaEntrega;

  Project({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.estudianteId,
    this.cursoId,
    this.esEstudianteAsignado = false,
    required this.profesorId,
    required this.versionActual,
    this.fechaEntrega,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      estudianteId: json['estudiante_id'] ?? json['estudianteId'],
      cursoId: json['curso_id'] ?? json['cursoId'],
      esEstudianteAsignado: json['es_estudiante_asignado'] == true ||
          (json['esEstudianteAsignado'] == true),
      profesorId: json['profesor_id'] ?? json['profesorId'] ?? 0,
      versionActual: json['version_actual'] ?? json['versionActual'] ?? 1,
      fechaEntrega: json['fecha_entrega'] != null
          ? json['fecha_entrega'].toString()
          : null,
    );
  }
}
