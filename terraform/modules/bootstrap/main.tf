# Data source: Resource Group (created in Phase 0 by scripts)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

# Data source: Storage Account (created in Phase 0 by scripts)
data "azurerm_storage_account" "state" {
  name                = "tfstate${var.organization_for_sa}${var.project_name}${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
}

# Local: Construct full repository names
locals {
  # Construct full repository names: "organization/repo-name"
  terraform_repos_full = [
    for repo in var.terraform_repos : "${var.organization}/${repo}"
  ]
}

# Application Registration for Service Principal
resource "azuread_application" "gha" {
  display_name = "sp-gha-${var.project_name}-infra-${var.environment}"

  tags = [
    "Environment:${var.environment}",
    "Project:${var.project_name}",
    "ManagedBy:Terraform",
    "Phase:Bootstrap"
  ]
}

# Service Principal
resource "azuread_service_principal" "gha" {
  application_id = azuread_application.gha.application_id

  tags = [
    "Environment:${var.environment}",
    "Project:${var.project_name}",
    "ManagedBy:Terraform",
    "Phase:Bootstrap"
  ]
}

# Federated Identity Credentials for Terraform repositories
# Creates one FIC per repository per environment
resource "azuread_application_federated_identity_credential" "terraform_repos" {
  for_each = toset(local.terraform_repos_full)

  application_object_id = azuread_application.gha.object_id
  display_name          = "GitHub${replace(title(replace(each.value, "/", "-")), "-", "")}Env-${var.environment}"
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${each.value}:environment:${var.environment}"
  audiences             = ["api://AzureADTokenExchange"]
}

# RBAC: Contributor on Resource Group
resource "azurerm_role_assignment" "contributor_rg" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: User Access Administrator on Resource Group
# Required for Terraform to assign roles to Managed Identities it creates
resource "azurerm_role_assignment" "user_access_admin_rg" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Storage Blob Data Contributor on Storage Account
# Required for Terraform to read/write state files
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = data.azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Storage Blob Data Contributor for users (optional)
# Allows specified users to view and browse state files in Azure Portal
resource "azurerm_role_assignment" "users_storage_access" {
  for_each = toset(var.users_with_state_access)

  scope                = data.azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}
