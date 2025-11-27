# syntax=docker/dockerfile:1
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on \
    APP_HOME=/app \
    PORT=8000

WORKDIR $APP_HOME

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install python deps separately for caching
COPY backend/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy application code
COPY backend ./backend

# Create a non-root user
RUN useradd -m appuser && chown -R appuser:appuser $APP_HOME

# Copy entrypoint script and ensure executable
COPY backend/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# We'll use the entrypoint to set ownership of mounted volumes at container start
# The entrypoint will drop privileges and execute the CMD as `appuser` when possible.
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8000

# Healthcheck (simple)
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 CMD curl -f http://localhost:$PORT/ || exit 1

# Run uvicorn (will be executed by entrypoint as `appuser` when possible)
CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
