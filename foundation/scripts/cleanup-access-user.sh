#!/usr/bin/env bash
# =============================================================================
# Script: cleanup-access-user.sh
# Component: foundation
# Purpose: Revoke current user access to Terraform state Storage Accounts.
# =============================================================================
# Usage:
#   ./cleanup-access-user.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]
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
Usage: ./cleanup-access-user.sh [--dry-run|--execute] [--env <env>] [--all-envs] --confirm "DELETE phase0 <project>" [-h|--help]

Revoke "Storage Blob Data Contributor" access for the currently signed-in Azure user
from Terraform state Storage Accounts.

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
  - This script removes role assignments created by setup-access-user.sh.

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

DRY_RUN=true

init_script "$@"
parse_env_args "$@"
parse_confirm_args "$@"
check_required_commands az
az_require_login

require_confirm "DELETE phase0 ${PROJECT}"

log_info "=== Revoking Current User Access to Terraform State Storage Accounts ==="
log_dry_run
log_info "Subscription:  $SUBSCRIPTION_ID"
log_info "Environments:  $(envs_to_string)"
echo ""

# Resolve current user principal
CURRENT_USER_EMAIL="$(az_call account show --query user.name --output tsv)"
CURRENT_USER_OBJECT_ID="$(az_call ad signed-in-user show --query id --output tsv 2>/dev/null || echo "")"

if [[ -z "$CURRENT_USER_OBJECT_ID" || "$CURRENT_USER_OBJECT_ID" == "null" ]]; then
  log_info "Trying alternative method to get Object ID from email..."
  CURRENT_USER_OBJECT_ID="$(az_call ad user show --id "$CURRENT_USER_EMAIL" --query id --output tsv 2>/dev/null || echo "")"
fi

if [[ -z "$CURRENT_USER_OBJECT_ID" || "$CURRENT_USER_OBJECT_ID" == "null" ]]; then
  die "Could not resolve Object ID for signed-in user (${CURRENT_USER_EMAIL})." 1
fi

log_info "Current user: $CURRENT_USER_EMAIL"
log_info "Object ID:    $CURRENT_USER_OBJECT_ID"
echo ""

ERRORS=0
REVOKED=0

for ENV in "${TARGET_ENVS[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"

  log_info "--- Revoking access on ${SA_NAME} (${ENV}) ---"

  # Only attempt delete if an assignment exists.
  ASSIGNMENT_COUNT="$(az_call role assignment list \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --scope "$SA_SCOPE" \
    --role "Storage Blob Data Contributor" \
    --query "length(@)" \
    --output tsv 2>/dev/null || echo "0")"

  if [[ "$ASSIGNMENT_COUNT" == "0" ]]; then
    log_warning "No role assignment found (nothing to revoke)."
    echo ""
    continue
  fi

  if az_exec role assignment delete \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_SCOPE" \
    --output none; then
    log_success "Access revoked"
    REVOKED=$((REVOKED + 1))
  else
    log_error "Failed to revoke access"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

log_info "=== Cleanup Summary ==="
log_info "Role assignments revoked: ${REVOKED}/${#TARGET_ENVS[@]}"

if [[ "$DRY_RUN" == true ]]; then
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
