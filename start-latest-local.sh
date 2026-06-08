#!/usr/bin/env bash
# One command to run the LATEST local full stack.
#
# Running `./start-latest-local.sh` is meant to be sufficient on its own to see
# every local change in the app's behaviour and appearance — no other manual
# steps required. It:
#   1. rebuilds the backend image from the current source (the api container
#      runs a baked build, so source changes need a rebuild);
#   2. force-recreates the containers so they actually run the freshly built
#      images (no stale containers left behind);
#   3. lets the backend run its SQLite migrations on boot (e.g. adding the
#      users.credits column to an existing database);
#   4. waits until the API reports healthy, then prints where to go.
#
# The frontend (web) is bind-mounted, so its source changes are already live via
# Vite HMR; recreating it also re-syncs dependencies when package-lock changes.
#
# Usage:
#   ./start-latest-local.sh                 # rebuild + (re)start everything
#   ./start-latest-local.sh --attach        # ...then follow logs
#   ./start-latest-local.sh --clean         # full rebuild, ignoring Docker cache
#   ./start-latest-local.sh --reset-db      # wipe local DB first (fresh schema + admin)
#   ./start-latest-local.sh api             # limit to specific service(s)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ATTACH=0
NO_CACHE=0
RESET_DB=0
SERVICES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --attach) ATTACH=1; shift ;;
    --clean|--no-cache) NO_CACHE=1; shift ;;
    --reset-db|--reset) RESET_DB=1; shift ;;
    -h|--help)
      # Print the leading comment block (skip the shebang; stop at the first code line).
      awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    --) shift; while [ "$#" -gt 0 ]; do SERVICES+=("$1"); shift; done ;;
    -*) echo "error: unknown option '$1' (try --help)" >&2; exit 1 ;;
    *) SERVICES+=("$1"); shift ;;
  esac
done

log() { printf '\n==> %s\n' "$*"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' (Compose V2) is not available" >&2
  exit 1
fi
if [ ! -f "$ROOT/.env" ]; then
  echo "warning: $ROOT/.env not found; defaults from docker-compose.yml will be used" >&2
fi

# Read a single value from .env without sourcing it (values may contain spaces/<>).
read_env() {
  [ -f "$ROOT/.env" ] || return 0
  grep -E "^$1=" "$ROOT/.env" | head -n1 | cut -d= -f2- || true
}

API_PORT="${API_HOST_PORT:-$(read_env API_HOST_PORT)}"
API_PORT="${API_PORT:-18080}"
WEB_PORT=5173

if [ "$RESET_DB" -eq 1 ]; then
  log "Resetting local database (removing the backend data volume)"
  docker compose down --remove-orphans || true
  db_volumes="$(docker volume ls -q --filter name=fullstack_backend_data || true)"
  if [ -n "$db_volumes" ]; then
    # shellcheck disable=SC2086
    docker volume rm $db_volumes || true
  fi
fi

if [ "$NO_CACHE" -eq 1 ]; then
  log "Building images from scratch (no cache)"
  docker compose build --no-cache ${SERVICES[@]+"${SERVICES[@]}"}
else
  log "Building images from the current source"
  docker compose build ${SERVICES[@]+"${SERVICES[@]}"}
fi

log "(Re)creating containers so they run the freshly built images"
docker compose up -d --force-recreate --remove-orphans ${SERVICES[@]+"${SERVICES[@]}"}

wait_for_api() {
  local url="http://localhost:${API_PORT}/health"
  if ! command -v curl >/dev/null 2>&1; then
    log "curl not found — skipping API readiness check (give it a few seconds)"
    return 0
  fi
  log "Waiting for the API to become healthy at ${url}"
  local attempt
  for attempt in $(seq 1 60); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      printf '    API is healthy.\n'
      return 0
    fi
    sleep 2
  done
  echo "warning: API was not healthy within ~120s — check 'docker compose logs api'" >&2
  return 0
}

# Only meaningful when the api service is part of this run.
if [ "${#SERVICES[@]}" -eq 0 ] || printf '%s\n' "${SERVICES[@]}" | grep -qx "api"; then
  wait_for_api
fi

ADMIN_USER="$(read_env INITIAL_ADMIN_USERNAME)"

cat <<EOF

==> Local stack is running the latest code.

  Frontend (Vite, HMR):  http://localhost:${WEB_PORT}
  API (NestJS):          http://localhost:${API_PORT}
  API health:            http://localhost:${API_PORT}/health
  API docs (Swagger):    http://localhost:${API_PORT}/swagger
  OpenAPI spec:          http://localhost:${API_PORT}/openapi.yaml

  Admin login:           ${ADMIN_USER:-<INITIAL_ADMIN_USERNAME in .env>} (password: INITIAL_ADMIN_PASSWORD in .env)

  Backend image rebuilt from source; DB migrations ran on boot.
  Frontend source changes are live via the bind mount.

  Follow logs:  docker compose logs -f
  Stop (keep data):  docker compose down
  Wipe local DB:     ./start-latest-local.sh --reset-db
EOF

if [ "$ATTACH" -eq 1 ]; then
  log "Following logs (Ctrl+C stops the log follow; containers keep running)"
  exec docker compose logs -f --tail=120 ${SERVICES[@]+"${SERVICES[@]}"}
fi
