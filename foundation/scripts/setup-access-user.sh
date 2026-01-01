#!/usr/bin/env bash
# =============================================================================
# Script: setup-access-user.sh
# Component: foundation
# Purpose: Grant current user access to Terraform state Storage Accounts.
# =============================================================================
# Usage:
#   ./setup-access-user.sh [--dry-run|--execute] [-h|--help]
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
Usage: ./setup-access-user.sh [--dry-run|--execute] [-h|--help]
       ./setup-access-user.sh [--dry-run|--execute] [--env <env>] [--all-envs] [-h|--help]

Grant "Storage Blob Data Contributor" access for the currently signed-in Azure user
to all Terraform state Storage Accounts (dev/test/stage/prod).

Options:
  --dry-run     Print planned actions without executing
  --execute     Execute actions (default)
  --env <env>   Target a single environment (repeatable): dev|test|stage|prod
  --all-envs    Target all environments (default)
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).
  - Uses az_call account show + az_call ad signed-in-user show to resolve the principal.

EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --dry-run|--execute|--env|--environment|--all-envs) : ;;
    *) usage; exit 1 ;;
  esac
done

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

parse_env_args "$@"
check_required_commands az
az_require_login

log_info "=== Granting Storage Blob Data Contributor Access to Current User ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

# Get current user information
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] az_call account show --query user.name --output tsv" >&2
  echo "[DRY-RUN] az_call ad signed-in-user show --query id --output tsv" >&2
  CURRENT_USER_EMAIL="<current-user-email>"
  CURRENT_USER_OBJECT_ID="<current-user-object-id>"
else
  CURRENT_USER_EMAIL=$(az_call account show --query user.name --output tsv)
  CURRENT_USER_OBJECT_ID=$(az_call ad signed-in-user show --query id --output tsv)

  # If signed-in-user doesn't work, try alternative method
  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_info "Trying alternative method to get Object ID from email..."
    CURRENT_USER_OBJECT_ID=$(az_call ad user show --id "$CURRENT_USER_EMAIL" --query id --output tsv 2>/dev/null || echo "")
  fi

  # Verify we got a valid Object ID
  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_error "Could not find Object ID for user $CURRENT_USER_EMAIL"
    log_info "Try using Azure Portal to assign the role manually, or use your Object ID directly:"
    log_info "  az_call role assignment create --assignee <your-object-id> --role 'Storage Blob Data Contributor' --scope <scope>"
    exit 1
  fi
fi

log_info "Current user email: $CURRENT_USER_EMAIL"
log_info "Current user Object ID: $CURRENT_USER_OBJECT_ID"
log_info "Granting Storage Blob Data Contributor role to yourself..."
echo ""

ERRORS=0
GRANTED=0

# Grant access to all State Storage Accounts
for ENV in "${TARGET_ENVS[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "--- Granting access to ${SA_NAME} ---"

  # Grant Storage Blob Data Contributor role
  if az_exec role assignment create \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}" \
    --output none 2>/dev/null; then
    log_success "Access granted to ${SA_NAME}"
    GRANTED=$((GRANTED + 1))
  else
    # Check if role already exists
    if [ "$DRY_RUN" != true ]; then
      if az_call role assignment list \
        --assignee "$CURRENT_USER_OBJECT_ID" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}" \
        --role "Storage Blob Data Contributor" \
        --query "[].{Principal:principalName, Role:roleDefinitionName}" \
        --output table 2>/dev/null | grep -q "Storage Blob Data Contributor"; then
        log_warning "Role already exists for ${SA_NAME}"
        GRANTED=$((GRANTED + 1))
      else
        log_error "Failed to grant access to ${SA_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Role may already exist for ${SA_NAME}"
      GRANTED=$((GRANTED + 1))
    fi
  fi

  echo ""
done

# Summary
log_info "=== Access Grant Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would grant access to Storage Accounts: ${#TARGET_ENVS[@]} (selected environments)"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Access granted to ${GRANTED} Storage Account(s)"
  else
    log_error "Access grant completed with ${ERRORS} error(s)"
    log_warning "Only ${GRANTED} Storage Account(s) were granted access"
    exit 1
  fi
fi

echo ""
log_info "You can now view containers and blobs in Azure Portal for all State Storage Accounts."
