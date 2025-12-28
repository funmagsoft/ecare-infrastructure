terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    # Environment-specific configuration
    # Update these values when setting up a new environment
    resource_group_name  = "rg-ecare-stage"
    storage_account_name = "tfstatehycomecarestage"
    container_name       = "tfstate"
    key                  = "infra-platform/terraform.tfstate"
    use_azuread_auth     = true
  }
}
