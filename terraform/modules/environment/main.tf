terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}

  # subscription_id is not set - Terraform will use the active subscription from Azure CLI
  # Use 'az account set --subscription <subscription-id>' to switch subscriptions
}

# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Local variables
locals {
  environment = var.environment
  project     = var.project
  location    = data.azurerm_resource_group.main.location

  common_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
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
