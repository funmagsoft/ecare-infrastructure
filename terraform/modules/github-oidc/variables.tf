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
}

variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

variable "aks_id" {
  description = "ID of the Azure Kubernetes Service cluster"
  type        = string
}

variable "service_repos" {
  description = <<-EOT
    Map of service repositories for GitHub OIDC integration.
    Key: service name
    Value: object with repo (org/repo-name) and branch (default: main)
    
    Example:
    service_repos = {
      billing = {
        repo   = "hycom/billing-service"
        branch = "main"
      }
    }
  EOT
  type = map(object({
    repo   = string
    branch = optional(string, "main")
  }))
  default = {}
}

variable "enable_aks_rbac_writer" {
  description = "Enable Azure Kubernetes Service RBAC Writer role (for deployments)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}


