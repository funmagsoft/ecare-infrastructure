# VPN Gateway Module

Terraform module for creating an optional VPN Gateway with Public IP for site-to-site and client VPN scenarios.

## Resources Created

- **Public IP** - Public IP address for VPN Gateway
- **Virtual Network Gateway** - VPN Gateway for site-to-site and point-to-site connections

## Features

- Site-to-site VPN connectivity
- Point-to-site VPN connectivity
- Configurable VPN Gateway SKU
- Root certificate support for point-to-site
- Configurable client address space

## Usage

```hcl
module "vpn_gateway" {
  source = "../../modules/vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vpn_gateway_name = "vgw-ecare-dev"
  public_ip_name   = "pip-vgw-ecare-dev"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = "VpnGw1"
  vpn_client_address_space = "192.168.255.0/24"
  vpn_root_cert_name       = "VPN-Root-Cert"
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the Resource Group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| vpn_gateway_name | Name of the VPN Gateway | `string` | - | yes |
| public_ip_name | Name of the Public IP for VPN Gateway | `string` | - | yes |
| gateway_subnet_id | ID of the Gateway Subnet | `string` | - | yes |
| vpn_gateway_sku | SKU for VPN Gateway | `string` | `"VpnGw1"` | no |
| vpn_client_address_space | Address space for VPN clients | `string` | `"192.168.255.0/24"` | no |
| vpn_root_cert_name | Name of the root certificate for VPN | `string` | - | yes |
| vpn_root_cert_data | Root certificate data for VPN (base64 encoded) | `string` | - | yes |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| vpn_gateway_id | ID of the VPN Gateway | no |
| vpn_gateway_name | Name of the VPN Gateway | no |
| public_ip_address | Public IP address of the VPN Gateway | no |

## Module-Specific Configuration

### VPN Gateway SKUs

| SKU | Throughput | Tunnels | P2S Connections | Use Case |
|-----|------------|---------|-----------------|----------|
| VpnGw1 | 650 Mbps | 30 | 128 | Small to medium deployments |
| VpnGw2 | 1 Gbps | 30 | 128 | Medium to large deployments |
| VpnGw3 | 1.25 Gbps | 30 | 128 | Large deployments |
| VpnGw4 | 5 Gbps | 30 | 128 | Very large deployments |
| VpnGw5 | 10 Gbps | 30 | 128 | Enterprise deployments |

**Recommendation**: Start with `VpnGw1` for development and scale up based on requirements.

### Point-to-Site Configuration

The module supports point-to-site VPN with root certificate authentication:

- **Root Certificate**: Base64-encoded certificate data
- **Client Address Space**: IP range for VPN clients (default: `192.168.255.0/24`)
- **Certificate Name**: Name for the root certificate

## Naming Convention

Resources follow this naming pattern:

- **VPN Gateway**: User-defined (e.g., `vgw-ecare-dev`)
- **Public IP**: User-defined (e.g., `pip-vgw-ecare-dev`)

## Security Features

- **Certificate-based Authentication**: Point-to-site VPN uses root certificate authentication
- **Encrypted Connections**: All VPN traffic is encrypted
- **Network Isolation**: VPN Gateway provides secure access to private network
- **Sensitive Data**: Root certificate data is marked as sensitive

## Examples

### Development Environment

```hcl
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../../modules/vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vpn_gateway_name = "vgw-ecare-dev"
  public_ip_name   = "pip-vgw-ecare-dev"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = "VpnGw1"  # Lower cost for dev
  vpn_client_address_space = "192.168.255.0/24"
  vpn_root_cert_name       = "VPN-Root-Cert"
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags
}
```

### Production Environment

```hcl
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../../modules/vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = "West Europe"

  vpn_gateway_name = "vgw-ecare-prod"
  public_ip_name   = "pip-vgw-ecare-prod"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = "VpnGw2"  # Higher throughput for prod
  vpn_client_address_space = "192.168.255.0/24"
  vpn_root_cert_name       = "VPN-Root-Cert"
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags
}
```

## Integration with Other Modules

### Network Module

The VPN Gateway module requires the gateway subnet from the network module:

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
- Gateway subnet must exist (created by network module when `enable_vpn_gateway = true`)
- Root certificate data must be available (base64 encoded)

**Note**: `vpn_root_cert_data` is sensitive; keep it out of version control. Use Terraform variables or Key Vault.

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
