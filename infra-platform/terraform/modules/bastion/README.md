# Bastion VM Module

Terraform module for deploying a Bastion (jump host) VM with pre-installed management tools for accessing private Azure resources.

## Resources Created

- **Linux VM** - Ubuntu 22.04 LTS virtual machine
- **Static Public IP** - Standard public IP address
- **Network Interface** - Network interface in the management subnet
- **Network Security Group** - NSG with SSH allow rule
- **SSH Key** - Generated or provided SSH key pair

## Features

- Installs tools via cloud-init: Azure CLI, kubectl (+completion), Helm (+completion), psql, jq, git, curl, wget.
- Preconfigured aliases and helper functions.
- Custom MOTD with quick instructions.
- NSG rules for SSH, outbound AKS API, and PostgreSQL.

## Usage

```hcl
module "bastion" {
  source = "../../modules/bastion"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  subnet_id      = var.mgmt_subnet_id
  vm_size        = "Standard_B1s"
  admin_username = "azureuser"
  ubuntu_sku     = "22_04-lts-gen2"

  allowed_ssh_source_ips = ["203.0.113.0/24"]  # Your office IP
  
  enable_system_assigned_identity = true
  install_tools                  = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name for resource naming | `string` | `"ecare"` | no |
| subnet_id | Subnet ID for Bastion VM | `string` | - | yes |
| vm_size | VM size for Bastion | `string` | `"Standard_D2als_v6"` | no |
| admin_username | Admin username for Bastion VM | `string` | `"azureuser"` | no |
| admin_ssh_public_key | SSH public key for Bastion VM admin user | `string` | - | no |
| disable_password_authentication | Disable password authentication (use SSH keys only) | `bool` | `true` | no |
| ubuntu_sku | Ubuntu SKU for Jammy (22.04) | `string` | `"22_04-lts-gen2"` | no |
| os_disk_size_gb | OS disk size in GB | `number` | `30` | no |
| os_disk_storage_account_type | Storage account type for OS disk | `string` | `"Standard_LRS"` | no |
| allowed_ssh_source_ips | List of source IPs allowed for SSH access | `list(string)` | `["0.0.0.0/0"]` | no |
| enable_system_assigned_identity | Enable system-assigned managed identity | `bool` | `true` | no |
| install_tools | Install common tools (az, kubectl, psql, helm) | `bool` | `true` | no |
| additional_users | Map of additional users to create on bastion | `map(list(string))` | `{}` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| bastion_vm_id | ID of the Bastion VM | no |
| bastion_vm_name | Name of the Bastion VM | no |
| bastion_public_ip | Public IP address of the Bastion VM | no |
| bastion_private_ip | Private IP address of the Bastion VM | no |
| bastion_admin_username | Admin username for Bastion VM | no |
| bastion_ssh_private_key | SSH private key for Bastion VM (if generated) | yes |
| bastion_ssh_public_key | SSH public key for Bastion VM | no |
| bastion_principal_id | Principal ID of the Bastion VM system-assigned identity | no |
| bastion_nsg_id | ID of the Bastion NSG | no |

## Module-Specific Configuration

### Installed Tools

The cloud-init script automatically installs:

1. **Azure CLI** - Manage Azure resources
2. **kubectl** - Kubernetes command-line tool
3. **Helm** - Kubernetes package manager
4. **PostgreSQL client (psql)** - Database access
5. **jq** - JSON processor
6. **git** - Version control
7. **curl, wget** - HTTP tools

### Pre-configured Aliases

```bash
# Kubernetes shortcuts
k='kubectl'
kgp='kubectl get pods'
kgs='kubectl get services'
kgn='kubectl get nodes'
kd='kubectl describe'
kl='kubectl logs'

# Azure shortcuts
azls='az account show'
azrg='az group list -o table'

# Helper functions
kexec <pod>        # Execute shell in pod
kport <pod> <port> # Port forward
```

### Connecting to Bastion

### Using SSH

```bash
# Get public IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Connect using generated key
terraform output -raw bastion_ssh_private_key > bastion_key.pem
chmod 600 bastion_key.pem
ssh -i bastion_key.pem azureuser@$BASTION_IP

# Or using your own key
ssh azureuser@$BASTION_IP
```

### Using Azure CLI

```bash
# Using Azure CLI (requires Azure Bastion Service, not this VM)
az ssh vm \
  --resource-group rg-ecare-dev \
  --name vm-bastion-ecare-dev
```

### Post-Deployment Setup

After VM is provisioned, login and configure Azure access:

```bash
# Login with managed identity
az login --identity

