#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

# Get BASE_DIR relative to infra-foundation root
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_BASE="$(cd "$BASE_DIR/.." && pwd)"

echo "=== Storage Account Verification ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Repository base: $BASE_DIR"
log_info "Workspace base: $REPO_BASE"
echo ""

ERRORS=0

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

echo "2. Checking Storage Accounts..."
for ENV in dev test stage prod; do
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  RG_NAME="rg-${PROJECT}-${ENV}"

  echo "=== Verifying ${SA_NAME} ==="

  # Check Storage Account exists
  if az storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name}" \
    --output table 2>/dev/null; then
    log_success "Storage Account exists"
  else
    log_error "Storage Account missing"
    continue
  fi

  # Check container exists
  if az storage container show \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --query "{Name:name, PublicAccess:properties.publicAccess}" \
    --output table 2>/dev/null; then
    log_success "Container 'tfstate' exists"
  else
    log_error "Container 'tfstate' missing"
  fi

  # Check versioning enabled
  VERSIONING=$(az storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "isVersioningEnabled" \
    --output tsv)

  if [ "$VERSIONING" == "true" ]; then
    log_success "Blob versioning enabled"
  else
    log_error "Blob versioning not enabled"
  fi

  # Check soft delete enabled
  SOFT_DELETE=$(az storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "deleteRetentionPolicy.enabled" \
    --output tsv)

  if [ "$SOFT_DELETE" == "true" ]; then
    log_success "Soft delete enabled"
  else
    log_error "Soft delete not enabled"
  fi

  echo ""
done
