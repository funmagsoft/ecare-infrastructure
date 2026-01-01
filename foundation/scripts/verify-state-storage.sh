#!/usr/bin/env bash
# =============================================================================
# Script: verify-state-storage.sh
# Component: foundation
# Purpose: Verify Terraform state Storage Accounts and containers exist and are configured.
# =============================================================================
# Usage:
#   ./verify-state-storage.sh [-h|--help]
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
Usage: ./verify-state-storage.sh [-h|--help]

Verify Terraform state Storage Accounts and containers exist and are configured.

Options:
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).

EOF
}

if [ $# -gt 0 ]; then
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

# Verify scripts do not modify resources; dry-run is not applicable.
DRY_RUN=false
init_script

# Get BASE_DIR relative to foundation root
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_BASE="$(cd "$BASE_DIR/.." && pwd)"

log_info "=== Storage Account Verification ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Repository base: $BASE_DIR"
log_info "Workspace base: $REPO_BASE"
echo ""

ERRORS=0

# Check Azure CLI authentication
log_info "1. Checking Azure CLI authentication..."
if az_call account show --output none 2>/dev/null; then
  log_success "Azure CLI authenticated"
else
  log_error "Azure CLI not authenticated"
  ERRORS=$((ERRORS + 1))
fi

# Set active subscription
az_call account set --subscription "$SUBSCRIPTION_ID"

log_info "2. Checking Storage Accounts..."
for ENV in dev test stage prod; do
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  RG_NAME="rg-${PROJECT}-${ENV}"

  log_info "=== Verifying ${SA_NAME} ==="

  # Check Storage Account exists
  if az_call storage account show \
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
  if az_call storage container show \
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
  VERSIONING=$(az_call storage account blob-service-properties show \
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
  SOFT_DELETE=$(az_call storage account blob-service-properties show \
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
