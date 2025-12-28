#------------------------------------------------------------------------------
# Module: Service Bus (with Private Endpoint)
#------------------------------------------------------------------------------

module "service_bus" {
  source = "../service-bus"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  sku            = var.service_bus_sku
  capacity       = var.service_bus_capacity
  zone_redundant = var.service_bus_zone_redundant

  # Private Endpoint configuration
  subnet_id = local.data_subnet_id
  vnet_id   = local.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = local.common_tags
}
