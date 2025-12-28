# Terraform Code Review: infra-foundation

**Review Date**: Current  
**Status**: Updated after environment standardization

## Executive Summary

This review analyzes the Terraform code in `infra-foundation` for improvements in DRY principles, modularization, and naming conventions. The codebase has been improved with standardized backend configurations and complete environment setups, but significant opportunities remain for reducing duplication, especially in environment-specific files.

## 1. DRY (Don't Repeat Yourself) Principles

### 1.1 ✅ Backend Configuration Duplication - RESOLVED

**Status**: ✅ **IMPROVED** - Backend configurations have been standardized with consistent structure and helpful comments.

**Current State**:

- All `backend.tf` files now have consistent structure with `required_version`
- Template file created at `terraform/templates/backend.tf.template`
- Comments added to indicate environment-specific values

**Note**: Terraform backend blocks cannot use variables/locals (Terraform limitation), so full DRY is not possible. Current approach is acceptable.

**Impact**: Medium - Structure is now consistent and maintainable.

---

### 1.2 Environment File Duplication - HIGH PRIORITY

**Issue**: Complete duplication of Terraform files across all environments. Files are 100% identical except for the environment name in `locals.tf`.

**Current State**:

- `network.tf` - **100% identical** across dev/test/stage/prod
- `vpn.tf` - **100% identical** across dev/test/stage/prod
- `data.tf` - **100% identical** across dev/test/stage/prod
- `outputs.tf` - **100% identical** across dev/test/stage/prod
- `variables.tf` - **100% identical** across dev/test/stage/prod
- `providers.tf` - **100% identical** across dev/test/stage/prod
- `locals.tf` - Only difference is `environment = "dev"` vs `"test"` vs `"stage"` vs `"prod"`

**Recommendation**: Extract common configuration to a shared module or use a wrapper module pattern.

**Option A: Shared Configuration Module (Recommended)**

Create a shared module that handles environment-specific logic:

```hcl
# terraform/modules/environment/main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  environment = var.environment
  project     = var.project
  location    = data.azurerm_resource_group.main.location

  common_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
  }
}

module "network" {
  source = "../network"
  # ... network configuration
}

module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../vpn-gateway"
  # ... VPN configuration
}
```

Then environments would only need:

- `backend.tf` (environment-specific)
- `main.tf` (calls the environment module)
- `terraform.tfvars` (environment-specific values)

**Option B: Terragrunt (Alternative)**

Consider using Terragrunt for DRY configuration management across environments.

**Impact**: **HIGH** - Eliminates ~90% of code duplication across environments.

---

### 1.3 NSG Rules Repetition

**Issue**: NSG rules in `modules/network/nsg.tf` have significant repetition. Each NSG has similar rules with only minor variations.

**Current State**:

- AKS NSG: 5 rules (AllowVNetInbound, AllowAzureLoadBalancer, DenyAllInbound, AllowVNetOutbound, AllowInternetOutbound)
- Data NSG: 2 rules (AllowVNetInbound, DenyAllInbound)
- Management NSG: 3 rules (AllowVNetInbound, AllowSSHInbound conditional, DenyAllInbound)

**Recommendation**: Use `for_each` with a rules map to define NSG rules declaratively.

**Improved Approach**:

```hcl
# modules/network/nsg.tf
locals {
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
            name                        = "AllowSSHInbound"
            priority                    = 200
            direction                   = "Inbound"
            access                      = "Allow"
            protocol                    = "Tcp"
            source_port_range           = "*"
            destination_port_range      = "22"
            source_address_prefixes      = var.mgmt_subnet_allowed_ssh_ips
            destination_address_prefix  = "*"
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
            key            = "${nsg_name}-${direction}-${rule.name}"
            nsg_name       = nsg_name
            nsg_id         = azurerm_network_security_group[nsg_name].id
            network_security_group_name = azurerm_network_security_group[nsg_name].name
            rule           = rule
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
```

**Impact**: Medium - Reduces code duplication and makes rule management easier.

---

### 1.4 Subnet Resource Repetition

**Issue**: Subnet resources are defined individually with similar structure.

**Current State**: Each subnet (aks, data, mgmt, gateway) is defined as a separate resource block.

