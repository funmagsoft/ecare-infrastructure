output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.name
}

output "public_ip_address" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn.ip_address
}
