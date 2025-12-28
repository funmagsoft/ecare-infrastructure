variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
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
}

variable "storage_replication_type" {
  description = "Storage Account replication type"
  type        = string
  default     = "LRS"
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
}

#------------------------------------------------------------------------------
# Key Vault Variables
#------------------------------------------------------------------------------

variable "key_vault_sku" {
  description = "SKU for Key Vault"
  type        = string
  default     = "standard"
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
}

#------------------------------------------------------------------------------
# ACR Variables
#------------------------------------------------------------------------------

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Premium"
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
  description = "Kubernetes version for AKS"
  type        = string
  default     = null
}

variable "aks_sku_tier" {
  description = "SKU tier for AKS"
  type        = string
  default     = "Standard"
}

variable "aks_network_plugin" {
  description = "Network plugin for AKS"
  type        = string
  default     = "azure"
}

variable "aks_network_policy" {
  description = "Network policy for AKS"
  type        = string
  default     = "azure"
}

variable "aks_service_cidr" {
  description = "Service CIDR for AKS"
  type        = string
  default     = "10.2.0.0/16"
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
}

variable "aks_user_node_pool_max_count" {
  description = "Maximum node count for AKS user node pool"
  type        = number
  default     = 3
}

variable "aks_user_node_pool_os_disk_size_gb" {
  description = "OS disk size for AKS user nodes"
  type        = number
  default     = 128
}

variable "aks_enable_auto_scaling" {
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
}

variable "bastion_additional_users" {
  description = "Map of additional users to create on bastion. Key is username, value is list of SSH public keys. Users will have sudo access."
  type        = map(list(string))
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags to merge with required tags. Required tags cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.additional_tags) : !contains(["Environment", "Project", "ManagedBy", "Phase", "GitRepository", "TerraformPath"], key)
    ])
    error_message = "Additional tags cannot override required tags: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath."
  }
}
