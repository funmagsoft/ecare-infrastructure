# Storage Module

Terraform module for deploying Azure Storage Account with containers and Private Endpoints for
secure, network-isolated storage access.

## Resources Created

- **Storage Account** - Azure Storage with blob, file, queue, and table services
- **Storage Containers** - Blob containers (app-data, logs, backups)
- **Private Endpoint (Blob)** - Private network access to blob storage
- **Private Endpoint (File)** - Private network access to file storage

## Features

- Public network access disabled by default
- Private Endpoints for blob and file services
- Blob versioning support
- Soft delete for blobs and containers
- Configurable retention policies
- TLS 1.2 minimum encryption
- Integration with Private DNS Zones

## Usage

```hcl
module "storage" {
  source = "../../modules/storage"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  project_name        = "ecare"

  account_tier             = "Standard"
  account_replication_type = "LRS"
  containers               = ["app-data", "logs", "backups"]

  enable_versioning               = true
  enable_soft_delete_blob         = true
  blob_soft_delete_retention_days = 7

  # Private Endpoint configuration
  subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  vnet_id   = data.terraform_remote_state.foundation.outputs.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| organization_name | Organization name for resource naming | `string` | `"hycom"` | no |
| project_name | Project name for resource naming | `string` | `"ecare"` | no |
| account_tier | Storage Account tier (Standard or Premium) | `string` | `"Standard"` | no |
| account_replication_type | Replication type (LRS, GRS, RAGRS, ZRS) | `string` | `"LRS"` | no |
| enable_https_traffic_only | Enable HTTPS traffic only | `bool` | `true` | no |
| min_tls_version | Minimum TLS version | `string` | `"TLS1_2"` | no |
| containers | List of container names to create | `list(string)` | `["app-data", "logs", "backups"]` | no |
| enable_versioning | Enable blob versioning | `bool` | `true` | no |
| enable_soft_delete_blob | Enable soft delete for blobs | `bool` | `true` | no |
| blob_soft_delete_retention_days | Retention days for blob soft delete | `number` | `7` | no |
| enable_soft_delete_container | Enable soft delete for containers | `bool` | `true` | no |
| container_soft_delete_retention_days | Retention days for container soft delete | `number` | `7` | no |
| subnet_id | Subnet ID for Private Endpoints | `string` | - | yes |
| vnet_id | Virtual Network ID for Private DNS Zone links | `string` | - | no |
| vnet_name | Virtual Network name for Private DNS Zone links | `string` | - | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| storage_account_id | ID of the Storage Account | no |
| storage_account_name | Name of the Storage Account | no |
| storage_account_primary_blob_endpoint | Primary blob endpoint of the Storage Account | no |
| storage_account_primary_file_endpoint | Primary file endpoint of the Storage Account | no |
| storage_account_primary_access_key | Primary access key of the Storage Account | yes |
| storage_account_primary_connection_string | Primary connection string of the Storage Account | yes |
| container_names | Names of created containers | no |
| blob_private_endpoint_id | ID of the Blob Private Endpoint | no |
| blob_private_endpoint_ip | Private IP address of the Blob Private Endpoint | no |
| file_private_endpoint_id | ID of the File Private Endpoint | no |
| file_private_endpoint_ip | Private IP address of the File Private Endpoint | no |
| blob_private_dns_zone_id | ID of the Private DNS Zone for Blob Storage | no |
| file_private_dns_zone_id | ID of the Private DNS Zone for File Storage | no |

## Module-Specific Configuration

### Replication Types

| Type | Description | Use Case |
|------|-------------|----------|
| LRS | Locally Redundant Storage | Dev/Test (3 copies in single datacenter) |
| ZRS | Zone Redundant Storage | Production (3 copies across availability zones) |
| GRS | Geo-Redundant Storage | Production (6 copies, 2 regions) |
| RAGRS | Read-Access GRS | Production with read access to secondary region |

## Naming Convention

Resources follow this naming pattern:

- Storage Account: `st{project_name}{environment}` (e.g., `stecaredev`)
- Containers: User-defined (default: `app-data`, `logs`, `backups`)
- Private Endpoints: `{storage_account_name}-{service}-pe` (e.g., `stecaredev-blob-pe`)

## Storage Account Name Constraints

- Must be globally unique across all Azure
- 3-24 characters, lowercase letters and numbers only
- Module automatically generates: `st{project_name}{environment}`

## Security Features

### Network Isolation

- `public_network_access_enabled = false` - No public internet access
- Access only via Private Endpoints within VNet
- Private DNS integration for name resolution

### Data Protection

- **Versioning**: Automatic versioning of blob changes
- **Soft Delete (Blobs)**: Recoverable for configured retention period
- **Soft Delete (Containers)**: Prevents accidental container deletion
- **TLS 1.2+**: Enforced minimum encryption level

## Examples

### Development Environment

```hcl
module "storage" {
  source = "../../modules/storage"

  resource_group_name      = "rg-ecare-dev"
  location                 = "West Europe"
  environment              = "dev"
  account_replication_type = "LRS"  # Local redundancy for dev
  
  blob_soft_delete_retention_days = 7  # Short retention for dev
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

### Production Environment

```hcl
module "storage" {
  source = "../../modules/storage"

  resource_group_name      = "rg-ecare-prod"
  location                 = "West Europe"
  environment              = "prod"
  account_replication_type = "GRS"  # Geo-redundancy for prod
  
  blob_soft_delete_retention_days = 30  # Longer retention for prod
  enable_versioning                = true
  
  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

## Access from Applications

### Using Managed Identity (Recommended)

```bash
# Application uses Azure AD authentication with Managed Identity
# No keys needed - RBAC roles assigned to app identity
az role assignment create \
  --assignee <app-identity-id> \
  --role "Storage Blob Data Contributor" \
  --scope <storage-account-id>
```

### Using Connection String (Not Recommended)

```bash
# Store connection string in Key Vault
export STORAGE_CONNECTION_STRING=$(terraform output -raw storage_account_primary_connection_string)
```

## Integration with Other Modules

No specific integration with other modules.

## Prerequisites

From Phase 1 (infra-foundation):

- Data subnet for Private Endpoints
- Virtual Network ID and name for Private DNS Zone links

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
