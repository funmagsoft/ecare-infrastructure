variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the Public IP for VPN Gateway"
  type        = string
}

variable "gateway_subnet_id" {
  description = "Resource ID of the Gateway Subnet (must be named 'GatewaySubnet')"
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/.+$", var.gateway_subnet_id))
    error_message = "gateway_subnet_id must be a valid Azure subnet resource ID (format: /subscriptions/.../providers/Microsoft.Network/virtualNetworks/.../subnets/...)."
  }
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway. Must support P2S OpenVPN (VpnGw1-VpnGw5, with or without AZ suffix)"
  type        = string
  default     = "VpnGw1"

  validation {
    condition     = can(regex("^VpnGw[1-5]$", var.vpn_gateway_sku)) || can(regex("^VpnGw[1-5]AZ$", var.vpn_gateway_sku))
    error_message = "vpn_gateway_sku must be a supported VpnGw SKU that supports P2S OpenVPN (e.g., VpnGw1, VpnGw2, VpnGw1AZ, VpnGw2AZ, etc.)."
  }
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
}

variable "vpn_root_cert_data" {
  description = <<-EOT
    Root certificate data for VPN Point-to-Site authentication.

    Format: Base64-encoded X.509 public certificate data WITHOUT PEM headers.
    Do NOT include -----BEGIN CERTIFICATE----- or -----END CERTIFICATE----- lines.

    To convert a PEM certificate to the required format:
      1. Remove PEM headers/footers (-----BEGIN/END CERTIFICATE-----)
      2. Remove all newlines/whitespace
      3. The result should be a single line of base64 characters

    Example of correct format:
      MIIBkTCB+wIJAK... (base64 string without headers)
  EOT
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
