# Infrastructure Foundation - Architecture

## Overview

The `infra-foundation` component provides the foundational infrastructure layer for the ecare project. It establishes the core networking infrastructure and authentication mechanisms required for all subsequent infrastructure deployments.

## Purpose

This component serves as **Phase 1** of the infrastructure setup and creates:

1. **Core Networking Infrastructure**: Virtual Networks, Subnets, Network Security Groups (NSG), and optional VPN Gateway that form the network foundation for all Azure resources
2. **Terraform State Authentication**: Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments that enable GitHub Actions workflows to authenticate to Azure and manage infrastructure using Terraform

## Infrastructure Layers

The component is organized into distinct layers with clear separation of concerns:

### Layer 0: Phase 0 (Prerequisites)

Managed by **shell scripts** in `scripts/` directory:

- **Resource Groups**: Container for all resources per environment (`rg-ecare-{env}`)
- **Terraform State Storage Accounts**: Stores Terraform state files (`tfstatefmsecaredev`)
  - Blob versioning enabled
  - Soft delete enabled (7 days)
  - Private access by default
- **User Access**: RBAC role assignments for current user to view state files

**Why scripts, not Terraform?**

- Bootstrapping problem: Terraform needs a backend to store state
- These resources must exist before Terraform can run
- Manual setup ensures control over foundational resources

### Layer 1: Terraform Bootstrap Module

Managed by **Terraform module** `modules/bootstrap/`:

- **Service Principals**: Azure AD identities for GitHub Actions (`sp-gha-ecare-infra-{env}`)
- **Federated Identity Credentials (FIC)**: OIDC authentication for Terraform repositories
  - `infra-foundation`: This component
  - `infra-platform`: Platform infrastructure (AKS, ACR, databases)
  - `infra-identity`: Workload identities for services
- **RBAC Role Assignments**:
  - Contributor (manages infrastructure resources)
  - User Access Administrator (assigns roles to Managed Identities)
  - Storage Blob Data Contributor (reads/writes Terraform state)

**Purpose:** Enable GitHub Actions workflows in Terraform repositories to authenticate to Azure and manage infrastructure.

### Layer 2: Terraform Environment Module

Managed by **Terraform module** `modules/environment/`:

- **Virtual Network (VNet)**: Base network infrastructure
- **Subnets**:
  - `aks-subnet`: Azure Kubernetes Service nodes
  - `data-subnet`: Databases, storage (private endpoints)
  - `mgmt-subnet`: Management VMs, bastion hosts
  - `gateway-subnet`: VPN Gateway (optional)
- **Network Security Groups (NSG)**: Traffic filtering rules
- **VPN Gateway** (optional): Site-to-site and point-to-site VPN connectivity
- **Route Tables**: Custom routing rules

## Directory Structure

```
infra-foundation/
├── docs/
│   ├── ARCHITECTURE.md      # This file - high-level overview
│   ├── RUNBOOK.md           # Operational procedures (deployment, verification, cleanup)
│   └── SCRIPTS-REFERENCE.md # Shell scripts documentation
│
├── scripts/
│   ├── setup-phase0.sh      # Creates Phase 0 (RG, Storage, User Access)
│   ├── verify-phase0.sh     # Verifies Phase 0 resources
│   ├── cleanup-phase0.sh    # Deletes Phase 0 resources
│   ├── verify-terraform-bootstrap.sh  # Verifies bootstrap module resources
│   ├── verify-terraform-environment.sh # Verifies environment module resources
│   ├── verify-all.sh        # Verifies all layers (Phase 0 + Terraform)
│   ├── cleanup-terraform-emergency.sh # Emergency cleanup when terraform destroy fails
│   ├── recover-sp-ids.sh    # Recovers Service Principal IDs from Azure AD
│   └── common.sh            # Shared functions
│
└── terraform/
    ├── modules/
    │   ├── bootstrap/       # SP, FIC, RBAC for Terraform repositories
    │   ├── environment/     # Wrapper module for network + VPN
    │   ├── network/         # VNet, Subnets, NSG
    │   └── vpn-gateway/     # VPN Gateway (optional)
    │
    ├── environments/
    │   ├── dev/
    │   ├── test/
    │   ├── stage/
    │   └── prod/
    │       ├── versions.tf         # Backend config + required providers
    │       ├── providers.tf        # Provider configuration
    │       ├── variables.tf        # Environment-specific variables
    │       ├── main.tf             # Calls environment module
    │       ├── bootstrap.tf        # Calls bootstrap module (optional)
    │       ├── outputs.tf          # Re-exports module outputs
    │       └── terraform.tfvars.example
    │
    └── templates/
        ├── versions.tf.template
        └── providers.tf.template
```

## Module Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                      Phase 0 (Scripts)                      │
│  Resource Groups, Storage Accounts, User Access             │
└─────────────────────────────┬───────────────────────────────┘
                              │ (creates prerequisites)
                              ↓
┌─────────────────────────────────────────────────────────────┐
│             Terraform Bootstrap Module (optional)           │
│  Service Principals, FIC, RBAC for GitHub Actions           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│            Terraform Environment Module                      │
│                                                              │
│  ┌──────────────────────┐  ┌─────────────────────────────┐ │
│  │   Network Module     │  │  VPN Gateway Module         │ │
│  │  VNet, Subnets, NSG  │──│  (optional, if enabled)     │ │
│  └──────────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Shared Environment Module

