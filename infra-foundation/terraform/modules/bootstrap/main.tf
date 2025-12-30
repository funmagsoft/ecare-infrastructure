# Data source: Resource Group (created in Phase 0 by scripts)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

# Data source: Storage Account (created in Phase 0 by scripts)
data "azurerm_storage_account" "state" {
  name                = "tfstate${var.organization_for_sa}${var.project_name}${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
}

# Local variables for tags and GitHub OIDC configuration
locals {
  # Construct full repository names: "organization_name/repo-name"
  terraform_repos_full = [
    for repo in var.terraform_repos : "${var.organization_name}/${repo}"
  ]

  # FIC display names with 4-character hash for uniqueness
  # Format: GitHub{RepositoryName}Env-{environment}-{hash}
  # Adding 4-character hash ensures uniqueness if multiple repos transform to same name
  fic_display_names = {
    for repo in local.terraform_repos_full :
    repo => "GitHub${replace(title(replace(repo, "/", "-")), "-", "")}Env-${var.environment}-${substr(sha256(repo), 0, 4)}"
  }

  # Required tags - these must always be present
  # Ensures consistent tagging across all resources for tracking, cost allocation, and compliance
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = "Bootstrap"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${var.environment}"
    DeploymentId  = var.deployment_id
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags overwrite)
  # This ensures required tags cannot be overridden by var.tags, maintaining consistency
  merged_tags = merge(
    var.tags,
    local.required_tags
  )

  # Convert map to list of strings for Azure AD resources (format: "Key=Value")
  # Azure Entra ID (Azure AD) uses string tags in format "Key=Value" (not "Key:Value").
  # The "=" separator is required for proper tag filtering and querying in Azure Portal and Azure CLI.
  # References:
  # - Azure AD Application tags: https://learn.microsoft.com/en-us/graph/api/resources/application
  # - Azure AD Service Principal tags: https://learn.microsoft.com/en-us/graph/api/resources/serviceprincipal
  ad_tags = [
    for key, value in local.merged_tags : "${key}=${value}"
  ]
}

# Validation: Ensure all required tags are present in merged_tags
check "required_tags_validation" {
  assert {
    condition = alltrue([
      for key in ["Environment", "Project", "ManagedBy", "Phase", "GitRepository", "TerraformPath", "DeploymentId"] :
      contains(keys(local.merged_tags), key) && trimspace(local.merged_tags[key]) != ""
    ])
    error_message = "All required tags must be present and non-empty in merged_tags: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath, DeploymentId."
  }
}

# Application Registration for Service Principal
# Creates an Azure AD application that serves as the identity for GitHub Actions workflows
# This application will be used to authenticate Terraform repositories for infrastructure management
# Display name includes deployment_id for easy identification and cleanup
resource "azuread_application" "gha" {
  display_name = "sp-gha-${var.project_name}-infra-${var.environment}-${var.deployment_id}"

  tags = local.ad_tags
}

# Service Principal
# Creates a service principal (enterprise application) linked to the application registration
# This is the actual identity that will be assigned RBAC roles for managing Azure infrastructure
resource "azuread_service_principal" "gha" {
  client_id = azuread_application.gha.client_id

  tags = local.ad_tags
}

# Federated Identity Credentials for Terraform repositories
# Creates one FIC per repository per environment
# Using toset() ensures:
# 1. Each repository creates exactly one FIC (no duplicates)
# 2. Repository names are used as keys for stable Terraform state
# 3. Order changes in var.terraform_repos don't cause resource churn
resource "azuread_application_federated_identity_credential" "terraform_repos" {
  for_each = toset(local.terraform_repos_full)

  application_id = azuread_application.gha.id
  display_name   = local.fic_display_names[each.value]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value}:environment:${var.environment}"
  audiences      = ["api://AzureADTokenExchange"]
}

# RBAC: Contributor on Resource Group
# Grants Service Principal permission to:
# - Create, modify, and delete Azure infrastructure resources
# - Manage VNets, NSGs, VPN Gateways, and other network components
# - Required for Terraform to manage all resources in the Resource Group
resource "azurerm_role_assignment" "contributor_rg" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: User Access Administrator on Resource Group
# Grants Service Principal permission to:
# - Assign RBAC roles to Managed Identities
# - Manage user access to resources
# - Required for Terraform to create Managed Identities and assign them roles
# (e.g., UAMI for AKS workloads created by infra-identity)
resource "azurerm_role_assignment" "user_access_admin_rg" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Storage Blob Data Contributor on Storage Account
# Grants Service Principal permission to:
# - Read and write Terraform state files (.tfstate)
# - List containers and blobs
# - Required for remote state backend operations
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = data.azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# RBAC: Storage Blob Data Contributor for users (optional)
# Grants specified users permission to:
# - View and browse Terraform state files in Azure Portal
# - Download state files for debugging and auditing
# - Useful for DevOps team members who need to inspect infrastructure state
resource "azurerm_role_assignment" "users_storage_access" {
  for_each = toset(var.users_with_state_access)

  scope                = data.azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}
