#!/usr/bin/env bash
# Start PostgreSQL, Redis, Old Whale API, and Vite dev server (all in Docker).
# Uses the latest-local launcher, then follows logs.
# Detached launch: ./start-latest-local.sh   Stop stack: docker compose down
# GitHub Pages builds are unchanged: use oldwhale-frontend/.github/workflows and npm run build:gh-pages in CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
exec "$ROOT/start-latest-local.sh" --attach "$@"
