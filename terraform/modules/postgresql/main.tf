terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "this" {
  name                = "psql-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  version      = var.postgresql_version
  sku_name     = var.sku_name
  storage_mb   = var.storage_mb
  storage_tier = "P30"

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  public_network_access_enabled = var.public_network_access_enabled

  # Note: Not using delegated_subnet_id to avoid subnet delegation requirements
  # Using Private Endpoint instead for network isolation

  # High Availability
  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []
    content {
      mode = var.high_availability_mode
    }
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "postgresql"
    }
  )

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone
    ]
  }
}

# PostgreSQL Configuration - commented out to avoid restart conflicts during initial deployment
# Can be applied later via Azure Portal or az cli
# resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
#   name      = "require_secure_transport"
#   server_id = azurerm_postgresql_flexible_server.this.id
#   value     = "off"
# }
#
# resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
#   name      = "max_connections"
#   server_id = azurerm_postgresql_flexible_server.this.id
#   value     = "100"
# }

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "postgresql"
    }
  )
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = var.vnet_id != null && var.vnet_name != null ? 1 : 0

  name                  = "${var.vnet_name}-postgresql-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "postgresql"
    }
  )
}

# Private Endpoint for PostgreSQL
resource "azurerm_private_endpoint" "this" {
  name                = "${azurerm_postgresql_flexible_server.this.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${azurerm_postgresql_flexible_server.this.name}-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "postgresql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "postgresql"
    }
  )
}
