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
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less to ensure resource names stay within Azure limits."
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

variable "services" {
  description = "Map of services to create workload identities for"
  type = map(object({
    repo                      = string
    branch                    = optional(string, "main")
    enable_key_vault_access   = optional(bool, false)
    enable_storage_access     = optional(bool, false)
    enable_service_bus_access = optional(bool, false)
    additional_roles = optional(list(object({
      role  = string
      scope = string
    })), [])
  }))
  default = {}
}

variable "gitops_repos" {
  description = <<-EOT
    List of GitOps repositories (full names in org/repo-name format) for environment-based OIDC integration.
    Creates one FIC per repository per environment with subject: repo:{repo}:environment:{environment}
    
    Example:
    gitops_repos = [
      "hycom/gitops"
    ]
  EOT
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to merge with required tags (Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath). Required tags take precedence and cannot be overridden."
  type        = map(string)
  default     = {}
}
