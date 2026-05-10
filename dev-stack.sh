#!/usr/bin/env bash
# Start PostgreSQL, Old Whale API, and Vite dev server (all in Docker).
# Rebuild + restart (detached): ./dev-stack-rebuild.sh   Stop stack: ./dev-stack-stop.sh
# GitHub Pages builds are unchanged: use oldwhale-frontend/.github/workflows and npm run build:gh-pages in CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
exec docker compose up --build "$@"
