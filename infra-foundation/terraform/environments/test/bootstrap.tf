# ============================================================================
# Bootstrap Module: SP, FIC, RBAC for Terraform Repositories
# ============================================================================
# This module creates Service Principals, Federated Identity Credentials, and RBAC
# role assignments needed for GitHub Actions authentication in Azure.
#
# Note: On first deployment, bootstrap must be created BEFORE running Terraform
# in GitHub Actions. You can:
# 1. Run locally: terraform apply -target=module.bootstrap
# 2. Or use Azure CLI for the first deployment
#
# If bootstrap already exists (created by bash scripts), set
# enable_bootstrap = false in terraform.tfvars.
# ============================================================================
module "bootstrap" {
  count = var.enable_bootstrap ? 1 : 0

  source = "../../modules/bootstrap"

  environment         = var.environment
  phase               = var.phase
  organization_name   = var.organization_name
  organization_for_sa = var.organization_for_sa
  project_name        = var.project_name
  deployment_id       = var.deployment_id

  terraform_repos         = var.terraform_repos
  users_with_state_access = var.users_with_state_access

  tags = var.tags
}
