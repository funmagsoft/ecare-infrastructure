module "environment" {
  source = "../../modules/environment"

  environment  = var.environment
  project_name = var.project_name

  services     = var.services
  gitops_repos = var.gitops_repos

  additional_tags = var.additional_tags
}
