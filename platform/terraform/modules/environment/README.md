# Environment Module

Terraform module that encapsulates all common platform infrastructure configuration for an environment, eliminating code duplication across environments by providing a single source of truth for platform-specific infrastructure.

## Resources Created

- **AKS Cluster** - Azure Kubernetes Service with Workload Identity and OIDC
- **AKS Namespace** - Shared Kubernetes namespace `ecare` for workloads
- **Bastion VM** - Jump host VM with pre-installed management tools
- **Storage Account** - Azure Storage Account with Private Endpoint
- **PostgreSQL Flexible Server** - Managed PostgreSQL database with Private Endpoint
- **Key Vault** - Azure Key Vault with Private Endpoint
- **Azure Container Registry (ACR)** - Container registry with Private Endpoint
- **Service Bus** - Azure Service Bus namespace with Private Endpoint
- **Log Analytics Workspace** - Centralized logging
- **Application Insights** - Application performance monitoring
- **RBAC Role Assignments** - Role assignments for Bastion and AKS access

## Features

- Single source of truth for all platform infrastructure
- Eliminates ~95% of code duplication across environments
- Automatic propagation of changes to all environments
- Consistent infrastructure configuration across all environments
- Private Endpoints for all services (Storage, PostgreSQL, Key Vault, ACR, Service Bus)
- Workload Identity and OIDC support for AKS
- RBAC integration for secure access
- Tag validation to ensure required tags are present

## Usage

