#!/usr/bin/env bash
# Cleanup Azure and Entra ID resources by Deployment ID
#
# This script removes all resources tagged with a specific deployment_id.
# It handles both Azure resources (via Resource Groups) and Entra ID resources
# (Application Registrations and Service Principals).
#
# Usage:
#   ./cleanup-by-deployment-id.sh <deployment_id> [--dry-run]
#
# Arguments:
#   deployment_id - 8-character deployment identifier (e.g., a1b2c3d4)
#
# Options:
#   --dry-run     Preview changes without executing them (default)
#
# Examples:
#   ./cleanup-by-deployment-id.sh a1b2c3d4           # Dry run (preview only)
#   ./cleanup-by-deployment-id.sh a1b2c3d4 --dry-run # Explicit dry run
#   ./cleanup-by-deployment-id.sh a1b2c3d4 --execute # Actually delete resources
#
# Note: This script requires Azure CLI to be installed and authenticated.

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Parse Arguments
# ============================================================================

DEPLOYMENT_ID=""
DRY_RUN=true

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --execute)
      DRY_RUN=false
      shift
      ;;
    *)
      if [[ -z "$DEPLOYMENT_ID" ]]; then
        DEPLOYMENT_ID="$arg"
      fi
      shift
      ;;
  esac
done

# ============================================================================
# Functions
# ============================================================================

# Display usage information
usage() {
  cat << EOF
Usage: $(basename "$0") <deployment_id> [--dry-run|--execute]

Cleanup Azure and Entra ID resources by Deployment ID.

Arguments:
  deployment_id   8-character deployment identifier (e.g., a1b2c3d4)

Options:
  --dry-run       Preview changes without executing them (default)
  --execute       Actually delete resources

Examples:
  $(basename "$0") a1b2c3d4           # Dry run (preview only)
  $(basename "$0") a1b2c3d4 --dry-run # Explicit dry run
  $(basename "$0") a1b2c3d4 --execute # Actually delete resources

Environment-specific deployment IDs (from globals.sh):
  dev:   a1b2c3d4
  test:  e5f6g7h8
  stage: i9j0k1l2
  prod:  m3n4o5p6

Note: This script requires Azure CLI to be installed and authenticated.
EOF
}

# Validate deployment ID format
validate_deployment_id() {
  local deployment_id="$1"

  if [[ ! "$deployment_id" =~ ^[a-z0-9]{8}$ ]]; then
    error "Invalid deployment_id format: $deployment_id"
    error "deployment_id must be exactly 8 lowercase alphanumeric characters"
    exit 1
  fi
}