# Get AKS credentials
az aks get-credentials \
  --resource-group rg-ecare-dev \
  --name aks-ecare-dev

# Verify kubectl access
kubectl get nodes

# Test PostgreSQL connection
psql -h psql-ecare-dev.postgres.database.azure.net \
     -U psqladmin \
     -d postgres
```

### Granting Access to Resources

The module output `bastion_principal_id` is used to grant RBAC roles:

```hcl
# Automatic in main.tf
resource "azurerm_role_assignment" "bastion_aks_user" {
  principal_id         = module.bastion.bastion_principal_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  scope                = module.aks.aks_cluster_id
}

resource "azurerm_role_assignment" "bastion_acr_pull" {
  principal_id         = module.bastion.bastion_principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id
}
```

### Network Security Group Rules

**Inbound:**

- SSH (port 22) from `allowed_ssh_source_ips`

**Outbound:**

- HTTPS (port 443) to AKS API server
- PostgreSQL (port 5432) to database
- All other Azure services

### Best Practices

1. **Restrict SSH source IPs** - Use specific IP ranges, not `0.0.0.0/0`
2. **Use SSH keys only** - Disable password authentication
3. **Managed identity** - No need to store Azure credentials
4. **Regular updates** - Keep VM and tools updated
5. **Audit access** - Monitor SSH login attempts

### VM Sizes

| Size | vCPU | Memory | Cost | Use Case |
|------|------|--------|------|----------|
| Standard_B1s | 1 | 1 GiB | Lowest | Dev/Test |
| Standard_B2s | 2 | 4 GiB | Low | Small teams |
| Standard_D2s_v3 | 2 | 8 GiB | Medium | Production |

**Recommendation**: `Standard_B1s` is sufficient for bastion usage.

### Cloud-init Script

Located at `scripts/cloud-init.tpl`, the script:

1. Updates package lists
2. Installs all tools
3. Configures bash completion
4. Creates helpful aliases
5. Sets up custom MOTD
6. Enables managed identity login script

### Troubleshooting

#### Cannot SSH to Bastion

1. Check NSG rules allow your IP
2. Verify public IP is assigned
3. Check VM is running: `az vm get-instance-view`

#### Tools not installed

1. Check cloud-init logs: `cat /var/log/cloud-init-output.log`
2. Manually run: `sudo bash /var/lib/cloud/instance/scripts/part-001`

#### Cannot access AKS

1. Verify managed identity role assignment
2. Run: `az login --identity`
3. Get credentials: `az aks get-credentials ...`

## Naming Convention

Resources follow this naming pattern:

- **VM**: `vm-bastion-{project_name}-{environment}` (e.g., `vm-bastion-ecare-dev`)
- **Public IP**: `pip-bastion-{project_name}-{environment}`
- **NIC**: `nic-bastion-{project_name}-{environment}`
- **NSG**: `nsg-bastion-{project_name}-{environment}`

## Security Features

- **Network Isolation**: NSG rules restrict SSH access to specified source IPs
- **SSH Key Authentication**: Password authentication disabled by default
- **Managed Identity**: System-assigned managed identity for Azure resource access (no stored credentials)
- **Network Security Group**: Inbound SSH from allowed IPs only, outbound to AKS API and PostgreSQL
- **Best Practices**: Restrict SSH source IPs, use SSH keys only, regular updates, audit access

## Examples

### Development Environment

```hcl
module "bastion" {
  source = "../../modules/bastion"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  subnet_id      = var.mgmt_subnet_id
  vm_size        = "Standard_B1s"  # Lower cost for dev
  admin_username = "azureuser"
  
  allowed_ssh_source_ips = ["203.0.113.0/24"]  # Office IP range
  
  enable_system_assigned_identity = true
  install_tools                  = true
}
```

### Production Environment

```hcl
module "bastion" {
  source = "../../modules/bastion"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"
  
  subnet_id      = var.mgmt_subnet_id
  vm_size        = "Standard_D2s_v3"  # More resources for prod
  admin_username = "azureuser"
  
  allowed_ssh_source_ips = ["203.0.113.0/24", "198.51.100.0/24"]  # Multiple IP ranges
  
  enable_system_assigned_identity = true
  install_tools                  = true
}
```

## Integration with Other Modules

No specific integration with other modules.

## Prerequisites

From Phase 1 (infra-foundation):

- Management subnet for Bastion VM

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
- TLS Provider ~> 4.0 (for SSH key generation)
