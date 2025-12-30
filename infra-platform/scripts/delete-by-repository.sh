#!/bin/bash
# Delete resources by repository tag (selective cleanup)

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Selective Resource Deletion by Repository ===${NC}"
echo ""

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo ""
  echo "Usage: $0 <environment> <repository>"
  echo ""
  echo "Arguments:"
  echo "  environment  - dev, test, stage, prod"
  echo "  repository   - infra-foundation, infra-platform, infra-identity"
  echo ""
  echo "Example:"
  echo "  $0 dev infra-platform"
  echo ""
  echo "This will delete ONLY resources tagged with GitRepository=infra-platform"
  exit 1
fi

ENV="$1"
REPO="$2"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
  exit 1
fi

# Validate repository
if [[ ! "$REPO" =~ ^(infra-foundation|infra-platform|infra-identity)$ ]]; then
  echo -e "${RED}Error: Invalid repository '${REPO}'${NC}"
  echo "Must be one of: infra-foundation, infra-platform, infra-identity"
  exit 1
fi

RG="rg-ecare-${ENV}"

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}Resource Group:${NC} ${RG}"
echo -e "${BLUE}Repository Filter:${NC} ${REPO}"
echo ""

# Check if resource group exists
if ! az group show --name "$RG" --output none 2>/dev/null; then
  echo -e "${RED}Error: Resource group '${RG}' not found${NC}"
  exit 1
fi

echo "Step 1: Finding resources tagged with GitRepository=${REPO}..."
echo ""

# Get resources with specific tag
RESOURCES=$(az resource list \
  --resource-group "$RG" \
  --tag GitRepository="$REPO" \
  --query "[].{Name:name, Type:type, Id:id}" \
  --output json)

RESOURCE_COUNT=$(echo "$RESOURCES" | jq '. | length')

if [ "$RESOURCE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}No resources found with tag GitRepository=${REPO}${NC}"
  echo ""
  echo "This could mean:"
  echo "  - Resources were already deleted"
  echo "  - Resources don't have the GitRepository tag"
  echo "  - Wrong environment or repository name"
  exit 0
fi

echo -e "${GREEN}Found ${RESOURCE_COUNT} resources:${NC}"
echo ""
echo "$RESOURCES" | jq -r '.[] | "  - \(.Name) (\(.Type))"'
echo ""

# Safety confirmation
echo -e "${YELLOW}⚠  WARNING: This will DELETE ${RESOURCE_COUNT} resources!${NC}"
echo ""
read -p "Are you sure you want to delete these resources? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Deletion cancelled."
  exit 0
fi

echo ""
echo "Step 2: Deleting resources..."
echo ""

# Delete each resource
DELETED=0
FAILED=0

echo "$RESOURCES" | jq -r '.[] | .Id' | while read -r RESOURCE_ID; do
  RESOURCE_NAME=$(echo "$RESOURCES" | jq -r ".[] | select(.Id==\"$RESOURCE_ID\") | .Name")
  RESOURCE_TYPE=$(echo "$RESOURCES" | jq -r ".[] | select(.Id==\"$RESOURCE_ID\") | .Type")

  echo -n "Deleting ${RESOURCE_NAME} (${RESOURCE_TYPE})... "

  if az resource delete --ids "$RESOURCE_ID" --output none 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    DELETED=$((DELETED + 1))
  else
    echo -e "${RED}✗ Failed${NC}"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Deletion Summary ==="
echo -e "${GREEN}Deleted: ${DELETED}${NC}"
if [ $FAILED -gt 0 ]; then
  echo -e "${RED}Failed: ${FAILED}${NC}"
fi

echo ""
echo -e "${GREEN}✓ Selective deletion complete${NC}"
echo ""
echo "Remaining resources in ${RG}:"
az resource list --resource-group "$RG" --output table
