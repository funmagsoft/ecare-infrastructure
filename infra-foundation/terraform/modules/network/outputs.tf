output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.subnets["aks"].id
}

output "data_subnet_id" {
  description = "ID of the Data subnet"
  value       = azurerm_subnet.subnets["data"].id
}

output "mgmt_subnet_id" {
  description = "ID of the Management subnet"
  value       = azurerm_subnet.subnets["mgmt"].id
}

output "gateway_subnet_id" {
  description = "ID of the Gateway subnet (if enabled)"
  value       = var.enable_vpn_gateway ? azurerm_subnet.gateway[0].id : null
}

output "aks_nsg_id" {
  description = "ID of the NSG for AKS subnet"
  value       = azurerm_network_security_group.aks.id
}

output "data_nsg_id" {
  description = "ID of the NSG for Data subnet"
  value       = azurerm_network_security_group.data.id
}

output "mgmt_nsg_id" {
  description = "ID of the NSG for Management subnet"
  value       = azurerm_network_security_group.mgmt.id
}
