#------------------------------------------------------------------------------
# Local Variables
#------------------------------------------------------------------------------

# Local variables for Storage Account naming
locals {
  # Create deterministic hash from org+project+env+location
  # Using MD5 hash and taking first 4 characters for uniqueness
  name_hash = substr(
    md5("${lower(var.organization_name)}${lower(var.project_name)}${lower(var.environment)}${lower(var.location)}"),
    0,
    4
  )

  # Format: st{org}{project}{env}{hash}
  # Example: sthycomecaredev1a2b (20 characters)
  storage_account_name = "st${lower(var.organization_name)}${lower(var.project_name)}${lower(var.environment)}${local.name_hash}"
}

# Storage Account
resource "azurerm_storage_account" "this" {
  name                       = local.storage_account_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  account_tier               = var.account_tier
  account_replication_type   = var.account_replication_type
  min_tls_version            = var.min_tls_version
  https_traffic_only_enabled = var.enable_https_traffic_only

  # Network access configuration
  # NOTE: public_network_access_enabled is set to true during initial deployment to allow Terraform
  # to manage the storage account. Private Endpoints are configured below for secure access.
  # In production, consider restricting public access after initial deployment via network_rules.
  public_network_access_enabled = true

  # Network rules commented out during initial deployment to allow Terraform access
  # Can be enabled after deployment via separate configuration
  # network_rules {
  #   default_action = "Deny"
  #   bypass         = ["AzureServices"]
  # }

  # Blob properties
  blob_properties {
    versioning_enabled = var.enable_versioning

    dynamic "delete_retention_policy" {
      for_each = var.enable_soft_delete_blob ? [1] : []
      content {
        days = var.blob_soft_delete_retention_days
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = var.enable_soft_delete_container ? [1] : []
      content {
        days = var.container_soft_delete_retention_days
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

# Storage Containers
resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.containers)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

# Private DNS Zone for Blob Storage
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

# Private DNS Zone for File Storage
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

# Link Private DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  count = var.vnet_id != null && var.vnet_name != null ? 1 : 0

  name                  = "${var.vnet_name}-blob-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  count = var.vnet_id != null && var.vnet_name != null ? 1 : 0

  name                  = "${var.vnet_name}-file-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

# Private Endpoint for Blob
resource "azurerm_private_endpoint" "blob" {
  name                = "${azurerm_storage_account.this.name}-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_storage_account.this.name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}

# Private Endpoint for File
resource "azurerm_private_endpoint" "file" {
  name                = "${azurerm_storage_account.this.name}-file-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_storage_account.this.name}-file-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "file-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }

  tags = merge(
    var.tags,
    {
      Module = "storage"
    }
  )
}
