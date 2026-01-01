#!/usr/bin/env bash
# =============================================================================
# Script: cleanup-phase0.sh
# Component: foundation
# Purpose: Orchestrate Phase 0 cleanup (user access, state storage, resource groups).
# =============================================================================
# Usage:
#   ./cleanup-phase0.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]
# =============================================================================

set -Eeuo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/common.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/globals.sh"

setup_traps

usage() {
  cat <<'EOF'
Usage: ./cleanup-phase0.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]

Run the Phase 0 cleanup sequence (inverse of setup-phase0.sh):
  1) cleanup-access-user.sh
  2) cleanup-state-storage.sh
  3) cleanup-rg.sh

Safety:
  Cleanup scripts default to --dry-run. To apply changes, pass --execute AND a matching --confirm.

Options:
  --dry-run      Print planned actions without executing (default)
  --execute      Execute actions
  --confirm <s>  Must equal: "DELETE phase0 <project>" (project comes from shared/scripts/globals.sh)
  --env <env>    Target a single environment (repeatable): dev|test|stage|prod
  --all-envs     Target all environments
  -h, --help     Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).
  - Deleting resource groups is destructive and cannot be undone.

EOF
}

# Help must be handled before init_script(), which may validate environment
# variables and interact with Azure.
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
done

# Default to dry-run for destructive operations.
DRY_RUN=true

init_script "$@"
parse_env_args "$@"
parse_confirm_args "$@"
check_required_commands az
az_require_login

require_confirm "DELETE phase0 ${PROJECT}"

log_info "=== Phase 0 Infrastructure Cleanup ==="
log_dry_run
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription:    $SUBSCRIPTION_ID"
log_info "Environments:    $(envs_to_string)"
echo ""

TOTAL_ERRORS=0
FAILED_CLEANUPS=()

CLEANUP_SCRIPTS=(
  "cleanup-access-user.sh"
  "cleanup-state-storage.sh"
  "cleanup-rg.sh"
)

for cleanup_script in "${CLEANUP_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${cleanup_script}"

  if [[ ! -f "$script_path" ]]; then
    log_error "Cleanup script not found: $script_path"
    FAILED_CLEANUPS+=("$cleanup_script (not found)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    continue
  fi

  echo ""
  log_info "================================================================================"
  log_info "Running: $cleanup_script"
  log_info "================================================================================"
  echo ""

  if bash "$script_path" "$@"; then
    log_success "$cleanup_script completed successfully"
  else
    exit_code=$?
    log_error "$cleanup_script failed with exit code: $exit_code"
    FAILED_CLEANUPS+=("$cleanup_script (exit code: $exit_code)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
  fi

  echo ""
done

echo ""
log_info "================================================================================"
log_info "=== Cleanup Summary ==="
log_info "================================================================================"
echo ""

if [[ $TOTAL_ERRORS -eq 0 ]]; then
  log_success "Phase 0 cleanup completed successfully"
  exit 0
else
  log_error "Phase 0 cleanup completed with $TOTAL_ERRORS error(s)"
  echo ""
  log_error "Failed cleanups:"
  for failed in "${FAILED_CLEANUPS[@]}"; do
    log_error "$failed"
  done
  exit 1
fi
