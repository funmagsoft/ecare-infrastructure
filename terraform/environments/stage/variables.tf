variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
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

variable "additional_tags" {
  description = "Additional tags to merge with required tags. Required tags (Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath) cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.additional_tags) : !contains(["Environment", "Project", "ManagedBy", "Phase", "GitRepository", "TerraformPath"], key)
    ])
    error_message = "Additional tags cannot override required tags: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath."
  }
}
