#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../oldwhale-backend"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 26.1.0 >/dev/null
printf '\nY\n' | npx nest generate resource admin-ai-group-variants --no-spec
