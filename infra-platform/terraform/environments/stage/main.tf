module "environment" {
  source = "../../modules/environment"

  environment       = var.environment
  deployment_id     = var.deployment_id
  organization_name = var.organization_name
  project_name      = var.project_name

  # Monitoring
  log_analytics_sku            = var.log_analytics_sku
  log_analytics_retention_days = var.log_analytics_retention_days
  application_insights_type    = var.application_insights_type

  # Storage
  storage_account_tier                         = var.storage_account_tier
  storage_replication_type                     = var.storage_replication_type
  storage_containers                           = var.storage_containers
  storage_enable_versioning                    = var.storage_enable_versioning
  storage_enable_soft_delete_blob              = var.storage_enable_soft_delete_blob
  storage_blob_soft_delete_retention_days      = var.storage_blob_soft_delete_retention_days
  storage_enable_soft_delete_container         = var.storage_enable_soft_delete_container
  storage_container_soft_delete_retention_days = var.storage_container_soft_delete_retention_days

  # Key Vault
  key_vault_sku                        = var.key_vault_sku
  key_vault_purge_protection_enabled   = var.key_vault_purge_protection_enabled
  key_vault_soft_delete_retention_days = var.key_vault_soft_delete_retention_days

  # ACR
  acr_sku                     = var.acr_sku
  acr_zone_redundancy_enabled = var.acr_zone_redundancy_enabled
  acr_retention_days          = var.acr_retention_days

  # PostgreSQL
  postgresql_version                      = var.postgresql_version
  postgresql_sku_name                     = var.postgresql_sku_name
  postgresql_storage_mb                   = var.postgresql_storage_mb
  postgresql_backup_retention_days        = var.postgresql_backup_retention_days
  postgresql_geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup_enabled
  postgresql_high_availability_enabled    = var.postgresql_high_availability_enabled
  postgresql_high_availability_mode       = var.postgresql_high_availability_mode
  postgresql_admin_username               = var.postgresql_admin_username
  postgresql_admin_password               = var.postgresql_admin_password

  # Service Bus
  service_bus_sku            = var.service_bus_sku
  service_bus_capacity       = var.service_bus_capacity
  service_bus_zone_redundant = var.service_bus_zone_redundant

  # AKS
  aks_kubernetes_version               = var.aks_kubernetes_version
  aks_sku_tier                         = var.aks_sku_tier
  aks_network_plugin                   = var.aks_network_plugin
  aks_network_policy                   = var.aks_network_policy
  aks_service_cidr                     = var.aks_service_cidr
  aks_dns_service_ip                   = var.aks_dns_service_ip
  aks_system_node_pool_vm_size         = var.aks_system_node_pool_vm_size
  aks_system_node_pool_node_count      = var.aks_system_node_pool_node_count
  aks_system_node_pool_os_disk_size_gb = var.aks_system_node_pool_os_disk_size_gb
  aks_user_node_pool_enabled           = var.aks_user_node_pool_enabled
  aks_user_node_pool_vm_size           = var.aks_user_node_pool_vm_size
  aks_user_node_pool_min_count         = var.aks_user_node_pool_min_count
  aks_user_node_pool_max_count         = var.aks_user_node_pool_max_count
  aks_user_node_pool_os_disk_size_gb   = var.aks_user_node_pool_os_disk_size_gb
  aks_enable_auto_scaling              = var.aks_enable_auto_scaling
  aks_oidc_issuer_enabled              = var.aks_oidc_issuer_enabled
  aks_workload_identity_enabled        = var.aks_workload_identity_enabled
  aks_azure_policy_enabled             = var.aks_azure_policy_enabled
  aks_enable_container_insights        = var.aks_enable_container_insights

  # Bastion
  bastion_vm_size                = var.bastion_vm_size
  bastion_admin_username         = var.bastion_admin_username
  bastion_ubuntu_sku             = var.bastion_ubuntu_sku
  bastion_allowed_ssh_source_ips = var.bastion_allowed_ssh_source_ips
  bastion_additional_users       = var.bastion_additional_users

  # Tags
  tags = var.tags
}
