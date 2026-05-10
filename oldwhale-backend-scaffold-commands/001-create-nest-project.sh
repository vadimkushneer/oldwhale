#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 26.1.0 >/dev/null
npx --yes @nestjs/cli@latest new oldwhale-backend --package-manager npm --skip-git --strict
