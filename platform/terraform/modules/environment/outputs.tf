#------------------------------------------------------------------------------
# Monitoring Outputs
#------------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = module.monitoring.application_insights_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = module.monitoring.application_insights_name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key for Application Insights"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection String for Application Insights"
  value       = module.monitoring.application_insights_connection_string
  sensitive   = true
}

#------------------------------------------------------------------------------
# Storage Outputs
#------------------------------------------------------------------------------

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = module.storage.storage_account_id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.storage.storage_account_primary_blob_endpoint
}

#------------------------------------------------------------------------------
# Key Vault Outputs
#------------------------------------------------------------------------------

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.key_vault.key_vault_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.key_vault_uri
}

#------------------------------------------------------------------------------
# ACR Outputs
#------------------------------------------------------------------------------

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.acr.acr_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = module.acr.acr_login_server
}

#------------------------------------------------------------------------------
# PostgreSQL Outputs
#------------------------------------------------------------------------------

output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = module.postgresql.postgresql_server_id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.postgresql.postgresql_server_name
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.postgresql.postgresql_fqdn
}

output "postgresql_administrator_login" {
  description = "Administrator login for PostgreSQL"
  value       = module.postgresql.postgresql_administrator_login
}

#------------------------------------------------------------------------------
# Service Bus Outputs
#------------------------------------------------------------------------------

output "servicebus_namespace_id" {
  description = "ID of the Service Bus Namespace"
  value       = module.service_bus.servicebus_namespace_id
}

output "servicebus_namespace_name" {
  description = "Name of the Service Bus Namespace"
  value       = module.service_bus.servicebus_namespace_name
}

output "servicebus_endpoint" {
  description = "Endpoint of the Service Bus Namespace"
  value       = module.service_bus.servicebus_endpoint
}

#------------------------------------------------------------------------------
# AKS Outputs
#------------------------------------------------------------------------------

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_cluster_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_cluster_name
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.aks_fqdn
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity"
  value       = module.aks.aks_kubelet_identity_object_id
}

output "aks_kubelet_identity_client_id" {
  description = "Client ID of the AKS kubelet identity"
  value       = module.aks.aks_kubelet_identity_client_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL for AKS (for Workload Identity in Phase 3)"
  value       = module.aks.aks_oidc_issuer_url
}

output "aks_kube_config" {
  description = "Kubeconfig for AKS cluster (for Kubernetes provider)"
  value       = module.aks.aks_kube_config
  sensitive   = true
}

output "aks_host" {
  description = "Kubernetes API server host"
  value       = module.aks.aks_host
  sensitive   = true
}

output "aks_client_certificate" {
  description = "Kubernetes client certificate"
  value       = module.aks.aks_client_certificate
  sensitive   = true
}

output "aks_client_key" {
  description = "Kubernetes client key"
  value       = module.aks.aks_client_key
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = module.aks.aks_cluster_ca_certificate
  sensitive   = true
}

output "aks_namespace_names" {
  description = "Names of the shared AKS namespaces for workloads"
  value       = module.aks_namespace.namespace_names
}

output "aks_node_resource_group" {
  description = "Resource group containing AKS node resources"
  value       = module.aks.aks_node_resource_group
}

#------------------------------------------------------------------------------
# Bastion Outputs
#------------------------------------------------------------------------------

output "bastion_vm_id" {
  description = "ID of the Bastion VM"
  value       = module.bastion.bastion_vm_id
}

output "bastion_vm_name" {
  description = "Name of the Bastion VM"
  value       = module.bastion.bastion_vm_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion VM"
  value       = module.bastion.bastion_public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the Bastion VM"
  value       = module.bastion.bastion_private_ip
}

output "bastion_admin_username" {
  description = "Admin username for Bastion VM"
  value       = module.bastion.bastion_admin_username
}

output "bastion_ssh_private_key" {
  description = "SSH private key for Bastion VM (if generated)"
  value       = module.bastion.bastion_ssh_private_key
  sensitive   = true
}

output "bastion_principal_id" {
  description = "Principal ID of the Bastion VM system-assigned identity"
  value       = module.bastion.bastion_principal_id
}

#------------------------------------------------------------------------------
# Summary Output
#------------------------------------------------------------------------------

output "deployment_id" {
  description = "Unique deployment identifier for cleanup operations"
  value       = var.deployment_id
}

output "deployment_summary" {
  description = "Summary of deployed platform resources"
  value = {
    environment          = var.environment
    deployment_id        = var.deployment_id
    aks_cluster          = module.aks.aks_cluster_name
    aks_oidc_issuer      = module.aks.aks_oidc_issuer_url
    acr_login_server     = module.acr.acr_login_server
    postgresql_fqdn      = module.postgresql.postgresql_fqdn
    key_vault_uri        = module.key_vault.key_vault_uri
    storage_account      = module.storage.storage_account_name
    servicebus_namespace = module.service_bus.servicebus_namespace_name
    bastion_public_ip    = module.bastion.bastion_public_ip
    log_analytics        = module.monitoring.log_analytics_workspace_name
  }
}
