module "network" {
  source = "../../modules/network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vnet_name = "vnet-${local.project}-${local.environment}"
  vnet_cidr = var.vnet_cidr

  aks_subnet_name = "snet-${local.project}-${local.environment}-aks"
  aks_subnet_cidr = var.aks_subnet_cidr
  aks_nsg_name    = "nsg-${local.project}-${local.environment}-aks"

  data_subnet_name = "snet-${local.project}-${local.environment}-data"
  data_subnet_cidr = var.data_subnet_cidr
  data_nsg_name    = "nsg-${local.project}-${local.environment}-data"

  mgmt_subnet_name = "snet-${local.project}-${local.environment}-mgmt"
  mgmt_subnet_cidr = var.mgmt_subnet_cidr
  mgmt_nsg_name    = "nsg-${local.project}-${local.environment}-mgmt"

  mgmt_subnet_allowed_ssh_ips = var.mgmt_subnet_allowed_ssh_ips

  gateway_subnet_cidr = var.gateway_subnet_cidr
  enable_vpn_gateway  = var.enable_vpn_gateway

  tags = local.common_tags
}
