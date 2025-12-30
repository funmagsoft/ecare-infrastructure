variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "deployment_id" {
  description = "Unique deployment identifier (8 lowercase alphanumeric characters). Use the same ID across all phases (foundation/identity/platform) for easy cleanup."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.deployment_id))
    error_message = "deployment_id must be exactly 8 lowercase alphanumeric characters (e.g., 'a1b2c3d4')."
  }
}

variable "subscription_id" {
  description = "Azure subscription ID. Optional locally; recommended in CI/CD."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"

  validation {
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less to ensure resource names stay within Azure limits."
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

variable "organization_name" {
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
    Full repository names will be constructed as: organization_name/repo-name

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

  validation {
    condition = alltrue([
      for id in var.users_with_state_access :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "users_with_state_access must contain valid Azure AD Object IDs (GUIDs in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."
  }
}
