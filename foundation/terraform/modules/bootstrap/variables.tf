variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "phase" {
  description = "Phase identifier for resource naming and tags"
  type        = string

  validation {
    condition     = contains(["foundation", "platform", "workload"], var.phase)
    error_message = "phase must be one of: foundation, platform, workload."
  }
}

variable "deployment_id" {
  description = "Unique deployment identifier (8 lowercase alphanumeric characters)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.deployment_id))
    error_message = "deployment_id must be exactly 8 lowercase alphanumeric characters."
  }
}

variable "organization_name" {
  description = "GitHub organization name"
  type        = string
}

variable "organization_for_sa" {
  description = "Organization name for Storage Account naming (may differ from organization due to Azure naming constraints)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.organization_for_sa))
    error_message = "organization_for_sa must contain only lowercase letters and digits (storage account naming constraint: 3-24 chars, lowercase alphanumeric only)."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters and digits (used in storage account naming)."
  }

  validation {
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less to ensure resource names stay within Azure limits."
  }
}

variable "terraform_repos" {
  description = <<-EOT
    List of Terraform repository names (without organization prefix).
    Full repository names will be constructed as: organization_name/repo-name

    Default repositories:
    - ecare-infrastructure
  EOT
  type        = list(string)
  default     = ["ecare-infrastructure"]

  validation {
    condition = alltrue([
      for r in var.terraform_repos : can(regex("^[A-Za-z0-9_.-]+$", r))
    ])
    error_message = "terraform_repos entries must be simple repo names (no slashes, spaces, or special characters except: _, ., -)."
  }
}

variable "users_with_state_access" {
  description = <<-EOT
    List of Azure AD user Object IDs who should have Storage Blob Data Contributor
    role on the Terraform state Storage Account. This allows them to view and browse
    state files in Azure Portal, which is useful for debugging and auditing.

    To get a user's Object ID:
      az ad user show --id <user-email> --query id --output tsv

    Example:
      users_with_state_access = [
        "12345678-1234-1234-1234-123456789012",
        "87654321-4321-4321-4321-210987654321"
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

variable "tags" {
  description = "Additional tags to apply to all resources (will be merged with required tags)"
  type        = map(string)
  default     = {}
}
