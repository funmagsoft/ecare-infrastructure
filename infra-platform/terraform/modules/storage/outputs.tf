output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.this.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "storage_account_primary_file_endpoint" {
  description = "Primary file endpoint of the Storage Account"
  value       = azurerm_storage_account.this.primary_file_endpoint
}

output "storage_account_primary_access_key" {
  description = "Primary access key of the Storage Account"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string of the Storage Account"
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "container_names" {
  description = "Names of created containers"
  value       = [for c in azurerm_storage_container.containers : c.name]
}

output "blob_private_endpoint_id" {
  description = "ID of the Blob Private Endpoint"
  value       = azurerm_private_endpoint.blob.id
}

output "blob_private_endpoint_ip" {
  description = "Private IP address of the Blob Private Endpoint"
  value       = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}

output "file_private_endpoint_id" {
  description = "ID of the File Private Endpoint"
  value       = azurerm_private_endpoint.file.id
}

output "file_private_endpoint_ip" {
  description = "Private IP address of the File Private Endpoint"
  value       = azurerm_private_endpoint.file.private_service_connection[0].private_ip_address
}

output "blob_private_dns_zone_id" {
  description = "ID of the Private DNS Zone for Blob Storage"
  value       = azurerm_private_dns_zone.blob.id
}

output "file_private_dns_zone_id" {
  description = "ID of the Private DNS Zone for File Storage"
  value       = azurerm_private_dns_zone.file.id
}
