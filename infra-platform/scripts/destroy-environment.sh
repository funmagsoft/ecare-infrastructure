#!/bin/bash
# Destroy Terraform-managed resources for a specific environment

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}=== Terraform Environment Destruction ===${NC}"
echo ""

# Check if environment is specified
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo ""
  echo "Usage: $0 <environment> [--force]"
  echo ""
  echo "Available environments:"
  echo "  - dev"
  echo "  - test"
  echo "  - stage"
  echo "  - prod"
  echo ""
  echo "Options:"
  echo "  --force    Skip confirmation prompts (DANGEROUS!)"
  echo ""
  echo "Example:"
  echo "  $0 dev"
  exit 1
fi

ENV="$1"
FORCE=false

# Parse options
if [ "$2" == "--force" ]; then
  FORCE=true
fi

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
  exit 1
fi

# Extra safety for PROD
if [ "$ENV" == "prod" ]; then
  echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
  echo -e "${RED}!!! WARNING: DESTROYING PRODUCTION ENVIRONMENT !!!${NC}"
  echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
  echo ""
  echo "This will DELETE all production platform resources including:"
  echo "  - AKS cluster and all workloads"
  echo "  - PostgreSQL database and all data"
  echo "  - Storage accounts and all data"
  echo "  - Key Vault and all secrets"
  echo "  - Service Bus and all messages"
  echo "  - ACR and all container images"
  echo ""

  if [ "$FORCE" == "false" ]; then
    read -p "Type 'destroy-production' to confirm: " CONFIRM
    if [ "$CONFIRM" != "destroy-production" ]; then
      echo "Destruction cancelled."
      exit 1
    fi
  fi
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="${REPO_DIR}/terraform/environments/${ENV}"

if [ ! -d "$ENV_DIR" ]; then
  echo -e "${RED}Error: Environment directory not found: ${ENV_DIR}${NC}"
  exit 1
fi

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}Directory:${NC} ${ENV_DIR}"
echo ""

# Navigate to environment directory
cd "$ENV_DIR"

# Final confirmation
if [ "$FORCE" == "false" ]; then
  echo -e "${YELLOW}This will destroy all Terraform-managed resources in ${ENV} environment.${NC}"
  echo ""
  read -p "Are you absolutely sure? (yes/no): " FINAL_CONFIRM
  if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
  fi
fi

echo ""
echo "Step 1: Creating destruction plan..."
if terraform plan -destroy -out=destroy.tfplan -input=false; then
  echo -e "${GREEN}✓ Destruction plan created${NC}"
else
  echo -e "${RED}✗ Plan creation failed${NC}"
  exit 1
fi

echo ""
echo "Step 2: Destroying resources..."
echo ""

START_TIME=$(date +%s)

if terraform apply destroy.tfplan; then
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  DURATION_MIN=$((DURATION / 60))
  DURATION_SEC=$((DURATION % 60))

  echo ""
  echo -e "${GREEN}✓ Destruction completed successfully${NC}"
  echo -e "${GREEN}  Duration: ${DURATION_MIN}m ${DURATION_SEC}s${NC}"

  # Clean up plan file
  rm -f destroy.tfplan

  echo ""
  echo -e "${YELLOW}Note: The following resources were NOT deleted:${NC}"
  echo "  - Resource Group (rg-ecare-${ENV}) - managed outside Terraform"
  echo "  - Terraform state Storage Account (tfstatehycomecare${ENV}) - created in Phase 0"
  echo "  - Service Principals and Federated Identity Credentials - created in Phase 0"
  echo ""
  echo "To completely remove the environment, run:"
  echo "  az group delete --name rg-ecare-${ENV} --yes"

else
  echo ""
  echo -e "${RED}✗ Destruction failed!${NC}"
  echo ""
  echo "Some resources may have dependencies. Review errors above."
  echo "You may need to manually delete some resources via Azure Portal."
  exit 1
fi
