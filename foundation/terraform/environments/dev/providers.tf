provider "azurerm" {
  features {}

  # Required in azurerm 4.x. If var.subscription_id is null, ARM_SUBSCRIPTION_ID environment variable must be set.
  subscription_id = var.subscription_id
}

provider "azuread" {
  # Uses Azure CLI authentication by default
}
