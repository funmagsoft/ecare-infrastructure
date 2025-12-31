#!/usr/bin/env bash
# =============================================================================
# Script: verify-terraform-environment.sh
# Component: infra-foundation
# Purpose: Verify Terraform environment module prerequisites and state configuration.
# =============================================================================
# Usage:
#   ./verify-terraform-environment.sh [-h|--help]
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
Usage: ./verify-terraform-environment.sh [env1 env2 ...] [-h|--help]

Verify Terraform environment module prerequisites and state configuration.

Arguments:
  env1 env2 ...  Optional list of environments to verify (dev, test, stage, prod).

Options:
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).

EOF
}

ENV_LIST=()

if [ $# -gt 0 ]; then
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        usage
        exit 1
        ;;
      *)
        validate_environment "$arg" || exit 1
        ENV_LIST+=("$arg")
        ;;
    esac
  done
fi

# Verify scripts do not modify resources; dry-run is not applicable.
DRY_RUN=false
init_script

log_info "=== Terraform Environment Module Verification ==="
log_info "Verifies resources created by terraform/modules/environment:"
log_info "  - Virtual Network and Subnets"
log_info "  - Network Security Groups"
log_info "  - VPN Gateway (if enabled)"
log_info "  - Route Tables"
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

# Verify Environment resources for each environment
log_info "2. Verifying Environment resources..."
echo ""

TOTAL_VNETS=0
TOTAL_SUBNETS=0
TOTAL_NSGS=0
TOTAL_VPNS=0

if [ "${#ENV_LIST[@]}" -eq 0 ]; then
  ENV_LIST=(dev test stage prod)
fi

for ENV in "${ENV_LIST[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  VNET_NAME="vnet-${PROJECT}-${ENV}"

  log_info "=== Verifying Environment for ${ENV} ==="

  # Check if Resource Group exists (prerequisite)
  if ! az_call group show --name "$RG_NAME" --output none 2>/dev/null; then
    log_error "Resource Group not found: ${RG_NAME}"
    log_info "  Phase 0 setup may not have been run."
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # 1. Verify VNet
  log_info "  Checking Virtual Network..."
  VNET_INFO=$(az_call network vnet show \
    --name "$VNET_NAME" \
    --resource-group "$RG_NAME" \
    --query "{CIDR:addressSpace.addressPrefixes[0], Location:location, ProvisioningState:provisioningState}" \
    --output json 2>/dev/null)

  if [ -n "$VNET_INFO" ] && [ "$VNET_INFO" != "null" ]; then
    VNET_CIDR=$(echo "$VNET_INFO" | jq -r '.CIDR')
    VNET_LOCATION=$(echo "$VNET_INFO" | jq -r '.Location')
    VNET_STATE=$(echo "$VNET_INFO" | jq -r '.ProvisioningState')

    log_success "  VNet exists: $VNET_NAME"
    log_info "    CIDR: $VNET_CIDR"
    log_info "    Location: $VNET_LOCATION"

    if [ "$VNET_STATE" == "Succeeded" ]; then
      log_success "    Provisioning State: $VNET_STATE"
      TOTAL_VNETS=$((TOTAL_VNETS + 1))
    else
      log_warning "    Provisioning State: $VNET_STATE (expected: Succeeded)"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    log_error "  VNet not found: $VNET_NAME"
    log_info "    Terraform environment module may not have been applied yet."
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # 2. Verify Subnets
  log_info "  Checking Subnets..."
  SUBNET_COUNT=0

  # No gateway subnet here, as this is handled in the VPN module if enabled
  for SUBNET_TYPE in aks data mgmt; do
    SUBNET_NAME="snet-${PROJECT}-${ENV}-${SUBNET_TYPE}"

    if az_call network vnet subnet show \
      --name "$SUBNET_NAME" \
      --vnet-name "$VNET_NAME" \
      --resource-group "$RG_NAME" \
      --output none 2>/dev/null; then
      log_success "    Subnet exists: $SUBNET_NAME"
      SUBNET_COUNT=$((SUBNET_COUNT + 1))
    else
      log_error "    Subnet missing: $SUBNET_NAME"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $SUBNET_COUNT -eq 3 ]; then
    log_success "  All 3 subnets verified"
    TOTAL_SUBNETS=$((TOTAL_SUBNETS + 3))
  else
    log_warning "  Only ${SUBNET_COUNT}/3 subnets found"
    WARNINGS=$((WARNINGS + 1))
    TOTAL_SUBNETS=$((TOTAL_SUBNETS + SUBNET_COUNT))
  fi

  # 3. Verify NSGs
  log_info "  Checking Network Security Groups..."
  NSG_COUNT=0

  for NSG_TYPE in aks data mgmt; do
    NSG_NAME="nsg-${PROJECT}-${ENV}-${NSG_TYPE}"

    NSG_INFO=$(az_call network nsg show \
      --name "$NSG_NAME" \
      --resource-group "$RG_NAME" \
      --query "{Name:name, ProvisioningState:provisioningState}" \
      --output json 2>/dev/null)

    if [ -n "$NSG_INFO" ] && [ "$NSG_INFO" != "null" ]; then
      NSG_STATE=$(echo "$NSG_INFO" | jq -r '.ProvisioningState')
      log_success "    NSG exists: $NSG_NAME"

      if [ "$NSG_STATE" == "Succeeded" ]; then
        NSG_COUNT=$((NSG_COUNT + 1))
      else
        log_warning "      Provisioning State: $NSG_STATE"
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      log_error "    NSG missing: $NSG_NAME"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $NSG_COUNT -eq 3 ]; then
    log_success "  All 3 NSGs verified"
    TOTAL_NSGS=$((TOTAL_NSGS + 3))
  else
    log_warning "  Only ${NSG_COUNT}/3 NSGs found"
    WARNINGS=$((WARNINGS + 1))
    TOTAL_NSGS=$((TOTAL_NSGS + NSG_COUNT))
  fi

  # 4. Verify VPN Gateway (optional - depends on enable_vpn_gateway variable)
  log_info "  Checking VPN Gateway..."
  VPN_NAME="vgw-${PROJECT}-${ENV}"
  ENV_DIR="${REPO_ROOT}/infra-foundation/terraform/environments/${ENV}"
  ENABLE_VPN_GATEWAY="$(get_enable_vpn_gateway "$ENV_DIR")"

  if [ "$ENABLE_VPN_GATEWAY" = "true" ]; then
    VPN_INFO=$(az_call network vnet-gateway show \
      --name "$VPN_NAME" \
      --resource-group "$RG_NAME" \
      --query "{Name:name, ProvisioningState:provisioningState, GatewayType:gatewayType}" \
      --output json 2>/dev/null)

    if [ -n "$VPN_INFO" ] && [ "$VPN_INFO" != "null" ]; then
      VPN_STATE=$(echo "$VPN_INFO" | jq -r '.ProvisioningState')
      VPN_TYPE=$(echo "$VPN_INFO" | jq -r '.GatewayType')

      log_success "    VPN Gateway exists: $VPN_NAME"
      log_info "      Gateway Type: $VPN_TYPE"
      log_info "      Provisioning State: $VPN_STATE"

      if [ "$VPN_STATE" == "Succeeded" ]; then
        TOTAL_VPNS=$((TOTAL_VPNS + 1))
      else
        log_warning "      Provisioning State: $VPN_STATE (may still be deploying)"
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      log_error "    VPN Gateway missing: $VPN_NAME (enabled in terraform.tfvars)"
      ERRORS=$((ERRORS + 1))
    fi
  else
    log_info "    VPN Gateway disabled in terraform.tfvars"
  fi

  # 5. Verify Route Tables (optional - may not exist in all deployments)
  log_info "  Checking Route Tables..."
  RT_NAME="rt-${PROJECT}-${ENV}"

  if az_call network route-table show \
    --name "$RT_NAME" \
    --resource-group "$RG_NAME" \
    --output none 2>/dev/null; then
    log_success "    Route Table exists: $RT_NAME"
  else
    log_info "    Route Table not found (may not be required for this deployment)"
  fi

  echo ""
