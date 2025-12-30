#!/bin/bash
# Verify Phase 1 foundation is deployed

echo "=== Phase 2 Prerequisites Validation ==="

# All environments
# ENVIRONMENTS=(dev test stage prod)
ENVIRONMENTS=(dev)

for ENV in "${ENVIRONMENTS[@]}"; do
  echo ""
  echo "Checking ${ENV} environment..."

  # Check VNet exists
  VNET_NAME="vnet-ecare-${ENV}"
  if az network vnet show \
    --resource-group "rg-ecare-${ENV}" \
    --name "$VNET_NAME" \
    --output none 2>/dev/null; then
    echo "✓ VNet ${VNET_NAME} exists"
  else
    echo "✗ VNet ${VNET_NAME} missing - deploy Phase 1 first!"
    exit 1
  fi

  # Check subnets
  SUBNET_COUNT=$(az network vnet subnet list \
    --resource-group "rg-ecare-${ENV}" \
    --vnet-name "$VNET_NAME" \
    --query "length(@)" \
    --output tsv)

  if [ "$SUBNET_COUNT" -ge 3 ]; then
    echo "✓ Subnets configured (${SUBNET_COUNT} subnets)"
  else
    echo "✗ Insufficient subnets - expected at least 3, found ${SUBNET_COUNT}"
    exit 1
  fi

  # Check Private DNS Zones
  DNS_ZONE_COUNT=$(az network private-dns zone list \
    --resource-group "rg-ecare-${ENV}" \
    --query "length(@)" \
    --output tsv)

  if [ "$DNS_ZONE_COUNT" -ge 6 ]; then
    echo "✓ Private DNS Zones configured (${DNS_ZONE_COUNT} zones)"
  else
    echo "✗ Insufficient DNS zones - expected 6, found ${DNS_ZONE_COUNT}"
    exit 1
  fi

  # Check Terraform state from Phase 1 exists
  STATE_SA="tfstatehycomecare${ENV}"
  if az storage blob exists \
    --account-name "$STATE_SA" \
    --container-name tfstate \
    --name "infra-foundation/terraform.tfstate" \
    --auth-mode login \
    --query "exists" \
    --output tsv 2>/dev/null | grep -q "true"; then
    echo "✓ Phase 1 Terraform state exists"
  else
    echo "✗ Phase 1 Terraform state not found!"
    exit 1
  fi
done

echo ""
echo "=== All prerequisites validated! Ready for Phase 2. ==="
