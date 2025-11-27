class User {
  final int id;
  final String email;
  final String? role;
  final String? nombre;
  final String? apellido;
  final String? nombreCompleto;

  User({
    required this.id,
    required this.email,
    this.role,
    this.nombre,
    this.apellido,
    this.nombreCompleto,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre'] as String?;
    final apellido = json['apellido'] as String?;
    return User(
      id: json['id'],
      email: json['email'],
      role: (json['rol'] ?? json['role']) as String?,
      nombre: nombre,
      apellido: apellido,
      nombreCompleto: json['nombre_completo'] as String? ??
          ((nombre != null || apellido != null)
              ? '${nombre ?? ''} ${apellido ?? ''}'.trim()
              : null),
    );
  }
}
