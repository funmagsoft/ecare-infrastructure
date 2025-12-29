#!/bin/bash

# Common helpers for infra-identity scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

load_dotenv() {
  local env_file="${REPO_ROOT}/.env"
  if [ -f "$env_file" ] && [ -r "$env_file" ]; then
    set -a
    # Strip comments and empty lines, support optional 'export'
    source <(grep -v '^#' "$env_file" | grep -v '^$' | sed -E 's/^export[[:space:]]+//')
    set +a
    return 0
  else
    return 1
  fi
}

parse_dry_run() {
  DRY_RUN=false
  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      *)
        REMAINING_ARGS+=("$1")
        ;;
    esac
    shift
  done
}

log_info() {
  echo "[INFO ] $*"
}

log_warn() {
  echo "[WARN ] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC ] $*"
    "$@"
  fi
}
