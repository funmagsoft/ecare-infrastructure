variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network"
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr must be a valid CIDR notation (e.g., 10.1.0.0/16)."
  }
}

variable "aks_subnet_name" {
  description = "Name of the AKS subnet"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.aks_subnet_cidr, 0))
    error_message = "aks_subnet_cidr must be a valid CIDR notation (e.g., 10.1.1.0/24)."
  }
}

variable "data_subnet_name" {
  description = "Name of the Data subnet"
  type        = string
}

variable "data_subnet_cidr" {
  description = "CIDR block for Data subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.data_subnet_cidr, 0))
    error_message = "data_subnet_cidr must be a valid CIDR notation (e.g., 10.1.2.0/24)."
  }
}

variable "mgmt_subnet_name" {
  description = "Name of the Management subnet"
  type        = string
}

variable "mgmt_subnet_cidr" {
  description = "CIDR block for Management subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.mgmt_subnet_cidr, 0))
    error_message = "mgmt_subnet_cidr must be a valid CIDR notation (e.g., 10.1.3.0/24)."
  }
}

variable "gateway_subnet_cidr" {
  description = "CIDR block for Gateway subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.gateway_subnet_cidr, 0))
    error_message = "gateway_subnet_cidr must be a valid CIDR notation (e.g., 10.1.4.0/24)."
  }
}

variable "aks_nsg_name" {
  description = "Name of the NSG for AKS subnet"
  type        = string
}

variable "data_nsg_name" {
  description = "Name of the NSG for Data subnet"
  type        = string
}

variable "mgmt_nsg_name" {
  description = "Name of the NSG for Management subnet"
  type        = string
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway subnet"
  type        = bool
  default     = false
}

variable "mgmt_subnet_allowed_ssh_ips" {
  description = "List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet. If empty, SSH from internet is blocked."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
