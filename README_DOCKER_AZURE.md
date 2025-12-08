# Despliegue con Docker en una VM de Azure

Este documento explica cómo crear una imagen Docker de la app Flutter (web) y desplegarla en una máquina virtual en Azure. La configuración incluida compila la app a `build/web` y la sirve con nginx.

Archivos añadidos:
- `Dockerfile` — multi-stage: compila con Flutter y sirve con nginx.
- `.dockerignore` — reduce el contexto del build.
- `nginx.conf` — configuración para SPA y cacheo de assets.
- `docker-compose.yml` — orquesta el contenedor localmente.

1) Construir y probar localmente


Construir la imagen localmente:

```bash
cd /ruta/al/proyecto
docker build -t eduprojects_web:latest .
```

Ejecutar la imagen:

```bash
docker run -d --name eduprojects_web -p 80:80 eduprojects_web:latest
```

O con docker-compose:

```bash
docker-compose up --build -d
```

2) Pasos rápidos para desplegar en una VM de Azure (Ubuntu)

- Crear una VM (Ubuntu 22.04 LTS). Desde portal o Azure CLI.
- SSH a la VM.

Instalar Docker y Docker Compose:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# (Opcional) permitir usar docker sin sudo para el usuario actual
sudo usermod -aG docker $USER
```

Si prefieres desplegar la imagen desde un registry (Docker Hub, ACR):

```bash
# En tu máquina local
docker build -t myregistry/eduprojects_web:latest .
docker push myregistry/eduprojects_web:latest

# En la VM
docker pull myregistry/eduprojects_web:latest
docker run -d --name eduprojects_web -p 80:80 --restart unless-stopped myregistry/eduprojects_web:latest
```

3) (Opcional) Unit systemd para gestión como servicio

Guardar `/etc/systemd/system/eduprojects_web.service` con:

```ini
[Unit]
Description=EduProjects App (Docker container)
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run --rm --name eduprojects_web -p 80:80 myregistry/eduprojects_web:latest
ExecStop=/usr/bin/docker stop -t 10 eduprojects_web

[Install]
WantedBy=multi-user.target
```

Recargar systemd y habilitar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now eduprojects_web.service
```

4) Notas y recomendaciones

- El `Dockerfile` usa Flutter para compilar web. Si prefieres compilar fuera del contenedor y subir sólo artefactos, ajusta el Dockerfile para copiar `build/web` directamente.
- Para entornos de producción y seguridad: habilita HTTPS (certbot + nginx reverse proxy o un load balancer); configura firewall/NSG en Azure para permitir sólo el puerto necesario.
- Alternativas: usar Azure App Service para contenedores o Azure Container Instances / Azure Container Apps para un despliegue sin servidor.

Si quieres que también prepare un artefacto para ejecutar la app nativa de Linux en la VM (no web), dímelo y preparo un Dockerfile alternativo o instrucciones de empaquetado.