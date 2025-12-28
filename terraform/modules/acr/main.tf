terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "this" {
  name                          = "acr${var.project_name}${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access_enabled
  zone_redundancy_enabled       = var.zone_redundancy_enabled

  # Network rule set (deny public access)
  network_rule_set {
    default_action = "Allow"
  }

  # Retention policy (Premium SKU only)
  dynamic "retention_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      days    = var.retention_days
      enabled = true
    }
  }

  # Trust policy (Premium SKU only)
  dynamic "trust_policy" {
    for_each = var.sku == "Premium" && var.trust_policy_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "acr"
    }
  )
}

# Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "acr"
    }
  )
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = var.vnet_id != null && var.vnet_name != null ? 1 : 0

  name                  = "${var.vnet_name}-acr-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "acr"
    }
  )
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "this" {
  name                = "${azurerm_container_registry.this.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_container_registry.this.name}-psc"
    private_connection_resource_id = azurerm_container_registry.this.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "registry-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "acr"
    }
  )
}
