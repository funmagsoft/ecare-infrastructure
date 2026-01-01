# Environment Module

Terraform module that encapsulates all common infrastructure configuration for an environment, eliminating code duplication across environments by providing a single source of truth for environment-specific infrastructure.

## Resources Created

- **Virtual Network** - Base virtual network for the infrastructure
- **Subnets** - AKS subnet, Data subnet (for private endpoints), Management subnet, optional Gateway subnet
- **Network Security Groups** - NSGs for AKS, Data, and Management subnets with default rules
- **NSG Rules** - Security rules for network isolation and SSH access control
- **VPN Gateway** - Optional VPN Gateway for site-to-site and point-to-site connectivity
- **Public IP** - Public IP address for VPN Gateway (if enabled)

## Features

- Single source of truth for all environment infrastructure
- Eliminates ~90% of code duplication across environments
- Automatic propagation of changes to all environments
- Consistent infrastructure configuration across all environments
- Optional VPN Gateway deployment
- Configurable SSH access to management subnet
- Network isolation with NSG rules

## Usage

```hcl
module "environment" {
  source = "../../modules/environment"

  environment  = var.environment
  project_name = var.project_name

  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  data_subnet_cidr    = var.data_subnet_cidr
  mgmt_subnet_cidr    = var.mgmt_subnet_cidr
  gateway_subnet_cidr = var.gateway_subnet_cidr

  enable_vpn_gateway          = var.enable_vpn_gateway
  vpn_gateway_sku            = var.vpn_gateway_sku
  vpn_client_address_space   = var.vpn_client_address_space
  vpn_root_cert_name         = var.vpn_root_cert_name
  vpn_root_cert_data         = var.vpn_root_cert_data
  mgmt_subnet_allowed_ssh_ips = var.mgmt_subnet_allowed_ssh_ips

  tags = var.tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name | `string` | `"ecare"` | no |
| vnet_cidr | CIDR block for VNet | `string` | - | yes |
| aks_subnet_cidr | CIDR block for AKS subnet | `string` | - | yes |
| data_subnet_cidr | CIDR block for Data subnet | `string` | - | yes |
| mgmt_subnet_cidr | CIDR block for Management subnet | `string` | - | yes |
| gateway_subnet_cidr | CIDR block for Gateway subnet | `string` | - | yes |
| enable_vpn_gateway | Enable VPN Gateway deployment | `bool` | `false` | no |
| vpn_gateway_sku | SKU for VPN Gateway | `string` | `"VpnGw1"` | no |
| vpn_client_address_space | Address space for VPN clients | `string` | `"192.168.255.0/24"` | no |
| vpn_root_cert_name | Name of the root certificate for VPN | `string` | `"VPN-Root-Cert"` | no |
| vpn_root_cert_data | Root certificate data (base64) | `string` | `""` | no |
| mgmt_subnet_allowed_ssh_ips | List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet | `list(string)` | `[]` | no |
| tags | Additional tags to merge with required tags. Required tags cannot be overridden. | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| vnet_id | ID of the Virtual Network | no |
| vnet_name | Name of the Virtual Network | no |
| aks_subnet_id | ID of the AKS subnet | no |
| data_subnet_id | ID of the Data subnet | no |
| mgmt_subnet_id | ID of the Management subnet | no |
| gateway_subnet_id | ID of the Gateway subnet | no |
| aks_nsg_id | ID of the AKS NSG | no |
| data_nsg_id | ID of the Data NSG | no |
| mgmt_nsg_id | ID of the Management NSG | no |
| vpn_gateway_id | ID of the VPN Gateway | no |
| vpn_public_ip | Public IP address of VPN Gateway | no |

## Module-Specific Configuration

### Network Configuration

The module creates a Virtual Network with four types of subnets:

- **AKS Subnet**: For Azure Kubernetes Service nodes
- **Data Subnet**: For private endpoints (Storage, Key Vault, PostgreSQL, etc.)
- **Management Subnet**: For bastion VMs and management tools
- **Gateway Subnet**: Optional subnet for VPN Gateway (only created when `enable_vpn_gateway = true`)

### Network Security Groups

Each subnet has an associated NSG with default deny rules:

- **AKS NSG**: Default rules for Kubernetes cluster (allows VNet traffic, Azure Load Balancer, and outbound internet on port 443)
- **Data NSG**: Default rules for private endpoints (allows only VNet inbound traffic)
- **Management NSG**: Default deny all inbound, with optional SSH rule if `mgmt_subnet_allowed_ssh_ips` is provided

### SSH Access to Management Subnet

If `mgmt_subnet_allowed_ssh_ips` is non-empty, the module creates an `AllowSSHInbound` rule (priority 200) on the management NSG. If empty, SSH from the internet remains blocked by `DenyAllInbound`.

### VPN Gateway Configuration

The VPN Gateway is optional and can be enabled by setting `enable_vpn_gateway = true`. When enabled:

- Creates a Public IP for the VPN Gateway
- Configures point-to-site VPN with root certificate authentication
- Supports site-to-site VPN connectivity

### Tags Validation

The module enforces tag validation to ensure all required tags are present:

**Required Tags** (automatically set, cannot be overridden):

- `Environment` - Environment name (dev, test, stage, prod)
- `Project` - Project name
- `ManagedBy` - Always set to "Terraform"
- `Phase` - Always set to "Foundation"
- `GitRepository` - Always set to "ecare-infrastructure"
- `TerraformPath` - Path to Terraform configuration (e.g., "foundation/terraform/environments/dev")
- `DeploymentId` - Deployment identifier for this environment

**Additional Tags**:

- Use `tags` variable to add custom tags
- Required tags cannot be overridden via `tags`
- Validation ensures all required tags are present and non-empty

**Validation**:

- The module uses Terraform `check` blocks to validate that all required tags are present
- If any required tag is missing or empty, Terraform will fail with a clear error message
- The `tags` variable has validation to prevent overriding required tags

## Naming Convention

Resources follow this naming pattern:

- **Resource Group**: `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`) - automatically constructed from `project_name` and `environment` variables
- **Virtual Network**: `vnet-{project_name}-{environment}` (e.g., `vnet-ecare-dev`)
- **Subnets**: `snet-{project_name}-{environment}-{purpose}` (e.g., `snet-ecare-dev-aks`)
- **Network Security Groups**: `nsg-{project_name}-{environment}-{purpose}` (e.g., `nsg-ecare-dev-aks`)
- **VPN Gateway**: `vgw-{project_name}-{environment}` (e.g., `vgw-ecare-dev`)
- **Public IP**: `pip-vgw-{project_name}-{environment}` (e.g., `pip-vgw-ecare-dev`)

**Note**: The Resource Group name is hardcoded within the module as `rg-${var.project_name}-${var.environment}`. The Resource Group must exist (created in Phase 0) before deploying this module.

**Note**: Gateway subnet must be named `GatewaySubnet` (fixed name required by Azure).

## Security Features

- **Network Isolation**: Subnets are isolated with NSGs
- **Default Deny Rules**: All NSGs have default deny-all inbound rules
- **Selective SSH Access**: SSH access to management subnet can be restricted to specific IP addresses
- **Private Endpoints Ready**: Data subnet is configured for private endpoints
- **Network Segmentation**: Separate subnets for different workload types
- **VPN Security**: VPN Gateway uses certificate-based authentication for point-to-site connections
- **Encrypted Connections**: All VPN traffic is encrypted

## Examples

### Development Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment  = "dev"
  project_name = "ecare"

  vnet_cidr           = "10.1.0.0/16"
  aks_subnet_cidr     = "10.1.1.0/24"
  data_subnet_cidr    = "10.1.2.0/24"
  mgmt_subnet_cidr    = "10.1.3.0/24"
  gateway_subnet_cidr = "10.1.4.0/24"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105"]  # Office IP

  enable_vpn_gateway = false

  tags = {
    CostCenter = "Engineering"
    Team       = "DevOps"
  }
}
```

