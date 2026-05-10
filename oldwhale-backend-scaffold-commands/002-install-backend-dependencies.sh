#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../oldwhale-backend"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 26.1.0 >/dev/null
npm install @nestjs/config @nestjs/typeorm typeorm pg @nestjs/swagger swagger-ui-express class-validator class-transformer @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt uuid
npm install --save-dev @types/bcrypt @types/passport-jwt
