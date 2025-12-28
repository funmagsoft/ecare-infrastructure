terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vpn_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  vpn_client_configuration {
    address_space        = [var.vpn_client_address_space]
    vpn_client_protocols = ["OpenVPN"]

    root_certificate {
      name             = var.vpn_root_cert_name
      public_cert_data = var.vpn_root_cert_data
    }
  }

  tags = var.tags
}
