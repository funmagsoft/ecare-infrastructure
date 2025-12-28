locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = "WorkloadIdentity"
    GitRepository = "infra-identity"
    TerraformPath = "terraform/environments/${var.environment}"
  }

  services_expanded = {
    for name, cfg in var.services :
    name => merge(cfg, {
      key_vault_id             = cfg.enable_key_vault_access ? data.terraform_remote_state.platform.outputs.key_vault_id : null
      storage_account_id       = cfg.enable_storage_access ? data.terraform_remote_state.platform.outputs.storage_account_id : null
      service_bus_namespace_id = cfg.enable_service_bus_access ? data.terraform_remote_state.platform.outputs.service_bus_namespace_id : null
    })
  }
}

