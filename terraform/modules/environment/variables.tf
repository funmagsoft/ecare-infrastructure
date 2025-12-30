variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "project_name may contain only letters, numbers, and hyphens."
  }
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr must be a valid CIDR notation (e.g., 10.1.0.0/16)."
  }
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.aks_subnet_cidr, 0))
    error_message = "aks_subnet_cidr must be a valid CIDR notation (e.g., 10.1.1.0/24)."
  }
}

variable "data_subnet_cidr" {
  description = "CIDR block for Data subnet"
  type        = string

  validation {
    condition     = can(cidrhost(var.data_subnet_cidr, 0))
    error_message = "data_subnet_cidr must be a valid CIDR notation (e.g., 10.1.2.0/24)."
  }
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

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway deployment"
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_client_address_space" {
  description = "Address space for VPN clients (CIDR notation)"
  type        = string
  default     = "192.168.255.0/24"

  validation {
    condition     = can(cidrhost(var.vpn_client_address_space, 0))
    error_message = "vpn_client_address_space must be a valid CIDR notation (e.g., 192.168.255.0/24)."
  }
}

variable "vpn_root_cert_name" {
  description = "Name of the root certificate for VPN"
  type        = string
  default     = "VPN-Root-Cert"

  validation {
    condition     = !var.enable_vpn_gateway || trimspace(var.vpn_root_cert_name) != ""
    error_message = "vpn_root_cert_name must be provided (non-empty) when enable_vpn_gateway = true."
  }
}

variable "vpn_root_cert_data" {
  description = "Root certificate data (base64)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_vpn_gateway || trimspace(var.vpn_root_cert_data) != ""
    error_message = "vpn_root_cert_data must be provided (non-empty) when enable_vpn_gateway = true."
  }
}

variable "mgmt_subnet_allowed_ssh_ips" {
  description = "List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.mgmt_subnet_allowed_ssh_ips :
      can(cidrhost(ip, 0)) || can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", ip))
    ])
    error_message = "mgmt_subnet_allowed_ssh_ips must contain valid IP addresses or CIDR blocks."
  }
}

variable "tags" {
  description = "Additional tags to merge with required tags (Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath). Required tags take precedence and cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.tags) : !contains(["Environment", "Project", "ManagedBy", "Phase", "GitRepository", "TerraformPath"], key)
    ])
    error_message = "Additional tags cannot override required tags: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath."
  }
}
