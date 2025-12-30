# ACR (Azure Container Registry) Module

Terraform module for deploying Azure Container Registry with Private Endpoint for secure container image storage and distribution.

## Resources Created

- **Azure Container Registry** - Private container registry
- **Private Endpoint** - Private network access to ACR

## Features

- Public network access disabled by default
- Premium SKU with zone redundancy support
- Retention policy for untagged manifests
- Content trust policy support (Premium)
- Private Endpoint integration
- Automatic AcrPull role assignment for AKS

## Usage

```hcl
module "acr" {
  source = "../../modules/acr"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  project_name        = "ecare"

  sku                     = "Premium"
  zone_redundancy_enabled = false  # true for production
  retention_days          = 7

  subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  vnet_id   = data.terraform_remote_state.foundation.outputs.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name for resource naming | `string` | `"ecare"` | no |
| sku | SKU for ACR (Basic, Standard, Premium) | `string` | `"Premium"` | no |
| admin_enabled | Enable admin user | `bool` | `false` | no |
| public_network_access_enabled | Enable public network access | `bool` | `true` | no |
| zone_redundancy_enabled | Enable zone redundancy (Premium SKU only) | `bool` | `false` | no |
| retention_days | Retention policy in days for untagged manifests | `number` | `7` | no |
| trust_policy_enabled | Enable content trust policy | `bool` | `false` | no |
| subnet_id | Subnet ID for Private Endpoint | `string` | - | yes |
| vnet_id | Virtual Network ID for Private DNS Zone link | `string` | - | no |
| vnet_name | Virtual Network name for Private DNS Zone link | `string` | - | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| acr_id | ID of the Azure Container Registry | no |
| acr_name | Name of the Azure Container Registry | no |
| acr_login_server | Login server of the Azure Container Registry | no |
| acr_admin_username | Admin username of the Azure Container Registry | yes |
| acr_admin_password | Admin password of the Azure Container Registry | yes |
| private_endpoint_id | ID of the Private Endpoint | no |
| private_endpoint_ip | Private IP address of the Private Endpoint | no |
| private_dns_zone_id | ID of the Private DNS Zone for ACR | no |

## Module-Specific Configuration

### SKU Comparison

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| Storage | 10 GiB | 100 GiB | 500 GiB |
| Webhooks | 2 | 10 | 500 |
| Geo-replication | ✗ | ✗ | ✓ |
| Zone redundancy | ✗ | ✗ | ✓ |
| Content trust | ✗ | ✗ | ✓ |
| Private Endpoints | ✗ | ✗ | ✓ |

**Recommendation**: Use `Premium` for production environments to enable Private Endpoints and zone redundancy.

## Naming Convention

Resources follow this naming pattern:

- **ACR**: `acr{project_name}{environment}` (e.g., `acrecaredev`)
- Must be globally unique, 5-50 alphanumeric characters
- No hyphens allowed (Azure constraint)

## Security Features

- **Network Isolation**: Public network access disabled by default
- **Private Endpoints**: Secure access within VNet
- **Content Trust**: Image signing and verification (Premium)
- **Retention Policy**: Automatic cleanup of untagged manifests

## Examples

### Development Environment

```hcl
module "acr" {
  source = "../../modules/acr"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  sku            = "Standard"  # Lower cost for dev
  retention_days = 7
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

### Production Environment

```hcl
module "acr" {
  source = "../../modules/acr"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"
  
  sku                     = "Premium"  # Premium for prod
  zone_redundancy_enabled = true       # HA across zones
  retention_days          = 30        # Longer retention
  trust_policy_enabled     = true      # Content trust
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

## Integration with Other Modules

### AKS Module

ACR is automatically integrated with AKS. The AKS module receives the ACR ID and grants the kubelet identity the `AcrPull` role:

```hcl
module "aks" {
  source = "../../modules/aks"
  
  acr_id = module.acr.acr_id
  # ... other variables
}
```

## Docker Login

### Using Azure CLI (Managed Identity)

```bash
az acr login --name acrecaredev
```

### Using Docker

```bash
docker login acrecaredev.azurecr.io
```

## Prerequisites

From Phase 1 (infra-foundation):

- Data subnet for Private Endpoints
- Virtual Network ID and name for Private DNS Zone links

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
