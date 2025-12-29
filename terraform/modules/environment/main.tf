# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}-${var.environment}"
}

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

# Local variables
locals {
  # Required tags - these must always be present
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Phase         = "WorkloadIdentity"
    GitRepository = "infra-identity"
    TerraformPath = "terraform/environments/${var.environment}"
  }

  # Merge required tags with additional tags
  # Required tags take precedence (merge order: additional_tags first, then required_tags)
  common_tags = merge(
    var.additional_tags,
    local.required_tags
  )

  # Expand services with resource IDs from platform remote state
  services_expanded = {
    for name, cfg in var.services :
    name => merge(cfg, {
      key_vault_id             = cfg.enable_key_vault_access ? data.terraform_remote_state.platform.outputs.key_vault_id : null
      storage_account_id       = cfg.enable_storage_access ? data.terraform_remote_state.platform.outputs.storage_account_id : null
      service_bus_namespace_id = cfg.enable_service_bus_access ? data.terraform_remote_state.platform.outputs.service_bus_namespace_id : null
    })
  }
}

# Validation: Ensure all required tags are present
# This precondition will fail if any required tag is missing or empty
check "required_tags_validation" {
  assert {
    condition = alltrue([
      trimspace(local.common_tags["Environment"]) != "",
      trimspace(local.common_tags["Project"]) != "",
      trimspace(local.common_tags["ManagedBy"]) != "",
      trimspace(local.common_tags["Phase"]) != "",
      trimspace(local.common_tags["GitRepository"]) != "",
      trimspace(local.common_tags["TerraformPath"]) != ""
    ])
    error_message = "All required tags must be present and non-empty (after trimming whitespace): Environment, Project, ManagedBy, Phase, GitRepository, TerraformPath."
  }
}

# GitHub OIDC Azure Integration Module
# Creates Service Principal and FIC for service repositories to build images and deploy to AKS
module "github_oidc_integration" {
  source = "../github-oidc"

  environment         = var.environment
  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.main.name

  acr_id = data.terraform_remote_state.platform.outputs.acr_id
  aks_id = data.terraform_remote_state.platform.outputs.aks_cluster_id

  # Extract service repositories for GitHub OIDC (repo and branch)
  service_repos = {
    for name, cfg in var.services :
    name => {
      repo   = cfg.repo
      branch = lookup(cfg, "branch", "main")
    }
  }

  # GitOps repositories for environment-based OIDC integration
  gitops_repos = var.gitops_repos

  enable_aks_rbac_writer = true

  tags = local.common_tags
}

# Workload Identity Module
# Creates UAMI and FIC for AKS pods to access Azure resources (Key Vault, Storage, Service Bus)
module "workload_identity" {
  for_each = local.services_expanded

  source = "../workload-identity"

  project_name        = var.project_name
  service_name        = each.key
  environment         = var.environment
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  namespace       = data.terraform_remote_state.platform.outputs.aks_namespace_name
  aks_oidc_issuer = data.terraform_remote_state.platform.outputs.aks_oidc_issuer_url

  enable_key_vault_access   = lookup(each.value, "enable_key_vault_access", false)
  enable_storage_access     = lookup(each.value, "enable_storage_access", false)
  enable_service_bus_access = lookup(each.value, "enable_service_bus_access", false)

  key_vault_id             = each.value.key_vault_id
  storage_account_id       = each.value.storage_account_id
  service_bus_namespace_id = each.value.service_bus_namespace_id

  additional_roles = lookup(each.value, "additional_roles", [])

  tags = local.common_tags
}

