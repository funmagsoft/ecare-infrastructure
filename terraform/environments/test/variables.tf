variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"
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

variable "organization" {
  description = "GitHub organization name"
  type        = string
  default     = "hycom"
}

variable "organization_for_sa" {
  description = "Organization name for Storage Account naming (may differ from organization due to Azure naming constraints)"
  type        = string
  default     = "hycom"
}

variable "enable_bootstrap" {
  description = <<-EOT
    Enable bootstrap module (SP, FIC, RBAC for Terraform repos).

    Set to false if:
    - Bootstrap was already created manually (using scripts)
    - Bootstrap was already created in a previous Terraform run
    - You want to manage bootstrap separately

    Set to true if:
    - This is the first deployment
    - You want Terraform to manage bootstrap resources
  EOT
  type        = bool
  default     = true
}

variable "terraform_repos" {
  description = <<-EOT
    List of Terraform repository names (without organization prefix).
    Full repository names will be constructed as: organization/repo-name

    Default repositories:
    - infra-foundation
    - infra-platform
    - infra-identity
  EOT
  type        = list(string)
  default     = ["infra-foundation", "infra-platform", "infra-identity"]
}

variable "users_with_state_access" {
  description = <<-EOT
    List of Azure AD user Object IDs who should have Storage Blob Data Contributor
    role on the Terraform state Storage Account. This allows them to view and browse
    state files in Azure Portal.

    To get a user's Object ID:
      az ad user show --id <user-email> --query id --output tsv

    Example:
      users_with_state_access = [
        "12345678-1234-1234-1234-123456789012"
      ]
  EOT
  type        = list(string)
  default     = []
}
