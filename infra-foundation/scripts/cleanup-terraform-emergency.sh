#!/usr/bin/env bash
# =============================================================================
# Script: cleanup-terraform-emergency.sh
# Component: infra-foundation
# Purpose: Emergency cleanup of Terraform-managed resources when normal destroy is blocked.
# =============================================================================
# Usage:
#   ./cleanup-terraform-emergency.sh [-h|--help] [--dry-run|--execute]
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
Usage: ./cleanup-terraform-emergency.sh [--dry-run|--execute] [-h|--help]

Emergency cleanup helper intended for rare cases where resources are stuck and
Terraform destroy cannot proceed (e.g., broken state, partial deploy).

Options:
  --dry-run     Print planned actions without executing
  --execute     Execute actions (default)
  -h, --help    Show this help and exit

Notes:
  - This script performs destructive operations. Use only if you fully understand the impact.
  - Requires Azure CLI (az) and an active login (az login).

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

log_info "=== EMERGENCY Terraform Resource Cleanup ==="
log_dry_run
log_error "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
log_error "┃  WARNING: THIS IS AN EMERGENCY CLEANUP SCRIPT                   ┃"
log_error "┃  Use ONLY when 'terraform destroy' fails                        ┃"
log_error "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""
log_warning "This script will DELETE Terraform-managed resources directly via Azure API:"
log_warning ""
log_warning "  Terraform Bootstrap:"
log_warning "    - RBAC role assignments for Service Principals"
log_warning "    - Federated Identity Credentials (FIC)"
log_warning "    - Service Principals for GitHub Actions"
log_warning "    - service-principals.env file"
log_warning ""
log_warning "  Terraform Environment:"
log_warning "    - VPN Gateway (if exists)"
log_warning "    - Network Security Groups"
log_warning "    - Route Tables"
log_warning "    - Virtual Network (includes all subnets)"
log_warning "    - Resource Locks (if any)"
log_warning ""
log_warning "  NOTE: Phase 0 resources (RG, Storage Accounts) are NOT deleted."
log_warning "        Use cleanup-phase0.sh separately if needed."
echo ""

if [ "$DRY_RUN" != true ]; then
  log_warning "To confirm, type exactly: DELETE-TERRAFORM-RESOURCES"
  read -p "Confirmation: " CONFIRM
  if [ "$CONFIRM" != "DELETE-TERRAFORM-RESOURCES" ]; then
    log_info "Aborted."
    exit 1
  fi
  echo ""
fi

TOTAL_ERRORS=0
TOTAL_DELETED=0

