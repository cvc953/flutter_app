# Flutter client para API de Gestión de Proyectos Escolares

Este es un scaffold mínimo (arquitectura MVC simple) para un cliente Flutter que consume la API que se encuentra en `app/`.

Supuestos importantes:
- La API corre en `http://localhost:8000` (ajusta `ApiService.baseUrl` si es distinto).
- En desarrollo puedes usar el plugin de Flutter en Android/iOS o `flutter run -d linux` si tu entorno lo permite.

Estructura creada:
- `lib/models`: modelos ligeros (`User`, `Project`).
- `lib/services/api_service.dart`: llamadas HTTP (login, listar proyectos, crear proyecto, subir versión, obtener versiones, calificaciones).
- `lib/controllers`: controladores (AuthController, ProjectController) usando `ChangeNotifier`.
- `lib/views`: vistas mínimas (`LoginView`, `HomeView`, `UploadView`).
- `pubspec.yaml`: dependencias `http`, `provider`.

Cómo ejecutar (local):
1. Asegúrate de tener Flutter SDK instalado.
2. Desde `flutter_app/` instala dependencias:

```bash
cd flutter_app
flutter pub get
```

3. Corre la app en el emulador o dispositivo:

```bash
flutter run
```

Notas y próximos pasos recomendados:
- Añadir manejo de JWT en llamadas (header Authorization: Bearer ...). Actualmente el token se obtiene pero no se incluye en requests.
- Implementar paginación y manejo de errores clave.
- Añadir vistas de detalle de proyecto para ver historial y descargar archivos.
- Añadir tests unitarios y de integración.

## Despliegue

Para instrucciones completas de despliegue (local, Docker, Azure y recomendaciones de producción), consulta `DEPLOYMENT.md` en la raíz del repositorio.


