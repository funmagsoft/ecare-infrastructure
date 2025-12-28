# Data source: Resource Group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Local variables for tags and GitHub OIDC configuration
locals {
  # Required tags - these must always be present
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = "GitHubOIDCIntegration"
    GitRepository = "infra-identity"
    TerraformPath = "terraform/environments/${var.environment}"
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags)
  merged_tags = merge(
    var.tags,
    local.required_tags
  )

  # Convert map to list of strings for Azure AD resources (format: "Key:Value")
  ad_tags = [
    for key, value in local.merged_tags : "${key}:${value}"
  ]

  # GitHub OIDC configuration constants
  # These are used for all Federated Identity Credentials in this module
  github_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_oidc_audience = ["api://AzureADTokenExchange"]

  # Helper to format repository name for display (removes slashes and formats)
  format_repo_display_name = {
    for repo in var.gitops_repos :
    repo => "GitHub${replace(title(replace(repo, "/", "-")), "-", "")}"
  }

  # Service repository display names
  # Format: GitHub{RepositoryName}Branch-{branch}
  service_repo_display_names = {
    for name, cfg in var.service_repos :
    name => "GitHub${replace(title(replace(cfg.repo, "/", "-")), "-", "")}Branch-${replace(cfg.branch, "/", "-")}"
  }

  # GitOps repository display names
  # Format: GitHub{RepositoryName}Env-{environment}
  gitops_repo_display_names = {
    for repo in var.gitops_repos :
    repo => "${local.format_repo_display_name[repo]}Env-${var.environment}"
  }
}

# Application Registration for Service Principal
resource "azuread_application" "gha" {
  display_name = "sp-gha-${var.project_name}-${var.environment}"

  tags = local.ad_tags
}

# Service Principal
resource "azuread_service_principal" "gha" {
  application_id = azuread_application.gha.application_id

  tags = local.ad_tags
}

# Federated Identity Credentials for service repositories
# Creates one FIC per service repository per environment
# Subject: repo:{repo}:ref:refs/heads/{branch}
resource "azuread_application_federated_identity_credential" "service_repos" {
  for_each = var.service_repos

  application_object_id = azuread_application.gha.object_id
  display_name          = local.service_repo_display_names[each.key]
  issuer                = local.github_oidc_issuer
  subject               = "repo:${each.value.repo}:ref:refs/heads/${each.value.branch}"
  audiences             = local.github_oidc_audience
}

# Federated Identity Credentials for GitOps repositories
# Creates one FIC per GitOps repository per environment
# Subject: repo:{repo}:environment:{environment}
resource "azuread_application_federated_identity_credential" "gitops_repos" {
  for_each = toset(var.gitops_repos)

  application_object_id = azuread_application.gha.object_id
  display_name          = local.gitops_repo_display_names[each.value]
  issuer                = local.github_oidc_issuer
  subject               = "repo:${each.value}:environment:${var.environment}"
  audiences             = local.github_oidc_audience
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

