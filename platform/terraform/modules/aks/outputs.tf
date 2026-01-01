output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.fqdn
}

output "aks_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "aks_kube_config_admin" {
  description = "Admin kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_admin_config_raw
  sensitive   = true
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "aks_kubelet_identity_client_id" {
  description = "Client ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL (for Workload Identity)"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "aks_node_resource_group" {
  description = "Resource group containing AKS node resources"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "aks_principal_id" {
  description = "Principal ID of the AKS system-assigned identity"
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "user_node_pool_id" {
  description = "ID of the user node pool"
  value       = try(azurerm_kubernetes_cluster_node_pool.user[0].id, null)
}
