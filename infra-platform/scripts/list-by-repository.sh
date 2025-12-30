#!/bin/bash
# List resources grouped by repository tag

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Resources by Repository Tag ===${NC}"
echo ""

# Check environment argument
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo ""
  echo "Usage: $0 <environment>"
  echo ""
  echo "Example: $0 dev"
  exit 1
fi

ENV="$1"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
  exit 1
fi

RG="rg-ecare-${ENV}"

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}Resource Group:${NC} ${RG}"
echo ""

# Check if resource group exists
if ! az group show --name "$RG" --output none 2>/dev/null; then
  echo -e "${RED}Error: Resource group '${RG}' not found${NC}"
  exit 1
fi

# Get all resources
ALL_RESOURCES=$(az resource list --resource-group "$RG" --output json)
TOTAL_COUNT=$(echo "$ALL_RESOURCES" | jq '. | length')

echo -e "${GREEN}Total resources: ${TOTAL_COUNT}${NC}"
echo ""

# Group by repository
for REPO in "infra-foundation" "infra-platform" "infra-identity" "untagged"; do
  echo -e "${YELLOW}=== ${REPO} ===${NC}"

  if [ "$REPO" == "untagged" ]; then
    # Resources without GitRepository tag
    RESOURCES=$(echo "$ALL_RESOURCES" | jq '[.[] | select(.tags.GitRepository == null)]')
  else
    # Resources with specific GitRepository tag
    RESOURCES=$(echo "$ALL_RESOURCES" | jq --arg repo "$REPO" '[.[] | select(.tags.GitRepository == $repo)]')
  fi

  COUNT=$(echo "$RESOURCES" | jq '. | length')

  if [ "$COUNT" -eq 0 ]; then
    echo "  (no resources)"
  else
    echo -e "  ${GREEN}${COUNT} resources:${NC}"
    echo "$RESOURCES" | jq -r '.[] | "    - \(.name) (\(.type))"'
  fi

  echo ""
done

# Summary
echo "=== Summary ==="
echo ""

for REPO in "infra-foundation" "infra-platform" "infra-identity"; do
  COUNT=$(echo "$ALL_RESOURCES" | jq --arg repo "$REPO" '[.[] | select(.tags.GitRepository == $repo)] | length')
  echo -e "${REPO}: ${GREEN}${COUNT}${NC} resources"
done

UNTAGGED=$(echo "$ALL_RESOURCES" | jq '[.[] | select(.tags.GitRepository == null)] | length')
if [ "$UNTAGGED" -gt 0 ]; then
  echo -e "${YELLOW}untagged: ${UNTAGGED} resources (should be tagged!)${NC}"
fi

echo ""
echo -e "${BLUE}Total: ${TOTAL_COUNT} resources${NC}"
