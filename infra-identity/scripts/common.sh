#!/bin/bash
# Common functions and utilities for infra-identity scripts
#
# This file sources the shared scripts library and adds identity-specific functions.

# ============================================================================
# Source Shared Scripts Library
# ============================================================================
# Get the monorepo root (2 levels up from infra-identity/scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -f "${REPO_ROOT}/shared/scripts/common.sh" ]; then
  source "${REPO_ROOT}/shared/scripts/common.sh"
else
  echo "ERROR: Shared scripts library not found at ${REPO_ROOT}/shared/scripts/common.sh"
  exit 1
fi

# ============================================================================
# Identity-Specific Configuration
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT is already set by shared/scripts/common.sh via get_project_root()

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
