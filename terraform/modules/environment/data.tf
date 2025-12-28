# Remote state: infra-foundation
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

# Remote state: infra-platform
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${var.project_name}-${var.environment}"
    storage_account_name = "tfstatehycomecare${var.environment}"
    container_name       = "tfstate"
    key                  = "infra-platform/terraform.tfstate"
    use_azuread_auth     = true
  }
}

data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

