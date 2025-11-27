#!/bin/sh
set -e

# Ensure storage folders and DB file are writable by appuser
DEFAULT_DIRS="/app/backend/storage/assignments /app/backend/storage/submissions"
for d in $DEFAULT_DIRS; do
  if [ -d "$d" ]; then
    chown -R appuser:appuser "$d" || true
  else
    mkdir -p "$d" && chown -R appuser:appuser "$d" || true
  fi
done

# If sqlite DB exists at /app/backend.db ensure ownership
if [ -f "/app/backend.db" ]; then
  chown appuser:appuser /app/backend.db || true
fi

# If DATABASE_URL points to sqlite file inside container, change ownership
if [ -n "$DATABASE_URL" ] && echo "$DATABASE_URL" | grep -q "sqlite"; then
  # Extract path portion after sqlite: (handles sqlite:///relative and sqlite:////absolute)
  # Use a simple safe sed to strip the prefix and any leading slashes
  path=$(echo "$DATABASE_URL" | sed 's|^sqlite:/*||')
  echo "[entrypoint] detected sqlite path: $path" >&2
  if [ -n "$path" ]; then
    # If the path is absolute after removing prefix, keep as-is; otherwise assume inside /app
    case "$path" in
      /*) abspath="$path" ;;
      *) abspath="/app/$path" ;;
    esac
    echo "[entrypoint] resolved sqlite absolute path: $abspath" >&2
    if [ -f "$abspath" ]; then
      chown appuser:appuser "$abspath" || true
    fi
  fi
fi

# Execute the passed command as appuser if runuser exists, else fall back to running as root
if command -v runuser >/dev/null 2>&1; then
  exec runuser -u appuser -- "$@"
elif command -v su >/dev/null 2>&1; then
  exec su -s /bin/sh appuser -c "$*"
else
  echo "Warning: cannot drop privileges to appuser; running as root"
  exec "$@"
fi
