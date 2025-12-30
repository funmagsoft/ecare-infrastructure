#!/bin/bash
# Create Terraform plans for all environments

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Terraform Plan - All Environments ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Environments to plan
ENVIRONMENTS="${1:-dev test stage prod}"

echo "Planning for environments: ${ENVIRONMENTS}"
echo ""

# Track results
TOTAL_ENVS=0
SUCCESS_ENVS=0
FAILED_ENVS=0

for ENV in $ENVIRONMENTS; do
  TOTAL_ENVS=$((TOTAL_ENVS + 1))

  echo ""
  echo -e "${BLUE}=== Planning ${ENV} environment ===${NC}"
  echo ""

  ENV_DIR="${REPO_DIR}/terraform/environments/${ENV}"

  if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}✗ Environment directory not found: ${ENV_DIR}${NC}"
    FAILED_ENVS=$((FAILED_ENVS + 1))
    continue
  fi

  cd "$ENV_DIR"

  # Initialize if needed
  if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    if ! terraform init -input=false > /dev/null 2>&1; then
      echo -e "${RED}✗ Initialization failed for ${ENV}${NC}"
      FAILED_ENVS=$((FAILED_ENVS + 1))
      continue
    fi
  fi

  # Create plan
  PLAN_FILE="tfplan-${ENV}-$(date +%Y%m%d-%H%M%S)"

  echo "Creating plan..."
  if terraform plan -out="$PLAN_FILE" -input=false; then
    echo -e "${GREEN}✓ Plan created for ${ENV}: ${PLAN_FILE}${NC}"

    # Show summary
    RESOURCES_TO_ADD=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "create")] | length' 2>/dev/null || echo "0")
    RESOURCES_TO_CHANGE=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "update")] | length' 2>/dev/null || echo "0")
    RESOURCES_TO_DESTROY=$(terraform show -json "$PLAN_FILE" | jq -r '[.resource_changes[] | select(.change.actions[] == "delete")] | length' 2>/dev/null || echo "0")

    echo "  Changes:"
    echo -e "    ${GREEN}+ ${RESOURCES_TO_ADD} to add${NC}"
    echo -e "    ${YELLOW}~ ${RESOURCES_TO_CHANGE} to change${NC}"
    echo -e "    ${RED}- ${RESOURCES_TO_DESTROY} to destroy${NC}"

    SUCCESS_ENVS=$((SUCCESS_ENVS + 1))
  else
    echo -e "${RED}✗ Plan failed for ${ENV}${NC}"
    FAILED_ENVS=$((FAILED_ENVS + 1))
  fi
done

echo ""
echo "=== Summary ==="
echo "Total environments: ${TOTAL_ENVS}"
echo -e "${GREEN}Successful: ${SUCCESS_ENVS}${NC}"
if [ $FAILED_ENVS -gt 0 ]; then
  echo -e "${RED}Failed: ${FAILED_ENVS}${NC}"
fi

echo ""
if [ $FAILED_ENVS -eq 0 ]; then
  echo -e "${GREEN}✓ All plans created successfully!${NC}"
  echo ""
  echo "To apply a specific environment:"
  echo "  cd ${REPO_DIR}/terraform/environments/<env>"
  echo "  terraform apply tfplan-<env>-<timestamp>"
  exit 0
else
  echo -e "${RED}✗ Some plans failed. Please review errors above.${NC}"
  exit 1
fi
