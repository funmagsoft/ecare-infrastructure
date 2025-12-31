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

set -Eeuo pipefail

IFS=$'\n\t'
# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

setup_traps

# ============================================================================
# Parse Arguments
# ============================================================================

DEPLOYMENT_ID=""
DRY_RUN=true

# Extract deployment_id and validate options
for arg in "$@"; do
  case $arg in
    --dry-run|--execute)
      ;;
    --*)
      echo "Unknown option: $arg" >&2
      echo "" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$DEPLOYMENT_ID" ]]; then
        DEPLOYMENT_ID="$arg"
      else
        echo "Unexpected argument: $arg" >&2
        echo "" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

parse_dry_run "$@"

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
    log_error "Invalid deployment_id format: $deployment_id"
    log_error "deployment_id must be exactly 8 lowercase alphanumeric characters"
    exit 1
  fi
}

# Cleanup Azure Resource Groups
cleanup_resource_groups() {
  local deployment_id="$1"
  local dry_run="$2"

  log_info "Searching for Azure Resource Groups with DeploymentId=$deployment_id..."

  # Find resource groups with matching DeploymentId tag
  local rgs
  rgs=$(az_call group list \
    --tag "DeploymentId=$deployment_id" \
    --query "[].name" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$rgs" ]]; then
    log_info "  No Resource Groups found with DeploymentId=$deployment_id"
    return 0
  fi

  # Process each resource group
  while IFS= read -r rg; do
    if [[ -n "$rg" ]]; then
      if [[ "$dry_run" == false ]]; then
        log_info "  Deleting Resource Group: $rg"
        az_call group delete --name "$rg" --yes --no-wait
        log_success "  Initiated deletion of Resource Group: $rg"
      else
        log_info "  [DRY-RUN] Would delete Resource Group: $rg"
      fi
    fi
  done <<< "$rgs"
}

# Cleanup Azure AD Applications
cleanup_ad_applications() {
  local deployment_id="$1"
  local dry_run="$2"

  log_info "Searching for Entra ID Applications ending with -$deployment_id..."

  # Find applications with display names ending in -deployment_id
  local apps
  apps=$(az_call ad app list \
    --filter "endswith(displayName, '-${deployment_id}')" \
    --query "[].{id:id,name:displayName}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$apps" ]]; then
    log_info "  No Applications found ending with -$deployment_id"
    return 0
  fi

  # Process each application
  while IFS=$'\t' read -r app_id app_name; do
    if [[ -n "$app_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        log_info "  Deleting Application: $app_name ($app_id)"
        az_call ad app delete --id "$app_id"
        log_success "  Deleted Application: $app_name"
      else
        log_info "  [DRY-RUN] Would delete Application: $app_name ($app_id)"
      fi
    fi
  done <<< "$apps"
}

# Cleanup Service Principals (usually auto-deleted with app, but check anyway)
cleanup_service_principals() {
  local deployment_id="$1"
  local dry_run="$2"

  log_info "Searching for Service Principals ending with -$deployment_id..."

  # Find service principals with display names ending in -deployment_id
  local sps
  sps=$(az_call ad sp list \
    --filter "endswith(displayName, '-${deployment_id}')" \
    --query "[].{id:id,name:displayName}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$sps" ]]; then
    log_info "  No Service Principals found ending with -$deployment_id"
    return 0
  fi

  # Process each service principal
  while IFS=$'\t' read -r sp_id sp_name; do
    if [[ -n "$sp_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        log_info "  Deleting Service Principal: $sp_name ($sp_id)"
        az_call ad sp delete --id "$sp_id"
        log_success "  Deleted Service Principal: $sp_name"
      else
        log_info "  [DRY-RUN] Would delete Service Principal: $sp_name ($sp_id)"
      fi
    fi
  done <<< "$sps"
}

# Cleanup Managed Identities (from infra-identity phase)
cleanup_managed_identities() {
  local deployment_id="$1"
  local dry_run="$2"

  log_info "Searching for Managed Identities with DeploymentId=$deployment_id..."

  # Find managed identities with matching DeploymentId tag
  local identities
  identities=$(az_call identity list \
    --query "[?tags.DeploymentId=='${deployment_id}'].{id:id,name:name,rg:resourceGroup}" \
    --output tsv 2>/dev/null || true)

  if [[ -z "$identities" ]]; then
    log_info "  No Managed Identities found with DeploymentId=$deployment_id"
    return 0
  fi

  # Process each managed identity
  while IFS=$'\t' read -r identity_id identity_name identity_rg; do
    if [[ -n "$identity_id" ]]; then
      if [[ "$dry_run" == false ]]; then
        log_info "  Deleting Managed Identity: $identity_name (in $identity_rg)"
        az_call identity delete --ids "$identity_id"
        log_success "  Deleted Managed Identity: $identity_name"
      else
        log_info "  [DRY-RUN] Would delete Managed Identity: $identity_name (in $identity_rg)"
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
  echo "║  Cleanup Resources by Deployment ID                            ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""

  # Validate arguments
  if [[ -z "$DEPLOYMENT_ID" ]]; then
    log_error "Missing required argument: deployment_id"
    echo ""
    usage
    exit 1
  fi

  validate_deployment_id "$DEPLOYMENT_ID"

  # Display configuration
  log_info "Configuration:"
  log_info "  Deployment ID: $DEPLOYMENT_ID"
  log_info "  Mode:          $([ "$DRY_RUN" = true ] && echo "DRY-RUN (preview only)" || echo "EXECUTE (actual deletion)")"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    log_warning "Running in DRY-RUN mode - no resources will be deleted"
    log_warning "Use --execute flag to actually delete resources"
    echo ""
  else
    log_warning "Running in DELETION mode - resources WILL BE DELETED"
    log_warning "This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      log_info "Cleanup cancelled by user"
      exit 0
    fi
  fi

  # Check Azure CLI authentication
  check_azure_cli

  # Perform cleanup operations
  log_info "Starting cleanup operations..."
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
    log_success "Dry run completed - no resources were deleted"
    log_info "Use --execute flag to actually delete resources"
  else
    log_success "Cleanup completed!"
    log_info "Note: Resource Group deletions are asynchronous and may take several minutes"
    log_info "Check Azure Portal to monitor deletion progress"
  fi

  echo ""
}

# Run main function
main "$@"
