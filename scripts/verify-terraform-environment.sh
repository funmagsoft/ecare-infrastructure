#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Terraform Environment Module Verification ==="
echo "Verifies resources created by terraform/modules/environment:"
echo "  - Virtual Network and Subnets"
echo "  - Network Security Groups"
echo "  - VPN Gateway (if enabled)"
echo "  - Route Tables"
echo ""
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

ERRORS=0
WARNINGS=0

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

# Verify Environment resources for each environment
echo "2. Verifying Environment resources..."
echo ""

TOTAL_VNETS=0
TOTAL_SUBNETS=0
TOTAL_NSGS=0
TOTAL_VPNS=0

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  VNET_NAME="vnet-${PROJECT}-${ENV}"

  echo "=== Verifying Environment for ${ENV} ==="

  # Check if Resource Group exists (prerequisite)
  if ! az group show --name "$RG_NAME" --output none 2>/dev/null; then
    log_error "Resource Group not found: ${RG_NAME}"
    log_info "  Phase 0 setup may not have been run."
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # 1. Verify VNet
  echo "  Checking Virtual Network..."
  VNET_INFO=$(az network vnet show \
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
  echo "  Checking Subnets..."
  SUBNET_COUNT=0

  for SUBNET_TYPE in aks data mgmt gateway; do
    SUBNET_NAME="${SUBNET_TYPE}-subnet"

    if az network vnet subnet show \
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

  if [ $SUBNET_COUNT -eq 4 ]; then
    log_success "  All 4 subnets verified"
    TOTAL_SUBNETS=$((TOTAL_SUBNETS + 4))
  else
    log_warning "  Only ${SUBNET_COUNT}/4 subnets found"
    WARNINGS=$((WARNINGS + 1))
    TOTAL_SUBNETS=$((TOTAL_SUBNETS + SUBNET_COUNT))
  fi

  # 3. Verify NSGs
  echo "  Checking Network Security Groups..."
  NSG_COUNT=0

  for NSG_TYPE in aks data mgmt; do
    NSG_NAME="nsg-${NSG_TYPE}-${PROJECT}-${ENV}"

    NSG_INFO=$(az network nsg show \
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
  echo "  Checking VPN Gateway..."
  VPN_NAME="vpn-gw-${PROJECT}-${ENV}"

  VPN_INFO=$(az network vnet-gateway show \
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
    log_info "    VPN Gateway not found (may be disabled in terraform.tfvars)"
  fi

  # 5. Verify Route Tables (optional - may not exist in all deployments)
  echo "  Checking Route Tables..."
  RT_NAME="rt-${PROJECT}-${ENV}"

  if az network route-table show \
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
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All Terraform Environment verifications passed!"
  echo ""
  echo "Verified:"
  echo "  - Virtual Networks: ${TOTAL_VNETS}/4"
  echo "  - Subnets: ${TOTAL_SUBNETS}/16 (4 subnets × 4 environments)"
  echo "  - Network Security Groups: ${TOTAL_NSGS}/12 (3 NSGs × 4 environments)"
  if [ $TOTAL_VPNS -gt 0 ]; then
    echo "  - VPN Gateways: ${TOTAL_VPNS}/4 (enabled in some environments)"
  else
    echo "  - VPN Gateways: Not enabled"
  fi
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  echo ""
  echo "Verified:"
  echo "  - Virtual Networks: ${TOTAL_VNETS}/4"
  echo "  - Subnets: ${TOTAL_SUBNETS}/16"
  echo "  - Network Security Groups: ${TOTAL_NSGS}/12"
  echo "  - VPN Gateways: ${TOTAL_VPNS}"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  echo ""
  echo "Status:"
  echo "  - Virtual Networks: ${TOTAL_VNETS}/4"
  echo "  - Subnets: ${TOTAL_SUBNETS}/16"
  echo "  - Network Security Groups: ${TOTAL_NSGS}/12"
  echo "  - VPN Gateways: ${TOTAL_VPNS}"
  echo ""
  log_info "Hint: If resources are missing, run: cd terraform/environments/dev && terraform apply"
  exit 1
fi
