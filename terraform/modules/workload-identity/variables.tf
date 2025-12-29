variable "project_name" {
  description = "Project name (e.g. ecare)"
  type        = string
  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must be a non-empty string."
  }
}

variable "service_name" {
  description = "Logical service name (e.g. billing)"
  type        = string
  validation {
    condition     = trimspace(var.service_name) != ""
    error_message = "service_name must be a non-empty string."
  }
}

variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string
  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must be a non-empty string."
  }
}

variable "resource_group_name" {
  description = "Resource group where the User Assigned Managed Identity will be created"
  type        = string
  validation {
    condition     = trimspace(var.resource_group_name) != ""
    error_message = "resource_group_name must be a non-empty string."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  validation {
    condition     = trimspace(var.location) != ""
    error_message = "location must be a non-empty string."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "ecare"
  validation {
    condition     = trimspace(var.namespace) != ""
    error_message = "namespace must be a non-empty string."
  }
}

variable "aks_oidc_issuer" {
  description = "AKS OIDC issuer URL (from AKS output)"
  type        = string
  validation {
    condition     = trimspace(var.aks_oidc_issuer) != ""
    error_message = "aks_oidc_issuer must be a non-empty string."
  }
}

variable "enable_key_vault_access" {
  description = "If true, assign Key Vault Secrets User role on key_vault_id"
  type        = bool
  default     = false
}

variable "enable_storage_access" {
  description = "If true, assign Storage Blob Data Contributor role on storage_account_id"
  type        = bool
  default     = false
}

variable "enable_service_bus_access" {
  description = "If true, assign Azure Service Bus Data Owner role on service_bus_namespace_id"
  type        = bool
  default     = false
}

variable "key_vault_id" {
  description = "Key Vault ID for RBAC (required if enable_key_vault_access = true)"
  type        = string
  default     = null
  nullable    = true
  
  validation {
    condition     = !var.enable_key_vault_access || (var.key_vault_id != null && trimspace(var.key_vault_id) != "")
    error_message = "key_vault_id is required (non-empty) when enable_key_vault_access = true."
  }
}

variable "storage_account_id" {
  description = "Storage Account ID for RBAC (required if enable_storage_access = true)"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = !var.enable_storage_access || (var.storage_account_id != null && trimspace(var.storage_account_id) != "")
    error_message = "storage_account_id is required (non-empty) when enable_storage_access = true."
  }
}

variable "service_bus_namespace_id" {
  description = "Service Bus Namespace ID for RBAC (required if enable_service_bus_access = true)"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = !var.enable_service_bus_access || (var.service_bus_namespace_id != null && trimspace(var.service_bus_namespace_id) != "")
    error_message = "service_bus_namespace_id is required (non-empty) when enable_service_bus_access = true."
  }
}

variable "additional_roles" {
  description = "Additional RBAC roles to assign to the managed identity"
  type = list(object({
    role  = string
    scope = string
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.additional_roles : (
        trimspace(r.role) != "" && trimspace(r.scope) != ""
      )
    ])
    error_message = "Each additional_roles entry must have non-empty role and scope."
  }
}

variable "tags" {
  description = "Additional tags to apply to the managed identity"
  type        = map(string)
  default     = {}
}
