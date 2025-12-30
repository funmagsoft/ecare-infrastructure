#!/bin/bash
# Comprehensive validation of all Phase 2 platform resources across all environments

# Note: Don't use 'set -e' - we want to continue validation even if some checks fail
# to see ALL issues, not just the first one

echo "=== Phase 2 Platform Validation ==="
echo ""

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to check resource
check_resource() {
  local DESCRIPTION="$1"
  local COMMAND="$2"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  if eval "$COMMAND" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ${DESCRIPTION}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "${RED}✗${NC} ${DESCRIPTION}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  fi
}

# All environments to validate
#ENVIRONMENTS=(dev test stage prod)
ENVIRONMENTS=(dev)

for ENV in "${ENVIRONMENTS[@]}"; do
  echo ""
  echo "=== Validating ${ENV} environment ==="

  RG="rg-ecare-${ENV}"

  # Check if environment exists (Resource Group)
  if ! az group show --name "$RG" --output none 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  Environment ${ENV} not deployed yet - skipping"
    continue
  fi

  echo ""
  echo "Checking Monitoring Resources..."
  check_resource "Log Analytics Workspace (log-ecare-${ENV})" \
    "az resource show --resource-group '$RG' --name 'log-ecare-${ENV}' --resource-type 'Microsoft.OperationalInsights/workspaces' --output none"

  check_resource "Application Insights (appi-ecare-${ENV})" \
    "az resource show --resource-group '$RG' --name 'appi-ecare-${ENV}' --resource-type 'Microsoft.Insights/components' --output none"

  echo ""
  echo "Checking Storage Resources..."
  check_resource "Storage Account (stecare${ENV})" \
    "az storage account show --resource-group '$RG' --name 'stecare${ENV}' --output none"

  # Check containers
  for CONTAINER in app-data logs backups; do
    check_resource "Storage Container (${CONTAINER})" \
      "az storage container exists --account-name 'stecare${ENV}' --name '${CONTAINER}' --auth-mode login --query 'exists' -o tsv | grep -q 'true'"
  done

  # Check Private Endpoints for Storage
  check_resource "Storage Blob Private Endpoint" \
    "az network private-endpoint show --resource-group '$RG' --name 'stecare${ENV}-blob-pe' --output none"

  check_resource "Storage File Private Endpoint" \
    "az network private-endpoint show --resource-group '$RG' --name 'stecare${ENV}-file-pe' --output none"

  echo ""
  echo "Checking Key Vault..."
  check_resource "Key Vault (kv-ecare-${ENV})" \
    "az keyvault show --resource-group '$RG' --name 'kv-ecare-${ENV}' --output none"

  check_resource "Key Vault Private Endpoint" \
    "az network private-endpoint show --resource-group '$RG' --name 'kv-ecare-${ENV}-pe' --output none"

  echo ""
  echo "Checking Azure Container Registry..."
  check_resource "ACR (acrecare${ENV})" \
    "az acr show --resource-group '$RG' --name 'acrecare${ENV}' --output none"

  check_resource "ACR Private Endpoint" \
    "az network private-endpoint show --resource-group '$RG' --name 'acrecare${ENV}-pe' --output none"

  echo ""
  echo "Checking PostgreSQL..."
  check_resource "PostgreSQL Server (psql-ecare-${ENV})" \
    "az postgres flexible-server show --resource-group '$RG' --name 'psql-ecare-${ENV}' --output none"

  check_resource "PostgreSQL Private Endpoint" \
    "az network private-endpoint show --resource-group '$RG' --name 'psql-ecare-${ENV}-pe' --output none"

  echo ""
  echo "Checking Service Bus..."
  check_resource "Service Bus Namespace (sb-ecare-${ENV})" \
    "az servicebus namespace show --resource-group '$RG' --name 'sb-ecare-${ENV}' --output none"

  # Check Service Bus Private Endpoint (only for Premium SKU)
  SB_SKU=$(az servicebus namespace show --resource-group "$RG" --name "sb-ecare-${ENV}" --query "sku.name" -o tsv 2>/dev/null)
  if [ "$SB_SKU" = "Premium" ]; then
    check_resource "Service Bus Private Endpoint" \
      "az network private-endpoint show --resource-group '$RG' --name 'sb-ecare-${ENV}-pe' --output none"
  else
    echo -e "  ${YELLOW}ℹ${NC}  Service Bus Private Endpoint: N/A (${SB_SKU} SKU - PE only available for Premium)"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  fi

  echo ""
  echo "Checking AKS..."
  check_resource "AKS Cluster (aks-ecare-${ENV})" \
    "az aks show --resource-group '$RG' --name 'aks-ecare-${ENV}' --output none"

  # Check AKS nodes
  if az aks show --resource-group "$RG" --name "aks-ecare-${ENV}" --output none 2>/dev/null; then
    az aks get-credentials --resource-group "$RG" --name "aks-ecare-${ENV}" --overwrite-existing --output none 2>/dev/null
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")

    if [ "$NODE_COUNT" -gt 0 ]; then
      echo -e "${GREEN}✓${NC} AKS nodes running (${NODE_COUNT} nodes)"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
      echo -e "${RED}✗${NC} No AKS nodes found"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Check OIDC Issuer (Workload Identity)
    OIDC_ISSUER=$(az aks show --resource-group "$RG" --name "aks-ecare-${ENV}" --query "oidcIssuerProfile.issuerUrl" -o tsv 2>/dev/null)
    if [ -n "$OIDC_ISSUER" ] && [ "$OIDC_ISSUER" != "null" ]; then
      echo -e "${GREEN}✓${NC} AKS OIDC Issuer configured (${OIDC_ISSUER})"
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
      echo -e "${RED}✗${NC} AKS OIDC Issuer not configured"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  fi

  echo ""
  echo "Checking Bastion VM..."
  check_resource "Bastion VM (vm-bastion-ecare-${ENV})" \
    "az vm show --resource-group '$RG' --name 'vm-bastion-ecare-${ENV}' --output none"

  # Check VM power state
  if az vm show --resource-group "$RG" --name "vm-bastion-ecare-${ENV}" --output none 2>/dev/null; then
    POWER_STATE=$(az vm get-instance-view --resource-group "$RG" --name "vm-bastion-ecare-${ENV}" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv)
    echo -e "  ${YELLOW}ℹ${NC}  VM Power State: ${POWER_STATE}"
  fi

  echo ""
  echo "Checking Private Endpoints..."
  PE_COUNT=$(az network private-endpoint list \
    --resource-group "$RG" \
    --query "length(@)" -o tsv)
  echo -e "${GREEN}✓${NC} Private Endpoints count: ${PE_COUNT}"

  # Check Terraform state
  echo ""
  echo "Checking Terraform State..."
  STATE_SA="tfstatehycomecare${ENV}"
  if az storage blob exists \
    --account-name "$STATE_SA" \
    --container-name tfstate \
    --name "infra-platform/terraform.tfstate" \
    --auth-mode login \
    --query "exists" \
    --output tsv 2>/dev/null | grep -q "true"; then
    echo -e "${GREEN}✓${NC} Phase 2 Terraform state exists"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    echo -e "${RED}✗${NC} Phase 2 Terraform state not found!"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo ""
  echo -e "${GREEN}✓ ${ENV} environment validated${NC}"
done

echo ""
echo "=== Validation Summary ==="
echo -e "Total checks: ${TOTAL_CHECKS}"
echo -e "${GREEN}Passed: ${PASSED_CHECKS}${NC}"
if [ $FAILED_CHECKS -gt 0 ]; then
  echo -e "${RED}Failed: ${FAILED_CHECKS}${NC}"
fi

echo ""
if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}✓ All validations passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some validations failed. Please review errors above.${NC}"
  exit 1
fi
