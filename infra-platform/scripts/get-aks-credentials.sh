#!/usr/bin/env bash
# =============================================================================
# Script: get-aks-credentials.sh
# Component: infra-platform
# Purpose: Retrieve kubeconfig credentials for an AKS cluster in the given environment.
# =============================================================================
# Usage:
#   ./get-aks-credentials.sh <environment> [--admin] [--dry-run|--execute] [-h|--help]
# =============================================================================

set -Eeuo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/common.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/globals.sh"


setup_traps
ENV=""
ADMIN_MODE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./get-aks-credentials.sh <environment> [--admin] [--dry-run|--execute] [-h|--help]

Retrieves kubeconfig credentials for the AKS cluster in the given environment.

Arguments:
  environment    Target environment (dev, test, stage, prod)

Options:
  --admin        Retrieve admin credentials (cluster-admin)
  --dry-run      Print planned actions without executing
  --execute      Execute actions (default)
  -h, --help     Show this help and exit

Notes:
  - Requires Azure CLI (az) and kubectl to be installed.
  - Requires an active Azure CLI login (az login).
  - This script will update your local kubeconfig (typically ~/.kube/config) in execute mode.
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

ENV="$1"
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --admin)
      ADMIN_MODE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --execute)
      DRY_RUN=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if ! validate_environment "$ENV"; then
  exit 1
fi

RG="rg-${PROJECT}-${ENV}"
AKS_NAME="aks-${PROJECT}-${ENV}"

log_info "=== Get AKS Credentials ==="
log_info "Environment:    ${ENV}"
log_info "Resource Group: ${RG}"
log_info "AKS Cluster:    ${AKS_NAME}"
log_info "Admin Mode:     ${ADMIN_MODE}"
log_dry_run
echo ""

# Dependency checks
check_required_commands az kubectl
check_azure_login

if [ "$DRY_RUN" = true ]; then
  log_info "Planned actions:"
  log_info "  1) Verify AKS cluster exists:"
  log_info "     az aks show --resource-group "${RG}" --name "${AKS_NAME}""
  log_info "  2) Retrieve kubeconfig credentials:"
  if [ "$ADMIN_MODE" = true ]; then
    log_info "     az aks get-credentials --resource-group "${RG}" --name "${AKS_NAME}" --admin --overwrite-existing"
  else
    log_info "     az aks get-credentials --resource-group "${RG}" --name "${AKS_NAME}" --overwrite-existing"
  fi
  log_info "  3) Validate connectivity:"
  log_info "     kubectl cluster-info"
  log_info "     kubectl get nodes"
  log_info "     kubectl get namespaces"
  log_info "     kubectl get pods -n kube-system"
  echo ""
  log_dry_run_complete
  exit 0
fi

# -------------------------------------------------------------------------
# Step 1: Check cluster exists
# -------------------------------------------------------------------------
log_info "Step 1: Checking AKS cluster exists..."
if ! az_call aks show --resource-group "$RG" --name "$AKS_NAME" --output none 2>/dev/null; then
  log_error "AKS cluster not found: ${AKS_NAME}"
  echo ""
  log_info "Deploy infra-platform for ${ENV} environment first."
  exit 1
fi

KUBE_VERSION=$(az_call aks show --resource-group "$RG" --name "$AKS_NAME" --query "kubernetesVersion" -o tsv)
PROVISIONING_STATE=$(az_call aks show --resource-group "$RG" --name "$AKS_NAME" --query "provisioningState" -o tsv)

log_info "  Kubernetes version: ${KUBE_VERSION}"
log_info "  Provisioning state: ${PROVISIONING_STATE}"
if [ "$PROVISIONING_STATE" != "Succeeded" ]; then
  log_warning "Cluster is not in 'Succeeded' state"
fi

# -------------------------------------------------------------------------
# Step 2: Retrieve credentials (mutates local kubeconfig)
# -------------------------------------------------------------------------
echo ""
log_info "Step 2: Retrieving credentials..."

if [ "$ADMIN_MODE" = true ]; then
  if az_call aks get-credentials --resource-group "$RG" --name "$AKS_NAME" --admin --overwrite-existing; then
    log_success "Admin credentials retrieved"
    log_warning "You now have cluster-admin privileges"
  else
    log_error "Failed to retrieve admin credentials"
    exit 1
  fi
else
  if az_call aks get-credentials --resource-group "$RG" --name "$AKS_NAME" --overwrite-existing; then
    log_success "User credentials retrieved"
  else
    log_error "Failed to retrieve user credentials"
    exit 1
  fi
fi

# -------------------------------------------------------------------------
# Step 3: Test connectivity
# -------------------------------------------------------------------------
echo ""
log_info "Step 3: Testing cluster connectivity..."
if kubectl cluster-info > /dev/null 2>&1; then
  log_success "Cluster is accessible"
  echo ""
  kubectl cluster-info
else
  log_error "Cannot connect to cluster"
  echo ""
  log_info "Troubleshooting:"
  log_info "  1) Check cluster state:"
  log_info "     az aks show --resource-group ${RG} --name ${AKS_NAME}"
  log_info "  2) Verify RBAC permissions:"
  log_info "     az role assignment list --assignee <your-user-id>"
  exit 1
fi

# -------------------------------------------------------------------------
# Step 4: Basic health checks
# -------------------------------------------------------------------------
echo ""
log_info "Step 4: Checking cluster health..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
log_info "  Nodes: ${NODE_COUNT} total, ${READY_NODES} ready"
echo ""
kubectl get nodes

echo ""
log_info "Step 5: Checking namespaces..."
kubectl get namespaces

echo ""
log_info "Step 6: Checking system pods..."
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
log_info "  System pods: ${SYSTEM_PODS} total, ${RUNNING_PODS} running"

echo ""
log_success "=== Cluster is healthy and accessible ==="
echo ""
log_info "Useful commands:"
log_info "  kubectl get nodes"
log_info "  kubectl get pods --all-namespaces"
log_info "  kubectl get services --all-namespaces"
