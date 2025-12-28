terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

locals {
  dns_prefix = var.dns_prefix != null ? var.dns_prefix : "aks-${var.project_name}-${var.environment}"
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "this" {
  name                      = "aks-${var.project_name}-${var.environment}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = local.dns_prefix
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled

  # System node pool
  default_node_pool {
    name                         = var.system_node_pool_name
    vm_size                      = var.system_node_pool_vm_size
    node_count                   = var.system_node_pool_node_count
    os_disk_size_gb              = var.system_node_pool_os_disk_size_gb
    vnet_subnet_id               = var.vnet_subnet_id
    type                         = "VirtualMachineScaleSets"
    enable_auto_scaling          = false
    only_critical_addons_enabled = true

    tags = merge(
      var.tags,
      {
        Environment = var.environment
        NodePool    = "system"
      }
    )
  }

  # Network profile
  network_profile {
    network_plugin = var.network_plugin
    network_policy = var.network_policy
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Identity
  identity {
    type = var.identity_type
  }

  # Azure Policy (simple boolean in provider 3.x)
  azure_policy_enabled = var.azure_policy_enabled

  # Monitoring
  dynamic "oms_agent" {
    for_each = var.enable_container_insights && var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "aks"
    }
  )

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      default_node_pool[0].upgrade_settings,
      kubernetes_version
    ]
  }
}

# User node pool
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.user_node_pool_enabled ? 1 : 0

  name                  = var.user_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_pool_vm_size
  os_disk_size_gb       = var.user_node_pool_os_disk_size_gb
  vnet_subnet_id        = var.vnet_subnet_id

  enable_auto_scaling = var.enable_auto_scaling
  min_count           = var.enable_auto_scaling ? var.user_node_pool_min_count : null
  max_count           = var.enable_auto_scaling ? var.user_node_pool_max_count : null
  node_count          = var.enable_auto_scaling ? null : var.user_node_pool_min_count

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      NodePool    = "user"
    }
  )

  lifecycle {
    ignore_changes = [
      node_count,
      upgrade_settings
    ]
  }
}

# Note: ACR Pull role assignment is created in the environment main.tf
# to avoid count/for_each issues with dynamic acr_id from module output
