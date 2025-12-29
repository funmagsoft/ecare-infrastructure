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
}

variable "postgresql_version" {
  description = "PostgreSQL version (11, 12, 13, 14, 15, 16)"
  type        = string
  default     = "15"
}

variable "sku_name" {
  description = "SKU name for PostgreSQL Flexible Server (e.g., B_Standard_B1ms, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB (32768-16777216)"
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention in days (7-35)"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup"
  type        = bool
  default     = false
}

variable "high_availability_enabled" {
  description = "Enable high availability (zone redundant)"
  type        = bool
  default     = false
}

variable "high_availability_mode" {
  description = "High availability mode (ZoneRedundant or SameZone)"
  type        = string
  default     = "ZoneRedundant"
}

variable "administrator_login" {
  description = "Administrator login name"
  type        = string
  default     = "psqladmin"
}

variable "administrator_password" {
  description = "Administrator password (minimum 8 characters)"
  type        = string
  sensitive   = true
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

# Private Endpoint configuration (recommended approach)
variable "private_endpoint_subnet_id" {
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
