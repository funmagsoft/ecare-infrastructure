variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string
}

variable "data_subnet_cidr" {
  description = "CIDR block for Data subnet"
  type        = string
}

variable "mgmt_subnet_cidr" {
  description = "CIDR block for Management subnet"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "CIDR block for Gateway subnet"
  type        = string
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
  description = "Address space for VPN clients"
  type        = string
  default     = "192.168.255.0/24"
}

variable "vpn_root_cert_name" {
  description = "Name of the root certificate for VPN"
  type        = string
  default     = "VPN-Root-Cert"
}

variable "vpn_root_cert_data" {
  description = "Root certificate data (base64)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "mgmt_subnet_allowed_ssh_ips" {
  description = "List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet"
  type        = list(string)
  default     = []
}
