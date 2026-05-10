#!/usr/bin/env bash
# Stop and remove containers for the full local stack (Postgres + API + Vite).
# Named volumes (Postgres data, frontend node_modules) are kept unless you pass -v.
#
# Usage:
#   ./dev-stack-stop.sh           # stop stack, keep volumes
#   ./dev-stack-stop.sh -v        # stop stack and remove named volumes (wipes DB data)
#
# Extra args are passed through to `docker compose down`.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' (Compose V2) is not available" >&2
  exit 1
fi

exec docker compose down "$@"
