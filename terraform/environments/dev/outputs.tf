# ============================================================================
# Bootstrap Outputs
# ============================================================================
output "bootstrap_service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions"
  value       = var.enable_bootstrap ? module.bootstrap[0].service_principal_app_id : null
}

output "bootstrap_service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions"
  value       = var.enable_bootstrap ? module.bootstrap[0].service_principal_object_id : null
}

output "bootstrap_federated_identity_credentials" {
  description = "Map of repository names to their Federated Identity Credential IDs"
  value       = var.enable_bootstrap ? module.bootstrap[0].federated_identity_credentials : null
}

# ============================================================================
# Environment Outputs
# ============================================================================
# Re-export outputs from the environment module
output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.environment.vnet_id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.environment.vnet_name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.environment.aks_subnet_id
}

output "data_subnet_id" {
  description = "ID of the Data subnet"
  value       = module.environment.data_subnet_id
}

output "mgmt_subnet_id" {
  description = "ID of the Management subnet"
  value       = module.environment.mgmt_subnet_id
}

output "gateway_subnet_id" {
  description = "ID of the Gateway subnet"
  value       = module.environment.gateway_subnet_id
}

output "aks_nsg_id" {
  description = "ID of the AKS NSG"
  value       = module.environment.aks_nsg_id
}

output "data_nsg_id" {
  description = "ID of the Data NSG"
  value       = module.environment.data_nsg_id
}

output "mgmt_nsg_id" {
  description = "ID of the Management NSG"
  value       = module.environment.mgmt_nsg_id
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = module.environment.vpn_gateway_id
}

output "vpn_public_ip" {
  description = "Public IP address of VPN Gateway"
  value       = module.environment.vpn_public_ip
}
