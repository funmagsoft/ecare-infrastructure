variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "phase" {
  description = "Fixed phase identifier for infra-platform"
  type        = string
  default     = "platform"

  validation {
    condition     = var.phase == "platform"
    error_message = "phase must be \"platform\" for infra-platform."
  }
}

variable "deployment_id" {
  description = "Unique deployment identifier (8 lowercase alphanumeric characters). Use the same ID across all phases (foundation/identity/platform) for easy cleanup."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.deployment_id))
    error_message = "deployment_id must be exactly 8 lowercase alphanumeric characters (e.g., 'a1b2c3d4')."
  }
}

variable "subscription_id" {
  description = "Azure subscription ID. If not provided, Terraform will use ARM_SUBSCRIPTION_ID environment variable or Azure CLI authenticated subscription."
  type        = string
  default     = null
  nullable    = true
}

variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "hycom"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"

  validation {
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less to ensure resource names stay within Azure limits."
  }
}

#------------------------------------------------------------------------------
# Monitoring Variables
#------------------------------------------------------------------------------

variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730 days."
  }
}

variable "application_insights_type" {
  description = "Application type for Application Insights"
  type        = string
  default     = "web"
}

#------------------------------------------------------------------------------
# Storage Variables
#------------------------------------------------------------------------------

variable "storage_account_tier" {
  description = "Storage Account tier"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "storage_account_tier must be either Standard or Premium."
  }
}

variable "storage_replication_type" {
  description = "Storage Account replication type"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "storage_containers" {
  description = "List of container names to create"
  type        = list(string)
  default     = ["app-data", "logs", "backups"]
}

variable "storage_enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = true
}

variable "storage_enable_soft_delete_blob" {
  description = "Enable soft delete for blobs"
  type        = bool
  default     = true
}

variable "storage_blob_soft_delete_retention_days" {
  description = "Retention days for blob soft delete"
  type        = number
  default     = 7

  validation {
    condition     = var.storage_blob_soft_delete_retention_days >= 1 && var.storage_blob_soft_delete_retention_days <= 365
    error_message = "storage_blob_soft_delete_retention_days must be between 1 and 365 days."
  }
}

variable "storage_enable_soft_delete_container" {
  description = "Enable soft delete for containers"
  type        = bool
  default     = true
}

variable "storage_container_soft_delete_retention_days" {
  description = "Retention days for container soft delete"
  type        = number
  default     = 7

  validation {
    condition     = var.storage_container_soft_delete_retention_days >= 1 && var.storage_container_soft_delete_retention_days <= 365
    error_message = "storage_container_soft_delete_retention_days must be between 1 and 365 days."
  }
}

variable "storage_cross_tenant_replication_enabled" {
  description = "Enable cross-tenant replication for storage account"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Key Vault Variables
#------------------------------------------------------------------------------

variable "key_vault_sku" {
  description = "SKU for Key Vault"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "key_vault_sku must be either standard or premium."
  }
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 7

  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "key_vault_soft_delete_retention_days must be between 7 and 90 days."
  }
}

#------------------------------------------------------------------------------
# ACR Variables
#------------------------------------------------------------------------------

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}

variable "acr_zone_redundancy_enabled" {
  description = "Enable zone redundancy for ACR"
  type        = bool
  default     = false
}

variable "acr_retention_days" {
  description = "Retention days for untagged manifests"
  type        = number
  default     = 7

  validation {
    condition     = var.acr_retention_days >= 0 && var.acr_retention_days <= 365
    error_message = "acr_retention_days must be between 0 and 365 days."
  }
}

#------------------------------------------------------------------------------
# PostgreSQL Variables
#------------------------------------------------------------------------------

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "postgresql_sku_name" {
  description = "SKU name for PostgreSQL"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention days for PostgreSQL"
  type        = number
  default     = 7

  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "postgresql_backup_retention_days must be between 7 and 35 days."
  }
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup for PostgreSQL"
  type        = bool
  default     = false
}

variable "postgresql_high_availability_enabled" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

variable "postgresql_high_availability_mode" {
  description = "High availability mode for PostgreSQL"
  type        = string
  default     = "ZoneRedundant"
}

variable "postgresql_admin_username" {
  description = "Admin username for PostgreSQL"
  type        = string
  default     = "psqladmin"
}

variable "postgresql_admin_password" {
  description = "Admin password for PostgreSQL"
  type        = string
  sensitive   = true
}

#------------------------------------------------------------------------------
# Service Bus Variables
#------------------------------------------------------------------------------

variable "service_bus_sku" {
  description = "SKU for Service Bus"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.service_bus_sku)
    error_message = "service_bus_sku must be one of: Basic, Standard, Premium."
  }
}

variable "service_bus_capacity" {
  description = "Messaging units for Service Bus (Premium only)"
  type        = number
  default     = 1
}

