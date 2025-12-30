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
      trimspace(local.common_tags["Environment"]) != "",
      trimspace(local.common_tags["Project"]) != "",
      trimspace(local.common_tags["ManagedBy"]) != "",
      trimspace(local.common_tags["Phase"]) != "",
      trimspace(local.common_tags["GitRepository"]) != "",
      trimspace(local.common_tags["TerraformPath"]) != "",
      trimspace(local.common_tags["DeploymentId"]) != ""
    ])
    error_message = "All required tags must be present and non-empty (after trimming whitespace): Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath, DeploymentId."
  }
}
