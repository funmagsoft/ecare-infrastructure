# Local variables
locals {
  environment = "stage"
  project     = "ecare"
  location    = data.azurerm_resource_group.main.location

  common_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
  }
}
