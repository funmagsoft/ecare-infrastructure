#!/usr/bin/env bash
# =============================================================================
# Script: cleanup-phase0.sh
# Component: foundation
# Purpose: Delete Phase 0 infrastructure (resource groups, state storage, role assignments) for all environments.
# =============================================================================
# Usage:
#   ./cleanup-phase0.sh [-h|--help] [--dry-run|--execute]
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
Usage: ./cleanup-phase0.sh [--dry-run|--execute] [-h|--help]

Delete Phase 0 infrastructure for all environments (dev/test/stage/prod).
This includes Terraform state storage and related role assignments.

Options:
  --dry-run     Print planned actions without executing
  --execute     Execute actions (default)
  -h, --help    Show this help and exit

Notes:
  - This script performs destructive operations. Review the output carefully.
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

log_info "=== Phase 0 Infrastructure Cleanup ==="
log_dry_run
log_warning "This will delete Phase 0 infrastructure ONLY:"
log_warning "  - Current user RBAC assignments (Storage Blob Data Contributor)"
log_warning "  - Storage Accounts for Terraform state (⚠️ ALL STATE FILES WILL BE LOST!)"
log_warning "  - Resource Groups (dev, test, stage, prod)"
echo ""
log_error "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
log_error "┃  CRITICAL: This will DELETE Terraform state files permanently!   ┃"
log_error "┃  Run 'terraform destroy' FIRST to delete Terraform resources.    ┃"
log_error "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""
log_info "This script does NOT delete Terraform-managed resources (SP, VNet, etc.)"
log_info "Those should be deleted with 'terraform destroy' first."
echo ""

if [ "$DRY_RUN" != true ]; then
  log_warning "To confirm Phase 0 cleanup, type exactly: DELETE-PHASE0"
  read -p "Confirmation: " CONFIRM
  if [ "$CONFIRM" != "DELETE-PHASE0" ]; then
    log_info "Aborted."
    exit 1
  fi
  echo ""
fi

ERRORS=0
DELETED=0

# ============================================================================
# Step 1: Delete Current User RBAC Role Assignments
# ============================================================================
log_info "=== Step 1: Deleting Current User RBAC Assignments ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  CURRENT_USER_EMAIL="<current-user-email>"
  CURRENT_USER_OBJECT_ID="<current-user-object-id>"
  log_info "[DRY-RUN] Would get current user information"
else
  CURRENT_USER_EMAIL=$(az_call account show --query user.name --output tsv)
  CURRENT_USER_OBJECT_ID=$(az_call ad signed-in-user show --query id --output tsv 2>/dev/null)

  # If signed-in-user doesn't work, try alternative method
  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_info "Trying alternative method to get Object ID from email..."
    CURRENT_USER_OBJECT_ID=$(az_call ad user show --id "$CURRENT_USER_EMAIL" --query id --output tsv 2>/dev/null || echo "")
  fi

  if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
    log_warning "Could not determine current user Object ID, skipping RBAC cleanup"
    log_info "User email: $CURRENT_USER_EMAIL"
  else
    log_info "Current user email: $CURRENT_USER_EMAIL"
    log_info "Current user Object ID: $CURRENT_USER_OBJECT_ID"
    echo ""
  fi
fi

if [ -n "$CURRENT_USER_OBJECT_ID" ] && [ "$CURRENT_USER_OBJECT_ID" != "null" ]; then
  for ENV in dev test stage prod; do
    RG_NAME="rg-${PROJECT}-${ENV}"
    SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
    SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"

    log_info "--- Removing access from ${SA_NAME} ---"

    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY-RUN] Would delete Storage Blob Data Contributor role for current user"
    else
      if az_exec role assignment delete \
        --assignee "$CURRENT_USER_OBJECT_ID" \
        --scope "$SA_SCOPE" \
        --role "Storage Blob Data Contributor" \
        --output none 2>/dev/null; then
        log_success "Removed Storage Blob Data Contributor role from ${SA_NAME}"
      else
        # Check if role assignment exists
        if az_call role assignment list \
          --assignee "$CURRENT_USER_OBJECT_ID" \
          --scope "$SA_SCOPE" \
          --role "Storage Blob Data Contributor" \
          --output none 2>/dev/null | grep -q "Storage Blob Data Contributor"; then
          log_error "Failed to remove role from ${SA_NAME}"
          ERRORS=$((ERRORS + 1))
        else
          log_info "Role not assigned on ${SA_NAME} (already removed or never assigned)"
        fi
      fi
    fi
  done
