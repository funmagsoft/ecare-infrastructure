#------------------------------------------------------------------------------
# Kubernetes Provider Configuration
#------------------------------------------------------------------------------
# Note: Kubernetes provider must be configured in root module (not in child modules)
# This provider is configured after AKS cluster is created to enable Kubernetes resources

# Get AKS kube config from platform remote state
data "terraform_remote_state" "platform_for_kube" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-${var.project_name}-${var.environment}"
    storage_account_name = "tfstatehycomecare${var.environment}"
    container_name       = "tfstate"
    key                  = "platform/terraform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  aks_kube_config = yamldecode(data.terraform_remote_state.platform_for_kube.outputs.aks_kube_config)
}

provider "kubernetes" {
  host                   = local.aks_kube_config["clusters"][0]["cluster"]["server"]
  client_certificate     = base64decode(local.aks_kube_config["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(local.aks_kube_config["users"][0]["user"]["client-key-data"])
  cluster_ca_certificate = base64decode(local.aks_kube_config["clusters"][0]["cluster"]["certificate-authority-data"])
}
