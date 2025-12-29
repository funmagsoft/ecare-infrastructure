provider "azurerm" {
  features {}

  # Optional: recommended in CI/CD
  subscription_id = var.subscription_id
}

provider "azuread" {
  # Uses Azure CLI authentication by default
}