else
  log_info "Skipping RBAC cleanup (current user Object ID not available)"
fi

echo ""

# ============================================================================
# Step 2: Delete Storage Accounts and Containers
# ============================================================================
log_info "=== Step 2: Deleting Storage Accounts ==="
echo ""

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "--- Deleting Storage Account: ${SA_NAME} ---"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete Storage Account: $SA_NAME and all containers"
  else
    # Check if Storage Account exists
    if az_call storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
      # Delete all containers first
      log_info "Deleting containers in ${SA_NAME}..."
      CONTAINERS=$(az_call storage container list --account-name "$SA_NAME" --auth-mode login --query "[].name" --output tsv 2>/dev/null)
      if [ -n "$CONTAINERS" ]; then
        echo "$CONTAINERS" | while read -r container_name; do
          if [ -n "$container_name" ]; then
            if az_exec storage container delete \
              --name "$container_name" \
              --account-name "$SA_NAME" \
              --auth-mode login \
              --output none 2>/dev/null; then
              log_success "  Deleted container: $container_name"
            else
              log_warning "  Failed to delete container: $container_name"
            fi
          fi
        done
      fi

      # Delete Storage Account
      if az_exec storage account delete \
        --name "$SA_NAME" \
        --resource-group "$RG_NAME" \
        --yes \
        --output none 2>/dev/null; then
        log_success "Deleted Storage Account: ${SA_NAME}"
        DELETED=$((DELETED + 1))
      else
        log_error "Failed to delete Storage Account: ${SA_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Storage Account ${SA_NAME} not found, skipping..."
    fi
  fi

  echo ""
done

# ============================================================================
# Step 3: Delete Resource Groups
# ============================================================================
log_info "=== Step 3: Deleting Resource Groups ==="
echo ""

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  log_info "--- Deleting Resource Group: ${RG_NAME} ---"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete Resource Group: $RG_NAME (and all resources within it)"
  else
    if az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_info "Deleting Resource Group ${RG_NAME} (this will delete all remaining resources)..."
      if az_exec group delete \
        --name "$RG_NAME" \
        --yes \
        --no-wait \
        --output none 2>/dev/null; then
        log_success "Deletion initiated for ${RG_NAME}"
        DELETED=$((DELETED + 1))
      else
        log_error "Failed to delete Resource Group: ${RG_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Resource Group ${RG_NAME} not found, skipping..."
    fi
  fi

  echo ""
done

# ============================================================================
# Summary
# ============================================================================
echo "================================================================================"
log_info "=== Phase 0 Cleanup Summary ==="
echo "================================================================================"
echo ""

if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  echo ""
  log_info "Would delete Phase 0 infrastructure:"
  log_info "  - Current user RBAC assignments (Storage Blob Data Contributor)"
  log_info "  - Storage Accounts and containers (4 environments)"
  log_info "  - Resource Groups (dev, test, stage, prod)"
  echo ""
  log_info "Terraform-managed resources (SP, VNet, etc.) would NOT be deleted."
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Phase 0 cleanup completed successfully!"
    echo ""
    log_info "Deleted/initiated deletion for ${DELETED} resource(s)"
    echo ""
    log_warning "Important Notes:"
    log_info "  - Resource Groups are being deleted asynchronously (may take 5-15 minutes)"
    log_info "  - All Terraform state files have been permanently deleted"
    log_info "  - Terraform-managed resources (SP, FIC, VNet, NSG, VPN) still exist"
    echo ""
    log_info "To verify cleanup:"
    echo "  az_call group list --query \"[?starts_with(name, 'rg-${PROJECT}-')]\""
    echo ""
    log_info "To remove Terraform resources (if not done yet):"
    log_info "  Run: terraform destroy (before Phase 0 cleanup)"
    log_info "  Or:  ./scripts/cleanup-terraform-emergency.sh (if terraform destroy failed)"
  else
    log_error "Phase 0 cleanup completed with ${ERRORS} error(s)"
    echo ""
    log_warning "Some resources may not have been deleted. Please review the output above."
    exit 1
  fi
fi
