#!/bin/bash
# Script to update all .terraform.lock.hcl files
# Run from the ecare-infrastructure directory

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Updating Terraform lock files..."
echo ""

# Array of environment directories
ENV_DIRS=(
  "infra-foundation/terraform/environments/dev"
  "infra-foundation/terraform/environments/test"
  "infra-foundation/terraform/environments/stage"
  "infra-foundation/terraform/environments/prod"
  "infra-identity/terraform/environments/dev"
  "infra-identity/terraform/environments/test"
  "infra-identity/terraform/environments/stage"
  "infra-identity/terraform/environments/prod"
  "infra-platform/terraform/environments/dev"
  "infra-platform/terraform/environments/test"
  "infra-platform/terraform/environments/stage"
  "infra-platform/terraform/environments/prod"
)

# Array of module directories
MODULE_DIRS=(
  "infra-foundation/terraform/modules/bootstrap"
  "infra-foundation/terraform/modules/environment"
  "infra-foundation/terraform/modules/network"
  "infra-foundation/terraform/modules/vpn-gateway"
  "infra-identity/terraform/modules/github-oidc"
  "infra-identity/terraform/modules/workload-identity"
  "infra-platform/terraform/modules/acr"
  "infra-platform/terraform/modules/aks"
  "infra-platform/terraform/modules/aks-namespace"
  "infra-platform/terraform/modules/bastion"
  "infra-platform/terraform/modules/environment"
  "infra-platform/terraform/modules/key-vault"
  "infra-platform/terraform/modules/monitoring"
  "infra-platform/terraform/modules/postgresql"
  "infra-platform/terraform/modules/service-bus"
  "infra-platform/terraform/modules/storage"
)

SUCCESS=0
FAILED=0

# Update environment directories
for dir in "${ENV_DIRS[@]}"; do
  full_path="${BASE_DIR}/${dir}"
  
  if [ ! -d "$full_path" ]; then
    echo "⚠️  Directory not found: $dir"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  echo "📦 Updating: $dir"
  cd "$full_path"
  
  if terraform init -upgrade > /dev/null 2>&1; then
    echo "   ✅ Success"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "   ❌ Failed"
    FAILED=$((FAILED + 1))
  fi
  
  cd - > /dev/null
  echo ""
done

# Update module directories
for dir in "${MODULE_DIRS[@]}"; do
  full_path="${BASE_DIR}/${dir}"
  
  if [ ! -d "$full_path" ]; then
    echo "⚠️  Directory not found: $dir"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  echo "📦 Updating: $dir"
  cd "$full_path"
  
  if terraform init -upgrade > /dev/null 2>&1; then
    echo "   ✅ Success"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "   ❌ Failed"
    FAILED=$((FAILED + 1))
  fi
  
  cd - > /dev/null
  echo ""
done

echo "=========================================="
echo "Summary:"
echo "  ✅ Success: $SUCCESS"
echo "  ❌ Failed: $FAILED"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
  exit 0
else
  exit 1
fi

