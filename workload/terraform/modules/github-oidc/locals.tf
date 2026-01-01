#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

# Local variables for tags and GitHub OIDC configuration
locals {
  # Required tags - these must always be present
  # Ensures consistent tagging across all resources for tracking, cost allocation, and compliance
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = title(var.phase)
    GitRepository = "ecare-infrastructure"
    TerraformPath = "workload/terraform/environments/${var.environment}"
    DeploymentId  = var.deployment_id
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags overwrite)
  # This ensures required tags cannot be overridden by var.tags, maintaining consistency
  merged_tags = merge(
    var.tags,
    local.required_tags
  )

  # Required tag keys for validation
  required_tag_keys = [
    "Environment",
    "Project",
    "ManagedBy",
    "Phase",
    "GitRepository",
    "TerraformPath",
    "DeploymentId"
  ]

  # Tags map used for validation
  tags_for_validation = local.merged_tags

  # Convert map to list of strings for Azure AD resources (format: "Key=Value")
  # Azure Entra ID (Azure AD) uses string tags in format "Key=Value" (not "Key:Value").
  # The "=" separator is required for proper tag filtering and querying in Azure Portal and Azure CLI.
  # References:
  # - Azure AD Application tags: https://learn.microsoft.com/en-us/graph/api/resources/application
  # - Azure AD Service Principal tags: https://learn.microsoft.com/en-us/graph/api/resources/serviceprincipal
  ad_tags = [
    for key, value in local.merged_tags : "${key}=${value}"
  ]

  # Stable repo list for app/SP display name hashing
  app_repos = sort(distinct(concat(
    [for _, cfg in var.service_repos : cfg.repo],
    var.gitops_repos
  )))
  app_repos_hash = substr(sha256(join(",", local.app_repos)), 0, 6)

  # GitHub OIDC configuration constants
  # These are used for all Federated Identity Credentials in this module
  # Issuer: GitHub's OIDC provider URL (fixed for all GitHub Actions workflows)
  # Audience: Azure AD token exchange API (standard for GitHub Actions → Azure authentication)
  github_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_oidc_audience = ["api://AzureADTokenExchange"]

  # Helper to format repository name for display (removes slashes and formats)
  format_repo_display_name = {
    for repo in var.gitops_repos :
    repo => "GitHub${replace(title(replace(repo, "/", "-")), "-", "")}"
  }

  # Service repository display names
  # Format: GitHub{RepositoryName}Branch-{branch}-{hash}-{phase}-{deployment_id}
  # Adding 4-character hash ensures uniqueness even if repo/branch combinations collide
  service_repo_display_names = {
    for name, cfg in var.service_repos :
    name => "GitHub${replace(title(replace(cfg.repo, "/", "-")), "-", "")}Branch-${replace(cfg.branch, "/", "-")}-${substr(sha256("${cfg.repo}:${cfg.branch}:${name}"), 0, 6)}-${var.phase}-${var.deployment_id}"
  }

  # GitOps repository display names
  # Format: GitHub{RepositoryName}Env-{environment}-{hash}
  # Adding 4-character hash ensures uniqueness if multiple repos transform to same name
  gitops_repo_display_names = {
    for repo in var.gitops_repos :
    repo => "${local.format_repo_display_name[repo]}Env-${var.environment}-${substr(sha256(repo), 0, 6)}-${var.phase}-${var.deployment_id}"
  }
}

#------------------------------------------------------------------------------
# Validation
#------------------------------------------------------------------------------

check "required_tags_validation" {
  assert {
    condition = alltrue([
      for key in local.required_tag_keys :
      contains(keys(local.tags_for_validation), key) && trimspace(local.tags_for_validation[key]) != ""
    ])
    error_message = "All required tags must be present and non-empty: ${join(", ", local.required_tag_keys)}."
  }
}
