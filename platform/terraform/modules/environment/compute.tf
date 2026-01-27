#------------------------------------------------------------------------------
# Module: AKS Cluster (with Workload Identity)
#------------------------------------------------------------------------------

module "aks" {
  source = "../aks"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  kubernetes_version = var.aks_kubernetes_version
  sku_tier           = var.aks_sku_tier

  # Network configuration
  vnet_subnet_id = local.aks_subnet_id
  network_plugin = var.aks_network_plugin
  network_policy = var.aks_network_policy
  service_cidr   = var.aks_service_cidr
  dns_service_ip = var.aks_dns_service_ip

  # System node pool
  system_node_pool_vm_size         = var.aks_system_node_pool_vm_size
  system_node_pool_node_count      = var.aks_system_node_pool_node_count
  system_node_pool_os_disk_size_gb = var.aks_system_node_pool_os_disk_size_gb

  # User node pool
  user_node_pool_enabled         = var.aks_user_node_pool_enabled
  user_node_pool_vm_size         = var.aks_user_node_pool_vm_size
  user_node_pool_min_count       = var.aks_user_node_pool_min_count
  user_node_pool_max_count       = var.aks_user_node_pool_max_count
  user_node_pool_os_disk_size_gb = var.aks_user_node_pool_os_disk_size_gb
  user_node_pool_node_count      = var.aks_user_node_pool_node_count
  auto_scaling_enabled           = var.aks_auto_scaling_enabled

  # Features
  oidc_issuer_enabled       = var.aks_oidc_issuer_enabled
  workload_identity_enabled = var.aks_workload_identity_enabled
  azure_policy_enabled      = var.aks_azure_policy_enabled

  # Monitoring
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_container_insights  = var.aks_enable_container_insights

  tags = local.common_tags

  aks_admin_group_object_ids = var.aks_admin_group_object_ids

  depends_on = [
    module.monitoring
  ]
}

#------------------------------------------------------------------------------
# Module: AKS Namespace
#------------------------------------------------------------------------------
# Note: Kubernetes provider configuration must be in root module (environments/*/)
# as providers cannot be configured in child modules

module "aks_namespace" {
  source = "../aks-namespace"

  namespace    = "ecare"
  environment  = var.environment
  project_name = var.project_name
  labels = {
    "app.kubernetes.io/name"       = "ecare"
    "app.kubernetes.io/env"        = var.environment
    "app.kubernetes.io/part-of"    = var.project_name
    "app.kubernetes.io/managed-by" = "terraform"
  }

  depends_on = [module.aks]
}

#------------------------------------------------------------------------------
# Module: Bastion VM (with tools)
#------------------------------------------------------------------------------

module "bastion" {
  source = "../bastion"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name

  subnet_id      = local.mgmt_subnet_id
  vm_size        = var.bastion_vm_size
  admin_username = var.bastion_admin_username
  ubuntu_sku     = var.bastion_ubuntu_sku

  allowed_ssh_source_ips          = var.bastion_allowed_ssh_source_ips
  additional_users                = var.bastion_additional_users
  enable_system_assigned_identity = true
  install_tools                   = true

  tags = local.common_tags
}
