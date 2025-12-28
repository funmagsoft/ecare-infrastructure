terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}

  # subscription_id is not set - Terraform will use the active subscription from Azure CLI
  # Use 'az account set --subscription <subscription-id>' to switch subscriptions
}
