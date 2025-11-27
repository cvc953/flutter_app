import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_proyectos_app/services/api_service.dart';

void main() {
  test('ApiService baseUrl is set and token handling works', () {
    expect(ApiService.baseUrl.isNotEmpty, true);
    ApiService.setToken('abc123');
    // Nothing to assert about private headers, but ensure no crash when setting token
    ApiService.setToken(null);
  });
}
