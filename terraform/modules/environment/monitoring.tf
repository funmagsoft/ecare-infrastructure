#------------------------------------------------------------------------------
# Module: Monitoring (Log Analytics + Application Insights)
#------------------------------------------------------------------------------

module "monitoring" {
  source = "../monitoring"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  log_analytics_sku            = var.log_analytics_sku
  log_analytics_retention_days = var.log_analytics_retention_days
  application_insights_type    = var.application_insights_type

  tags = local.common_tags
}
