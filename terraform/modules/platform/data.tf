# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

# Data source: Read outputs from Phase 1 (infra-foundation)
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${var.project_name}-${var.environment}"
    storage_account_name = "tfstatehycomecare${var.environment}"
    container_name       = "tfstate"
    key                  = "infra-foundation/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Data source: Current Azure client configuration
data "azurerm_client_config" "current" {}
