provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # Required in azurerm 4.x. Uses var.subscription_id if provided, otherwise falls back to Azure CLI subscription.
  subscription_id = var.subscription_id
}
