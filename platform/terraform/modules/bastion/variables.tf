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

variable "subnet_id" {
  description = "Subnet ID for Bastion VM"
  type        = string
}

variable "vm_size" {
  description = "VM size for Bastion"
  type        = string
  default     = "Standard_D2als_v6"
}

variable "admin_username" {
  description = "Admin username for Bastion VM"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for Bastion VM admin user"
  type        = string
  default     = null
  nullable    = true
}

variable "disable_password_authentication" {
  description = "Disable password authentication (use SSH keys only)"
  type        = bool
  default     = true
}

variable "ubuntu_sku" {
  description = "Ubuntu SKU for Jammy (22.04)"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for OS disk"
  type        = string
  default     = "Standard_LRS"
}

variable "allowed_ssh_source_ips" {
  description = "List of source IPs allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_system_assigned_identity" {
  description = "Enable system-assigned managed identity"
  type        = bool
  default     = true
}

variable "install_tools" {
  description = "Install common tools (az, kubectl, psql, helm)"
  type        = bool
  default     = true
}

variable "additional_users" {
  description = "Map of additional users to create on bastion. Key is username, value is list of SSH public keys."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
