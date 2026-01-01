module "environment" {
  source = "../../modules/environment"

  environment   = var.environment
  phase         = var.phase
  project_name  = var.project_name
  deployment_id = var.deployment_id

  services     = var.services
  gitops_repos = var.gitops_repos

  tags = var.tags
}
