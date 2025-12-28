# Data source: Resource Group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Application Registration for Service Principal
resource "azuread_application" "gha" {
  display_name = "sp-gha-${var.project_name}-${var.environment}"

  tags = [
    "Environment:${var.environment}",
    "Project:${var.project_name}",
    "ManagedBy:Terraform",
    "Phase:GitHubOIDCIntegration"
  ]
}

# Service Principal
resource "azuread_service_principal" "gha" {
  application_id = azuread_application.gha.application_id

  tags = [
    "Environment:${var.environment}",
    "Project:${var.project_name}",
    "ManagedBy:Terraform",
    "Phase:GitHubOIDCIntegration"
  ]
}

# Federated Identity Credentials for service repositories
# Creates one FIC per service repository per environment
resource "azuread_application_federated_identity_credential" "service_repos" {
  for_each = var.service_repos

  application_object_id = azuread_application.gha.object_id
  display_name          = "GitHub${replace(title(replace(each.value.repo, "/", "-")), "-", "")}Branch-${replace(each.value.branch, "/", "-")}"
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${each.value.repo}:ref:refs/heads/${each.value.branch}"
  audiences             = ["api://AzureADTokenExchange"]
}

# RBAC: Contributor on ACR
# Required for az acr build (managing ACR Tasks)
resource "azurerm_role_assignment" "acr_contributor" {
  scope                = var.acr_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Azure Kubernetes Service Cluster User Role on AKS
# Required for az aks get-credentials (retrieving kubeconfig)
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Azure Kubernetes Service RBAC Writer on AKS (optional)
# Required for deployments (creating deployments, services, configmaps, etc.)
resource "azurerm_role_assignment" "aks_rbac_writer" {
  count = var.enable_aks_rbac_writer ? 1 : 0

  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_service_principal.gha.object_id
}


