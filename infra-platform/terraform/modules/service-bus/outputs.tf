output "servicebus_namespace_id" {
  description = "ID of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.this.id
}

output "servicebus_namespace_name" {
  description = "Name of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.this.name
}

output "servicebus_endpoint" {
  description = "Endpoint of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.this.endpoint
}

output "servicebus_primary_connection_string" {
  description = "Primary connection string of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive   = true
}

output "servicebus_primary_key" {
  description = "Primary key of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.this.default_primary_key
  sensitive   = true
}

output "private_endpoint_id" {
  description = "ID of the Private Endpoint (Premium SKU only)"
  value       = try(azurerm_private_endpoint.this[0].id, null)
}

output "private_endpoint_ip" {
  description = "Private IP address of the Private Endpoint (Premium SKU only)"
  value       = try(azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address, null)
}

output "private_dns_zone_id" {
  description = "ID of the Private DNS Zone for Service Bus (Premium SKU only, null for non-Premium)"
  value       = var.sku == "Premium" ? azurerm_private_dns_zone.this[0].id : null
}