done

# Summary
log_info "=== Verification Summary ==="
ENV_COUNT=${#ENV_LIST[@]}
EXPECTED_VNETS=$ENV_COUNT
EXPECTED_SUBNETS=$((ENV_COUNT * 3))
EXPECTED_NSGS=$((ENV_COUNT * 3))
EXPECTED_VPNS=$ENV_COUNT
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All Terraform Environment verifications passed!"
  echo ""
  log_info "Verified:"
  log_info "  - Virtual Networks: ${TOTAL_VNETS}/${EXPECTED_VNETS}"
  log_info "  - Subnets: ${TOTAL_SUBNETS}/${EXPECTED_SUBNETS} (3 subnets × ${ENV_COUNT} environments)"
  log_info "  - Network Security Groups: ${TOTAL_NSGS}/${EXPECTED_NSGS} (3 NSGs × ${ENV_COUNT} environments)"
  if [ $TOTAL_VPNS -gt 0 ]; then
    log_info "  - VPN Gateways: ${TOTAL_VPNS}/${EXPECTED_VPNS} (enabled in some environments)"
  else
    log_info "  - VPN Gateways: Not enabled"
  fi
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  echo ""
  log_info "Verified:"
  log_info "  - Virtual Networks: ${TOTAL_VNETS}/${EXPECTED_VNETS}"
  log_info "  - Subnets: ${TOTAL_SUBNETS}/${EXPECTED_SUBNETS}"
  log_info "  - Network Security Groups: ${TOTAL_NSGS}/${EXPECTED_NSGS}"
  log_info "  - VPN Gateways: ${TOTAL_VPNS}/${EXPECTED_VPNS}"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  echo ""
  log_info "Status:"
  log_info "  - Virtual Networks: ${TOTAL_VNETS}/${EXPECTED_VNETS}"
  log_info "  - Subnets: ${TOTAL_SUBNETS}/${EXPECTED_SUBNETS}"
  log_info "  - Network Security Groups: ${TOTAL_NSGS}/${EXPECTED_NSGS}"
  log_info "  - VPN Gateways: ${TOTAL_VPNS}/${EXPECTED_VPNS}"
  echo ""
  log_info "Hint: If resources are missing, run: cd terraform/environments/dev && terraform apply"
  exit 1
fi
