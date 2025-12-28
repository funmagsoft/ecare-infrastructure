terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "this" {
  name                         = "sb-${var.project_name}-${var.environment}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = var.sku
  capacity                     = var.sku == "Premium" ? var.capacity : null
  premium_messaging_partitions = var.sku == "Premium" && var.zone_redundant ? 1 : 0
  # Premium SKU: use private endpoint only (public_network_access_enabled = false)
  # Non-Premium SKU: use public endpoint only (public_network_access_enabled = true)
  public_network_access_enabled = var.sku == "Premium" ? false : true
  minimum_tls_version           = var.minimum_tls_version

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "service-bus"
    }
  )
}

# Private DNS Zone for Service Bus (Premium SKU only)
resource "azurerm_private_dns_zone" "this" {
  count = var.sku == "Premium" ? 1 : 0

  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "service-bus"
    }
  )
}

# Link Private DNS Zone to VNet (Premium SKU only)
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = var.sku == "Premium" && var.vnet_id != null && var.vnet_name != null ? 1 : 0

  name                  = "${var.vnet_name}-servicebus-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "service-bus"
    }
  )
}

# Private Endpoint for Service Bus (Premium SKU only)
resource "azurerm_private_endpoint" "this" {
  count = var.sku == "Premium" ? 1 : 0

  name                = "${azurerm_servicebus_namespace.this.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_servicebus_namespace.this.name}-psc"
    private_connection_resource_id = azurerm_servicebus_namespace.this.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "servicebus-dns-zone-group"
    private_dns_zone_ids = var.sku == "Premium" ? [azurerm_private_dns_zone.this[0].id] : []
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "service-bus"
    }
  )
}
