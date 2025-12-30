#------------------------------------------------------------------------------
# Module: Key Vault (with Private Endpoint)
#------------------------------------------------------------------------------

module "key_vault" {
  source = "../key-vault"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  sku_name                   = var.key_vault_sku
  purge_protection_enabled   = var.key_vault_purge_protection_enabled
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days

  # Private Endpoint configuration
  subnet_id = local.data_subnet_id
  vnet_id   = local.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# RBAC Role Assignments
#------------------------------------------------------------------------------

# Grant Bastion VM access to AKS
resource "azurerm_role_assignment" "bastion_aks_user" {
  principal_id         = module.bastion.bastion_principal_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  scope                = module.aks.aks_cluster_id

  depends_on = [module.bastion, module.aks]
}

# Grant Bastion VM access to ACR
resource "azurerm_role_assignment" "bastion_acr_pull" {
  principal_id         = module.bastion.bastion_principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id

  depends_on = [module.bastion, module.acr]
}

# Grant AKS kubelet identity access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.aks_kubelet_identity_object_id
  role_definition_name             = "AcrPull"
  scope                            = module.acr.acr_id
  skip_service_principal_aad_check = true

  depends_on = [module.aks, module.acr]
}
