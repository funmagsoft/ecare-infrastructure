#!/bin/bash
# Setup and configure Bastion VM with required tools

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Bastion VM Setup ==="
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
  exit 1
fi

RG="rg-ecare-${ENV}"
VM_NAME="vm-bastion-ecare-${ENV}"
AKS_NAME="aks-ecare-${ENV}"

echo -e "${BLUE}Environment:${NC} ${ENV}"
echo -e "${BLUE}VM Name:${NC} ${VM_NAME}"
echo ""

# Check if VM exists
if ! az vm show --resource-group "$RG" --name "$VM_NAME" --output none 2>/dev/null; then
  echo -e "${RED}✗ Bastion VM not found: ${VM_NAME}${NC}"
  echo ""
  echo "Please deploy Phase 2 for ${ENV} environment first."
  exit 1
fi

echo "Step 1: Getting VM information..."
VM_STATE=$(az vm get-instance-view --resource-group "$RG" --name "$VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv)
echo -e "  VM Power State: ${VM_STATE}"

if [[ "$VM_STATE" != *"running"* ]]; then
  echo -e "${YELLOW}⚠ VM is not running. Starting VM...${NC}"
  az vm start --resource-group "$RG" --name "$VM_NAME"
  echo -e "${GREEN}✓ VM started${NC}"
fi

echo ""
echo "Step 2: Creating setup script..."

# Create temporary setup script
SETUP_SCRIPT=$(mktemp)

cat > "$SETUP_SCRIPT" <<'EOF'
#!/bin/bash
set -e

echo "=== Installing Required Tools on Bastion VM ==="
echo ""

# Update package list
echo "Updating package list..."
sudo apt-get update -qq

# Install Azure CLI
echo "Installing Azure CLI..."
if ! command -v az &> /dev/null; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  echo "✓ Azure CLI installed"
else
  echo "✓ Azure CLI already installed"
fi

# Install kubectl
echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  echo "✓ kubectl installed"
else
  echo "✓ kubectl already installed"
fi

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
if ! command -v psql &> /dev/null; then
  sudo apt-get install -y postgresql-client
  echo "✓ psql installed"
else
  echo "✓ psql already installed"
fi

# Install helm
echo "Installing Helm..."
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "✓ Helm installed"
else
  echo "✓ Helm already installed"
fi

# Install jq
echo "Installing jq..."
if ! command -v jq &> /dev/null; then
  sudo apt-get install -y jq
  echo "✓ jq installed"
else
  echo "✓ jq already installed"
fi

# Install git
echo "Installing git..."
if ! command -v git &> /dev/null; then
  sudo apt-get install -y git
  echo "✓ git installed"
else
  echo "✓ git already installed"
fi

# Install curl and wget
echo "Installing curl and wget..."
sudo apt-get install -y curl wget

# Create .bashrc additions for convenience
echo "Configuring shell environment..."

cat >> ~/.bashrc <<'BASHRC'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'

# Azure aliases
alias azls='az account show'
alias azrg='az group list -o table'

# Enable kubectl autocompletion
source <(kubectl completion bash)
complete -F __start_kubectl k

# Useful functions
kexec() {
  kubectl exec -it "$1" -- /bin/bash
}

kport() {
  kubectl port-forward "$1" "$2:$2"
}

BASHRC

echo "✓ Shell environment configured"

echo ""
echo "=== Tool Installation Complete ==="
echo ""
echo "Installed tools:"
az --version | head -1
kubectl version --client --short 2>/dev/null || kubectl version --client
psql --version
helm version --short
jq --version
git --version

echo ""
echo "To use kubectl, you need to:"
echo "  1. Login to Azure: az login"
echo "  2. Get AKS credentials: az aks get-credentials --resource-group <rg> --name <aks-name>"
EOF

chmod +x "$SETUP_SCRIPT"

echo ""
echo "Step 3: Uploading and executing setup script on VM..."

# Get VM admin username
VM_ADMIN=$(az vm show --resource-group "$RG" --name "$VM_NAME" --query "osProfile.adminUsername" -o tsv)

# Get VM private IP
VM_IP=$(az vm show --resource-group "$RG" --name "$VM_NAME" -d --query "privateIps" -o tsv)

echo -e "  VM Admin: ${VM_ADMIN}"
echo -e "  VM Private IP: ${VM_IP}"
echo ""

# Run setup via az vm run-command
echo "Executing setup script (this may take a few minutes)..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "@${SETUP_SCRIPT}" \
  --query "value[0].message" \
  --output tsv

# Clean up temp file
rm -f "$SETUP_SCRIPT"

echo ""
echo -e "${GREEN}✓ Bastion VM setup complete${NC}"

echo ""
echo "Step 4: Configuring AKS access..."

# Create script to get AKS credentials on bastion
AKS_SCRIPT=$(mktemp)

cat > "$AKS_SCRIPT" <<EOFAKS
#!/bin/bash
az login --identity
az aks get-credentials --resource-group ${RG} --name ${AKS_NAME} --overwrite-existing
kubectl get nodes
EOFAKS

echo "Configuring AKS access on Bastion VM..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "@${AKS_SCRIPT}" \
  --query "value[0].message" \
  --output tsv

rm -f "$AKS_SCRIPT"

echo ""
echo -e "${GREEN}=== Bastion VM is Ready ===${NC}"
echo ""
echo "To connect to the Bastion VM:"
echo "  az ssh vm --resource-group ${RG} --name ${VM_NAME}"
echo ""
echo "Or using native SSH:"
echo "  ssh ${VM_ADMIN}@${VM_IP}"
echo ""
echo "Available tools on Bastion:"
echo "  - Azure CLI (az)"
echo "  - kubectl"
echo "  - PostgreSQL client (psql)"
echo "  - Helm"
echo "  - jq, git, curl, wget"
echo ""
echo "Useful aliases configured:"
echo "  k, kgp, kgs, kgn, kd, kl"
