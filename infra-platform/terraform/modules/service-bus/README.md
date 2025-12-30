# Service Bus Module

Terraform module for deploying Azure Service Bus with Private Endpoint for secure messaging.

## Resources Created

- **Service Bus Namespace** - Messaging infrastructure
- **Private Endpoint** - Private network access (Premium SKU only)

## Features

- Standard and Premium tiers supported
- Private Endpoint integration (Premium SKU only)
- Zone redundancy (Premium tier)
- TLS 1.2 minimum
- Public network access automatically configured based on SKU

## Usage

```hcl
module "service_bus" {
  source = "../../modules/service-bus"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  project_name        = "ecare"

  sku            = "Standard"
  capacity       = 1  # Premium only
  zone_redundant = false  # Premium only

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
| sku | SKU for Service Bus (Basic, Standard, Premium) | `string` | `"Standard"` | no |
| capacity | Messaging units for Premium SKU (1, 2, 4, 8, 16) | `number` | `1` | no |
| zone_redundant | Enable zone redundancy (Premium SKU only) | `bool` | `false` | no |
| minimum_tls_version | Minimum TLS version | `string` | `"1.2"` | no |
| subnet_id | Subnet ID for Private Endpoint | `string` | - | yes |
| vnet_id | Virtual Network ID for Private DNS Zone link (required for Premium SKU) | `string` | - | no |
| vnet_name | Virtual Network name for Private DNS Zone link (required for Premium SKU) | `string` | - | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| servicebus_namespace_id | ID of the Service Bus Namespace | no |
| servicebus_namespace_name | Name of the Service Bus Namespace | no |
| servicebus_endpoint | Endpoint of the Service Bus Namespace | no |
| servicebus_primary_connection_string | Primary connection string of the Service Bus Namespace | yes |
| servicebus_primary_key | Primary key of the Service Bus Namespace | yes |
| private_endpoint_id | ID of the Private Endpoint (Premium SKU only) | no |
| private_endpoint_ip | Private IP address of the Private Endpoint (Premium SKU only) | no |
| private_dns_zone_id | ID of the Private DNS Zone for Service Bus (Premium SKU only) | no |

## Module-Specific Configuration

### SKU Comparison

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| Max message size | 256 KB | 256 KB | 1 MB |
| Topics | ✗ | ✓ | ✓ |
| Transactions | ✗ | ✓ | ✓ |
| Message batching | ✓ | ✓ | ✓ |
| Geo-disaster recovery | ✗ | ✗ | ✓ |
| Private Endpoints | ✗ | ✗ | ✓ |
| Zone redundancy | ✗ | ✗ | ✓ |

**Note**: Private Endpoints require Premium SKU in this module configuration.

### Creating Queues and Topics

Queues and topics are not created by this module. Create them separately:

```hcl
resource "azurerm_servicebus_queue" "example" {
  name         = "my-queue"
  namespace_id = module.service_bus.servicebus_namespace_id

  max_delivery_count = 10
  lock_duration      = "PT5M"
}

resource "azurerm_servicebus_topic" "example" {
  name         = "my-topic"
  namespace_id = module.service_bus.servicebus_namespace_id
}
```

## Naming Convention

Resources follow this naming pattern:

- **Service Bus Namespace**: `sb-{project_name}-{environment}` (e.g., `sb-ecare-dev`)

## Security Features

- **Network Isolation**: Premium SKU uses Private Endpoints only (public access disabled)
- **TLS 1.2+**: Enforced minimum encryption level
- **Connection Strings**: Stored securely, marked as sensitive outputs

## Examples

### Development Environment

```hcl
module "service_bus" {
  source = "../../modules/service-bus"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  sku = "Standard"  # Standard tier for dev
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

### Production Environment

```hcl
module "service_bus" {
  source = "../../modules/service-bus"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"
  
  sku            = "Premium"  # Premium tier for prod
  capacity       = 2          # Multiple messaging units
  zone_redundant = true        # Zone redundancy for HA
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

## Access from Applications

### Using Managed Identity (Recommended)

```bash
# Grant application identity access
az role assignment create \
  --assignee <app-identity-id> \
  --role "Azure Service Bus Data Owner" \
  --scope <servicebus-namespace-id>
```

### Using Connection String (Not Recommended)

```bash
# Store connection string in Key Vault
export SERVICE_BUS_CONNECTION_STRING=$(terraform output -raw servicebus_primary_connection_string)
```

## Integration with Other Modules

No specific integration with other modules.

## Prerequisites

From Phase 1 (infra-foundation):

- Data subnet for Private Endpoints (Premium SKU)
- Virtual Network ID and name for Private DNS Zone links (Premium SKU)

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
