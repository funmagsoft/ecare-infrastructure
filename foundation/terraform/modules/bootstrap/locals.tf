#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

locals {
  # Required tags - these must always be present
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = title(var.phase)
    GitRepository = "ecare-infrastructure"
    TerraformPath = "foundation/terraform/environments/${var.environment}"
    DeploymentId  = var.deployment_id
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags overwrite)
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

  # Azure AD uses "Key=Value" string tags
  ad_tags = [
    for key, value in local.merged_tags : "${key}=${value}"
  ]

  # Full Terraform repository names (org/repo)
  terraform_repos_full = [
    for repo in var.terraform_repos : "${var.organization_name}/${repo}"
  ]

  # FIC display names: GitHub{Repo}Env-{environment}-{phase}-{deployment_id}
  fic_display_names = {
    for repo in local.terraform_repos_full :
    repo => "GitHub${replace(title(replace(repo, "/", "-")), "-", "")}Env-${var.environment}-${var.phase}-${var.deployment_id}"
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
