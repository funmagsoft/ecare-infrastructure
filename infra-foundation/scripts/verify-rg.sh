#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Resource Group Verification ==="
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

ERRORS=0
VERIFIED=0

# Check Azure CLI authentication
echo "1. Checking Azure CLI authentication..."
if az account show --output none 2>/dev/null; then
  log_success "Azure CLI authenticated"
else
  log_error "Azure CLI not authenticated"
  ERRORS=$((ERRORS + 1))
fi

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

echo ""
echo "2. Checking Resource Groups..."
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  echo "=== Verifying ${RG_NAME} (${ENV} environment) ==="

  # Check if Resource Group exists
  RG_INFO=$(az group show \
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
    RG_TAGS=$(az group show \
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

      if [ "$MANAGED_BY_TAG" == "terraform" ]; then
        log_success "Tag ManagedBy: $MANAGED_BY_TAG"
      else
        log_warning "Tag ManagedBy: $MANAGED_BY_TAG (expected: terraform)"
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
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  echo "Verified:"
  echo "  - Resource Groups verified: ${VERIFIED}/4"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s)"
  echo ""
  echo "Status:"
  echo "  - Resource Groups verified: ${VERIFIED}/4"
  exit 1
fi
