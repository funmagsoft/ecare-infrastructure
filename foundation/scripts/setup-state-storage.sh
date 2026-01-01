#!/usr/bin/env bash
# =============================================================================
# Script: setup-state-storage.sh
# Component: foundation
# Purpose: Create and configure Terraform state Storage Accounts for all environments.
# =============================================================================
# Usage:
#   ./setup-state-storage.sh [--dry-run|--execute] [-h|--help]
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
Usage: ./setup-state-storage.sh [--dry-run|--execute] [-h|--help]

Create and configure Terraform state Storage Accounts (dev/test/stage/prod).

Actions per environment:
  - Create Storage Account tfstate<org><project><env>
  - Create container: tfstate
  - Enable blob versioning and soft delete

Options:
  --dry-run     Print planned actions without executing
  --execute     Execute actions (default)
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).
  - Requires Resource Groups to exist (run setup-rg.sh first).

EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
done

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

log_info "=== Creating Terraform State Storage Accounts ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

# Create Storage Accounts for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "--- Creating Storage Account for ${ENV} environment ---"
  log_info "Resource Group: $RG_NAME"
  log_info "Storage Account: $SA_NAME"

  # Verify Resource Group exists (skip check in dry-run mode)
  if [ "$DRY_RUN" != true ]; then
    if ! az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_error "Resource Group $RG_NAME does not exist. Create it first (Step 3)."
      exit 1
    fi
  else
    log_info "[DRY-RUN] Would check if Resource Group $RG_NAME exists"
  fi

  # Create Storage Account
  log_info "Creating Storage Account..."
  az_exec storage account create \
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
  az_exec storage container create \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --output none

  log_success "Container created"

  # Enable blob versioning and soft delete
  log_info "Enabling blob versioning and soft delete..."
  az_exec storage account blob-service-properties update \
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

log_info "=== All Storage Accounts Created ==="
log_dry_run_complete
