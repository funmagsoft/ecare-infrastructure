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
    TerraformPath = "workload/terraform/environments/${var.environment}"
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

  # Expand services with resource IDs from platform remote state
  services_expanded = {
    for name, cfg in var.services :
    name => merge(cfg, {
      key_vault_id             = cfg.enable_key_vault_access ? data.terraform_remote_state.platform.outputs.key_vault_id : null
      storage_account_id       = cfg.enable_storage_access ? data.terraform_remote_state.platform.outputs.storage_account_id : null
      service_bus_namespace_id = cfg.enable_service_bus_access ? data.terraform_remote_state.platform.outputs.service_bus_namespace_id : null
    })
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