```hcl
module "environment" {
  source = "../../modules/environment"

  environment       = "dev"
  organization_name = "hycom"
  project_name      = "ecare"

  # Monitoring configuration
  log_analytics_sku            = var.log_analytics_sku
  log_analytics_retention_days = var.log_analytics_retention_days
  application_insights_type    = var.application_insights_type

  # Storage configuration
  storage_account_tier             = var.storage_account_tier
  storage_replication_type         = var.storage_replication_type
  storage_containers               = var.storage_containers
  storage_enable_versioning        = var.storage_enable_versioning

  # Key Vault configuration
  key_vault_sku                   = var.key_vault_sku
  key_vault_purge_protection_enabled = var.key_vault_purge_protection_enabled

  # ACR configuration
  acr_sku                     = var.acr_sku
  acr_zone_redundancy_enabled = var.acr_zone_redundancy_enabled

  # PostgreSQL configuration
  postgresql_version                = var.postgresql_version
  postgresql_sku_name               = var.postgresql_sku_name
  postgresql_storage_mb             = var.postgresql_storage_mb
  postgresql_admin_username         = var.postgresql_admin_username
  postgresql_admin_password         = var.postgresql_admin_password

  # Service Bus configuration
  service_bus_sku            = var.service_bus_sku
  service_bus_capacity       = var.service_bus_capacity
  service_bus_zone_redundant = var.service_bus_zone_redundant

  # AKS configuration
  aks_kubernetes_version           = var.aks_kubernetes_version
  aks_sku_tier                     = var.aks_sku_tier
  aks_network_plugin               = var.aks_network_plugin
  aks_system_node_pool_vm_size     = var.aks_system_node_pool_vm_size
  aks_system_node_pool_node_count  = var.aks_system_node_pool_node_count
  aks_user_node_pool_enabled       = var.aks_user_node_pool_enabled
  aks_user_node_pool_vm_size      = var.aks_user_node_pool_vm_size
  aks_oidc_issuer_enabled          = var.aks_oidc_issuer_enabled
  aks_workload_identity_enabled    = var.aks_workload_identity_enabled

  # Bastion configuration
  bastion_vm_size              = var.bastion_vm_size
  bastion_admin_username       = var.bastion_admin_username
  bastion_allowed_ssh_source_ips = var.bastion_allowed_ssh_source_ips
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| organization_name | Organization name for resource naming | `string` | `"hycom"` | no |
| project_name | Project name | `string` | `"ecare"` | no |
| log_analytics_sku | SKU for Log Analytics Workspace | `string` | `"PerGB2018"` | no |
| log_analytics_retention_days | Retention period in days for Log Analytics | `number` | `30` | no |
| application_insights_type | Application type for Application Insights | `string` | `"web"` | no |
| storage_account_tier | Storage Account tier | `string` | `"Standard"` | no |
| storage_replication_type | Storage Account replication type | `string` | `"LRS"` | no |
| storage_containers | List of container names to create | `list(string)` | `["app-data", "logs", "backups"]` | no |
| storage_enable_versioning | Enable blob versioning | `bool` | `true` | no |
| storage_enable_soft_delete_blob | Enable soft delete for blobs | `bool` | `true` | no |
| storage_blob_soft_delete_retention_days | Retention days for blob soft delete | `number` | `7` | no |
| storage_enable_soft_delete_container | Enable soft delete for containers | `bool` | `true` | no |
| storage_container_soft_delete_retention_days | Retention days for container soft delete | `number` | `7` | no |
| key_vault_sku | SKU for Key Vault | `string` | `"standard"` | no |
| key_vault_purge_protection_enabled | Enable purge protection for Key Vault | `bool` | `false` | no |
| key_vault_soft_delete_retention_days | Soft delete retention days for Key Vault | `number` | `7` | no |
| acr_sku | SKU for Azure Container Registry | `string` | `"Premium"` | no |
| acr_zone_redundancy_enabled | Enable zone redundancy for ACR | `bool` | `false` | no |
| acr_retention_days | Retention days for untagged manifests | `number` | `7` | no |
| postgresql_version | PostgreSQL version | `string` | `"15"` | no |
| postgresql_sku_name | SKU name for PostgreSQL | `string` | `"B_Standard_B1ms"` | no |
| postgresql_storage_mb | Storage size in MB for PostgreSQL | `number` | `32768` | no |
| postgresql_backup_retention_days | Backup retention days for PostgreSQL | `number` | `7` | no |
| postgresql_geo_redundant_backup_enabled | Enable geo-redundant backup for PostgreSQL | `bool` | `false` | no |
| postgresql_high_availability_enabled | Enable high availability for PostgreSQL | `bool` | `false` | no |
| postgresql_high_availability_mode | High availability mode for PostgreSQL | `string` | `"ZoneRedundant"` | no |
| postgresql_admin_username | Admin username for PostgreSQL | `string` | `"psqladmin"` | no |
| postgresql_admin_password | Admin password for PostgreSQL | `string` | - | yes |
| service_bus_sku | SKU for Service Bus | `string` | `"Standard"` | no |
| service_bus_capacity | Messaging units for Service Bus (Premium only) | `number` | `1` | no |
| service_bus_zone_redundant | Enable zone redundancy for Service Bus | `bool` | `false` | no |
| aks_kubernetes_version | Kubernetes version for AKS | `string` | `null` | no |
| aks_sku_tier | SKU tier for AKS | `string` | `"Standard"` | no |
| aks_network_plugin | Network plugin for AKS | `string` | `"azure"` | no |
| aks_network_policy | Network policy for AKS | `string` | `"azure"` | no |
| aks_service_cidr | Service CIDR for AKS | `string` | `"10.2.0.0/16"` | no |
| aks_dns_service_ip | DNS service IP for AKS | `string` | `"10.2.0.10"` | no |
| aks_system_node_pool_vm_size | VM size for AKS system node pool | `string` | `"Standard_D2s_v3"` | no |
| aks_system_node_pool_node_count | Node count for AKS system node pool | `number` | `3` | no |
| aks_system_node_pool_os_disk_size_gb | OS disk size for AKS system nodes | `number` | `128` | no |
| aks_user_node_pool_enabled | Enable user node pool for AKS | `bool` | `true` | no |
| aks_user_node_pool_vm_size | VM size for AKS user node pool | `string` | `"Standard_A2_v2"` | no |
| aks_user_node_pool_min_count | Minimum node count for AKS user node pool | `number` | `1` | no |
| aks_user_node_pool_max_count | Maximum node count for AKS user node pool | `number` | `3` | no |
| aks_user_node_pool_os_disk_size_gb | OS disk size for AKS user nodes | `number` | `128` | no |
| aks_auto_scaling_enabled | Enable auto-scaling for AKS user node pool | `bool` | `true` | no |
| aks_oidc_issuer_enabled | Enable OIDC issuer for AKS (required for Workload Identity) | `bool` | `true` | no |
| aks_workload_identity_enabled | Enable Workload Identity for AKS | `bool` | `true` | no |
| aks_azure_policy_enabled | Enable Azure Policy add-on for AKS | `bool` | `true` | no |
| aks_enable_container_insights | Enable Container Insights for AKS | `bool` | `true` | no |
| bastion_vm_size | VM size for Bastion | `string` | `"Standard_B1s"` | no |
| bastion_admin_username | Admin username for Bastion VM | `string` | `"azureuser"` | no |
| bastion_ubuntu_sku | Ubuntu SKU for Bastion VM | `string` | `"22_04-lts-gen2"` | no |
| bastion_allowed_ssh_source_ips | Allowed source IPs for SSH to Bastion | `list(string)` | `["0.0.0.0/0"]` | no |
| bastion_additional_users | Map of additional users to create on bastion | `map(list(string))` | `{}` | no |
| tags | Additional tags to merge with required tags. Required tags cannot be overridden. | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| log_analytics_workspace_id | ID of the Log Analytics Workspace | no |
| log_analytics_workspace_name | Name of the Log Analytics Workspace | no |
| application_insights_id | ID of Application Insights | no |
| application_insights_name | Name of Application Insights | no |
| application_insights_instrumentation_key | Instrumentation Key for Application Insights | yes |
| application_insights_connection_string | Connection String for Application Insights | yes |
| storage_account_id | ID of the Storage Account | no |
| storage_account_name | Name of the Storage Account | no |
| storage_account_primary_blob_endpoint | Primary blob endpoint of the Storage Account | no |
| key_vault_id | ID of the Key Vault | no |
| key_vault_name | Name of the Key Vault | no |
| key_vault_uri | URI of the Key Vault | no |
| acr_id | ID of the Azure Container Registry | no |
| acr_name | Name of the Azure Container Registry | no |
| acr_login_server | Login server of the Azure Container Registry | no |
| postgresql_server_id | ID of the PostgreSQL server | no |
| postgresql_server_name | Name of the PostgreSQL server | no |
| postgresql_fqdn | FQDN of the PostgreSQL server | no |
| postgresql_administrator_login | Administrator login for PostgreSQL | no |
| servicebus_namespace_id | ID of the Service Bus Namespace | no |
| servicebus_namespace_name | Name of the Service Bus Namespace | no |
| servicebus_endpoint | Endpoint of the Service Bus Namespace | no |
| aks_cluster_id | ID of the AKS cluster | no |
| aks_cluster_name | Name of the AKS cluster | no |
| aks_fqdn | FQDN of the AKS cluster | no |
| aks_kubelet_identity_object_id | Object ID of the AKS kubelet identity | no |
| aks_kubelet_identity_client_id | Client ID of the AKS kubelet identity | no |
| aks_oidc_issuer_url | OIDC Issuer URL for AKS (for Workload Identity in Phase 3) | no |
| aks_kube_config | Kubeconfig for AKS cluster (for Kubernetes provider) | yes |
| aks_namespace_name | Name of the shared AKS namespace for workloads | no |
| aks_node_resource_group | Resource group containing AKS node resources | no |
| bastion_vm_id | ID of the Bastion VM | no |
| bastion_vm_name | Name of the Bastion VM | no |
| bastion_public_ip | Public IP address of the Bastion VM | no |
| bastion_private_ip | Private IP address of the Bastion VM | no |
| bastion_admin_username | Admin username for Bastion VM | no |
| bastion_ssh_private_key | SSH private key for Bastion VM (if generated) | yes |
| bastion_principal_id | Principal ID of the Bastion VM system-assigned identity | no |
| deployment_summary | Summary of deployed platform resources | no |

## Module-Specific Configuration

### Private Endpoints

All services (Storage, PostgreSQL, Key Vault, ACR, Service Bus) are configured with Private Endpoints in the `data_subnet_id` from the foundation infrastructure. This ensures network isolation and secure access.

### RBAC Role Assignments

The module automatically creates RBAC role assignments:

- **Bastion → AKS**: Grants Bastion VM "Azure Kubernetes Service Cluster User Role" for AKS access
- **Bastion → ACR**: Grants Bastion VM "AcrPull" role for container registry access
- **AKS → ACR**: Grants AKS kubelet identity "AcrPull" role for pulling container images

### Tags Validation

The module enforces tag validation to ensure all required tags are present:

**Required Tags** (automatically set, cannot be overridden):

- `Environment` - Environment name (dev, test, stage, prod)
- `Project` - Project name
- `ManagedBy` - Always set to "Terraform"
- `Phase` - Always set to "Platform"
- `GitRepository` - Always set to "ecare-infrastructure"
- `TerraformPath` - Path to Terraform configuration (e.g., "platform/terraform/environments/dev")
- `DeploymentId` - Deployment identifier for this environment

**Additional Tags**:

- Use `tags` variable to add custom tags
- Required tags cannot be overridden via `tags`
- Validation ensures all required tags are present and non-empty

**Validation**:

- The module uses Terraform `check` blocks to validate that all required tags are present
- If any required tag is missing or empty, Terraform will fail with a clear error message
- The `tags` variable has validation to prevent overriding required tags

### AKS Configuration

The module creates an AKS cluster with:

- **System Node Pool**: Fixed node count for system pods
- **User Node Pool**: Optional user node pool with auto-scaling support
- **Workload Identity**: Enabled for secure pod-to-Azure authentication
- **OIDC Issuer**: Enabled for Workload Identity integration
- **Container Insights**: Integrated with Log Analytics Workspace
- **Azure Policy**: Optional policy enforcement

### Kubernetes Provider

The Kubernetes provider must be configured in the root module (environment directory) after the AKS cluster is created. The module outputs `aks_kube_config` which can be used to configure the provider:

```hcl
locals {
  aks_kube_config = yamldecode(module.environment.aks_kube_config)
}

