# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
