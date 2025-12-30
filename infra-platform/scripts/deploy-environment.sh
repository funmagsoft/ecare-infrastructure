#!/bin/bash
# Deploy Terraform configuration for a specific environment

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Terraform Environment Deployment ==="
echo ""

# Check if environment is specified
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo ""
  echo "Usage: $0 <environment> [options]"
  echo ""
  echo "Available environments:"
  echo "  - dev"
  echo "  - test"
  echo "  - stage"
  echo "  - prod"
  echo ""
  echo "Options:"
  echo "  --auto-approve    Skip interactive approval"
  echo "  --plan-only       Only create plan, don't apply"
  echo ""
  echo "Example:"
  echo "  $0 dev"
  echo "  $0 prod --plan-only"
  exit 1
fi

ENV="$1"
AUTO_APPROVE=false
PLAN_ONLY=false

# Parse options
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    --plan-only)
      PLAN_ONLY=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

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

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}Directory:${NC} ${ENV_DIR}"
echo -e "${BLUE}Auto-approve:${NC} ${AUTO_APPROVE}"
echo -e "${BLUE}Plan-only:${NC} ${PLAN_ONLY}"
echo ""

# Navigate to environment directory
cd "$ENV_DIR"

# Safety check for PROD
if [ "$ENV" == "prod" ] && [ "$AUTO_APPROVE" == "true" ]; then
  echo -e "${YELLOW}⚠ WARNING: Auto-approve is dangerous for production!${NC}"
  echo ""
  read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 1
  fi
  echo ""
fi

# Initialize if needed
if [ ! -d ".terraform" ]; then
  echo "Step 1: Initializing Terraform..."
  if terraform init -input=false; then
    echo -e "${GREEN}✓ Terraform initialized${NC}"
  else
    echo -e "${RED}✗ Initialization failed${NC}"
    exit 1
  fi
else
  echo "Step 1: Terraform already initialized"

  # Reconfigure backend to ensure it's up-to-date
  echo "  Reconfiguring backend..."
  terraform init -reconfigure -input=false > /dev/null 2>&1
  echo -e "${GREEN}✓ Backend reconfigured${NC}"
fi

echo ""
echo "Step 2: Validating configuration..."
if terraform validate > /dev/null; then
  echo -e "${GREEN}✓ Configuration is valid${NC}"
else
  echo -e "${RED}✗ Configuration is invalid${NC}"
  terraform validate
  exit 1
fi

echo ""
echo "Step 3: Creating execution plan..."
PLAN_FILE="tfplan-$(date +%Y%m%d-%H%M%S)"

if terraform plan -out="$PLAN_FILE" -input=false; then
  echo -e "${GREEN}✓ Plan created: ${PLAN_FILE}${NC}"
else
  echo -e "${RED}✗ Plan creation failed${NC}"
  exit 1
fi

echo ""
echo "Step 4: Plan summary..."
terraform show -no-color "$PLAN_FILE" | head -50
echo ""
echo -e "${YELLOW}... (plan truncated, see full plan above) ...${NC}"

# Count resources
RESOURCE_CHANGES=$(terraform show -json "$PLAN_FILE" | jq -r '.resource_changes | length')
RESOURCES_TO_ADD=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "create")] | length')
RESOURCES_TO_CHANGE=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "update")] | length')
RESOURCES_TO_DESTROY=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "delete")] | length')

echo ""
echo "Resource changes:"
echo -e "  ${GREEN}+ ${RESOURCES_TO_ADD} to add${NC}"
echo -e "  ${YELLOW}~ ${RESOURCES_TO_CHANGE} to change${NC}"
echo -e "  ${RED}- ${RESOURCES_TO_DESTROY} to destroy${NC}"

# Stop if plan-only
if [ "$PLAN_ONLY" == "true" ]; then
  echo ""
  echo -e "${GREEN}Plan created successfully!${NC}"
  echo ""
  echo "To apply this plan, run:"
  echo "  cd ${ENV_DIR}"
  echo "  terraform apply ${PLAN_FILE}"
  exit 0
fi

# Prompt for approval if not auto-approve
if [ "$AUTO_APPROVE" == "false" ]; then
  echo ""
  read -p "Do you want to apply this plan? (yes/no): " APPLY_CONFIRM
  if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    echo ""
    echo "Plan saved as: ${PLAN_FILE}"
    echo "To apply later, run:"
    echo "  cd ${ENV_DIR}"
    echo "  terraform apply ${PLAN_FILE}"
    exit 0
  fi
fi

echo ""
echo "Step 5: Applying changes..."
echo ""

START_TIME=$(date +%s)

if [ "$AUTO_APPROVE" == "true" ]; then
  terraform apply "$PLAN_FILE"
else
  terraform apply "$PLAN_FILE"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

if [ $? -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
  echo -e "${GREEN}  Duration: ${DURATION_MIN}m ${DURATION_SEC}s${NC}"

  # Clean up old plan file
  rm -f "$PLAN_FILE"

  echo ""
  echo "Step 6: Exporting outputs..."
  OUTPUTS_DIR="${REPO_DIR}/outputs"
  mkdir -p "$OUTPUTS_DIR"

  OUTPUT_FILE="${OUTPUTS_DIR}/terraform-outputs-${ENV}.json"
  if terraform output -json > "$OUTPUT_FILE"; then
    echo -e "${GREEN}✓ Outputs exported to: ${OUTPUT_FILE}${NC}"
  fi

  echo ""
  echo "Step 7: Validating deployment..."
  "${SCRIPT_DIR}/validate-azure-resources.sh" || echo -e "${YELLOW}⚠ Validation had warnings${NC}"

  echo ""
  echo -e "${GREEN}=== Deployment Complete ===${NC}"
  echo ""
  echo "Environment ${ENV} has been deployed successfully."
  echo ""
  echo "Next steps:"
  echo "  1. Review outputs:  terraform output"
  echo "  2. Test resources:  ${SCRIPT_DIR}/validate-all.sh"
  echo "  3. Access AKS:      az aks get-credentials --resource-group rg-ecare-${ENV} --name aks-ecare-${ENV}"

else
  echo ""
  echo -e "${RED}✗ Deployment failed!${NC}"
  echo ""
  echo "Plan file preserved: ${PLAN_FILE}"
  echo "Review errors above and fix issues before retrying."
  exit 1
fi
