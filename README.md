# EduProjects - Cliente Flutter para API de Gestión de Proyectos Escolares

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

Para instrucciones completas de despliegue (local, Azure y recomendaciones de producción), consulta `DEPLOYMENT.md` en la raíz del repositorio.

### Despliegue con Docker (rápido)

Esta sección explica los pasos mínimos para levantar la aplicación completa (frontend web + backend API) usando `docker compose` desde la raíz del repositorio.

Requisitos: Docker y Docker Compose instalados en tu máquina.

1. Exporta un secreto JWT seguro en tu shell (o define un `.env` con `JWT_SECRET`):

```bash
export JWT_SECRET="cambia_esto_por_un_secreto_seguro"
```

2. Construir y levantar los servicios en background:

```bash
docker compose up --build -d
```

3. Verificar que los servicios están activos:

```bash
docker compose ps
```

4. Ver logs si algo falla:

```bash
docker compose logs -f api
docker compose logs -f eduprojects_web
```

5. Parar y eliminar contenedores (cuando quieras detenerlos):

```bash
docker compose down
```

Notas importantes:
- El frontend queda servido en `http://localhost` (puerto 80) y el backend en `http://localhost:8000`.
- El `docker-compose.yml` monta el volumen `api_data` para almacenamiento de archivos; la base de datos por defecto es SQLite (`./backend.db`). Para producción use PostgreSQL u otro servicio administrado.
- Si quieres publicar imágenes en un registry (Docker Hub, ACR), usa `docker build` con `-t` para etiquetar, luego `docker push`. Ejemplos en `DEPLOYMENT.md`.

Si necesitas, puedo añadir un bloque `Makefile` o scripts dentro del repo para simplificar estos comandos (`make up`, `make build-push`).


