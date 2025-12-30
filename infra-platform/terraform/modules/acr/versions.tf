# Terraform version and provider requirements
# Note: Provider configuration (provider block) is in the root module (environments/*/providers.tf)
# This module inherits the provider configuration from the root module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}