provider "kubernetes" {
  host                   = local.aks_kube_config["clusters"][0]["cluster"]["server"]
  client_certificate     = base64decode(local.aks_kube_config["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(local.aks_kube_config["users"][0]["user"]["client-key-data"])
  cluster_ca_certificate = base64decode(local.aks_kube_config["clusters"][0]["cluster"]["certificate-authority-data"])
}
```

## Naming Convention

Resources follow this naming pattern:

- **AKS Cluster**: `aks-{project_name}-{environment}` (e.g., `aks-ecare-dev`)
- **Key Vault**: `kv-{project_name}-{environment}` (e.g., `kv-ecare-dev`)
- **PostgreSQL**: `psql-{project_name}-{environment}` (e.g., `psql-ecare-dev`)
- **Service Bus**: `sb-{project_name}-{environment}` (e.g., `sb-ecare-dev`)
- **Storage Account**: `st{org}{project}{env}{hash}` (e.g., `sthycomecaredev1a2b`)
- **ACR**: `acr{project}{env}` (e.g., `acrecaredev`)
- **Bastion VM**: `vm-bastion-{project_name}-{environment}` (e.g., `vm-bastion-ecare-dev`)

**Note**: Storage Account and ACR names must be lowercase alphanumeric (no hyphens) due to Azure naming constraints.

## Security Features

- **Network Isolation**: All services use Private Endpoints in the data subnet
- **RBAC Integration**: Automatic role assignments for secure access
- **Workload Identity**: Secure pod-to-Azure authentication without secrets
- **OIDC Issuer**: Standards-based authentication for Kubernetes workloads
- **Tag Validation**: Ensures all resources are properly tagged
- **Private Endpoints**: All data services are accessible only from within the VNet
- **NSG Rules**: Network security groups from foundation infrastructure control access

## Examples

### Development Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment       = "dev"
  organization_name = "hycom"
  project_name      = "ecare"

  # Dev-specific configuration
  aks_system_node_pool_node_count = 1  # Lower cost for dev
  aks_user_node_pool_min_count    = 1
  aks_user_node_pool_max_count    = 2
  bastion_vm_size                 = "Standard_B1s"  # Lower cost for dev
  postgresql_sku_name             = "B_Standard_B1ms"  # Burstable for dev
  postgresql_admin_password       = var.postgresql_admin_password
}
```

### Production Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment       = "prod"
  organization_name = "hycom"
  project_name      = "ecare"

  # Prod-specific configuration
  aks_system_node_pool_node_count = 3  # Higher availability
  aks_user_node_pool_min_count    = 3
  aks_user_node_pool_max_count    = 10
  bastion_vm_size                 = "Standard_D2s_v3"  # More resources for prod
  postgresql_sku_name             = "GP_Standard_D2s_v3"  # General Purpose for prod
  postgresql_high_availability_enabled = true
  postgresql_geo_redundant_backup_enabled = true
  key_vault_purge_protection_enabled = true  # Enable for prod
  postgresql_admin_password       = var.postgresql_admin_password
}
```

## Integration with Other Modules

This module integrates with the following modules:

### Monitoring Module

The environment module calls the `monitoring` module to create Log Analytics Workspace and Application Insights:

```hcl
module "monitoring" {
  source = "../monitoring"
  # ... monitoring configuration
}
```

### AKS Module

The environment module calls the `aks` module to create the Kubernetes cluster:

```hcl
module "aks" {
  source = "../aks"
  # ... AKS configuration
}
```

### Storage Module

The environment module calls the `storage` module to create the Storage Account with Private Endpoint:

```hcl
module "storage" {
  source = "../storage"
  # ... storage configuration
}
```

### PostgreSQL Module

The environment module calls the `postgresql` module to create the database with Private Endpoint:

```hcl
module "postgresql" {
  source = "../postgresql"
  # ... PostgreSQL configuration
}
```

### Key Vault Module

The environment module calls the `key-vault` module to create Key Vault with Private Endpoint:

```hcl
module "key_vault" {
  source = "../key-vault"
  # ... Key Vault configuration
}
```

### ACR Module

The environment module calls the `acr` module to create the Container Registry with Private Endpoint:

```hcl
module "acr" {
  source = "../acr"
  # ... ACR configuration
}
```

### Service Bus Module

The environment module calls the `service-bus` module to create the Service Bus namespace with Private Endpoint:

```hcl
module "service_bus" {
  source = "../service-bus"
  # ... Service Bus configuration
}
```

### Bastion Module

The environment module calls the `bastion` module to create the Bastion VM:

```hcl
module "bastion" {
  source = "../bastion"
  # ... Bastion configuration
}
```

### AKS Namespace Module

The environment module calls the `aks-namespace` module to create the shared Kubernetes namespace:

```hcl
module "aks_namespace" {
  source = "../aks-namespace"
  # ... Namespace configuration
}
```

## Prerequisites

From Phase 0 (initial setup):

- Resource Group must exist (created in Phase 0)
- Resource Group naming: `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`)

From Phase 1 (foundation):

- Virtual Network must exist
- AKS subnet must exist
- Data subnet must exist (for Private Endpoints)
- Management subnet must exist (for Bastion VM)
- Network Security Groups must be configured

**Note**: This module replaces the previously duplicated configuration files (`compute.tf`, `storage.tf`, `database.tf`, `security.tf`, `container-registry.tf`, `messaging.tf`, `monitoring.tf`, `data.tf`, `locals.tf`, `outputs.tf`) that were duplicated across all environment directories. The Resource Group name is automatically constructed as `rg-${var.project_name}-${var.environment}`.

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
- Kubernetes Provider ~> 2.0
