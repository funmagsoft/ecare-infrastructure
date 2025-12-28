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
# The bootstrap module automatically assigns Storage Blob Data Contributor
# role to Service Principals on their respective Storage Accounts.
#
# See: terraform/modules/bootstrap/README.md for details
# ============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

echo "=== Granting Storage Blob Data Contributor Access to Service Principals ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

# Load Service Principal IDs from service-principals.env
SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"

if [ ! -f "$SP_IDS_FILE" ]; then
  if [ "$DRY_RUN" = true ]; then
    log_warning "File not found: $SP_IDS_FILE"
    log_info "[DRY-RUN] Would load Service Principal IDs from: $SP_IDS_FILE"
  else
    log_error "File not found: $SP_IDS_FILE"
    log_info "Run setup-access.sh first to create Service Principals and generate this file."
    exit 1
  fi
else
  log_info "Loading Service Principal IDs from: $SP_IDS_FILE"
  if ! load_env_file "$SP_IDS_FILE"; then
    if [ "$DRY_RUN" = true ]; then
      log_warning "Failed to load Service Principal IDs from $SP_IDS_FILE (dry-run mode)"
    else
      log_error "Failed to load Service Principal IDs from $SP_IDS_FILE"
      exit 1
    fi
  fi
fi

ERRORS=0
GRANTED=0

# Grant access to all State Storage Accounts for each Service Principal
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"

  eval "APP_ID=\$$APP_ID_VAR"

  # Verify APP_ID is set
  if [ -z "$APP_ID" ]; then
    log_error "${APP_ID_VAR} is not set. Please check service-principals.env file."
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  log_info "--- Granting access to ${SA_NAME} for ${SP_NAME} (App ID: ${APP_ID}) ---"

  # Grant Storage Blob Data Contributor role
  if run_cmd az role assignment create \
    --assignee "$APP_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}" \
    --output none 2>/dev/null; then
    log_success "Access granted to ${SA_NAME} for ${SP_NAME}"
    GRANTED=$((GRANTED + 1))
  else
    # Check if role already exists
    if [ "$DRY_RUN" != true ]; then
      if az role assignment list \
        --assignee "$APP_ID" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}" \
        --role "Storage Blob Data Contributor" \
        --query "[].{Principal:principalName, Role:roleDefinitionName}" \
        --output table 2>/dev/null | grep -q "Storage Blob Data Contributor"; then
        log_warning "Role already exists for ${SP_NAME} on ${SA_NAME}"
        GRANTED=$((GRANTED + 1))
      else
        log_error "Failed to grant access to ${SA_NAME} for ${SP_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Role may already exist for ${SP_NAME} on ${SA_NAME}"
      GRANTED=$((GRANTED + 1))
    fi
  fi

  echo ""
done

# Summary
echo "=== Access Grant Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would grant access to Storage Accounts: 4 (one per Service Principal/environment)"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Access granted to ${GRANTED} Storage Account(s) for Service Principals"
  else
    log_error "Access grant completed with ${ERRORS} error(s)"
    log_warning "Only ${GRANTED} Storage Account(s) were granted access"
    exit 1
  fi
fi

echo ""
log_info "Service Principals can now access Terraform state files in their respective Storage Accounts."
