#!/usr/bin/env bash
# Rebuild Docker images and restart the stack in detached mode (no attach).
# Use after changing oldwhale-backend or oldwhale-frontend (Dockerfile / code).
#
# Usage:
#   ./dev-stack-rebuild.sh              # rebuild all services, restart stack
#   ./dev-stack-rebuild.sh api web      # only api + frontend (db unchanged if healthy)
#
# For a clean image rebuild: docker compose build --no-cache api web && ./dev-stack-rebuild.sh api web
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

exec docker compose up -d --build "$@"
