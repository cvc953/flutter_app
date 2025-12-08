# EduProjects

**EduProjects** es una plataforma completa de gestión educativa que facilita la administración de cursos, tareas, entregas y calificaciones para instituciones educativas. Esta solución full-stack combina un frontend Flutter moderno con un backend robusto en FastAPI.

## Descripción del Proyecto

EduProjects es una aplicación educativa integral diseñada para conectar estudiantes, profesores y padres de familia en un entorno digital de aprendizaje. La plataforma permite:

- **Gestión de Cursos**: Los profesores pueden crear y administrar cursos, agregar estudiantes y estructurar el contenido académico.
- **Asignación de Tareas**: Creación de tareas con archivos adjuntos (PDF) y seguimiento del progreso estudiantil.
- **Entregas de Trabajos**: Los estudiantes pueden subir múltiples versiones de sus entregas con versionamiento automático.
- **Calificaciones y Retroalimentación**: Sistema de evaluación con comentarios detallados para cada entrega.
- **Reportes Académicos**: Visualización de calificaciones y progreso para estudiantes y padres.
- **Sistema de Roles**: Acceso diferenciado para estudiantes, profesores y padres de familia.

## Arquitectura Técnica

### Frontend (Flutter)
El cliente Flutter proporciona una interfaz moderna y multiplataforma (web, móvil, escritorio) utilizando:
- **Arquitectura MVC**: Separación clara entre modelos, vistas y controladores.
- **Estado con Provider**: Gestión reactiva del estado de la aplicación.
- **Material Design**: Interfaz intuitiva y moderna con Google Fonts.
- **Comunicación HTTP**: Integración completa con la API REST del backend.

Estructura del código:
- `lib/models`: Modelos de datos (User, Project, Course, etc.)
- `lib/services`: Servicios de API y comunicación HTTP
- `lib/controllers`: Controladores de estado con ChangeNotifier
- `lib/views`: Vistas de usuario (Login, Home, Upload, etc.)
- `lib/widgets`: Componentes reutilizables

### Backend (FastAPI)
API REST construida con Python y FastAPI que proporciona:
- **Autenticación JWT**: Sistema seguro de tokens Bearer para autenticación.
- **Base de Datos**: SQLAlchemy con soporte para SQLite (desarrollo) y PostgreSQL (producción).
- **Almacenamiento de Archivos**: Sistema de gestión de archivos para entregas y adjuntos.
- **Validación de Datos**: Schemas con Pydantic para validación robusta.
- **Documentación Automática**: Swagger UI y ReDoc integrados.

Endpoints principales:
- `/auth`: Registro y autenticación de usuarios
- `/courses`: Gestión de cursos
- `/assignments`: Creación y administración de tareas
- `/submissions`: Entregas de estudiantes con versionamiento
- `/reports`: Reportes y calificaciones

## Inicio Rápido

### Ejecución Local

1. **Instalar Flutter SDK** si no lo tienes: https://flutter.dev/docs/get-started/install

2. **Instalar dependencias del frontend**:
```bash
flutter pub get
```

3. **Ejecutar la aplicación**:
```bash
flutter run
```

Para ejecutar el backend localmente:
```bash
cd backend
pip install -r requirements.txt
uvicorn backend.main:app --reload
```

### Ejecución con Docker (Recomendado)

La forma más rápida de ejecutar todo el stack completo es usando Docker Compose:

**Requisitos**: Docker y Docker Compose instalados.

1. **Exportar secreto JWT** (o crear archivo `.env`):
```bash
export JWT_SECRET="cambia_esto_por_un_secreto_seguro"
```

2. **Construir y levantar servicios**:
```bash
docker compose up --build -d
```

3. **Verificar que los servicios están activos**:
```bash
docker compose ps
```

**Acceso a la aplicación**:
- Frontend web: `http://localhost` (puerto 80)
- API backend: `http://localhost:8000`
- Documentación API: `http://localhost:8000/docs`

4. **Ver logs** (si algo falla):
```bash
docker compose logs -f api
docker compose logs -f eduprojects_web
```

5. **Detener servicios**:
```bash
docker compose down
```

## Configuración

### Variables de Entorno

- `DATABASE_URL`: URL de conexión a la base de datos (por defecto SQLite)
- `JWT_SECRET`: Secreto para firmar tokens JWT (requerido)
- `PORT`: Puerto del backend (por defecto 8000)

### Base de Datos

- **Desarrollo**: SQLite (`./backend.db`)
- **Producción**: PostgreSQL recomendado
  ```
  postgresql+psycopg://usuario:contraseña@host:5432/nombre_db
  ```

## Despliegue en Producción

Para instrucciones detalladas de despliegue en Azure, configuración de registries de contenedores, y mejores prácticas de producción, consulta `DEPLOYMENT.md`.

### Resumen rápido:

1. **Construir y etiquetar imágenes**:
```bash
docker build -f Dockerfile.web -t miregistry/eduprojects_web:latest .
docker build -f backend/Dockerfile -t miregistry/eduprojects_api:latest .
```

2. **Publicar al registry**:
```bash
docker push miregistry/eduprojects_web:latest
docker push miregistry/eduprojects_api:latest
```

## Estructura del Proyecto

```
.
├── lib/                    # Código fuente Flutter
│   ├── models/            # Modelos de datos
│   ├── views/             # Vistas de usuario
│   ├── controllers/       # Lógica de negocio
│   ├── services/          # Servicios de API
│   └── widgets/           # Componentes reutilizables
├── backend/               # Backend FastAPI
│   ├── routers/          # Rutas de la API
│   ├── models.py         # Modelos de base de datos
│   ├── schemas.py        # Schemas Pydantic
│   ├── main.py           # Punto de entrada
│   └── requirements.txt  # Dependencias Python
├── assets/               # Recursos estáticos
├── web/                  # Configuración web de Flutter
├── docker-compose.yml    # Orquestación de servicios
├── Dockerfile.web        # Dockerfile para frontend
└── pubspec.yaml         # Dependencias Flutter
```

## Tecnologías Utilizadas

### Frontend
- **Flutter** - Framework multiplataforma
- **Provider** - Gestión de estado
- **HTTP** - Comunicación con API
- **Material Design** - Diseño de interfaz
- **Google Fonts** - Tipografía

### Backend
- **FastAPI** - Framework web Python
- **SQLAlchemy** - ORM para base de datos
- **Pydantic** - Validación de datos
- **JWT** - Autenticación
- **Uvicorn** - Servidor ASGI

### DevOps
- **Docker** - Containerización
- **Docker Compose** - Orquestación
- **Nginx** - Servidor web para frontend

## Próximos Pasos y Mejoras

- [ ] Implementar autorización completa con JWT en todas las peticiones
- [ ] Añadir paginación en listados de cursos y tareas
- [ ] Migrar a PostgreSQL para producción
- [ ] Implementar almacenamiento en nube (Azure Blob Storage, S3)
- [ ] Añadir tests unitarios y de integración
- [ ] Implementar CI/CD con GitHub Actions o Azure Pipelines
- [ ] Añadir migraciones de base de datos con Alembic
- [ ] Mejorar manejo de errores y validaciones
- [ ] Implementar notificaciones en tiempo real
- [ ] Añadir vistas de detalle de proyectos con historial completo

## Contribuir

Este proyecto está en desarrollo activo. Para contribuir:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/NuevaFuncionalidad`)
3. Commit tus cambios (`git commit -m 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/NuevaFuncionalidad`)
5. Abre un Pull Request

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

## Soporte

Para preguntas, problemas o sugerencias, por favor abre un issue en el repositorio de GitHub.


