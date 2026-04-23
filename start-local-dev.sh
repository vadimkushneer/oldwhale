#!/usr/bin/env bash
# Start the full local stack (Postgres + API + Vite in Docker) using the code
# currently present in ./oldwhale-frontend and ./oldwhale-backend. No Git operations.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH (install Docker Desktop or Docker Engine)" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' (Compose V2) is not available; install the Docker Compose plugin" >&2
  exit 1
fi

for sub in oldwhale-frontend oldwhale-backend; do
  if [ ! -d "$ROOT/$sub" ] || [ -z "$(ls -A "$ROOT/$sub" 2>/dev/null || true)" ]; then
    echo "error: '$sub' folder is missing or empty; populate it before running this script" >&2
    exit 1
  fi
done

exec "$ROOT/dev-stack.sh" "$@"
