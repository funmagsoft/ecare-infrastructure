module "workload_identity" {
  for_each = local.services_expanded

  source = "../workload-identity"

  project_name        = var.project_name
  service_name        = each.key
  environment         = var.environment
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  namespace       = data.terraform_remote_state.platform.outputs.aks_namespace_name
  aks_oidc_issuer = data.terraform_remote_state.platform.outputs.aks_oidc_issuer_url

  repo   = each.value.repo
  branch = lookup(each.value, "branch", "main")

  enable_key_vault_access   = lookup(each.value, "enable_key_vault_access", false)
  enable_storage_access     = lookup(each.value, "enable_storage_access", false)
  enable_service_bus_access = lookup(each.value, "enable_service_bus_access", false)

  key_vault_id             = each.value.key_vault_id
  storage_account_id       = each.value.storage_account_id
  service_bus_namespace_id = each.value.service_bus_namespace_id

  additional_roles = lookup(each.value, "additional_roles", [])

  tags = local.common_tags
}