### Production Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment  = "prod"
  project_name = "ecare"

  vnet_cidr           = "10.4.0.0/16"
  aks_subnet_cidr     = "10.4.1.0/24"
  data_subnet_cidr    = "10.4.2.0/24"
  mgmt_subnet_cidr    = "10.4.3.0/24"
  gateway_subnet_cidr = "10.4.4.0/24"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105", "198.51.100.0/24"]  # Multiple IP ranges

  enable_vpn_gateway          = true  # Enable VPN Gateway for prod
  vpn_gateway_sku            = "VpnGw2"  # Higher throughput for prod
  vpn_client_address_space   = "192.168.255.0/24"
  vpn_root_cert_name         = "VPN-Root-Cert"
  vpn_root_cert_data         = var.vpn_root_cert_data  # Use environment variable for production

  tags = {
    CostCenter = "Engineering"
    Team       = "DevOps"
    Compliance = "SOC2"
  }
}
```

## Integration with Other Modules

This module integrates with the following modules:

### Network Module

The environment module calls the `network` module to create the Virtual Network, subnets, and NSGs:

```hcl
module "network" {
  source = "../network"
  # ... network configuration
}
```

### VPN Gateway Module

The environment module conditionally calls the `vpn-gateway` module when VPN Gateway is enabled:

```hcl
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../vpn-gateway"
  # ... VPN configuration
}
```

The VPN Gateway module depends on the network module's gateway subnet output.

## Prerequisites

From Phase 0 (initial setup):

- Resource Group must exist (created in Phase 0)
- Resource Group naming: `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`)
- Storage Account for Terraform state must exist
- Service Principal with appropriate permissions must be configured

**Note**: This module replaces the previously duplicated configuration files (`data.tf`, `locals.tf`, `network.tf`, `vpn.tf`, `outputs.tf`, `variables.tf`, `providers.tf`) that were duplicated across all environment directories. The Resource Group name is automatically constructed as `rg-${var.project_name}-${var.environment}`.

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
