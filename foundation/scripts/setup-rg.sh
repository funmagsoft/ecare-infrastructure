#!/usr/bin/env bash
# =============================================================================
# Script: setup-rg.sh
# Component: foundation
# Purpose: Create Azure Resource Groups for all environments (dev/test/stage/prod).
# =============================================================================
# Usage:
#   ./setup-rg.sh [--dry-run|--execute] [-h|--help]
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
Usage: ./setup-rg.sh [--dry-run|--execute] [-h|--help]

Create Azure Resource Groups for all environments (dev/test/stage/prod).

Options:
  --dry-run     Print planned actions without executing
  --execute     Execute actions (default)
  -h, --help    Show this help and exit

Notes:
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

log_info "=== Creating Resource Groups ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

ERRORS=0
CREATED=0

# Create Resource Groups for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  log_info "--- Creating Resource Group for ${ENV} environment ---"
  log_info "Resource Group: $RG_NAME"
  log_info "Location: $LOCATION"

  # Check if Resource Group already exists
  if [ "$DRY_RUN" != true ]; then
    if az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_warning "Resource Group $RG_NAME already exists, skipping..."
      CREATED=$((CREATED + 1))
      echo ""
      continue
    fi
  fi

  # Create Resource Group
  log_info "Creating Resource Group..."
  if az_exec group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --tags \
      Environment="${ENV}" \
      Project="${PROJECT}" \
      ManagedBy="Bootstrap" \
      Purpose="terraform-state" \
      CreatedDate="$(date +%Y-%m-%d)" \
    --output none; then
    log_success "Resource Group ${RG_NAME} created successfully"
    CREATED=$((CREATED + 1))
  else
    log_error "Failed to create Resource Group ${RG_NAME}"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

# Summary
log_info "=== Resource Group Creation Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would create Resource Groups: 4 (one per environment)"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Resource Groups created/verified: ${CREATED}/4"
  else
    log_error "Resource Group creation completed with ${ERRORS} error(s)"
    log_warning "Only ${CREATED}/4 Resource Groups were created/verified"
    exit 1
  fi
fi

echo ""
log_info "Resource Groups are ready for use."
