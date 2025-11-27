import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_proyectos_app/models/user.dart';

void main() {
  test('User.fromJson prefers "rol" field and builds nombreCompleto', () {
    final data = {
      'id': 1,
      'email': 'a@b.com',
      'rol': 'profesor',
      'nombre': 'Juan',
      'apellido': 'Perez'
    };
    final u = User.fromJson(data);
    expect(u.id, 1);
    expect(u.email, 'a@b.com');
    expect(u.role, 'profesor');
    expect(u.nombreCompleto, 'Juan Perez');
  });

  test('User.fromJson reads "role" when "rol" absent', () {
    final data = {'id': 2, 'email': 'x@y.com', 'role': 'estudiante'};
    final u = User.fromJson(data);
    expect(u.role, 'estudiante');
  });
}