variable "service_bus_zone_redundant" {
  description = "Enable zone redundancy for Service Bus"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# AKS Variables
#------------------------------------------------------------------------------

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS (null = use latest supported)"
  type        = string
  default     = null
  nullable    = true
}

variable "aks_sku_tier" {
  description = "SKU tier for AKS"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "aks_network_plugin" {
  description = "Network plugin for AKS"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet", "none"], var.aks_network_plugin)
    error_message = "aks_network_plugin must be one of: azure, kubenet, none."
  }
}

variable "aks_network_policy" {
  description = "Network policy for AKS"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico", "cilium"], var.aks_network_policy)
    error_message = "aks_network_policy must be one of: azure, calico, cilium."
  }
}

variable "aks_service_cidr" {
  description = "Service CIDR for AKS"
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.aks_service_cidr, 0))
    error_message = "aks_service_cidr must be a valid CIDR notation (e.g., 10.2.0.0/16)."
  }
}

variable "aks_dns_service_ip" {
  description = "DNS service IP for AKS"
  type        = string
  default     = "10.2.0.10"
}

variable "aks_system_node_pool_vm_size" {
  description = "VM size for AKS system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_system_node_pool_node_count" {
  description = "Node count for AKS system node pool"
  type        = number
  default     = 3
}

variable "aks_system_node_pool_os_disk_size_gb" {
  description = "OS disk size for AKS system nodes"
  type        = number
  default     = 128
}

variable "aks_user_node_pool_enabled" {
  description = "Enable user node pool for AKS"
  type        = bool
  default     = true
}

variable "aks_user_node_pool_vm_size" {
  description = "VM size for AKS user node pool"
  type        = string
  default     = "Standard_A2_v2"
}

variable "aks_user_node_pool_min_count" {
  description = "Minimum node count for AKS user node pool"
  type        = number
  default     = 1
  validation {
    condition     = var.aks_user_node_pool_min_count >= 1
    error_message = "aks_user_node_pool_min_count must be >= 1."
  }
}

variable "aks_user_node_pool_max_count" {
  description = "Maximum node count for AKS user node pool"
  type        = number
  default     = 3
  validation {
    condition     = var.aks_user_node_pool_max_count >= var.aks_user_node_pool_min_count
    error_message = "aks_user_node_pool_max_count must be >= aks_user_node_pool_min_count."
  }
}

variable "aks_user_node_pool_os_disk_size_gb" {
  description = "OS disk size for AKS user nodes"
  type        = number
  default     = 128
}

variable "aks_user_node_pool_node_count" {
  description = "Fixed node count for AKS user node pool when autoscaling is disabled"
  type        = number
  default     = 1
  validation {
    condition     = var.aks_user_node_pool_node_count >= 1
    error_message = "aks_user_node_pool_node_count must be >= 1."
  }
}

variable "aks_auto_scaling_enabled" {
  description = "Enable auto-scaling for AKS user node pool"
  type        = bool
  default     = true
}

variable "aks_oidc_issuer_enabled" {
  description = "Enable OIDC issuer for AKS (required for Workload Identity)"
  type        = bool
  default     = true
}

variable "aks_workload_identity_enabled" {
  description = "Enable Workload Identity for AKS"
  type        = bool
  default     = true
}

variable "aks_azure_policy_enabled" {
  description = "Enable Azure Policy add-on for AKS"
  type        = bool
  default     = true
}

variable "aks_enable_container_insights" {
  description = "Enable Container Insights for AKS"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Bastion Variables
#------------------------------------------------------------------------------

variable "bastion_vm_size" {
  description = "VM size for Bastion"
  type        = string
  default     = "Standard_B1s"
}

variable "bastion_admin_username" {
  description = "Admin username for Bastion VM"
  type        = string
  default     = "azureuser"
}

variable "bastion_ubuntu_sku" {
  description = "Ubuntu SKU for Bastion VM"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "bastion_allowed_ssh_source_ips" {
  description = "Allowed source IPs for SSH to Bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for ip in var.bastion_allowed_ssh_source_ips :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?$", ip))
    ])
    error_message = "bastion_allowed_ssh_source_ips must contain valid IP addresses or CIDR blocks (e.g., 192.168.1.1 or 192.168.1.0/24)."
  }
}

variable "bastion_additional_users" {
  description = "Map of additional users to create on bastion. Key is username, value is list of SSH public keys. Users will have sudo access."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Additional tags to merge with required tags (Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath, DeploymentId). Required tags take precedence and cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.tags) : !contains(["Environment", "Project", "ManagedBy", "Phase", "GitRepository", "TerraformPath", "DeploymentId"], key)
    ])
    error_message = "Additional tags cannot override required tags: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath, DeploymentId."
  }
}
