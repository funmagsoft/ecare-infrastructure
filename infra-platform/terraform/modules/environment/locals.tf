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
    Phase         = title(var.phase)
    GitRepository = "ecare-infrastructure"
    TerraformPath = "platform/terraform/environments/${var.environment}"
    DeploymentId  = var.deployment_id
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: var.tags first, then required_tags)
  common_tags = merge(
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
  tags_for_validation = local.common_tags

  # Extract foundation outputs
  vnet_id        = data.terraform_remote_state.foundation.outputs.vnet_id
  aks_subnet_id  = data.terraform_remote_state.foundation.outputs.aks_subnet_id
  data_subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  mgmt_subnet_id = data.terraform_remote_state.foundation.outputs.mgmt_subnet_id
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
