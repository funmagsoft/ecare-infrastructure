#------------------------------------------------------------------------------
# Module: Azure Container Registry (with Private Endpoint)
#------------------------------------------------------------------------------

module "acr" {
  source = "../acr"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  sku                     = var.acr_sku
  zone_redundancy_enabled = var.acr_zone_redundancy_enabled
  retention_days          = var.acr_retention_days

  # Private Endpoint configuration
  subnet_id = local.data_subnet_id
  vnet_id   = local.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = local.common_tags
}
