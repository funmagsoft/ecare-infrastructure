#------------------------------------------------------------------------------
# Azure AD Resources
#------------------------------------------------------------------------------

# Application Registration for Service Principal
# Creates an Azure AD application that serves as the identity for GitHub Actions workflows
# This application will be used to authenticate service and GitOps repositories
# Display name includes deployment_id for easy identification and cleanup
resource "azuread_application" "gha" {
  display_name = "sp-gha-${var.project_name}-${var.environment}-${var.deployment_id}"

  tags = local.ad_tags
}

# Service Principal
# Creates a service principal (enterprise application) linked to the application registration
# This is the actual identity that will be assigned RBAC roles for ACR and AKS access
resource "azuread_service_principal" "gha" {
  client_id = azuread_application.gha.client_id

  tags = local.ad_tags
}

# Federated Identity Credentials for service repositories
# Creates one FIC per service repository per environment
# Subject: repo:{repo}:ref:refs/heads/{branch}
resource "azuread_application_federated_identity_credential" "service_repos" {
  for_each = var.service_repos

  application_id = azuread_application.gha.id
  display_name   = local.service_repo_display_names[each.key]
  issuer         = local.github_oidc_issuer
  subject        = "repo:${each.value.repo}:ref:refs/heads/${each.value.branch}"
  audiences      = local.github_oidc_audience
}

# Federated Identity Credentials for GitOps repositories
# Creates one FIC per GitOps repository per environment
# Subject: repo:{repo}:environment:{environment}
resource "azuread_application_federated_identity_credential" "gitops_repos" {
  for_each = toset(var.gitops_repos)

  application_id = azuread_application.gha.id
  display_name   = local.gitops_repo_display_names[each.value]
  issuer         = local.github_oidc_issuer
  subject        = "repo:${each.value}:environment:${var.environment}"
  audiences      = local.github_oidc_audience
}

#------------------------------------------------------------------------------
# RBAC Role Assignments
#------------------------------------------------------------------------------

# RBAC: Contributor on ACR
# Grants Service Principal permission to:
# - Push and pull container images
# - Manage ACR tasks (az acr build)
# - View and manage repository metadata
resource "azurerm_role_assignment" "acr_contributor" {
  scope                = var.acr_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Azure Kubernetes Service Cluster User Role on AKS
# Grants Service Principal permission to:
# - Retrieve kubeconfig (az aks get-credentials)
# - List cluster resources
# - Required as base permission for Kubernetes access
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Azure Kubernetes Service RBAC Writer on AKS (optional)
# Grants Service Principal permission to:
# - Deploy applications (create/update/delete deployments, services, configmaps, secrets)
# - Manage Kubernetes resources in all namespaces
# - Required for CI/CD deployments from GitHub Actions
resource "azurerm_role_assignment" "aks_rbac_writer" {
  count = var.enable_aks_rbac_writer ? 1 : 0

  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_service_principal.gha.object_id
}
