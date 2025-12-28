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

# Subnets Configuration
locals {
  subnets = {
    aks = {
      name             = var.aks_subnet_name
      address_prefixes = [var.aks_subnet_cidr]
      nsg_id           = azurerm_network_security_group.aks.id
    }
    data = {
      name             = var.data_subnet_name
      address_prefixes = [var.data_subnet_cidr]
      nsg_id           = azurerm_network_security_group.data.id
    }
    mgmt = {
      name             = var.mgmt_subnet_name
      address_prefixes = [var.mgmt_subnet_cidr]
      nsg_id           = azurerm_network_security_group.mgmt.id
    }
  }
}

# Create subnets using for_each
resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = each.value.nsg_id
}

# Gateway Subnet (for VPN Gateway)
# Gateway subnet remains separate due to special requirements (fixed name "GatewaySubnet")
resource "azurerm_subnet" "gateway" {
  count                = var.enable_vpn_gateway ? 1 : 0
  name                 = "GatewaySubnet" # Fixed name required by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}
