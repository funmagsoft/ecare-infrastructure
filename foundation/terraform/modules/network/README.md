# Network Module

Terraform module for creating the base virtual network, subnets, and network security groups for the ecare foundation layer.

## Resources Created

- **Virtual Network** - Base virtual network for the infrastructure
- **Subnets** - AKS subnet, Data subnet (for private endpoints), Management subnet, optional Gateway subnet
- **Network Security Groups** - NSGs for AKS, Data, and Management subnets with default rules
- **NSG Rules** - SSH rule for management subnet (optional, based on allowed IPs)
- **NSG Associations** - NSG to subnet associations

## Features

- Virtual Network with configurable CIDR
- Multiple subnets for different purposes (AKS, Data, Management, Gateway)
- Network Security Groups with default deny rules
- Optional SSH access to management subnet from specified IPs
- Optional Gateway subnet for VPN Gateway integration
- NSG associations for network isolation

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vnet_name = "vnet-ecare-dev"
  vnet_cidr = "10.1.0.0/16"

  aks_subnet_name  = "snet-ecare-dev-aks"
  aks_subnet_cidr  = "10.1.1.0/24"
  aks_nsg_name     = "nsg-ecare-dev-aks"

  data_subnet_name = "snet-ecare-dev-data"
  data_subnet_cidr = "10.1.2.0/24"
  data_nsg_name    = "nsg-ecare-dev-data"

  mgmt_subnet_name = "snet-ecare-dev-mgmt"
  mgmt_subnet_cidr = "10.1.3.0/24"
  mgmt_nsg_name    = "nsg-ecare-dev-mgmt"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105"]

  enable_vpn_gateway  = false
  gateway_subnet_cidr = "10.1.4.0/24"

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the Resource Group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| vnet_name | Name of the Virtual Network | `string` | - | yes |
| vnet_cidr | CIDR block for the Virtual Network | `string` | - | yes |
| aks_subnet_name | Name of the AKS subnet | `string` | - | yes |
| aks_subnet_cidr | CIDR block for AKS subnet | `string` | - | yes |
| aks_nsg_name | Name of the NSG for AKS subnet | `string` | - | yes |
| data_subnet_name | Name of the Data subnet | `string` | - | yes |
| data_subnet_cidr | CIDR block for Data subnet | `string` | - | yes |
| data_nsg_name | Name of the NSG for Data subnet | `string` | - | yes |
| mgmt_subnet_name | Name of the Management subnet | `string` | - | yes |
| mgmt_subnet_cidr | CIDR block for Management subnet | `string` | - | yes |
| mgmt_nsg_name | Name of the NSG for Management subnet | `string` | - | yes |
| gateway_subnet_cidr | CIDR block for Gateway subnet | `string` | - | yes |
| enable_vpn_gateway | Enable VPN Gateway subnet | `bool` | `false` | no |
| mgmt_subnet_allowed_ssh_ips | List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet. If empty, SSH from internet is blocked. | `list(string)` | `[]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| vnet_id | ID of the Virtual Network | no |
| vnet_name | Name of the Virtual Network | no |
| aks_subnet_id | ID of the AKS subnet | no |
| data_subnet_id | ID of the Data subnet | no |
| mgmt_subnet_id | ID of the Management subnet | no |
| gateway_subnet_id | ID of the Gateway subnet (if enabled) | no |
| aks_nsg_id | ID of the NSG for AKS subnet | no |
| data_nsg_id | ID of the NSG for Data subnet | no |
| mgmt_nsg_id | ID of the NSG for Management subnet | no |

## Module-Specific Configuration

### Subnet Configuration

The module creates four types of subnets:

- **AKS Subnet**: For Azure Kubernetes Service nodes
- **Data Subnet**: For private endpoints (Storage, Key Vault, PostgreSQL, etc.)
- **Management Subnet**: For bastion VMs and management tools
- **Gateway Subnet**: Optional subnet for VPN Gateway (only created when `enable_vpn_gateway = true`)

### Network Security Groups

Each subnet has an associated NSG with default deny rules:

- **AKS NSG**: Default rules for Kubernetes cluster
- **Data NSG**: Default rules for private endpoints
- **Management NSG**: Default deny all inbound, with optional SSH rule if `mgmt_subnet_allowed_ssh_ips` is provided

### SSH Access to Management Subnet

If `mgmt_subnet_allowed_ssh_ips` is non-empty, the module creates an `AllowSSHInbound` rule (priority 200) on the management NSG. If empty, SSH from the internet remains blocked by `DenyAllInbound`.

## Naming Convention

Resources follow this naming pattern:

- **Virtual Network**: User-defined (e.g., `vnet-ecare-dev`)
- **Subnets**: User-defined (e.g., `snet-ecare-dev-aks`, `snet-ecare-dev-data`)
- **Network Security Groups**: User-defined (e.g., `nsg-ecare-dev-aks`, `nsg-ecare-dev-data`)

## Security Features

- **Network Isolation**: Subnets are isolated with NSGs
- **Default Deny Rules**: All NSGs have default deny-all inbound rules
- **Selective SSH Access**: SSH access to management subnet can be restricted to specific IP addresses
- **Private Endpoints Ready**: Data subnet is configured for private endpoints
- **Network Segmentation**: Separate subnets for different workload types

## Examples

### Development Environment

```hcl
module "network" {
  source = "../../modules/network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vnet_name = "vnet-ecare-dev"
  vnet_cidr = "10.1.0.0/16"

