#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULES=(oldwhale-backend oldwhale-frontend)

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

require_main_branch() {
  local repo="$1"
  local branch
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" ]]; then
    printf 'error: %s is on branch %s, expected main\n' "$repo" "$branch" >&2
    exit 1
  fi
}

commit_message_for() {
  local repo="$1"
  case "$repo" in
    oldwhale-backend)
      printf '%s\n' "${BACKEND_COMMIT_MESSAGE:-${COMMIT_MESSAGE:-chore: sync backend changes}}"
      ;;
    oldwhale-frontend)
      printf '%s\n' "${FRONTEND_COMMIT_MESSAGE:-${COMMIT_MESSAGE:-chore: sync frontend changes}}"
      ;;
    *)
      printf '%s\n' "${COMMIT_MESSAGE:-chore: sync local changes}"
      ;;
  esac
}

commit_and_push_submodule() {
  local repo="$1"
  local message
  message="$(commit_message_for "$repo")"

  require_main_branch "$repo"

  log "$repo: fetching origin/main"
  git -C "$repo" fetch origin main --quiet

  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    log "$repo: committing local changes"
    git -C "$repo" add -A
    git -C "$repo" commit -m "$message"
  else
    log "$repo: no uncommitted changes"
  fi

  log "$repo: rebasing/fast-forwarding on origin/main"
  git -C "$repo" pull --rebase --autostash origin main

  if [[ "$(git -C "$repo" rev-list --count origin/main..HEAD)" != "0" ]]; then
    log "$repo: pushing main"
    git -C "$repo" push origin main
  else
    log "$repo: nothing to push"
  fi
}

sync_meta_repo_pins() {
  require_main_branch "$ROOT_DIR"

  log "meta-repo: fetching origin/main"
  git -C "$ROOT_DIR" fetch origin main --quiet

  if [[ "$(git -C "$ROOT_DIR" rev-list --count HEAD..origin/main)" != "0" ]]; then
    log "meta-repo: rebasing local main on origin/main"
    git -C "$ROOT_DIR" pull --rebase --autostash origin main
  fi

  log "meta-repo: staging submodule pins"
  git -C "$ROOT_DIR" add -- "${SUBMODULES[@]}"

  # Include updates to this helper itself when the script is changed.
  git -C "$ROOT_DIR" add -- "$(basename "${BASH_SOURCE[0]}")"

  if git -C "$ROOT_DIR" diff --cached --quiet; then
    log "meta-repo: no pin changes to commit"
  else
    log "meta-repo: committing updated submodule pins"
    git -C "$ROOT_DIR" commit -m "${META_COMMIT_MESSAGE:-chore(dev): sync submodule pins}"
  fi

  if [[ "$(git -C "$ROOT_DIR" rev-list --count origin/main..HEAD)" != "0" ]]; then
    log "meta-repo: pushing main"
    git -C "$ROOT_DIR" push origin main
  else
    log "meta-repo: nothing to push"
  fi
}

main() {
  cd "$ROOT_DIR"

  for repo in "${SUBMODULES[@]}"; do
    commit_and_push_submodule "$ROOT_DIR/$repo"
  done

  sync_meta_repo_pins
  log "done"
}

main "$@"
