#------------------------------------------------------------------------------
# SSH Key Generation
#------------------------------------------------------------------------------

# Generate SSH key if not provided
resource "tls_private_key" "ssh" {
  count = var.admin_ssh_public_key == null ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  ssh_public_key = var.admin_ssh_public_key != null ? var.admin_ssh_public_key : tls_private_key.ssh[0].public_key_openssh

  cloud_init_script = var.install_tools ? templatefile("${path.module}/scripts/cloud-init.tpl", {
    environment      = var.environment
    admin_username   = var.admin_username
    admin_ssh_key    = local.ssh_public_key
    additional_users = var.additional_users
  }) : null
}

# Network Security Group for Bastion
resource "azurerm_network_security_group" "this" {
  name                = "nsg-bastion-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow SSH from specified source IPs
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_source_ips
    destination_address_prefix = "*"
  }

  # Allow outbound to AKS API
  security_rule {
    name                       = "AllowAKSAPI"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound to PostgreSQL
  security_rule {
    name                       = "AllowPostgreSQL"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Module = "bastion"
    }
  )
}

# Public IP for Bastion
resource "azurerm_public_ip" "this" {
  name                = "pip-bastion-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Module = "bastion"
    }
  )
}

# Network Interface for Bastion
resource "azurerm_network_interface" "this" {
  name                = "nic-bastion-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }

  tags = merge(
    var.tags,
    {
      Module = "bastion"
    }
  )
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# Bastion VM
resource "azurerm_linux_virtual_machine" "this" {
  name                = "vm-bastion-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = var.disable_password_authentication

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = var.ubuntu_sku
    version   = "latest"
  }

  # System-assigned managed identity
  dynamic "identity" {
    for_each = var.enable_system_assigned_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  # Cloud-init for tool installation
  custom_data = local.cloud_init_script != null ? base64encode(local.cloud_init_script) : null

  tags = merge(
    var.tags,
    {
      Module = "bastion"
    }
  )
}
