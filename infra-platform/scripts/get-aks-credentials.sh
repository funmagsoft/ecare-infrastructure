#!/bin/bash
# Get AKS credentials for a specific environment

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Get AKS Credentials ==="
echo ""

# Check if environment is specified
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo ""
  echo "Usage: $0 <environment> [--admin]"
  echo ""
  echo "Available environments:"
  echo "  - dev"
  echo "  - test"
  echo "  - stage"
  echo "  - prod"
  echo ""
  echo "Options:"
  echo "  --admin    Get admin credentials (cluster-admin role)"
  echo ""
  echo "Example:"
  echo "  $0 dev"
  echo "  $0 prod --admin"
  exit 1
fi

ENV="$1"
ADMIN_MODE=false

# Parse options
if [ "$2" == "--admin" ]; then
  ADMIN_MODE=true
fi

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
  exit 1
fi

RG="rg-ecare-${ENV}"
AKS_NAME="aks-ecare-${ENV}"

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}Resource Group:${NC} ${RG}"
echo -e "${BLUE}AKS Cluster:${NC} ${AKS_NAME}"
echo -e "${BLUE}Admin Mode:${NC} ${ADMIN_MODE}"
echo ""

# Check if AKS cluster exists
if ! az aks show --resource-group "$RG" --name "$AKS_NAME" --output none 2>/dev/null; then
  echo -e "${RED}✗ AKS cluster not found: ${AKS_NAME}${NC}"
  echo ""
  echo "Please deploy Phase 2 for ${ENV} environment first."
  exit 1
fi

echo "Step 1: Getting cluster information..."
KUBE_VERSION=$(az aks show --resource-group "$RG" --name "$AKS_NAME" --query "kubernetesVersion" -o tsv)
PROVISIONING_STATE=$(az aks show --resource-group "$RG" --name "$AKS_NAME" --query "provisioningState" -o tsv)

echo -e "  Kubernetes version: ${KUBE_VERSION}"
echo -e "  Provisioning state: ${PROVISIONING_STATE}"

if [ "$PROVISIONING_STATE" != "Succeeded" ]; then
  echo -e "${YELLOW}⚠ Cluster is not in 'Succeeded' state${NC}"
fi

echo ""
echo "Step 2: Retrieving credentials..."

if [ "$ADMIN_MODE" == "true" ]; then
  az aks get-credentials \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --admin \
    --overwrite-existing

  echo -e "${GREEN}✓ Admin credentials retrieved${NC}"
  echo -e "${YELLOW}⚠ You now have cluster-admin privileges${NC}"
else
  az aks get-credentials \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --overwrite-existing

  echo -e "${GREEN}✓ User credentials retrieved${NC}"
fi

echo ""
echo "Step 3: Testing cluster connectivity..."

if kubectl cluster-info > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Cluster is accessible${NC}"

  # Show cluster info
  echo ""
  kubectl cluster-info

  echo ""
  echo "Step 4: Checking cluster health..."

  # Get nodes
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")

  echo -e "  Nodes: ${NODE_COUNT} total, ${READY_NODES} ready"

  # Show nodes
  echo ""
  kubectl get nodes

  # Get namespaces
  echo ""
  echo "Step 5: Checking namespaces..."
  kubectl get namespaces

  # Check system pods
  echo ""
  echo "Step 6: Checking system pods..."
  SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
  RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  echo -e "  System pods: ${SYSTEM_PODS} total, ${RUNNING_PODS} running"

  echo ""
  echo -e "${GREEN}=== Cluster is healthy and accessible ===${NC}"
  echo ""
  echo "You can now use kubectl to interact with the cluster."
  echo ""
  echo "Useful commands:"
  echo "  kubectl get nodes"
  echo "  kubectl get pods --all-namespaces"
  echo "  kubectl get services --all-namespaces"
  echo ""
  echo "To switch back to another cluster:"
  echo "  kubectl config use-context <context-name>"
  echo "  kubectl config get-contexts  # List all contexts"

else
  echo -e "${RED}✗ Cannot connect to cluster${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if cluster is running:"
  echo "     az aks show --resource-group ${RG} --name ${AKS_NAME}"
  echo ""
  echo "  2. Verify network connectivity"
  echo ""
  echo "  3. Check RBAC permissions:"
  echo "     az role assignment list --assignee <your-user-id> --scope <cluster-id>"
  exit 1
fi
