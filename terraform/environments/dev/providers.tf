terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.44"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}

  # subscription_id is not set - Terraform will use the active subscription from Azure CLI
  # Use 'az account set --subscription <subscription-id>' to switch subscriptions
}

provider "azuread" {
  # Uses Azure CLI authentication by default
  # Make sure you're logged in: az login
}
