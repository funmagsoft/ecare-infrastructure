module "environment" {
  source = "../../modules/environment"

  environment       = var.environment
  project_name      = var.project_name
  organization_name = var.organization_name

  services = local.services
}

