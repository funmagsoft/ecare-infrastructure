variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ecare"

  validation {
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less to ensure resource names stay within Azure limits."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version (null = use latest supported)"
  type        = string
  default     = null
  nullable    = true
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster (null = auto-generate)"
  type        = string
  default     = null
  nullable    = true
}

variable "sku_tier" {
  description = "SKU tier (Free, Standard, Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

# Network configuration
variable "vnet_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "network_plugin" {
  description = "Network plugin (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy (azure or calico)"
  type        = string
  default     = "azure"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.2.0.10"
}

# System node pool
variable "system_node_pool_name" {
  description = "Name of the system node pool"
  type        = string
  default     = "system"
}

variable "system_node_pool_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_pool_node_count" {
  description = "Number of nodes in system pool"
  type        = number
  default     = 3
}

variable "system_node_pool_os_disk_size_gb" {
  description = "OS disk size for system nodes"
  type        = number
  default     = 128
}

# User node pool
variable "user_node_pool_enabled" {
  description = "Enable user node pool"
  type        = bool
  default     = true
}

variable "user_node_pool_name" {
  description = "Name of the user node pool"
  type        = string
  default     = "user"
}

variable "user_node_pool_vm_size" {
  description = "VM size for user node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_pool_min_count" {
  description = "Minimum number of nodes in user pool"
  type        = number
  default     = 1
  validation {
    condition     = var.user_node_pool_min_count >= 1
    error_message = "user_node_pool_min_count must be >= 1."
  }
}

variable "user_node_pool_max_count" {
  description = "Maximum number of nodes in user pool"
  type        = number
  default     = 3
  validation {
    condition     = var.user_node_pool_max_count >= var.user_node_pool_min_count
    error_message = "user_node_pool_max_count must be >= user_node_pool_min_count."
  }
}

variable "user_node_pool_os_disk_size_gb" {
  description = "OS disk size for user nodes"
  type        = number
  default     = 128
}

variable "user_node_pool_node_count" {
  description = "Fixed node count for AKS user node pool when autoscaling is disabled"
  type        = number
  default     = 1
  validation {
    condition     = var.user_node_pool_node_count >= 1
    error_message = "user_node_pool_node_count must be >= 1."
  }
}

# Identity
variable "identity_type" {
  description = "Identity type (SystemAssigned or UserAssigned)"
  type        = string
  default     = "SystemAssigned"
}

# Features
variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer (required for Workload Identity)"
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity"
  type        = bool
  default     = true
}

variable "azure_policy_enabled" {
  description = "Enable Azure Policy add-on"
  type        = bool
  default     = true
}

variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for user node pool"
  type        = bool
  default     = true
}

# Monitoring
variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring"
  type        = string
  default     = null
  nullable    = true
}

variable "enable_container_insights" {
  description = "Enable Azure Monitor Container Insights"
  type        = bool
  default     = true
}

# Note: ACR integration via role assignment is now handled in environment main.tf
# to avoid dependency issues with dynamic module outputs

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "aks_admin_group_object_ids" {
  description = "Object IDs of Azure AD groups to be added as cluster admins"
  type        = list(string)
  default     = []
}
