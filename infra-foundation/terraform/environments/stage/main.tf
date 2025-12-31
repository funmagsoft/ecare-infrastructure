module "environment" {
  source = "../../modules/environment"

  environment   = var.environment
  phase         = var.phase
  project_name  = var.project_name
  deployment_id = var.deployment_id

  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  data_subnet_cidr    = var.data_subnet_cidr
  mgmt_subnet_cidr    = var.mgmt_subnet_cidr
  gateway_subnet_cidr = var.gateway_subnet_cidr

  enable_vpn_gateway          = var.enable_vpn_gateway
  vpn_gateway_sku             = var.vpn_gateway_sku
  vpn_client_address_space    = var.vpn_client_address_space
  vpn_root_cert_name          = var.vpn_root_cert_name
  vpn_root_cert_data          = var.vpn_root_cert_data
  mgmt_subnet_allowed_ssh_ips = var.mgmt_subnet_allowed_ssh_ips

  tags = var.tags
}
