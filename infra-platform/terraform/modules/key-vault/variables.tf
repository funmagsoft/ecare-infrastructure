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

variable "sku_name" {
  description = "SKU name for Key Vault (standard or premium)"
  type        = string
  default     = "standard"
}

variable "enabled_for_deployment" {
  description = "Enable Azure Virtual Machines to retrieve certificates"
  type        = bool
  default     = false
}

variable "enabled_for_disk_encryption" {
  description = "Enable Azure Disk Encryption to retrieve secrets"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "Enable Azure Resource Manager to retrieve secrets"
  type        = bool
  default     = true
}

variable "rbac_authorization_enabled" {
  description = "Use RBAC for authorization instead of access policies"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Retention days for soft delete (7-90)"
  type        = number
  default     = 90
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (cannot be disabled once enabled)"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = true
}

# Private Endpoint configuration
variable "subnet_id" {
  description = "Subnet ID for Private Endpoint"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID for Private DNS Zone link"
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_name" {
  description = "Virtual Network name for Private DNS Zone link"
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
