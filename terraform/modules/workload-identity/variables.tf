variable "project_name" {
  description = "Project name (e.g. ecare)"
  type        = string
}

variable "service_name" {
  description = "Logical service name (e.g. billing)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where the User Assigned Managed Identity will be created"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "ecare"
}

variable "aks_oidc_issuer" {
  description = "AKS OIDC issuer URL (from AKS output)"
  type        = string
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
}

variable "storage_account_id" {
  description = "Storage Account ID for RBAC (required if enable_storage_access = true)"
  type        = string
  default     = null
}

variable "service_bus_namespace_id" {
  description = "Service Bus Namespace ID for RBAC (required if enable_service_bus_access = true)"
  type        = string
  default     = null
}

variable "additional_roles" {
  description = "Additional RBAC roles to assign to the managed identity"
  type = list(object({
    role  = string
    scope = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to the managed identity"
  type        = map(string)
  default     = {}
}
