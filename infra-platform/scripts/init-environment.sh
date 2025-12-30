#!/bin/bash
# Initialize Terraform for a specific environment

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Terraform Environment Initialization ==="
echo ""

# Check if environment is specified
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo ""
  echo "Usage: $0 <environment>"
  echo ""
  echo "Available environments:"
  echo "  - dev"
  echo "  - test"
  echo "  - stage"
  echo "  - prod"
  echo ""
  echo "Example:"
  echo "  $0 dev"
  exit 1
fi

ENV="$1"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
  echo "Must be one of: dev, test, stage, prod"
  exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="${REPO_DIR}/terraform/environments/${ENV}"

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo -e "${RED}Error: Environment directory not found: ${ENV_DIR}${NC}"
  exit 1
fi

echo "Environment: ${ENV}"
echo "Directory: ${ENV_DIR}"
echo ""

# Navigate to environment directory
cd "$ENV_DIR"

# Check if backend.tf exists
if [ ! -f "backend.tf" ]; then
  echo -e "${RED}Error: backend.tf not found in ${ENV_DIR}${NC}"
  exit 1
fi

echo "Step 1: Checking Azure CLI authentication..."
if az account show > /dev/null 2>&1; then
  ACCOUNT_NAME=$(az account show --query "name" -o tsv)
  SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
  echo -e "${GREEN}✓ Authenticated to Azure${NC}"
  echo "  Account: ${ACCOUNT_NAME}"
  echo "  Subscription: ${SUBSCRIPTION_ID}"
else
  echo -e "${RED}✗ Not authenticated to Azure${NC}"
  echo ""
  echo "Please authenticate with:"
  echo "  az login"
  exit 1
fi

echo ""
echo "Step 2: Checking backend Storage Account..."
STATE_SA="tfstatehycomecare${ENV}"
RG="rg-ecare-${ENV}"

if az storage account show --name "$STATE_SA" --resource-group "$RG" --output none 2>/dev/null; then
  echo -e "${GREEN}✓ Backend Storage Account exists: ${STATE_SA}${NC}"
else
  echo -e "${RED}✗ Backend Storage Account not found: ${STATE_SA}${NC}"
  echo ""
  echo "Please create the Storage Account first (Phase 0)."
  exit 1
fi

# Check container
if az storage container show --name tfstate --account-name "$STATE_SA" --auth-mode login --output none 2>/dev/null; then
  echo -e "${GREEN}✓ Backend container exists: tfstate${NC}"
else
  echo -e "${RED}✗ Backend container not found: tfstate${NC}"
  exit 1
fi

# Check RBAC permissions
echo ""
echo "Step 3: Checking RBAC permissions..."
CURRENT_USER=$(az account show --query "user.name" -o tsv)
if az role assignment list \
  --assignee "$CURRENT_USER" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${STATE_SA}" \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor']" \
  -o tsv 2>/dev/null | grep -q "Storage Blob Data Contributor"; then
  echo -e "${GREEN}✓ User has Storage Blob Data Contributor role${NC}"
else
  echo -e "${YELLOW}⚠ User may not have required RBAC role${NC}"
  echo "  Required: Storage Blob Data Contributor on ${STATE_SA}"
fi

echo ""
echo "Step 4: Checking Phase 1 foundation state..."
if az storage blob exists \
  --account-name "$STATE_SA" \
  --container-name tfstate \
  --name "infra-foundation/terraform.tfstate" \
  --auth-mode login \
  --query "exists" \
  --output tsv 2>/dev/null | grep -q "true"; then
  echo -e "${GREEN}✓ Phase 1 foundation state exists${NC}"
else
  echo -e "${RED}✗ Phase 1 foundation state not found${NC}"
  echo ""
  echo "Phase 2 depends on Phase 1. Please deploy Phase 1 first."
  exit 1
fi

echo ""
echo "Step 5: Initializing Terraform..."
if terraform init -input=false; then
  echo -e "${GREEN}✓ Terraform initialized successfully${NC}"
else
  echo -e "${RED}✗ Terraform initialization failed${NC}"
  exit 1
fi

echo ""
echo "Step 6: Validating Terraform configuration..."
if terraform validate; then
  echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
else
  echo -e "${RED}✗ Terraform configuration is invalid${NC}"
  exit 1
fi

echo ""
echo "Step 7: Checking Terraform formatting..."
if terraform fmt -check -recursive > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Terraform files are properly formatted${NC}"
else
  echo -e "${YELLOW}⚠ Terraform files need formatting${NC}"
  echo ""
  echo "Run 'terraform fmt -recursive' to fix formatting"
fi

echo ""
echo -e "${GREEN}=== Initialization Complete ===${NC}"
echo ""
echo "Environment ${ENV} is ready for deployment."
echo ""
echo "Next steps:"
echo "  1. Review configuration: cd ${ENV_DIR}"
echo "  2. Create plan:          terraform plan -out=tfplan"
echo "  3. Review plan:          terraform show tfplan"
echo "  4. Apply changes:        terraform apply tfplan"
echo ""
echo "Or run deployment script:"
echo "  ${SCRIPT_DIR}/deploy-environment.sh ${ENV}"
