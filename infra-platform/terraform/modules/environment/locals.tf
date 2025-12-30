#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

# Local variables
locals {
  # Required tags - these must always be present
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = "Platform"
    GitRepository = "infra-platform"
    TerraformPath = "terraform/environments/${var.environment}"
    DeploymentId  = var.deployment_id
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags)
  common_tags = merge(
    var.tags,
    local.required_tags
  )

  # Extract foundation outputs
  vnet_id        = data.terraform_remote_state.foundation.outputs.vnet_id
  aks_subnet_id  = data.terraform_remote_state.foundation.outputs.aks_subnet_id
  data_subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  mgmt_subnet_id = data.terraform_remote_state.foundation.outputs.mgmt_subnet_id
}

#------------------------------------------------------------------------------
# Validation
#------------------------------------------------------------------------------

# Validation: Ensure all required tags are present
# This precondition will fail if any required tag is missing or empty
check "required_tags_validation" {
  assert {
    condition = alltrue([
      local.common_tags["Environment"] != null && local.common_tags["Environment"] != "",
      local.common_tags["Project"] != null && local.common_tags["Project"] != "",
      local.common_tags["ManagedBy"] != null && local.common_tags["ManagedBy"] != "",
      local.common_tags["Phase"] != null && local.common_tags["Phase"] != "",
      local.common_tags["GitRepository"] != null && local.common_tags["GitRepository"] != "",
      local.common_tags["TerraformPath"] != null && local.common_tags["TerraformPath"] != "",
      local.common_tags["DeploymentId"] != null && local.common_tags["DeploymentId"] != ""
    ])
    error_message = "All required tags must be present and non-empty: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath, DeploymentId."
  }
}
