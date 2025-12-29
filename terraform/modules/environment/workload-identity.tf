# GitHub OIDC Azure Integration Module
# Creates Service Principal and FIC for service repositories to build images and deploy to AKS
module "github_oidc_integration" {
  source = "../github-oidc"

  environment         = var.environment
  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.main.name

  acr_id = data.terraform_remote_state.platform.outputs.acr_id
  aks_id = data.terraform_remote_state.platform.outputs.aks_cluster_id

  # Extract service repositories for GitHub OIDC (repo and branch)
  service_repos = {
    for name, cfg in var.services :
    name => {
      repo   = cfg.repo
      branch = lookup(cfg, "branch", "main")
    }
  }

  # GitOps repositories for environment-based OIDC integration
  gitops_repos = var.gitops_repos

  enable_aks_rbac_writer = true

  tags = local.common_tags
}

# Workload Identity Module
# Creates UAMI and FIC for AKS pods to access Azure resources (Key Vault, Storage, Service Bus)
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

  enable_key_vault_access   = lookup(each.value, "enable_key_vault_access", false)
  enable_storage_access     = lookup(each.value, "enable_storage_access", false)
  enable_service_bus_access = lookup(each.value, "enable_service_bus_access", false)

  key_vault_id             = each.value.key_vault_id
  storage_account_id       = each.value.storage_account_id
  service_bus_namespace_id = each.value.service_bus_namespace_id

  additional_roles = lookup(each.value, "additional_roles", [])

  tags = local.common_tags
}

