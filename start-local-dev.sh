#!/usr/bin/env bash
# Initialize Git submodules and start the full local stack (Postgres + API + Vite in Docker).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is not installed or not on PATH" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH (install Docker Desktop or Docker Engine)" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' (Compose V2) is not available; install the Docker Compose plugin" >&2
  exit 1
fi

# Follow latest main in each submodule (see branch = main in .gitmodules); does not change meta-repo commits.
git submodule update --init --recursive --remote
exec "$ROOT/dev-stack.sh" "$@"
