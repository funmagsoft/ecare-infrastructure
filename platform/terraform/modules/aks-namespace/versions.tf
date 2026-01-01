# Terraform version and provider requirements
# Note: Provider configuration (provider block) is in the root module (environments/*/kubernetes-provider.tf)
# This module inherits the provider configuration from the root module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}
