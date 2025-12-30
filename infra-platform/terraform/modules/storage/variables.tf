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

variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "hycom"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ecare"
}

variable "account_tier" {
  description = "Storage Account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage Account replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "enable_https_traffic_only" {
  description = "Enable HTTPS traffic only"
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "TLS1_2"
}

variable "containers" {
  description = "List of container names to create"
  type        = list(string)
  default     = ["app-data", "logs", "backups"]
}

variable "enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = true
}

variable "enable_soft_delete_blob" {
  description = "Enable soft delete for blobs"
  type        = bool
  default     = true
}

variable "blob_soft_delete_retention_days" {
  description = "Retention days for blob soft delete"
  type        = number
  default     = 7
}

variable "enable_soft_delete_container" {
  description = "Enable soft delete for containers"
  type        = bool
  default     = true
}

variable "container_soft_delete_retention_days" {
  description = "Retention days for container soft delete"
  type        = number
  default     = 7
}

# Private Endpoint configuration
variable "subnet_id" {
  description = "Subnet ID for Private Endpoints"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID for Private DNS Zone links"
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_name" {
  description = "Virtual Network name for Private DNS Zone links"
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
