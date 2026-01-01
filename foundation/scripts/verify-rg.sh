#!/usr/bin/env bash
# =============================================================================
# Script: verify-rg.sh
# Component: foundation
# Purpose: Verify Resource Groups exist for all environments.
# =============================================================================
# Usage:
#   ./verify-rg.sh [-h|--help]
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
Usage: ./verify-rg.sh [--env <env>] [--all-envs] [-h|--help]

Verify Resource Groups exist for all environments.

Options:
  --env <env>   Target a single environment (repeatable): dev|test|stage|prod
  --all-envs    Target all environments (default)
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).

EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --env|--environment|--all-envs) : ;;
    *) usage; exit 1 ;;
  esac
done

DRY_RUN=false
init_script

parse_env_args "$@"
check_required_commands az jq
az_require_login
parse_env_args "$@"

check_required_commands az jq
az_require_login

log_info "=== Resource Group Verification ==="
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

ERRORS=0
VERIFIED=0

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
log_info "2. Checking Resource Groups..."
for ENV in "${TARGET_ENVS[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  log_info "=== Verifying ${RG_NAME} (${ENV} environment) ==="

  # Check if Resource Group exists
  RG_INFO=$(az_call group show \
    --name "$RG_NAME" \
    --query "{Name:name, Location:location, ProvisioningState:properties.provisioningState}" \
    --output json 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$RG_INFO" ]; then
    RG_LOCATION=$(echo "$RG_INFO" | jq -r '.Location')
    RG_STATE=$(echo "$RG_INFO" | jq -r '.ProvisioningState')

    log_success "Resource Group exists"
    log_info "  Name: $RG_NAME"
    log_info "  Location: $RG_LOCATION"
    log_info "  State: $RG_STATE"

    # Verify location matches expected location
    if [ "$RG_LOCATION" == "$LOCATION" ]; then
      log_success "Location matches expected: $LOCATION"
    else
      log_warning "Location mismatch: expected $LOCATION, got $RG_LOCATION"
    fi

    # Verify provisioning state
    if [ "$RG_STATE" == "Succeeded" ]; then
      log_success "Provisioning state: $RG_STATE"
    else
      log_warning "Provisioning state: $RG_STATE (expected: Succeeded)"
    fi

    # Check tags
    RG_TAGS=$(az_call group show \
      --name "$RG_NAME" \
      --query "tags" \
      --output json 2>/dev/null)

    if [ -n "$RG_TAGS" ] && [ "$RG_TAGS" != "null" ]; then
      ENV_TAG=$(echo "$RG_TAGS" | jq -r '.Environment // "missing"')
      PROJECT_TAG=$(echo "$RG_TAGS" | jq -r '.Project // "missing"')
      MANAGED_BY_TAG=$(echo "$RG_TAGS" | jq -r '.ManagedBy // "missing"')

      if [ "$ENV_TAG" == "$ENV" ]; then
        log_success "Tag Environment: $ENV_TAG"
      else
        log_warning "Tag Environment mismatch: expected $ENV, got $ENV_TAG"
      fi

      if [ "$PROJECT_TAG" == "$PROJECT" ]; then
        log_success "Tag Project: $PROJECT_TAG"
      else
        log_warning "Tag Project mismatch: expected $PROJECT, got $PROJECT_TAG"
      fi

      case "$MANAGED_BY_TAG" in
        terraform|Terraform|Bootstrap|bootstrap)
          log_success "Tag ManagedBy: $MANAGED_BY_TAG"
          ;;
        *)
          log_warning "Tag ManagedBy: $MANAGED_BY_TAG (expected: Terraform|Bootstrap)"
          ;;
      esac

      PHASE_TAG=$(echo "$RG_TAGS" | jq -r '.Phase // "missing"')
      if [ "$PHASE_TAG" == "Foundation" ]; then
        log_success "Tag Phase: $PHASE_TAG"
      else
        log_warning "Tag Phase: $PHASE_TAG (expected: Foundation)"
      fi
    else
      log_warning "No tags found on Resource Group"
    fi

    VERIFIED=$((VERIFIED + 1))
  else
    log_error "Resource Group missing or not accessible"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

# Summary
log_info "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  log_info "Verified:"
  log_info "  - Resource Groups verified: ${VERIFIED}/${#TARGET_ENVS[@]}"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s)"
  echo ""
  log_info "Status:"
  log_info "  - Resource Groups verified: ${VERIFIED}/${#TARGET_ENVS[@]}"
  exit 1
fi