All environments (dev, test, stage, prod) use the same `environment` module. This eliminates ~90% of code duplication and ensures consistency.

**Benefits:**

- Single source of truth for infrastructure configuration
- Changes propagate to all environments automatically
- Easier to maintain and test

### 2. Conditional Bootstrap Module

Bootstrap module can be disabled (`enable_bootstrap = false`) if Service Principals were created manually or by scripts.

**Why?**

- First deployment: Bootstrap must be created before GitHub Actions can run
- Options: Run `terraform apply -target=module.bootstrap` locally or use Azure CLI
- Subsequent deployments: Bootstrap can be managed by Terraform or kept manual

### 3. Remote State Backend

Terraform state is stored remotely in Azure Storage Accounts (created in Phase 0).

**Configuration:**

- Backend: `azurerm`
- Container: `tfstate`
- Key: `infra-foundation/terraform.tfstate`
- Authentication: Azure AD (OIDC for GitHub Actions, Azure CLI for local)

### 4. Network Architecture

**IP Address Allocation:**

- Dev: `10.1.0.0/16`
- Test: `10.2.0.0/16`
- Stage: `10.3.0.0/16`
- Prod: `10.4.0.0/16`

**Subnet Layout (example for dev):**

- VNet: `10.1.0.0/16`
  - AKS subnet: `10.1.0.0/20` (4096 IPs)
  - Data subnet: `10.1.16.0/24` (256 IPs)
  - Management subnet: `10.1.17.0/24` (256 IPs)
  - Gateway subnet: `10.1.255.0/27` (32 IPs)

### 5. Security Architecture

**Network Isolation:**

- All subnets have Network Security Groups (NSG)
- Default deny-all inbound traffic
- Explicit allow rules for required traffic
- SSH access to management subnet: configurable IP whitelist

**Identity & Access:**

- Service Principals use OIDC (no secrets stored)
- Least privilege RBAC assignments
- User access to state storage: explicit allow list

## Integration Points

### Consumed by other repositories:

1. **`infra-platform`**: Uses VNet and subnets (via remote state)
   - AKS subnet for Kubernetes nodes
   - Data subnet for database private endpoints
2. **`infra-identity`**: Uses Resource Groups and remote state
   - Creates workload identities in same RG
   - Shares Terraform state Storage Account

### Remote State Outputs:

See `terraform/modules/environment/outputs.tf` for complete list. Key outputs:

- `vnet_id`: Virtual Network resource ID
- `aks_subnet_id`: AKS subnet resource ID
- `data_subnet_id`: Data subnet resource ID (for private endpoints)
- `mgmt_subnet_id`: Management subnet resource ID
- `nsg_ids`: Map of NSG resource IDs

## Technology Stack

- **Terraform**: >= 1.5.0
- **Providers**:
  - `azurerm` ~> 3.0 (Azure Resource Manager)
  - `azuread` ~> 2.0 (Azure Active Directory)
- **Shell**: Bash (for Phase 0 scripts)
- **Azure CLI**: >= 2.50.0

## Deployment Flow

```
1. Configure .env file (TENANT_ID, SUBSCRIPTION_ID, LOCATION)
        ↓
2. Run scripts/setup-phase0.sh
   (creates RG, Storage Account, User Access)
        ↓
3. Verify: scripts/verify-phase0.sh
        ↓
4. cd terraform/environments/dev
        ↓
5. terraform init
   (configures backend, downloads providers)
        ↓
6. terraform plan
   (preview changes)
        ↓
7. terraform apply
   (creates bootstrap + environment resources)
        ↓
8. Verify: ../../scripts/verify-all.sh
```

## Related Documentation

- **[RUNBOOK.md](./RUNBOOK.md)**: Detailed operational procedures (setup, verification, cleanup, troubleshooting)
- **[SCRIPTS-REFERENCE.md](./SCRIPTS-REFERENCE.md)**: Complete reference for all shell scripts
- **[Main README](../README.md)**: Quick start guide and overview
- **Module READMEs**: See `terraform/modules/*/README.md` for module-specific documentation

## Security Considerations

1. **Terraform State**: Contains sensitive data (resource IDs, configuration). Access restricted to authorized users and Service Principals.
2. **Service Principal Credentials**: Use OIDC (no secrets stored in GitHub). Client IDs are outputs, not secrets.
3. **Network Access**: Default deny-all. Explicit allow rules required for any traffic.
4. **VPN Gateway**: Recommended for production environments. SSH access to management subnet is alternative for dev/test.
5. **Resource Locks**: Not implemented (would prevent Terraform destroy). Consider for production.

## Troubleshooting

For common issues and solutions, see **[RUNBOOK.md - Troubleshooting](./RUNBOOK.md#troubleshooting)** section.

Quick links:

- `terraform destroy` fails → [Emergency Cleanup](./RUNBOOK.md#procedure-2-emergency-teardown-terraform-destroy-failed)
- Lost Service Principal IDs → Run `scripts/recover-sp-ids.sh`
- Backend initialization fails → Verify Phase 0 with `scripts/verify-phase0.sh`
