#!/usr/bin/env bash
# =============================================================================
# Script: verify-terraform-bootstrap.sh
# Component: infra-foundation
# Purpose: Verify Terraform bootstrap module prerequisites and state configuration.
# =============================================================================
# Usage:
#   ./verify-terraform-bootstrap.sh [-h|--help]
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
Usage: ./verify-terraform-bootstrap.sh [-h|--help]

Verify Terraform bootstrap module prerequisites and state configuration.

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

log_info "=== Terraform Bootstrap Module Verification ==="
log_info "Verifies resources created by terraform/modules/bootstrap:"
log_info "  - Service Principals for GitHub Actions"
log_info "  - Federated Identity Credentials (OIDC)"
log_info "  - RBAC role assignments"
echo ""
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

ERRORS=0
WARNINGS=0

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
echo ""

# Set GitHub organization and repository names (same as bootstrap module)
INFRASTRUCTURE_REPO="${ORGANIZATION}/ecare-infrastructure"

# Verify Service Principals, FIC, and RBAC roles for each environment
log_info "2. Verifying Service Principals, FIC, and RBAC roles..."
echo ""

TOTAL_SP=0
TOTAL_FIC=0
TOTAL_RBAC=0

for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}-${DEPLOYMENT_IDS[$ENV]}"
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "=== Verifying ${SP_NAME} (${ENV} environment) ==="

  # Get Service Principal by name
  SP_INFO=$(az_call ad sp list --filter "displayName eq '${SP_NAME}'" \
    --query "[0].{appId:appId, id:id, displayName:displayName}" \
    --output json 2>/dev/null)

  if [ -z "$SP_INFO" ] || [ "$SP_INFO" == "null" ] || [ "$SP_INFO" == "[]" ]; then
    log_error "Service Principal not found: ${SP_NAME}"
    log_info "  Terraform bootstrap module may not have been applied yet."
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  APP_ID=$(echo "$SP_INFO" | jq -r '.appId')
  OBJECT_ID=$(echo "$SP_INFO" | jq -r '.id')
  DISPLAY_NAME=$(echo "$SP_INFO" | jq -r '.displayName')

  if [ "$DISPLAY_NAME" == "$SP_NAME" ]; then
    log_success "Service Principal exists: $SP_NAME"
    log_info "  App ID: $APP_ID"
    log_info "  Object ID: $OBJECT_ID"
    TOTAL_SP=$((TOTAL_SP + 1))
  else
    log_error "Service Principal name mismatch: expected $SP_NAME, got $DISPLAY_NAME"
    ERRORS=$((ERRORS + 1))
  fi

  # Verify Federated Identity Credentials
  log_info "  Checking Federated Identity Credentials..."
  FIC_COUNT=0
  FIC_EXPECTED=1

  # Check FIC for infra-foundation
  FIC_NAME="$(build_fic_display_name "$INFRASTRUCTURE_REPO" "$ENV")"
  if az_call ad app federated-credential list --id "$APP_ID" \
    --query "[?name=='${FIC_NAME}']" \
    --output json 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then
    log_success "  FIC exists: ${FIC_NAME}"
    FIC_COUNT=$((FIC_COUNT + 1))
  else
    log_error "  FIC missing: ${FIC_NAME}"
    ERRORS=$((ERRORS + 1))
  fi

  if [ $FIC_COUNT -eq $FIC_EXPECTED ]; then
    log_success "  All ${FIC_EXPECTED} FIC found for ${SP_NAME}"
    TOTAL_FIC=$((TOTAL_FIC + FIC_COUNT))
  else
    log_warning "  Only ${FIC_COUNT}/${FIC_EXPECTED} FIC found for ${SP_NAME}"
    WARNINGS=$((WARNINGS + 1))
    TOTAL_FIC=$((TOTAL_FIC + FIC_COUNT))
  fi

  # Verify RBAC Role Assignments
  log_info "  Checking RBAC Role Assignments..."
  RBAC_COUNT=0

  # Check Contributor role on Resource Group
  RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"
  if az_call role assignment list \
    --assignee "$APP_ID" \
    --scope "$RG_SCOPE" \
    --role "Contributor" \
    --output none 2>/dev/null; then
    log_success "  Contributor role assigned on Resource Group"
    RBAC_COUNT=$((RBAC_COUNT + 1))
  else
    log_error "  Contributor role missing on Resource Group"
    ERRORS=$((ERRORS + 1))
  fi

  # Check User Access Administrator role on Resource Group
  if az_call role assignment list \
    --assignee "$APP_ID" \
    --scope "$RG_SCOPE" \
    --role "User Access Administrator" \
    --output none 2>/dev/null; then
    log_success "  User Access Administrator role assigned on Resource Group"
    RBAC_COUNT=$((RBAC_COUNT + 1))
  else
    log_error "  User Access Administrator role missing on Resource Group"
    ERRORS=$((ERRORS + 1))
  fi

  # Check Storage Blob Data Contributor role on Storage Account
  SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"
  if az_call role assignment list \
    --assignee "$APP_ID" \
    --scope "$SA_SCOPE" \
    --role "Storage Blob Data Contributor" \
    --output none 2>/dev/null; then
    log_success "  Storage Blob Data Contributor role assigned on Storage Account"
    RBAC_COUNT=$((RBAC_COUNT + 1))
  else
    log_error "  Storage Blob Data Contributor role missing on Storage Account"
    ERRORS=$((ERRORS + 1))
  fi

  TOTAL_RBAC=$((TOTAL_RBAC + RBAC_COUNT))

  echo ""
done

# Summary
log_info "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All Terraform Bootstrap verifications passed!"
  echo ""
  log_info "Verified:"
  log_info "  - Service Principals: ${TOTAL_SP}/4"
  log_info "  - Federated Identity Credentials: ${TOTAL_FIC}/4 (1 repo × 4 environments)"
  log_info "  - RBAC role assignments: ${TOTAL_RBAC}/12 (3 roles × 4 environments)"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  echo ""
  log_info "Verified:"
  log_info "  - Service Principals: ${TOTAL_SP}/4"
  log_info "  - Federated Identity Credentials: ${TOTAL_FIC}/4"
  log_info "  - RBAC role assignments: ${TOTAL_RBAC}/12"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  echo ""
  log_info "Status:"
  log_info "  - Service Principals: ${TOTAL_SP}/4"
  log_info "  - Federated Identity Credentials: ${TOTAL_FIC}/4"
  log_info "  - RBAC role assignments: ${TOTAL_RBAC}/12"
  echo ""
  log_info "Hint: If resources are missing, run: cd terraform/environments/dev && terraform apply"
  exit 1
fi
