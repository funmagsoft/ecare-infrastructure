output "bastion_vm_id" {
  description = "ID of the Bastion VM"
  value       = azurerm_linux_virtual_machine.this.id
}

output "bastion_vm_name" {
  description = "Name of the Bastion VM"
  value       = azurerm_linux_virtual_machine.this.name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion VM"
  value       = azurerm_public_ip.this.ip_address
}

output "bastion_private_ip" {
  description = "Private IP address of the Bastion VM"
  value       = azurerm_network_interface.this.private_ip_address
}

output "bastion_admin_username" {
  description = "Admin username for Bastion VM"
  value       = var.admin_username
}

output "bastion_ssh_private_key" {
  description = "SSH private key for Bastion VM (if generated)"
  value       = try(tls_private_key.ssh[0].private_key_pem, null)
  sensitive   = true
}

output "bastion_ssh_public_key" {
  description = "SSH public key for Bastion VM"
  value       = local.ssh_public_key
}

output "bastion_principal_id" {
  description = "Principal ID of the Bastion VM system-assigned identity"
  value       = try(azurerm_linux_virtual_machine.this.identity[0].principal_id, null)
}

output "bastion_nsg_id" {
  description = "ID of the Bastion NSG"
  value       = azurerm_network_security_group.this.id
}

output "bastion_cloud_init_script" {
  description = "Generated cloud-init script (decoded, for debugging)"
  value       = local.cloud_init_script
  sensitive   = false
}

output "bastion_cloud_init_base64" {
  description = "Generated cloud-init script (base64 encoded, as sent to Azure)"
  value       = local.cloud_init_script != null ? base64encode(local.cloud_init_script) : null
  sensitive   = false
}