# Cleanup Azure Resource Groups
cleanup_resource_groups() {
  local deployment_id="$1"
  local dry_run="$2"

  info "Searching for Azure Resource Groups with DeploymentId=$deployment_id..."

  # Find resource groups with matching DeploymentId tag
  local rgs
  rgs=$(az group list \
    --tag "DeploymentId=$deployment_id" \
    --query "[].name" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$rgs" ]]; then
    info "  No Resource Groups found with DeploymentId=$deployment_id"
    return 0
  fi

  # Process each resource group
  while IFS= read -r rg; do
    if [[ -n "$rg" ]]; then
      if [[ "$dry_run" == false ]]; then
        info "  Deleting Resource Group: $rg"
        az group delete --name "$rg" --yes --no-wait
        success "  Initiated deletion of Resource Group: $rg"
      else
        info "  [DRY-RUN] Would delete Resource Group: $rg"
      fi
    fi
  done <<< "$rgs"
}

# Cleanup Azure AD Applications
cleanup_ad_applications() {
  local deployment_id="$1"
  local dry_run="$2"

  info "Searching for Entra ID Applications ending with -$deployment_id..."

  # Find applications with display names ending in -deployment_id
  local apps
  apps=$(az ad app list \
    --filter "endswith(displayName, '-${deployment_id}')" \
    --query "[].{id:id,name:displayName}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$apps" ]]; then
    info "  No Applications found ending with -$deployment_id"
    return 0
  fi

  # Process each application
  while IFS=$'\t' read -r app_id app_name; do
    if [[ -n "$app_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        info "  Deleting Application: $app_name ($app_id)"
        az ad app delete --id "$app_id"
        success "  Deleted Application: $app_name"
      else
        info "  [DRY-RUN] Would delete Application: $app_name ($app_id)"
      fi
    fi
  done <<< "$apps"
}

# Cleanup Service Principals (usually auto-deleted with app, but check anyway)
cleanup_service_principals() {
  local deployment_id="$1"
  local dry_run="$2"

  info "Searching for Service Principals ending with -$deployment_id..."

  # Find service principals with display names ending in -deployment_id
  local sps
  sps=$(az ad sp list \
    --filter "endswith(displayName, '-${deployment_id}')" \
    --query "[].{id:id,name:displayName}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$sps" ]]; then
    info "  No Service Principals found ending with -$deployment_id"
    return 0
  fi

  # Process each service principal
  while IFS=$'\t' read -r sp_id sp_name; do
    if [[ -n "$sp_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        info "  Deleting Service Principal: $sp_name ($sp_id)"
        az ad sp delete --id "$sp_id"
        success "  Deleted Service Principal: $sp_name"
      else
        info "  [DRY-RUN] Would delete Service Principal: $sp_name ($sp_id)"
      fi
    fi
  done <<< "$sps"
}

# Cleanup Managed Identities (from infra-identity phase)
cleanup_managed_identities() {
  local deployment_id="$1"
  local dry_run="$2"

  info "Searching for Managed Identities with DeploymentId=$deployment_id..."

  # Find managed identities with matching DeploymentId tag
  local identities
  identities=$(az identity list \
    --query "[?tags.DeploymentId=='${deployment_id}'].{id:id,name:name,rg:resourceGroup}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$identities" ]]; then
    info "  No Managed Identities found with DeploymentId=$deployment_id"
    return 0
  fi

  # Process each managed identity
  while IFS=$'\t' read -r identity_id identity_name identity_rg; do
    if [[ -n "$identity_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        info "  Deleting Managed Identity: $identity_name (in $identity_rg)"
        az identity delete --ids "$identity_id"
        success "  Deleted Managed Identity: $identity_name"
      else
        info "  [DRY-RUN] Would delete Managed Identity: $identity_name (in $identity_rg)"
      fi
    fi
  done <<< "$identities"
}

# ============================================================================
# Main Script
# ============================================================================

main() {
  # Display banner
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║  Cleanup Resources by Deployment ID                           ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""

  # Validate arguments
  if [[ -z "$DEPLOYMENT_ID" ]]; then
    error "Missing required argument: deployment_id"
    echo ""
    usage
    exit 1
  fi

  validate_deployment_id "$DEPLOYMENT_ID"

  # Display configuration
  info "Configuration:"
  info "  Deployment ID: $DEPLOYMENT_ID"
  info "  Mode:          $([ "$DRY_RUN" = true ] && echo "DRY-RUN (preview only)" || echo "EXECUTE (actual deletion)")"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    warning "Running in DRY-RUN mode - no resources will be deleted"
    warning "Use --execute flag to actually delete resources"
    echo ""
  else
    warning "Running in DELETION mode - resources WILL BE DELETED"
    warning "This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      info "Cleanup cancelled by user"
      exit 0
    fi
  fi

  # Check Azure CLI authentication
  check_azure_cli

  # Perform cleanup operations
  info "Starting cleanup operations..."
  echo ""

  cleanup_resource_groups "$DEPLOYMENT_ID" "$DRY_RUN"
  echo ""

  cleanup_ad_applications "$DEPLOYMENT_ID" "$DRY_RUN"
  echo ""

  cleanup_service_principals "$DEPLOYMENT_ID" "$DRY_RUN"
  echo ""

  cleanup_managed_identities "$DEPLOYMENT_ID" "$DRY_RUN"
  echo ""

  # Summary
  if [ "$DRY_RUN" = true ]; then
    success "Dry run completed - no resources were deleted"
    info "Use --execute flag to actually delete resources"
  else
    success "Cleanup completed!"
    info "Note: Resource Group deletions are asynchronous and may take several minutes"
    info "Check Azure Portal to monitor deletion progress"
  fi

  echo ""
}

# Run main function
main "$@"
