#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

echo "=== Creating Terraform State Storage Accounts ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

# Create Storage Accounts for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  echo "--- Creating Storage Account for ${ENV} environment ---"
  echo "Resource Group: $RG_NAME"
  echo "Storage Account: $SA_NAME"

  # Verify Resource Group exists (skip check in dry-run mode)
  if [ "$DRY_RUN" != true ]; then
    if ! az group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_error "Resource Group $RG_NAME does not exist. Create it first (Step 3)."
      exit 1
    fi
  else
    log_info "[DRY-RUN] Would check if Resource Group $RG_NAME exists"
  fi

  # Create Storage Account
  echo "Creating Storage Account..."
  run_cmd az storage account create \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags \
      Environment="${ENV}" \
      Project="${PROJECT}" \
      ManagedBy="terraform" \
      Purpose="terraform-state" \
      CreatedDate="$(date +%Y-%m-%d)" \
    --output none

  log_success "Storage Account created"

  # Create container
  log_info "Creating container 'tfstate'..."
  run_cmd az storage container create \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --output none

  log_success "Container created"

  # Enable blob versioning and soft delete
  log_info "Enabling blob versioning and soft delete..."
  run_cmd az storage account blob-service-properties update \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --output none

  log_success "Blob versioning and soft delete enabled"

  log_success "Storage Account ${SA_NAME} configured successfully"
  echo ""
done

echo "=== All Storage Accounts Created ==="
log_dry_run_complete