# Process each environment
for ENV in dev test stage prod; do
  echo ""
  echo "================================================================================"
  echo "Environment: $ENV"
  echo "================================================================================"
  echo ""

  RG_NAME="rg-${PROJECT}-${ENV}"
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  VNET_NAME="vnet-${PROJECT}-${ENV}"
  VPN_NAME="vgw-${PROJECT}-${ENV}"

  # Check if Resource Group exists
  if [ "$DRY_RUN" != true ]; then
    if ! az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_warning "Resource Group ${RG_NAME} not found, skipping environment..."
      continue
    fi
  fi

  # ============================================================================
  # Step 1: Remove Resource Locks
  # ============================================================================
  log_info "--- Step 1: Removing Resource Locks ---"
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would check for resource locks on ${RG_NAME}"
  else
    LOCKS=$(az_call lock list --resource-group "$RG_NAME" --query "[].id" -o tsv 2>/dev/null)
    if [ -n "$LOCKS" ]; then
      echo "$LOCKS" | while read -r lock_id; do
        if [ -n "$lock_id" ]; then
          if az_exec lock delete --ids "$lock_id" 2>/dev/null; then
            log_success "Deleted lock: $(basename $lock_id)"
            TOTAL_DELETED=$((TOTAL_DELETED + 1))
          else
            log_error "Failed to delete lock: $(basename $lock_id)"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
          fi
        fi
      done
    else
      log_info "No resource locks found"
    fi
  fi
  echo ""

  # ============================================================================
  # Step 2: Delete VPN Gateway (long-running operation)
  # ============================================================================
  log_info "--- Step 2: Deleting VPN Gateway (if exists) ---"
  if [ "$DRY_RUN" != true ]; then
    if az_call network vnet-gateway show --name "$VPN_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
      log_info "Deleting VPN Gateway $VPN_NAME (this may take 10-20 minutes)..."
      if az_exec network vnet-gateway delete \
        --name "$VPN_NAME" \
        --resource-group "$RG_NAME" \
        --no-wait 2>/dev/null; then
        log_success "VPN Gateway deletion initiated (async)"
        TOTAL_DELETED=$((TOTAL_DELETED + 1))
      else
        log_error "Failed to delete VPN Gateway: $VPN_NAME"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
      fi
    else
      log_info "VPN Gateway not found (may not be enabled)"
    fi
  else
    log_info "[DRY-RUN] Would check and delete VPN Gateway: $VPN_NAME"
  fi
  echo ""

  # ============================================================================
  # Step 3: Delete Network Security Groups
  # ============================================================================
  log_info "--- Step 3: Deleting Network Security Groups ---"
  for NSG_TYPE in aks data mgmt; do
    NSG_NAME="nsg-${NSG_TYPE}-${PROJECT}-${ENV}"

    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY-RUN] Would delete NSG: $NSG_NAME"
    else
      if az_call network nsg show --name "$NSG_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
        if az_exec network nsg delete \
          --name "$NSG_NAME" \
          --resource-group "$RG_NAME" \
          --no-wait 2>/dev/null; then
          log_success "Deleted NSG: $NSG_NAME"
          TOTAL_DELETED=$((TOTAL_DELETED + 1))
        else
          log_error "Failed to delete NSG: $NSG_NAME"
          TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
      else
        log_info "NSG not found: $NSG_NAME"
      fi
    fi
  done
  echo ""

  # ============================================================================
  # Step 4: Delete Route Tables
  # ============================================================================
  log_info "--- Step 4: Deleting Route Tables ---"
  RT_NAME="rt-${PROJECT}-${ENV}"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete Route Table: $RT_NAME"
  else
    if az_call network route-table show --name "$RT_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
      if az_exec network route-table delete \
        --name "$RT_NAME" \
        --resource-group "$RG_NAME" \
        --no-wait 2>/dev/null; then
        log_success "Deleted Route Table: $RT_NAME"
        TOTAL_DELETED=$((TOTAL_DELETED + 1))
      else
        log_error "Failed to delete Route Table: $RT_NAME"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
      fi
    else
      log_info "Route Table not found (may not exist)"
    fi
  fi
  echo ""

  # ============================================================================
  # Step 5: Wait for async operations (VPN, NSG)
  # ============================================================================
  if [ "$DRY_RUN" != true ]; then
    log_info "--- Step 5: Waiting for network resource deletions ---"
    log_info "Waiting 30 seconds for async deletions to progress..."
    sleep 30
    log_success "Wait completed"
    echo ""
  fi

  # ============================================================================
  # Step 6: Delete Virtual Network (includes subnets)
  # ============================================================================
  log_info "--- Step 6: Deleting Virtual Network ---"
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete VNet: $VNET_NAME (includes all subnets)"
  else
    if az_call network vnet show --name "$VNET_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
      log_info "Deleting VNet $VNET_NAME (includes all subnets)..."
      if az_exec network vnet delete \
        --name "$VNET_NAME" \
        --resource-group "$RG_NAME" 2>/dev/null; then
        log_success "Deleted VNet: $VNET_NAME"
        TOTAL_DELETED=$((TOTAL_DELETED + 1))
      else
        log_error "Failed to delete VNet: $VNET_NAME"
        log_warning "VNet deletion may fail if VPN Gateway is still deleting. Try again later."
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
      fi
    else
      log_info "VNet not found: $VNET_NAME"
    fi
  fi
  echo ""

  # ============================================================================
  # Step 7: Delete RBAC Role Assignments for Service Principal
  # ============================================================================
  log_info "--- Step 7: Deleting RBAC Role Assignments ---"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete RBAC role assignments for: $SP_NAME"
  else
    # Get Service Principal App ID
    SP_APP_ID=$(az_call ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null)

    if [ -n "$SP_APP_ID" ] && [ "$SP_APP_ID" != "null" ]; then
      log_info "Deleting RBAC assignments for ${SP_NAME} (App ID: ${SP_APP_ID})..."

      # Get all role assignments for this SP
      ROLE_ASSIGNMENTS=$(az_call role assignment list --assignee "$SP_APP_ID" --query "[].id" -o tsv 2>/dev/null)

      if [ -n "$ROLE_ASSIGNMENTS" ]; then
        echo "$ROLE_ASSIGNMENTS" | while read -r assignment_id; do
          if [ -n "$assignment_id" ]; then
            ROLE_NAME=$(az_call role assignment list --ids "$assignment_id" --query "[0].roleDefinitionName" -o tsv 2>/dev/null || echo "unknown")
            if az_exec role assignment delete --ids "$assignment_id" 2>/dev/null; then
              log_success "Deleted RBAC: $ROLE_NAME"
              TOTAL_DELETED=$((TOTAL_DELETED + 1))
            else
              log_error "Failed to delete RBAC assignment: $ROLE_NAME"
              TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            fi
          fi
        done
      else
        log_info "No RBAC assignments found for ${SP_NAME}"
      fi
    else
      log_info "Service Principal not found: ${SP_NAME}"
    fi
  fi
  echo ""

  # ============================================================================
  # Step 8: Delete Federated Identity Credentials
  # ============================================================================
  log_info "--- Step 8: Deleting Federated Identity Credentials ---"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete FICs for: $SP_NAME"
  else
    if [ -n "$SP_APP_ID" ] && [ "$SP_APP_ID" != "null" ]; then
      FIC_IDS=$(az_call ad app federated-credential list --id "$SP_APP_ID" --query "[].id" -o tsv 2>/dev/null)

      if [ -n "$FIC_IDS" ]; then
        echo "$FIC_IDS" | while read -r fic_id; do
          if [ -n "$fic_id" ]; then
            FIC_NAME=$(az_call ad app federated-credential show --id "$SP_APP_ID" --federated-credential-id "$fic_id" --query "name" -o tsv 2>/dev/null || echo "unknown")
            if az_exec ad app federated-credential delete \
              --id "$SP_APP_ID" \
              --federated-credential-id "$fic_id" 2>/dev/null; then
              log_success "Deleted FIC: $FIC_NAME"
              TOTAL_DELETED=$((TOTAL_DELETED + 1))
            else
              log_error "Failed to delete FIC: $FIC_NAME"
              TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            fi
          fi
        done
      else
        log_info "No FICs found for ${SP_NAME}"
      fi
    fi
  fi
  echo ""

  # ============================================================================
  # Step 9: Delete Service Principal
  # ============================================================================
  log_info "--- Step 9: Deleting Service Principal ---"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete Service Principal: $SP_NAME"
  else
    if [ -n "$SP_APP_ID" ] && [ "$SP_APP_ID" != "null" ]; then
      if az_exec ad sp delete --id "$SP_APP_ID" 2>/dev/null; then
        log_success "Deleted Service Principal: $SP_NAME"
        TOTAL_DELETED=$((TOTAL_DELETED + 1))
      else
        log_error "Failed to delete Service Principal: $SP_NAME"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
      fi
    else
      log_info "Service Principal not found: $SP_NAME"
    fi
  fi
  echo ""
