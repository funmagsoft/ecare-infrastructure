terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = merge(
    var.tags,
    {
      Module = "network"
    }
  )
}

# AKS Subnet
resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Data Subnet (for Private Endpoints)
resource "azurerm_subnet" "data" {
  name                 = var.data_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.data_subnet_cidr]
}

# Management Subnet
resource "azurerm_subnet" "mgmt" {
  name                 = var.mgmt_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.mgmt_subnet_cidr]
}

# Gateway Subnet (for VPN Gateway)
resource "azurerm_subnet" "gateway" {
  count                = var.enable_vpn_gateway ? 1 : 0
  name                 = "GatewaySubnet" # Fixed name required by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}
