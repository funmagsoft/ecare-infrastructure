
locals {
  # Resource naming patterns
  managed_identity_name = "mi-${var.project_name}-${var.service_name}-${var.environment}"
  service_account_name  = "sa-${var.service_name}"
  federated_cred_name   = "fic-${var.project_name}-${var.service_name}-${var.environment}"
  fic_subject           = "system:serviceaccount:${var.namespace}:${local.service_account_name}"

  # Determine if Azure access is needed (UAMI and FIC are only created when needed)
  needs_azure_access = var.enable_key_vault_access || var.enable_storage_access || var.enable_service_bus_access || length(var.additional_roles) > 0

  # Default tags merged with provided tags
  # Required tags ensure consistency across all resources and enable traceability
  tags = merge(
    {
      Environment   = var.environment
      Project       = var.project_name
      Service       = var.service_name
      ManagedBy     = "Terraform"
      Phase         = "WorkloadIdentity"
      GitRepository = "infra-identity"
      TerraformPath = "terraform/environments/${var.environment}"
    },
    var.tags
  )
}

# User Assigned Managed Identity (only if access is needed)
resource "azurerm_user_assigned_identity" "service" {
  count = local.needs_azure_access ? 1 : 0

  name                = local.managed_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = local.tags
}

# Federated Identity Credential for AKS Workload Identity
resource "azurerm_federated_identity_credential" "service" {
  count = local.needs_azure_access ? 1 : 0

  name                = local.federated_cred_name
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.service[0].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = var.aks_oidc_issuer
  subject  = local.fic_subject
}

# Key Vault Secrets User (conditional)
# Precondition Pattern:
# Each conditional RBAC assignment includes a precondition to ensure
# the required resource ID is provided when access is enabled.
# This prevents silent failures and provides clear error messages.
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  count = var.enable_key_vault_access ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.service[0].principal_id

  lifecycle {
    precondition {
      condition     = !var.enable_key_vault_access || var.key_vault_id != null
      error_message = "key_vault_id must be provided when enable_key_vault_access is true"
    }
  }
}

# Storage Blob Data Contributor (conditional)
# Precondition Pattern:
# Each conditional RBAC assignment includes a precondition to ensure
# the required resource ID is provided when access is enabled.
# This prevents silent failures and provides clear error messages.
resource "azurerm_role_assignment" "storage_blob_contributor" {
  count = var.enable_storage_access ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.service[0].principal_id

  lifecycle {
    precondition {
      condition     = !var.enable_storage_access || var.storage_account_id != null
      error_message = "storage_account_id must be provided when enable_storage_access is true"
    }
  }
}

# Service Bus Data Owner (conditional)
# Precondition Pattern:
# Each conditional RBAC assignment includes a precondition to ensure
# the required resource ID is provided when access is enabled.
# This prevents silent failures and provides clear error messages.
resource "azurerm_role_assignment" "service_bus_data_owner" {
  count = var.enable_service_bus_access ? 1 : 0

  scope                = var.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_user_assigned_identity.service[0].principal_id

  lifecycle {
    precondition {
      condition     = !var.enable_service_bus_access || var.service_bus_namespace_id != null
      error_message = "service_bus_namespace_id must be provided when enable_service_bus_access is true"
    }
  }
}

# Additional custom roles
resource "azurerm_role_assignment" "additional" {
  for_each = local.needs_azure_access ? { for idx, role in var.additional_roles : idx => role } : {}

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.service[0].principal_id
}

# Kubernetes ServiceAccount (always created; annotation only if MI exists)
resource "kubernetes_service_account_v1" "service" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace

    annotations = local.needs_azure_access ? {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.service[0].client_id
    } : {}

    labels = {
      "azure.workload.identity/use"  = local.needs_azure_access ? "true" : "false"
      "app.kubernetes.io/name"       = var.service_name
      "app.kubernetes.io/env"        = var.environment
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

