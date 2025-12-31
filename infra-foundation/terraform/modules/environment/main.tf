#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

# Network Module
module "network" {
  source = "../network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vnet_name = "vnet-${var.project_name}-${var.environment}"
  vnet_cidr = var.vnet_cidr

  aks_subnet_name = "snet-${var.project_name}-${var.environment}-aks"
  aks_subnet_cidr = var.aks_subnet_cidr
  aks_nsg_name    = "nsg-${var.project_name}-${var.environment}-aks"

  data_subnet_name = "snet-${var.project_name}-${var.environment}-data"
  data_subnet_cidr = var.data_subnet_cidr
  data_nsg_name    = "nsg-${var.project_name}-${var.environment}-data"

  mgmt_subnet_name = "snet-${var.project_name}-${var.environment}-mgmt"
  mgmt_subnet_cidr = var.mgmt_subnet_cidr
  mgmt_nsg_name    = "nsg-${var.project_name}-${var.environment}-mgmt"

  mgmt_subnet_allowed_ssh_ips = var.mgmt_subnet_allowed_ssh_ips

  gateway_subnet_cidr = var.gateway_subnet_cidr
  enable_vpn_gateway  = var.enable_vpn_gateway

  tags = local.common_tags
}

# VPN Gateway Module
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vpn_gateway_name  = "vgw-${var.project_name}-${var.environment}"
  public_ip_name    = "pip-vgw-${var.project_name}-${var.environment}"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = var.vpn_gateway_sku
  vpn_client_address_space = var.vpn_client_address_space
  vpn_root_cert_name       = var.vpn_root_cert_name
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags

  # Explicit dependency on network module ensures gateway subnet is fully created
  # before VPN Gateway attempts to use it. While gateway_subnet_id already creates
  # an implicit dependency, this explicit depends_on provides clarity and ensures
  # proper resource creation order, especially during initial deployments.
  depends_on = [module.network]
}
