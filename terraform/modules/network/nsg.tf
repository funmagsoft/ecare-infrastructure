# NSG for AKS Subnet
resource "azurerm_network_security_group" "aks" {
  name                = var.aks_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NSG for Data Subnet
resource "azurerm_network_security_group" "data" {
  name                = var.data_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NSG for Management Subnet
resource "azurerm_network_security_group" "mgmt" {
  name                = var.mgmt_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NSG Rules Configuration
locals {
  # Map NSG names to their resource names for reference
  nsg_name_map = {
    aks  = azurerm_network_security_group.aks.name
    data = azurerm_network_security_group.data.name
    mgmt = azurerm_network_security_group.mgmt.name
  }

  nsg_rules = {
    aks = {
      inbound = [
        {
          name                       = "AllowVNetInbound"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "AllowAzureLoadBalancer"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "AzureLoadBalancer"
          destination_address_prefix = "*"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4000
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      outbound = [
        {
          name                       = "AllowVNetOutbound"
          priority                   = 100
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "AllowInternetOutbound"
          priority                   = 110
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "Internet"
        }
      ]
    }
    data = {
      inbound = [
        {
          name                       = "AllowVNetInbound"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4000
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      outbound = []
    }
    mgmt = {
      # Use concat() to conditionally include SSH rule based on mgmt_subnet_allowed_ssh_ips
      # concat() is needed because Terraform doesn't allow conditional values directly in lists
      # We combine: [always-rule] + [conditional-rule] + [always-rule]
      inbound = concat(
        [
          {
            name                       = "AllowVNetInbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
          }
        ],
        # Conditionally add SSH rule only if mgmt_subnet_allowed_ssh_ips is not empty
        length(var.mgmt_subnet_allowed_ssh_ips) > 0 ? [
          {
            name                       = "AllowSSHInbound"
            priority                   = 200
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "22"
            source_address_prefixes    = var.mgmt_subnet_allowed_ssh_ips
            destination_address_prefix = "*"
          }
        ] : [],
        [
          {
            name                       = "DenyAllInbound"
            priority                   = 4000
            direction                  = "Inbound"
            access                     = "Deny"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          }
        ]
      )
      outbound = []
    }
  }
}

# Create NSG rules using for_each
resource "azurerm_network_security_rule" "rules" {
  for_each = {
    for rule in flatten([
      for nsg_name, rules in local.nsg_rules : [
        for direction, rule_list in rules : [
          for idx, rule in rule_list : {
            key                         = "${nsg_name}-${direction}-${rule.name}"
            nsg_name                    = nsg_name
            network_security_group_name = local.nsg_name_map[nsg_name]
            rule                        = rule
          }
        ]
      ]
    ]) : rule.key => rule
  }

  name                        = each.value.rule.name
  priority                    = each.value.rule.priority
  direction                   = each.value.rule.direction
  access                      = each.value.rule.access
  protocol                    = each.value.rule.protocol
  source_port_range           = each.value.rule.source_port_range
  destination_port_range      = each.value.rule.destination_port_range
  source_address_prefix       = lookup(each.value.rule, "source_address_prefix", null)
  source_address_prefixes     = lookup(each.value.rule, "source_address_prefixes", null)
  destination_address_prefix  = each.value.rule.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = each.value.network_security_group_name
}
