# Despliegue (Deployment)

Esta guía describe cómo desplegar la aplicación completa (frontend Flutter y backend FastAPI) en varios entornos: localmente, con Docker (docker-compose) y opcionalmente en Azure o un registry de contenedores. Está escrita en español y busca ser práctica para desarrolladores y para entornos de producción básicos.

## Resumen de la arquitectura
- Frontend: app Flutter (compila a `build/web` para la versión web). Se sirve con `nginx` en el contenedor `eduprojects_web`.
- Backend: API FastAPI (puerto `8000`) en el contenedor `api`.
- Orquestación local: `docker-compose.yml` en la raíz crea ambos servicios.

## Requisitos previos
- Git
- Docker (20.10+)
- Docker Compose (v2 plugin o `docker-compose` compatible)
- Si vas a ejecutar la app nativamente: Flutter SDK instalado.
- Python 3.11 si deseas ejecutar el backend localmente fuera de Docker.

## Variables de entorno importantes
- `DATABASE_URL`: cadena de conexión a la base de datos. Por defecto `sqlite:///./backend.db`.
- `JWT_SECRET`: secreto para firmar tokens JWT.
- `PORT`: puerto para el backend (por defecto `8000`).

Consejo: usa un fichero `.env` en tu entorno local (no subas credenciales a git) y exporta `JWT_SECRET` antes de ejecutar `docker compose`.

## Ejecución local (sin Docker)

1. Preparar el backend

```bash
# desde la raíz del repo
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# ejecutar servidor de desarrollo
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

El backend quedará disponible en `http://localhost:8000`.

2. Ejecutar el frontend (modo desarrollo)

```bash
cd ../
flutter pub get
flutter run
```

Por defecto el `ApiService` apunta a `http://localhost:8000`. Ajusta `lib/services/api_service.dart` si fuera necesario.

## Ejecutar con Docker (recomendado para pruebas de integración)

Este repo incluye `docker-compose.yml` y un `Dockerfile.web` para el frontend web y `backend/Dockerfile` para la API.

1) Construir y levantar con `docker compose` (desde la raíz):

```bash
# asegúrate de exportar JWT_SECRET en tu shell o usar .env
export JWT_SECRET="cambialo_por_un_secreto_seguro"

# construir y levantar en background
docker compose up --build -d
```

Servicios expuestos:
- Frontend: `http://localhost` (puerto 80)
- Backend: `http://localhost:8000`

2) Inspección y logs

```bash
docker compose ps
docker compose logs -f api
docker compose logs -f eduprojects_web
```

3) Volúmenes y persistencia

El `docker-compose.yml` define el volumen `api_data` montado en `/app/backend/storage` para conservar archivos subidos. La base de datos por defecto es SQLite (`./backend.db`) — si quieres persistencia durable y escalable en producción, usa PostgreSQL u otro servicio externo.

## Notas sobre `backend/entrypoint.sh` y SQLite

El `entrypoint.sh` ajusta permisos para directorios de almacenamiento y archivos SQLite cuando el contenedor arranca. Si usas `DATABASE_URL` apuntando a un fichero dentro del contenedor, el script intentará establecer la propiedad a `appuser`.

Si cambias a PostgreSQL, establece `DATABASE_URL` así:

```
postgresql+psycopg://user:password@host:5432/dbname
```

Y asegúrate de configurar el firewall y crear la base de datos y usuario antes del despliegue.

## Despliegue en un registry / producción (resumen rápido)

1) Construir y etiquetar imágenes (ejemplo Docker Hub o ACR):

```bash
# desde la raíz
docker build -f Dockerfile.web -t myregistry/eduprojects_web:latest .
docker build -f backend/Dockerfile -t myregistry/eduprojects_api:latest .
docker push myregistry/eduprojects_web:latest
docker push myregistry/eduprojects_api:latest
```

2) En la máquina de producción (VM, servidor o servicio de contenedores):

```bash
docker pull myregistry/eduprojects_web:latest
docker pull myregistry/eduprojects_api:latest
docker run -d --name eduprojects_web -p 80:80 myregistry/eduprojects_web:latest
docker run -d --name eduprojects_api -p 8000:8000 \
  -e DATABASE_URL="<tu-db>" -e JWT_SECRET="<secreto>" myregistry/eduprojects_api:latest
```

O bien usar `docker compose` con el `docker-compose.yml` (ajústalo para apuntar a las imágenes del registry si quieres).

## Despliegue en Azure (resumen)

Este repo incluye instrucciones específicas en `README_DOCKER_AZURE.md` y `backend/README.md`. Resumen rápido:

- Usar Azure Container Registry (ACR) para subir imágenes.
- Usar Azure App Service para contenedores o desplegar en una VM Ubuntu con Docker.
- Alternativa: usar un servicio de Kubernetes/Container Apps para orquestación.

Comandos útiles (ACR):

```bash
az acr login -n <acr-name>
docker tag eduprojects_api:latest <acr-name>.azurecr.io/eduprojects_api:latest
docker push <acr-name>.azurecr.io/eduprojects_api:latest
```

Luego crear un App Service o VM y apuntar al contenedor. Para App Service, configura variables de aplicación (`DATABASE_URL`, `JWT_SECRET`) desde `az webapp config appsettings set`.

## Migraciones y almacenamiento de archivos

- Actualmente no se indican migraciones automáticas (Alembic) — recomendado añadir Alembic para PostgreSQL en producción.
- Para archivos (tareas, entregas) considerar usar un servicio de blobs (Azure Blob Storage, S3) en lugar de almacenar en el contenedor.

## Troubleshooting (problemas comunes)

- El frontend no conecta con la API: verifica `ApiService.baseUrl` y que la API esté escuchando en `0.0.0.0:8000`.
- Permisos en archivos subidos: revisa logs del contenedor `api` y el `entrypoint.sh` que ajusta ownership a `appuser`.
- SQLite en contenedor efímero: si ves pérdida de datos, cambia a volumen externo o DB administrada.
- Error de `connect_args` o `sqlite` en SQLAlchemy: revisa que `DATABASE_URL` comience con `sqlite` para activar `check_same_thread`.

## CI/CD (sugerencias)

- Pipeline: compilar artefacto web con Flutter en CI, construir imagen Docker y publicar en registry.
- Tests: ejecutar `flutter test` y tests de backend (si existen) en el pipeline antes de publicar.
- Seguridad: escanear imágenes con herramientas como Trivy y usar secrets en el pipeline (no en el código).

## Recursos adicionales y próximos pasos

- Añadir `Makefile` o scripts para simplificar comandos comunes (`make build`, `make up`, `make push`).
- Añadir `azure-pipelines.yml`, GitHub Actions o similar para CI/CD automatizado.
- Añadir Alembic para migraciones de DB y configurar backup para la base de datos.

---

Si quieres, puedo:
- Generar un `Makefile` con comandos para build/compose/push.
- Añadir un `azure-pipelines.yml` o `.github/workflows/ci.yml` de ejemplo.
- Preparar scripts para backup o migraciones con Alembic.

Dime cuál de estas tareas quieres que haga a continuación.
