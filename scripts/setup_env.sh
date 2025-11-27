#!/usr/bin/env bash
set -euo pipefail

# Script para inicializar variables de entorno en .env a partir de .env.example
# - Crea un backup de .env si ya existe
# - Copia .env.example -> .env
# - Genera un JWT_SECRET aleatorio (hex 64) y lo inserta en .env

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE="$ROOT_DIR/.env.example"
DEST="$ROOT_DIR/.env"

if [ ! -f "$EXAMPLE" ]; then
  echo "Error: $EXAMPLE no encontrado. Crea primero .env.example o pasa tu propio .env." >&2
  exit 1
fi

if [ -f "$DEST" ]; then
  BACKUP="$DEST.bak.$(date +%s)"
  echo "Backup: existe $DEST — creando copia en $BACKUP"
  cp "$DEST" "$BACKUP"
fi

echo "Copiando $EXAMPLE -> $DEST"
cp "$EXAMPLE" "$DEST"

# Generar secreto seguro (openssl disponible en la mayoría de imágenes/hosts)
if command -v openssl >/dev/null 2>&1; then
  SECRET=$(openssl rand -hex 32)
else
  # Fallback a Python si no hay openssl
  if command -v python3 >/dev/null 2>&1; then
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  else
    echo "Error: neither openssl nor python3 available to generate a secret" >&2
    exit 1
  fi
fi

# Insertar o reemplazar JWT_SECRET en el .env
if grep -qE '^JWT_SECRET=' "$DEST"; then
  sed -i"" -E "s/^JWT_SECRET=.*/JWT_SECRET=${SECRET}/" "$DEST" 2>/dev/null || sed -i -E "s/^JWT_SECRET=.*/JWT_SECRET=${SECRET}/" "$DEST"
else
  echo "JWT_SECRET=${SECRET}" >> "$DEST"
fi

echo "Archivo .env creado/actualizado: $DEST"
echo "JWT_SECRET generado (longitud hex): ${#SECRET} caracteres"
echo "Revisa $DEST y no lo subas a git."
