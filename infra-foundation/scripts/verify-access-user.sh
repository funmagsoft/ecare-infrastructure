#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Current User Access Verification ==="
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

ERRORS=0
WARNINGS=0

# Check Azure CLI authentication
echo "1. Checking Azure CLI authentication..."
if az account show --output none 2>/dev/null; then
  log_success "Azure CLI authenticated"
else
  log_error "Azure CLI not authenticated"
  ERRORS=$((ERRORS + 1))
fi

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Get current user information
echo "2. Getting current user information..."
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
  ERRORS=$((ERRORS + 1))
else
  log_success "Current user email: $CURRENT_USER_EMAIL"
  log_success "Current user Object ID: $CURRENT_USER_OBJECT_ID"
fi
echo ""

# Verify Storage Blob Data Contributor role on all Storage Accounts
echo "3. Verifying Storage Blob Data Contributor role assignments..."
echo ""

GRANTED=0
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"

  echo "=== Verifying access to ${SA_NAME} (${ENV} environment) ==="

  # Check if Storage Account exists
  if ! az storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --output none 2>/dev/null; then
    log_error "Storage Account ${SA_NAME} does not exist"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # Check if role assignment exists
  ROLE_ASSIGNMENT=$(az role assignment list \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --scope "$SA_SCOPE" \
    --role "Storage Blob Data Contributor" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null)

  if echo "$ROLE_ASSIGNMENT" | grep -q "Storage Blob Data Contributor"; then
    log_success "Storage Blob Data Contributor role assigned on ${SA_NAME}"
    GRANTED=$((GRANTED + 1))
  else
    log_error "Storage Blob Data Contributor role missing on ${SA_NAME}"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

# Summary
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  echo "Verified:"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/4 Storage Accounts"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  echo ""
  echo "Verified:"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/4 Storage Accounts"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  echo ""
  echo "Status:"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/4 Storage Accounts"
  exit 1
fi
