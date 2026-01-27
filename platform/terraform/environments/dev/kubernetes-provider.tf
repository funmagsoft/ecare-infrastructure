#------------------------------------------------------------------------------
# Kubernetes Provider Configuration
#------------------------------------------------------------------------------
# Note: Kubernetes provider must be configured in root module (not in child modules)
# This provider is configured after AKS cluster is created to enable Kubernetes resources

provider "kubernetes" {
  host                   = module.environment.aks_host
  client_certificate     = base64decode(module.environment.aks_client_certificate)
  client_key             = base64decode(module.environment.aks_client_key)
  cluster_ca_certificate = base64decode(module.environment.aks_cluster_ca_certificate)
}
