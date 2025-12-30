#!/bin/bash

# ============================================================================
# DEPRECATED: This script is replaced by Terraform bootstrap module
# ============================================================================
# This script is kept for backward compatibility and migration purposes.
# For new deployments, use Terraform bootstrap module instead:
#
#   cd terraform/environments/dev
#   terraform init
#   terraform apply -target=module.bootstrap
#
# Configure users_with_state_access in terraform.tfvars:
#
#   users_with_state_access = [
#     "12345678-1234-1234-1234-123456789012"  # User Object ID
#   ]
#
# To get a user's Object ID:
#   az ad user show --id <user-email> --query id --output tsv
#
# The bootstrap module creates Storage Blob Data Contributor role assignments
# for all specified users on the Terraform state Storage Account.
#
# See: terraform/modules/bootstrap/README.md for details
# ============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

echo "=== Granting Storage Blob Data Contributor Access to Current User ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

# Get current user information
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] az account show --query user.name --output tsv" >&2
  echo "[DRY-RUN] az ad signed-in-user show --query id --output tsv" >&2
  CURRENT_USER_EMAIL="<current-user-email>"
  CURRENT_USER_OBJECT_ID="<current-user-object-id>"
else
  CURRENT_USER_EMAIL=$(az account show --query user.name --output tsv)
  CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)

  # If signed-in-user doesn't work, try alternative method
  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_info "Trying alternative method to get Object ID from email..."
    CURRENT_USER_OBJECT_ID=$(az ad user show --id "$CURRENT_USER_EMAIL" --query id --output tsv 2>/dev/null || echo "")
  fi

  # Verify we got a valid Object ID
  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_error "Could not find Object ID for user $CURRENT_USER_EMAIL"
    log_info "Try using Azure Portal to assign the role manually, or use your Object ID directly:"
    log_info "  az role assignment create --assignee <your-object-id> --role 'Storage Blob Data Contributor' --scope <scope>"
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
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "--- Granting access to ${SA_NAME} ---"

  # Grant Storage Blob Data Contributor role
  if run_cmd az role assignment create \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}" \
    --output none 2>/dev/null; then
    log_success "Access granted to ${SA_NAME}"
    GRANTED=$((GRANTED + 1))
  else
    # Check if role already exists
    if [ "$DRY_RUN" != true ]; then
      if az role assignment list \
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
echo "=== Access Grant Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would grant access to Storage Accounts: 4 (one per environment)"
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