**Recommendation**: Use `for_each` with a subnets map for non-gateway subnets (gateway subnet has special requirements).

**Improved Approach**:

```hcl
# modules/network/main.tf
locals {
  subnets = {
    aks = {
      name             = var.aks_subnet_name
      address_prefixes = [var.aks_subnet_cidr]
      nsg_id           = azurerm_network_security_group.aks.id
    }
    data = {
      name             = var.data_subnet_name
      address_prefixes = [var.data_subnet_cidr]
      nsg_id           = azurerm_network_security_group.data.id
    }
    mgmt = {
      name             = var.mgmt_subnet_name
      address_prefixes = [var.mgmt_subnet_cidr]
      nsg_id           = azurerm_network_security_group.mgmt.id
    }
  }
}

resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = each.value.nsg_id
}

# Gateway subnet remains separate due to special requirements
resource "azurerm_subnet" "gateway" {
  count                = var.enable_vpn_gateway ? 1 : 0
  name                 = "GatewaySubnet" # Fixed name required by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}
```

**Impact**: Medium - Reduces repetition and makes adding new subnets easier.

---

## 2. Modularization

### 2.1 Environment Configuration Module

**Issue**: All environment files are duplicated. This is the highest priority improvement.

**Recommendation**: Create a shared environment module that encapsulates all common configuration.

**Structure**:

```
terraform/
├── modules/
│   ├── environment/        # NEW: Shared environment module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── network/
│   └── vpn-gateway/
└── environments/
    ├── dev/
    │   ├── backend.tf
    │   ├── main.tf         # Calls module.environment
    │   └── terraform.tfvars
    └── ...
```

**Benefits**:

- Single source of truth for environment configuration
- Changes propagate to all environments automatically
- Easier to maintain and test
- Reduces code by ~85%

**Impact**: **HIGH** - Most significant improvement opportunity.

---

### 2.2 NSG Module Extraction

**Issue**: NSG creation and rule management could be extracted into a separate sub-module for better reusability.

**Recommendation**: Create a `modules/network/nsg/` sub-module that handles NSG creation and rule management.

**Structure**:

