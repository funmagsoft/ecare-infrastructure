# Re-export outputs from the platform module
#------------------------------------------------------------------------------
# Monitoring Outputs
#------------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.platform.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.platform.log_analytics_workspace_name
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = module.platform.application_insights_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = module.platform.application_insights_name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key for Application Insights"
  value       = module.platform.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection String for Application Insights"
  value       = module.platform.application_insights_connection_string
  sensitive   = true
}

#------------------------------------------------------------------------------
# Storage Outputs
#------------------------------------------------------------------------------

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = module.platform.storage_account_id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.platform.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.platform.storage_account_primary_blob_endpoint
}

#------------------------------------------------------------------------------
# Key Vault Outputs
#------------------------------------------------------------------------------

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.platform.key_vault_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.platform.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.platform.key_vault_uri
}

#------------------------------------------------------------------------------
# ACR Outputs
#------------------------------------------------------------------------------

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.platform.acr_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.platform.acr_name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = module.platform.acr_login_server
}

#------------------------------------------------------------------------------
# PostgreSQL Outputs
#------------------------------------------------------------------------------

output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = module.platform.postgresql_server_id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.platform.postgresql_server_name
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.platform.postgresql_fqdn
}

output "postgresql_administrator_login" {
  description = "Administrator login for PostgreSQL"
  value       = module.platform.postgresql_administrator_login
}

#------------------------------------------------------------------------------
# Service Bus Outputs
#------------------------------------------------------------------------------

output "servicebus_namespace_id" {
  description = "ID of the Service Bus Namespace"
  value       = module.platform.servicebus_namespace_id
}

output "servicebus_namespace_name" {
  description = "Name of the Service Bus Namespace"
  value       = module.platform.servicebus_namespace_name
}

output "servicebus_endpoint" {
  description = "Endpoint of the Service Bus Namespace"
  value       = module.platform.servicebus_endpoint
}

#------------------------------------------------------------------------------
# AKS Outputs
#------------------------------------------------------------------------------

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.platform.aks_cluster_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.platform.aks_cluster_name
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.platform.aks_fqdn
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity"
  value       = module.platform.aks_kubelet_identity_object_id
}

output "aks_kubelet_identity_client_id" {
  description = "Client ID of the AKS kubelet identity"
  value       = module.platform.aks_kubelet_identity_client_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL for AKS (for Workload Identity in Phase 3)"
  value       = module.platform.aks_oidc_issuer_url
}

output "aks_namespace_name" {
  description = "Name of the shared AKS namespace for workloads"
  value       = module.platform.aks_namespace_name
}

output "aks_node_resource_group" {
  description = "Resource group containing AKS node resources"
  value       = module.platform.aks_node_resource_group
}

#------------------------------------------------------------------------------
# Bastion Outputs
#------------------------------------------------------------------------------

output "bastion_vm_id" {
  description = "ID of the Bastion VM"
  value       = module.platform.bastion_vm_id
}

output "bastion_vm_name" {
  description = "Name of the Bastion VM"
  value       = module.platform.bastion_vm_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion VM"
  value       = module.platform.bastion_public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the Bastion VM"
  value       = module.platform.bastion_private_ip
}

output "bastion_admin_username" {
  description = "Admin username for Bastion VM"
  value       = module.platform.bastion_admin_username
}

output "bastion_ssh_private_key" {
  description = "SSH private key for Bastion VM (if generated)"
  value       = module.platform.bastion_ssh_private_key
  sensitive   = true
}

#------------------------------------------------------------------------------
# Summary Output
#------------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of deployed platform resources"
  value       = module.platform.deployment_summary
}
