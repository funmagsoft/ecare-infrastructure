variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "organization" {
  description = "GitHub organization name"
  type        = string
}

variable "organization_for_sa" {
  description = "Organization name for Storage Account naming (may differ from organization due to Azure naming constraints)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
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
}
