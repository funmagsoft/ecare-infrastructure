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

variable "sku" {
  description = "SKU for Service Bus (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "capacity" {
  description = "Messaging units for Premium SKU (1, 2, 4, 8, 16)"
  type        = number
  default     = 1
}

variable "zone_redundant" {
  description = "Enable zone redundancy (Premium SKU only)"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "[DEPRECATED] This variable is ignored. Public network access is automatically set based on SKU: Premium = false (private endpoint only), non-Premium = true (public endpoint only)"
  type        = bool
  default     = false
}

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

# Private Endpoint configuration
variable "subnet_id" {
  description = "Subnet ID for Private Endpoint"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID for Private DNS Zone link (required for Premium SKU)"
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_name" {
  description = "Virtual Network name for Private DNS Zone link (required for Premium SKU)"
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
