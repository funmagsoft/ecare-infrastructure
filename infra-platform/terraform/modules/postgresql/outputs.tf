output "postgresql_server_id" {
  description = "ID of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.this.id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.this.name
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgresql_administrator_login" {
  description = "Administrator login of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "postgresql_administrator_password" {
  description = "Administrator password of the PostgreSQL Flexible Server"
  value       = var.administrator_password
  sensitive   = true
}

output "private_endpoint_id" {
  description = "ID of the Private Endpoint"
  value       = azurerm_private_endpoint.this.id
}

output "private_endpoint_ip" {
  description = "Private IP address of the Private Endpoint"
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

output "private_dns_zone_id" {
  description = "ID of the Private DNS Zone for PostgreSQL"
  value       = azurerm_private_dns_zone.this.id
}