done

# ============================================================================
# Step 10: Clean up service-principals.env file
# ============================================================================
echo "================================================================================"
log_info "--- Step 10: Cleaning up service-principals.env file ---"
echo "================================================================================"
echo ""

SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"
if [ "$DRY_RUN" = true ]; then
  log_info "[DRY-RUN] Would delete: $SP_IDS_FILE"
else
  if [ -f "$SP_IDS_FILE" ]; then
    if cmd_exec rm -f "$SP_IDS_FILE"; then
      log_success "Deleted service-principals.env file"
      TOTAL_DELETED=$((TOTAL_DELETED + 1))
    else
      log_warning "Failed to delete service-principals.env file"
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
  else
    log_info "service-principals.env file not found"
  fi
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "================================================================================"
log_info "=== Emergency Cleanup Summary ==="
echo "================================================================================"
echo ""

if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  echo ""
  log_info "Would delete Terraform-managed resources:"
  log_info "  - Resource locks (if any)"
  log_info "  - VPN Gateways (if enabled)"
  log_info "  - Network Security Groups (3 × 4 environments)"
  log_info "  - Route Tables"
  log_info "  - Virtual Networks (includes subnets)"
  log_info "  - RBAC role assignments"
  log_info "  - Federated Identity Credentials (12 total)"
  log_info "  - Service Principals (4 environments)"
  log_info "  - service-principals.env file"
  echo ""
  log_info "Phase 0 resources (RG, Storage Accounts) are NOT deleted."
else
  if [ $TOTAL_ERRORS -eq 0 ]; then
    log_success "Emergency cleanup completed successfully!"
    echo ""
    log_info "Deleted/initiated deletion: ${TOTAL_DELETED} resource(s)"
    echo ""
    log_warning "Next steps:"
    log_info "  1. Verify cleanup: ./scripts/verify-terraform-bootstrap.sh (should fail)"
    log_info "  2. Verify cleanup: ./scripts/verify-terraform-environment.sh (should fail)"
    log_info "  3. Check for remaining resources:"
    log_info "     az_call resource list --resource-group rg-${PROJECT}-dev --output table"
    log_info "  4. Optional: Clean Phase 0 with ./scripts/cleanup-phase0.sh"
    echo ""
    log_info "Note: VPN Gateway deletions may still be in progress (takes 10-20 min)"
  else
    log_error "Emergency cleanup completed with ${TOTAL_ERRORS} error(s)"
    echo ""
    log_info "Deleted/initiated deletion: ${TOTAL_DELETED} resource(s)"
    echo ""
    log_warning "Some resources may not have been deleted. Please review the output above."
    log_warning "You may need to manually delete remaining resources through Azure Portal."
    exit 1
  fi
fi
