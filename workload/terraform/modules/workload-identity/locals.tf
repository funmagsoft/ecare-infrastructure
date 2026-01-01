#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

locals {
  # Resource naming patterns
  name_hash             = substr(sha256(var.service_name), 0, 6)
  managed_identity_name = "mi-${var.project_name}-${var.service_name}-${var.environment}-${local.name_hash}-${var.phase}-${var.deployment_id}"
  service_account_name  = "sa-${var.service_name}"
  federated_cred_name   = "fic-${var.project_name}-${var.service_name}-${var.environment}-${local.name_hash}-${var.phase}-${var.deployment_id}"
  fic_subject           = "system:serviceaccount:${var.namespace}:${local.service_account_name}"

  # Determine if Azure access is needed (UAMI and FIC are only created when needed)
  needs_azure_access = (
    var.enable_key_vault_access
    || var.enable_storage_access
    || var.enable_service_bus_access
    || length(var.additional_roles) > 0
  )

  # Default tags merged with provided tags
  # Required tags ensure consistency across all resources and enable traceability
  tags = merge(
    {
      Environment   = var.environment
      Project       = var.project_name
      Service       = var.service_name
      ManagedBy     = "Terraform"
      Phase         = title(var.phase)
      GitRepository = "ecare-infrastructure"
      TerraformPath = "workload/terraform/environments/${var.environment}"
      DeploymentId  = var.deployment_id
    },
    var.tags
  )

  # Required tag keys for validation
  required_tag_keys = [
    "Environment",
    "Project",
    "Service",
    "ManagedBy",
    "Phase",
    "GitRepository",
    "TerraformPath",
    "DeploymentId"
  ]

  # Tags map used for validation
  tags_for_validation = local.tags

  # Stable keys for additional role assignments to avoid churn on list reordering
  # Key format: "scope|role" - this ensures:
  # 1. Same role+scope combination is not created twice (automatic deduplication)
  # 2. Reordering list elements doesn't cause Terraform resource churn
  # 3. Stable resource names in Terraform state (based on scope and role, not list index)
  additional_roles_map = local.needs_azure_access ? {
    for r in var.additional_roles : "${trimspace(r.scope)}|${trimspace(r.role)}" => {
      role  = trimspace(r.role)
      scope = trimspace(r.scope)
    }
  } : {}
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
