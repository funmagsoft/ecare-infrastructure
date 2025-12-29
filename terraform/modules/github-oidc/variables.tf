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
  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must be a non-empty string."
  }
}

variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
  validation {
    condition     = trimspace(var.resource_group_name) != ""
    error_message = "resource_group_name must be a non-empty string."
  }
}

variable "acr_id" {
  description = "ID of the Azure Container Registry (full Azure resource ID)"
  type        = string
  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerRegistry/registries/[^/]+$", var.acr_id))
    error_message = "acr_id must be a full Azure resource ID of an ACR registry (format: /subscriptions/.../providers/Microsoft.ContainerRegistry/registries/...)."
  }
}

variable "aks_id" {
  description = "ID of the Azure Kubernetes Service cluster (full Azure resource ID)"
  type        = string
  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.aks_id))
    error_message = "aks_id must be a full Azure resource ID of an AKS cluster (format: /subscriptions/.../providers/Microsoft.ContainerService/managedClusters/...)."
  }
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

  validation {
    condition = alltrue([
      for _, cfg in var.service_repos :
      can(regex("^[^/]+/[^/]+$", cfg.repo))
    ])
    error_message = "Each service_repos[*].repo must be in 'org/repo' format (e.g., 'hycom/billing-service')."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.service_repos :
      trimspace(cfg.branch) != ""
    ])
    error_message = "Each service_repos[*].branch must be non-empty after trimming whitespace."
  }
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

  validation {
    condition = alltrue([
      for r in var.gitops_repos :
      can(regex("^[^/]+/[^/]+$", r))
    ])
    error_message = "Each gitops_repos entry must be in 'org/repo' format (e.g., 'hycom/gitops')."
  }
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
