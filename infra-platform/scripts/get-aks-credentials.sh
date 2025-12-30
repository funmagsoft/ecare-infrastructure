#!/usr/bin/env bash
# ============================================================================
# Get AKS Credentials
# ============================================================================
# Retrieves kubeconfig credentials for accessing an AKS cluster in a specific
# environment. Supports both user and admin credentials.
#
# Usage:
#   ./get-aks-credentials.sh <environment> [--admin]
#
# Examples:
#   ./get-aks-credentials.sh dev
#   ./get-aks-credentials.sh prod --admin

# ============================================================================
# Source Shared Scripts Library
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ -f "${REPO_ROOT}/shared/scripts/common.sh" ]; then
  source "${REPO_ROOT}/shared/scripts/common.sh"
else
  echo "ERROR: Shared scripts library not found at ${REPO_ROOT}/shared/scripts/common.sh"
  exit 1
fi

# ============================================================================
# Load Global Configuration
# ============================================================================
if [ -f "${REPO_ROOT}/shared/scripts/globals.sh" ]; then
  source "${REPO_ROOT}/shared/scripts/globals.sh"
else
  echo "ERROR: Shared globals not found at ${REPO_ROOT}/shared/scripts/globals.sh"
  exit 1
fi

# ============================================================================
# Script Configuration
# ============================================================================
set -euo pipefail

ENV=""
ADMIN_MODE=false

# ============================================================================
# Usage Information
# ============================================================================
usage() {
  cat <<EOF
Usage: $(basename "$0") <environment> [--admin]

Retrieves kubeconfig credentials for AKS cluster access.

Arguments:
  environment    Target environment (dev, test, stage, prod)

Options:
  --admin        Get admin credentials (cluster-admin role)

Examples:
  $(basename "$0") dev
  $(basename "$0") prod --admin

EOF
  exit 1
}

# ============================================================================
# Parse Arguments
# ============================================================================
if [ $# -eq 0 ]; then
  usage
fi

ENV="$1"
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --admin)
      ADMIN_MODE=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# ============================================================================
# Validate Environment
# ============================================================================
if [[ ! "$ENV" =~ ^(dev|test|stage|prod)$ ]]; then
  log_error "Invalid environment '${ENV}'. Must be: dev, test, stage, prod"
  exit 1
fi

# ============================================================================
# Set Resource Names
# ============================================================================
RG="rg-${PROJECT}-${ENV}"
AKS_NAME="aks-${PROJECT}-${ENV}"

# ============================================================================
# Main Script
# ============================================================================
log_info "=== Get AKS Credentials ==="
echo ""
log_info "Environment:     ${ENV}"
log_info "Resource Group:  ${RG}"
log_info "AKS Cluster:     ${AKS_NAME}"
log_info "Admin Mode:      ${ADMIN_MODE}"
echo ""

# ============================================================================
# Check AKS Cluster Exists
# ============================================================================
log_info "Step 1: Checking AKS cluster exists..."
if ! az aks show --resource-group "$RG" --name "$AKS_NAME" --output none 2>/dev/null; then
  log_error "AKS cluster not found: ${AKS_NAME}"
  echo ""
  echo "Please deploy infra-platform for ${ENV} environment first."
  exit 1
fi

# Get cluster information
KUBE_VERSION=$(az aks show --resource-group "$RG" --name "$AKS_NAME" --query "kubernetesVersion" -o tsv)
PROVISIONING_STATE=$(az aks show --resource-group "$RG" --name "$AKS_NAME" --query "provisioningState" -o tsv)

log_info "  Kubernetes version: ${KUBE_VERSION}"
log_info "  Provisioning state: ${PROVISIONING_STATE}"

if [ "$PROVISIONING_STATE" != "Succeeded" ]; then
  log_warning "Cluster is not in 'Succeeded' state"
fi

# ============================================================================
# Retrieve Credentials
# ============================================================================
echo ""
log_info "Step 2: Retrieving credentials..."

if [ "$ADMIN_MODE" = true ]; then
  if az aks get-credentials \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --admin \
    --overwrite-existing; then
    log_success "Admin credentials retrieved"
    log_warning "You now have cluster-admin privileges"
  else
    log_error "Failed to retrieve admin credentials"
    exit 1
  fi
else
  if az aks get-credentials \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --overwrite-existing; then
    log_success "User credentials retrieved"
  else
    log_error "Failed to retrieve user credentials"
    exit 1
  fi
fi

# ============================================================================
# Test Cluster Connectivity
# ============================================================================
echo ""
log_info "Step 3: Testing cluster connectivity..."

if kubectl cluster-info > /dev/null 2>&1; then
  log_success "Cluster is accessible"

  # Show cluster info
  echo ""
  kubectl cluster-info

  # ============================================================================
  # Check Cluster Health
  # ============================================================================
  echo ""
  log_info "Step 4: Checking cluster health..."

  # Get nodes
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")

  log_info "  Nodes: ${NODE_COUNT} total, ${READY_NODES} ready"

  # Show nodes
  echo ""
  kubectl get nodes

  # ============================================================================
  # Check Namespaces
  # ============================================================================
  echo ""
  log_info "Step 5: Checking namespaces..."
  kubectl get namespaces

  # ============================================================================
  # Check System Pods
  # ============================================================================
  echo ""
  log_info "Step 6: Checking system pods..."
  SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
  RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  log_info "  System pods: ${SYSTEM_PODS} total, ${RUNNING_PODS} running"

  # ============================================================================
  # Success Summary
  # ============================================================================
  echo ""
  log_success "=== Cluster is healthy and accessible ==="
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
  # ============================================================================
  # Connection Failed
  # ============================================================================
  log_error "Cannot connect to cluster"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if cluster is running:"
  echo "     az aks show --resource-group ${RG} --name ${AKS_NAME}"
  echo ""
  echo "  2. Verify network connectivity"
  echo ""
  echo "  3. Check RBAC permissions:"
  echo "     az role assignment list --assignee <your-user-id>"
  exit 1
fi
