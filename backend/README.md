# Backend FastAPI - Plataforma Educativa

Este backend provee la API para gestionar usuarios (estudiante, profesor, padre), cursos, tareas, entregas y reportes de calificaciones.

## Endpoints Principales

- Autenticación (`/auth/register`, `/auth/login`) JWT tipo Bearer
- Cursos (`/courses`) crear/listar y agregar estudiantes (profesor)
- Tareas (`/assignments`) crear con PDF adjunto, listar, descargar adjunto
- Entregas (`/submissions`) subir múltiples versiones, descargar por profesor, calificar y comentar
- Reportes (`/reports`) ver calificaciones y últimas entregas

## Roles
- `student`: sube entregas y ve sus reportes
- `teacher`: crea cursos, asigna tareas, califica y revisa entregas
- `parent`: puede ver reportes del hijo vinculado

## Ejecución Local

```bash
# Instalar dependencias
pip install -r backend/requirements.txt

# Ejecutar servidor
uvicorn backend.main:app --reload
```

## Docker (solo backend)

```bash
# Construir imagen
docker build -f backend/Dockerfile -t eduprojects_api:latest .

# Ejecutar contenedor
docker run -p 8000:8000 eduprojects_api:latest
```

Con `docker-compose` (frontend web + backend API):

```bash
docker compose up --build
```

Frontend quedará en `http://localhost` y API en `http://localhost:8000`.

## Deploy en Azure (App Service + Azure Container Registry)

1. Crear grupo de recursos y ACR:
```bash
az group create -n edu-plataforma-rg -l eastus
az acr create -n eduplataformaacr -g edu-plataforma-rg --sku Basic
az acr login -n eduplataformaacr
```
2. Etiquetar y subir imágenes:
```bash
ACR=eduplataformaacr.azurecr.io
docker build -f backend/Dockerfile -t $ACR/eduprojects_api:latest .
docker build -t $ACR/eduprojects_web:latest .
docker push $ACR/eduprojects_api:latest
docker push $ACR/eduprojects_web:latest
```
3. Crear App Service plano (Linux):
```bash
az appservice plan create -n edu-plataforma-plan -g edu-plataforma-rg --sku B1 --is-linux
```
4. Opción A (una sola imagen API):
```bash
az webapp create -n edu-plataforma-api -g edu-plataforma-rg -p edu-plataforma-plan --deployment-container-image-name $ACR/plataforma_api:latest
```
   Configurar variables:
```bash
az webapp config appsettings set -n edu-plataforma-api -g edu-plataforma-rg --settings DATABASE_URL="sqlite:///./backend.db" JWT_SECRET="<secreto>"
```

5. Opción B Multi-contenedor (Compose): crear `azure-docker-compose.yml` con servicios y subirlo (requiere SKU soportado):
```bash
az webapp create -n edu-plataforma-app -g edu-plataforma-rg -p edu-plataforma-plan --multicontainer-config-type compose --multicontainer-config-file docker-compose.yml
```

## Variables de Entorno
- `DATABASE_URL` (por defecto SQLite) sustituir por PostgreSQL en producción: `postgresql+psycopg://user:pass@host:5432/db`.
- `JWT_SECRET` secreto JWT.

## Persistencia
Actualmente SQLite dentro del contenedor. Para producción usar servicio administrado (Azure PostgreSQL) y montar volumen si se necesita almacenamiento de archivos o usar Azure Blob Storage.

## Next Steps
- Migraciones con Alembic
- Azure Blob Storage para archivos (entregas y PDFs)
- Paginación y filtros
- Rate limiting y CORS
- Tests automáticos CI/CD

