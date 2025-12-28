module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../../modules/vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vpn_gateway_name  = "vgw-${local.project}-${local.environment}"
  public_ip_name    = "pip-vgw-${local.project}-${local.environment}"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = var.vpn_gateway_sku
  vpn_client_address_space = var.vpn_client_address_space
  vpn_root_cert_name       = var.vpn_root_cert_name
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags

  depends_on = [module.network]
}
