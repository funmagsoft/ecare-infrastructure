provider "azurerm" {
  features {}

  # Required in azurerm 4.x. Uses var.subscription_id if provided, otherwise falls back to Azure CLI subscription.
  subscription_id = var.subscription_id
}

provider "azuread" {
  # Uses Azure CLI authentication by default
}
