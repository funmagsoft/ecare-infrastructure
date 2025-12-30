#!/bin/bash
# Validate Phase 1 prerequisites for Phase 2

echo "=== Phase 2 Prerequisites Validation ==="

# Check if infra-foundation repository exists
FOUNDATION_DIR="/Users/marek/workspace/ecare-infrastructure/infra-foundation"
if [ ! -d "$FOUNDATION_DIR" ]; then
  echo "✗ infra-foundation repository not found!"
  exit 1
fi
echo "✓ infra-foundation repository found"

# Check DEV environment is deployed
if ! az network vnet show \
  --resource-group rg-ecare-dev \
  --name vnet-ecare-dev \
  --output none 2>/dev/null; then
  echo "✗ DEV VNet not found - deploy Phase 1 first!"
  exit 1
fi
echo "✓ DEV environment foundation deployed"

# Check Terraform state from Phase 1
if az storage blob exists \
  --account-name tfstatehycomecaredev \
  --container-name tfstate \
  --name "infra-foundation/terraform.tfstate" \
  --auth-mode login \
  --query "exists" \
  --output tsv 2>/dev/null | grep -q "true"; then
  echo "✓ Phase 1 Terraform state accessible"
else
  echo "✗ Phase 1 Terraform state not found!"
  exit 1
fi

echo ""
echo "=== All prerequisites validated! ==="