  aks_subnet_name  = "snet-ecare-dev-aks"
  aks_subnet_cidr  = "10.1.1.0/24"
  aks_nsg_name     = "nsg-ecare-dev-aks"

  data_subnet_name = "snet-ecare-dev-data"
  data_subnet_cidr = "10.1.2.0/24"
  data_nsg_name    = "nsg-ecare-dev-data"

  mgmt_subnet_name = "snet-ecare-dev-mgmt"
  mgmt_subnet_cidr = "10.1.3.0/24"
  mgmt_nsg_name    = "nsg-ecare-dev-mgmt"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105"]  # Office IP

  enable_vpn_gateway  = false
  gateway_subnet_cidr = "10.1.4.0/24"

  tags = local.common_tags
}
```

### Production Environment

```hcl
module "network" {
  source = "../../modules/network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vnet_name = "vnet-ecare-prod"
  vnet_cidr = "10.1.0.0/16"

  aks_subnet_name  = "snet-ecare-prod-aks"
  aks_subnet_cidr  = "10.1.1.0/24"
  aks_nsg_name     = "nsg-ecare-prod-aks"

  data_subnet_name = "snet-ecare-prod-data"
  data_subnet_cidr = "10.1.2.0/24"
  data_nsg_name    = "nsg-ecare-prod-data"

  mgmt_subnet_name = "snet-ecare-prod-mgmt"
  mgmt_subnet_cidr = "10.1.3.0/24"
  mgmt_nsg_name    = "nsg-ecare-prod-mgmt"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105", "198.51.100.0/24"]  # Multiple IP ranges

  enable_vpn_gateway  = true  # Enable VPN Gateway for prod
  gateway_subnet_cidr = "10.1.4.0/24"

  tags = local.common_tags
}
```

## Integration with Other Modules

### VPN Gateway Module

The network module provides the gateway subnet for VPN Gateway:

```hcl
module "network" {
  source = "../../modules/network"

  enable_vpn_gateway = true
  gateway_subnet_cidr = "10.1.4.0/24"
  # ... other variables
}

module "vpn_gateway" {
  source = "../../modules/vpn-gateway"

  gateway_subnet_id = module.network.gateway_subnet_id
  # ... other variables
}
```

## Prerequisites

From Phase 0 (initial setup):

- Resource Group must exist
- No specific prerequisites required

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
