# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

# Local variables
locals {
  environment = var.environment
  project     = var.project_name
  location    = data.azurerm_resource_group.main.location

  # Required tags - these must always be present
  required_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: additional_tags first, then required_tags)
  common_tags = merge(
    var.additional_tags,
    local.required_tags
  )
}

# Validation: Ensure all required tags are present
# This precondition will fail if any required tag is missing or empty
check "required_tags_validation" {
  assert {
    condition = alltrue([
      local.common_tags["Environment"] != null && local.common_tags["Environment"] != "",
      local.common_tags["Project"] != null && local.common_tags["Project"] != "",
      local.common_tags["ManagedBy"] != null && local.common_tags["ManagedBy"] != "",
      local.common_tags["Phase"] != null && local.common_tags["Phase"] != "",
      local.common_tags["GitRepository"] != null && local.common_tags["GitRepository"] != "",
      local.common_tags["TerraformPath"] != null && local.common_tags["TerraformPath"] != ""
    ])
    error_message = "All required tags must be present and non-empty: Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath."
  }
}

# Network Module
module "network" {
  source = "../network"

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

# VPN Gateway Module
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../vpn-gateway"

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
