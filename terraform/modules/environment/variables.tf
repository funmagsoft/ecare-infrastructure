variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "hycom"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"
}

variable "services" {
  description = "Map of services to create workload identities for"
  type = map(object({
    repo                    = string
    branch                  = optional(string, "main")
    enable_key_vault_access = optional(bool, false)
    enable_storage_access   = optional(bool, false)
    enable_service_bus_access = optional(bool, false)
    additional_roles        = optional(list(object({
      role  = string
      scope = string
    })), [])
  }))
  default = {}
}

variable "additional_tags" {
  description = "Additional tags to merge with required tags. Required tags (Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath) cannot be overridden."
  type        = map(string)
  default     = {}
}

