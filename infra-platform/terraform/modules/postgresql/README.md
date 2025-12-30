# PostgreSQL Flexible Server Module

Terraform module for deploying Azure PostgreSQL Flexible Server with VNet integration for secure
database access.

## Resources Created

- **PostgreSQL Flexible Server** - Managed PostgreSQL database
- **Server Configurations** - Custom configuration overrides
- **Private Endpoint** (optional) - If not using delegated subnet

## Features

- PostgreSQL versions 11-16 supported
- VNet integration via delegated subnet
- High Availability (Zone Redundant or Same Zone)
- Geo-redundant backups
- Automatic maintenance
- Point-in-time restore
- Public network access disabled

## Usage

```hcl
module "postgresql" {
  source = "../../modules/postgresql"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"

  postgresql_version = "15"
  sku_name           = "B_Standard_B1ms"  # Burstable for dev
  storage_mb         = 32768

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  # VNet integration
  private_endpoint_subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  vnet_id                    = data.terraform_remote_state.foundation.outputs.vnet_id
  vnet_name                  = data.terraform_remote_state.foundation.outputs.vnet_name

  # Backups
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # High Availability (production only)
  high_availability_enabled = false
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name for resource naming (max 30 characters) | `string` | `"ecare"` | no |
| postgresql_version | PostgreSQL version (11, 12, 13, 14, 15, 16) | `string` | `"15"` | no |
| sku_name | SKU name for PostgreSQL Flexible Server | `string` | `"B_Standard_B1ms"` | no |
| storage_mb | Storage size in MB (32768-16777216) | `number` | `32768` | no |
| backup_retention_days | Backup retention in days (7-35) | `number` | `7` | no |
| geo_redundant_backup_enabled | Enable geo-redundant backup | `bool` | `false` | no |
| high_availability_enabled | Enable high availability (zone redundant) | `bool` | `false` | no |
| high_availability_mode | High availability mode (ZoneRedundant or SameZone) | `string` | `"ZoneRedundant"` | no |
| administrator_login | Administrator login name | `string` | `"psqladmin"` | no |
| administrator_password | Administrator password (minimum 8 characters) | `string` | - | yes |
| public_network_access_enabled | Enable public network access | `bool` | `false` | no |
| private_endpoint_subnet_id | Subnet ID for Private Endpoint | `string` | - | yes |
| vnet_id | Virtual Network ID for Private DNS Zone link | `string` | - | no |
| vnet_name | Virtual Network name for Private DNS Zone link | `string` | - | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| postgresql_server_id | ID of the PostgreSQL Flexible Server | no |
| postgresql_server_name | Name of the PostgreSQL Flexible Server | no |
| postgresql_fqdn | FQDN of the PostgreSQL Flexible Server | no |
| postgresql_administrator_login | Administrator login of the PostgreSQL Flexible Server | no |
| postgresql_administrator_password | Administrator password of the PostgreSQL Flexible Server | yes |
| private_endpoint_id | ID of the Private Endpoint | no |
| private_endpoint_ip | Private IP address of the Private Endpoint | no |
| private_dns_zone_id | ID of the Private DNS Zone for PostgreSQL | no |

## Module-Specific Configuration

### SKU Tiers

| Tier | SKU Example | Use Case | vCores | Memory |
|------|-------------|----------|---------|---------|
| Burstable | `B_Standard_B1ms` | Dev/Test | 1 | 2 GiB |
| General Purpose | `GP_Standard_D2s_v3` | Production | 2 | 8 GiB |
| Memory Optimized | `MO_Standard_E4s_v3` | High-performance | 4 | 32 GiB |

### High Availability

```hcl
# Production: Enable HA with zone redundancy
high_availability_enabled = true
high_availability_mode    = "ZoneRedundant"

# This creates:
# - Primary server in one availability zone
# - Standby replica in another zone
# - Automatic failover (< 2 min downtime)
```

### Connection Examples

#### From Bastion VM

```bash
psql -h psql-ecare-dev.postgres.database.azure.net \
     -U psqladmin \
     -d postgres
```

#### From Application (Connection String)

```text
postgresql://psqladmin:PASSWORD@psql-ecare-dev.postgres.database.azure.net:5432/mydb?sslmode=require
```

#### Using Environment Variable

```bash
export DATABASE_URL="postgresql://psqladmin:${DB_PASSWORD}@psql-ecare-dev.postgres.database.azure.net:5432/postgres"
```

## Naming Convention

Resources follow this naming pattern:

- **PostgreSQL Server**: `psql-{project_name}-{environment}` (e.g., `psql-ecare-dev`)

## Security Features

- **Network Isolation**: Public network access disabled by default, VNet integration via delegated subnet
- **Encryption at Rest**: Automatic encryption for all data
- **TLS 1.2+**: Enforced minimum encryption level for connections
- **Password Authentication**: Secure password-based authentication (Managed Identity support coming in future)
- **Private Endpoints**: Optional Private Endpoint support for additional network isolation

## Examples

### Development Environment

```hcl
module "postgresql" {
  source = "../../modules/postgresql"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"

  postgresql_version = "15"
  sku_name           = "B_Standard_B1ms"  # Burstable for dev
  storage_mb         = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  high_availability_enabled    = false

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  private_endpoint_subnet_id = var.data_subnet_id
  vnet_id                    = var.vnet_id
  vnet_name                  = var.vnet_name
}
```

### Production Environment

```hcl
module "postgresql" {
  source = "../../modules/postgresql"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"

  postgresql_version = "15"
  sku_name           = "GP_Standard_D2s_v3"  # General Purpose for prod
  storage_mb         = 131072

  backup_retention_days        = 35  # Maximum retention
  geo_redundant_backup_enabled = true
  high_availability_enabled    = true
  high_availability_mode      = "ZoneRedundant"

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  private_endpoint_subnet_id = var.data_subnet_id
  vnet_id                    = var.vnet_id
  vnet_name                  = var.vnet_name
}
```

## Backup and Restore

- Automatic backups daily
- Point-in-time restore to any time within retention period
- Geo-redundant backups replicate to paired region
- Manual backups via `pg_dump`

## Integration with Other Modules

No specific integration with other modules.

## Prerequisites

From Phase 1 (infra-foundation):

- Data subnet for Private Endpoint
- Virtual Network ID and name for Private DNS Zone link

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