```
modules/network/
├── main.tf
├── variables.tf
├── outputs.tf
└── nsg/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**Benefits**:

- Better separation of concerns
- Reusable NSG module for other projects
- Easier testing of NSG logic independently

**Impact**: Medium - Improves code organization but adds complexity.

---

### 2.3 Provider Version Consistency

**Issue**: Provider version constraints differ between modules and environments.

**Current State**:

- `environments/*/providers.tf`: `version = "~> 3.80"`
- `modules/network/main.tf`: `version = "~> 3.0"`
- `modules/vpn-gateway/main.tf`: `version = "~> 3.0"`

**Recommendation**: Standardize provider version constraints. Consider using a `versions.tf` file or ensuring all files use the same constraint.

```hcl
# versions.tf (shared)
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}
```

**Impact**: Medium - Ensures consistent provider versions across all modules.

---

## 3. Naming Conventions

### 3.1 Resource Naming Consistency

**Status**: ✅ **Compliant** - Resource names follow the documented conventions:

- ✅ Virtual Network: `vnet-${project}-${env}` ✓
- ✅ Subnets: `snet-${project}-${env}-${purpose}` ✓
- ✅ NSGs: `nsg-${project}-${env}-${purpose}` ✓
- ✅ VPN Gateway: `vgw-${project}-${env}` ✓
- ✅ Public IP: `pip-vgw-${project}-${env}` ✓ (matches `pip-{purpose}-{project}-{env}` pattern)

**Recommendation**: No changes needed for naming conventions.

---

### 3.2 Terraform Resource Naming

**Status**: ✅ **Compliant** - Terraform resource names use `snake_case` as per conventions:

- `azurerm_virtual_network.main`
- `azurerm_subnet.aks`
- `azurerm_network_security_group.aks`

**Recommendation**: No changes needed.

---

### 3.3 Variable Naming

**Status**: ✅ **Compliant** - Variables use `snake_case` consistently.

**Recommendation**: No changes needed.

---

## 4. Additional Recommendations

### 4.1 Output Consistency

**Status**: ✅ **Good** - Outputs in environment files are consistent and use appropriate conditional expressions for optional resources.

**Recommendation**: No changes needed.

---

### 4.2 Data Source Naming

**Status**: ✅ **Compliant** - Data sources use `main` naming convention:

- `data.azurerm_resource_group.main`

**Recommendation**: No changes needed.

---

### 4.3 Tags Management

**Status**: ✅ **Good Practice** - Tags are managed through `locals.common_tags` and passed to modules.

**Recommendation**: Consider adding a validation rule to ensure required tags are present:

```hcl
# locals.tf
locals {
  required_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
  }
  
  common_tags = merge(
    local.required_tags,
    var.additional_tags
  )
}
```

**Impact**: Low - Adds safety but current approach is acceptable.

---

## 5. Priority Recommendations

### 🔴 High Priority

1. **Environment File Duplication** (Section 1.2)
   - Extract common configuration to shared module
   - **Impact**: Eliminates ~90% of code duplication
   - **Effort**: Medium

### 🟡 Medium Priority

2. **NSG Rules Repetition** (Section 1.3)
   - Refactor to use `for_each` with rules map
   - **Impact**: Improves maintainability
   - **Effort**: Medium

3. **Subnet Resource Repetition** (Section 1.4)
   - Use `for_each` for subnet creation
   - **Impact**: Makes adding new subnets easier
   - **Effort**: Low

4. **Provider Version Consistency** (Section 2.3)
   - Standardize provider versions
   - **Impact**: Ensures consistency
   - **Effort**: Low

5. **NSG Module Extraction** (Section 2.2)
   - Extract NSG logic to sub-module
   - **Impact**: Better organization
   - **Effort**: Medium

### 🟢 Low Priority

6. **Tags Validation** (Section 4.3)
   - Add tag validation
   - **Impact**: Adds safety
   - **Effort**: Low

---

## 6. Implementation Notes

### When Refactoring Environment Files

- Test thoroughly with all environments
- Ensure backward compatibility during migration
- Update documentation and examples
- Consider gradual migration (one environment at a time)

### When Refactoring NSG Rules

- Test thoroughly as NSG rules are critical for security
- Ensure priority values don't conflict
- Verify conditional SSH rule logic works correctly
- Test with empty and populated `mgmt_subnet_allowed_ssh_ips`

### When Refactoring Subnets

- Gateway subnet must remain separate (Azure requirement)
- Update outputs to reference new resource structure
- Test subnet associations with NSGs

### When Standardizing Versions

- Test with all environments before deploying
- Update all `terraform` blocks consistently
- Consider using a shared `versions.tf` file

---

## 7. Summary

The Terraform code in `infra-foundation` has been improved with standardized backend configurations and complete environment setups. However, significant opportunities remain for improvement:

### ✅ Completed Improvements

- Backend configurations standardized
- All environments have complete configuration
- Template file created for backend configuration

### 🔴 Critical Issues Remaining

1. **Environment File Duplication**: ~90% of code is duplicated across environments
   - **Recommendation**: Create shared environment module
   - **Priority**: HIGH

### 🟡 Medium Priority Issues

2. **NSG Rules**: Significant repetition in rule definitions
3. **Subnet Resources**: Repetitive resource definitions
4. **Provider Versions**: Inconsistent version constraints

### ✅ Strengths

- Naming conventions are properly followed
- Good use of modules for network and VPN
- Consistent structure across environments
- Proper use of tags and locals

**Overall Assessment**: ✅ **Good** - The codebase is maintainable and follows Terraform best practices. The highest priority improvement is eliminating environment file duplication through a shared module pattern. Current state is production-ready, but refactoring would significantly improve maintainability.

---

## 8. Code Metrics

### Current State

- **Total Files**: ~30 Terraform files
- **Duplicated Files**: ~24 files (80% duplication across environments)
- **Lines of Code**: ~1,200 lines
- **Duplicated Lines**: ~900 lines (75% duplication)

### After Recommended Refactoring

- **Total Files**: ~15 Terraform files
- **Duplicated Files**: ~4 files (backend.tf per environment)
- **Lines of Code**: ~600 lines
- **Duplicated Lines**: ~100 lines (backend configs only)

**Estimated Reduction**: ~50% reduction in total code, ~90% reduction in duplication.
