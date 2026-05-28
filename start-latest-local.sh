#!/usr/bin/env bash
# Build only changed Docker layers, start the local stack, remove Compose orphans,
# and force-recreate only containers that still point at an older image ID.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ATTACH=0
EXPLICIT_SERVICES=0
SERVICES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --attach)
      ATTACH=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./start-latest-local.sh [--attach] [SERVICE...]

Build changed Docker layers, start the local Docker Compose stack, remove orphan
containers, and recreate only services whose running containers use stale image
IDs.

Examples:
  ./start-latest-local.sh
  ./start-latest-local.sh --attach
  ./start-latest-local.sh api web
EOF
      exit 0
      ;;
    *)
      EXPLICIT_SERVICES=1
      SERVICES+=("$1")
      shift
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "error: 'docker compose' (Compose V2) is not available" >&2
  exit 1
fi

if [ "${#SERVICES[@]}" -eq 0 ]; then
  while IFS= read -r service; do
    SERVICES+=("$service")
  done < <(docker compose config --services)
fi

echo "==> Building changed Docker layers"
if [ "$EXPLICIT_SERVICES" -eq 1 ]; then
  docker compose build "${SERVICES[@]}"
else
  docker compose build
fi

echo "==> Starting stack and removing orphaned Compose containers"
docker compose up -d --remove-orphans "${SERVICES[@]}"

STALE_SERVICES=()

for service in "${SERVICES[@]}"; do
  container_id="$(docker compose ps -q "$service" 2>/dev/null || true)"
  image_ref="$(docker compose images -q "$service" 2>/dev/null || true)"

  # Some services may be image-only dependencies or absent from this compose
  # invocation. Compose already handled them above, so there is nothing to
  # compare here.
  if [ -z "$container_id" ] || [ -z "$image_ref" ]; then
    continue
  fi

  container_image_id="$(docker inspect --format '{{.Image}}' "$container_id")"
  current_image_id="$(docker image inspect --format '{{.Id}}' "$image_ref")"

  if [ "$container_image_id" != "$current_image_id" ]; then
    STALE_SERVICES+=("$service")
  fi
done

if [ "${#STALE_SERVICES[@]}" -gt 0 ]; then
  echo "==> Recreating stale service containers: ${STALE_SERVICES[*]}"
  docker compose up -d --remove-orphans --no-deps --force-recreate "${STALE_SERVICES[@]}"
else
  echo "==> Running containers already match current Compose images"
fi

echo "==> Verifying running container image IDs"
MISMATCHES=0

for service in "${SERVICES[@]}"; do
  container_id="$(docker compose ps -q "$service" 2>/dev/null || true)"
  image_ref="$(docker compose images -q "$service" 2>/dev/null || true)"

  if [ -z "$container_id" ] || [ -z "$image_ref" ]; then
    continue
  fi

  container_image_id="$(docker inspect --format '{{.Image}}' "$container_id")"
  current_image_id="$(docker image inspect --format '{{.Id}}' "$image_ref")"

  if [ "$container_image_id" != "$current_image_id" ]; then
    echo "error: $service is still using stale image $container_image_id; expected $current_image_id" >&2
    MISMATCHES=$((MISMATCHES + 1))
  fi
done

if [ "$MISMATCHES" -gt 0 ]; then
  docker compose ps
  exit 1
fi

echo "==> Local stack is running the latest built images"
docker compose ps

if [ "$ATTACH" -eq 1 ]; then
  echo "==> Following logs (Ctrl+C stops log follow; containers keep running)"
  exec docker compose logs -f --tail=120 "${SERVICES[@]}"
fi
