#!/usr/bin/env bash
# =============================================================================
# Script: cleanup-rg.sh
# Component: foundation
# Purpose: Delete Azure Resource Groups for selected environments.
# =============================================================================
# Usage:
#   ./cleanup-rg.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]
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
Usage: ./cleanup-rg.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]

Delete Azure Resource Groups for selected environments.

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
  - This deletes the entire Resource Group and all contained resources.

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

log_info "=== Deleting Resource Groups ==="
log_dry_run
log_info "Subscription:  $SUBSCRIPTION_ID"
log_info "Location:      $LOCATION"
log_info "Environments:  $(envs_to_string)"
echo ""

ERRORS=0
DELETED=0

for ENV in "${TARGET_ENVS[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  log_info "--- Deleting Resource Group ${RG_NAME} (${ENV}) ---"

  if ! az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
    log_warning "Resource Group does not exist (skipping)."
    echo ""
    continue
  fi

  if az_exec group delete --name "$RG_NAME" --yes --output none; then
    log_success "Resource Group delete requested"
    DELETED=$((DELETED + 1))
  else
    log_error "Failed to delete Resource Group"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

log_info "=== Cleanup Summary ==="
log_info "Resource Groups deleted: ${DELETED}/${#TARGET_ENVS[@]}"

if [[ "${DRY_RUN}" == true ]]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  exit 0
fi

if [[ $ERRORS -eq 0 ]]; then
  log_success "Cleanup completed successfully"
  exit 0
else
  log_error "Cleanup completed with ${ERRORS} error(s)"
  exit 1
fi
