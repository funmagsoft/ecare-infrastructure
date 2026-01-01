# Naming Conventions - Infrastructure Platform

## Overview

This document defines the naming conventions used in the `platform` repository for Azure platform services (AKS, ACR, PostgreSQL, Storage, Key Vault, Service Bus, Bastion, Monitoring).

For architecture overview, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

For deployment procedures, see **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

---

## Table of Contents

1. [General Rules](#general-rules)
2. [Compute Resources](#compute-resources)
3. [Storage Resources](#storage-resources)
4. [Database Resources](#database-resources)
5. [Security Resources](#security-resources)
6. [Messaging Resources](#messaging-resources)
7. [Monitoring Resources](#monitoring-resources)
8. [Management Resources](#management-resources)
9. [Kubernetes Resources](#kubernetes-resources)
10. [Naming Patterns Summary](#naming-patterns-summary)
11. [Examples by Environment](#examples-by-environment)

---

## General Rules

### Casing and Separators

- **Lowercase only**: Required for Azure resource names (Storage Accounts, DNS names, etc.)
- **Hyphens for separation**: Use `-` not `_` (e.g., `aks-ecare-dev`, not `aks_ecare_dev`)
- **No special characters**: Some Azure resources (ACR, Storage) only allow alphanumeric

### Environment Suffix

All resources include environment suffix:

- Development: `-dev` or `dev`
- Testing: `-test` or `test`
- Staging: `-stage` or `stage`
- Production: `-prod` or `prod`

### Component Order

Standard pattern: `<prefix>-<project>-<environment>[-<component>]`

Example: `aks-ecare-dev`

- Prefix: `aks` (Azure Kubernetes Service)
- Project: `ecare`
- Environment: `dev`

### Length Limits

Respect Azure resource limits:

- **AKS Cluster**: 63 characters (practical limit: 40)
- **ACR**: 50 characters, alphanumeric only (practical limit: 30)
- **PostgreSQL**: 63 characters (practical limit: 40)
- **Storage Account**: 24 characters, lowercase alphanumeric only
- **Key Vault**: 24 characters, alphanumeric + hyphens
- **Service Bus**: 50 characters (practical limit: 40)

---

## Compute Resources

### Azure Kubernetes Service (AKS)

**Pattern:** `aks-<project>-<environment>`

**Purpose:** Kubernetes cluster for containerized applications

**Examples:**

- `aks-ecare-dev`
- `aks-ecare-test`
- `aks-ecare-stage`
- `aks-ecare-prod`

**DNS Prefix Pattern:** `aks-<project>-<environment>`

**Node Pools:**

- **System Node Pool**: `system` (fixed name)
- **User Node Pool**: `user` (fixed name)

**Features:**

- Workload Identity enabled
- OIDC Issuer enabled
- Azure Policy enabled (optional)
- Container Insights enabled (optional)

**Tags:**

- AKS resource: Standard tags + `NodePool: system` or `NodePool: user`
- Node pools: Inherit cluster tags + specific `NodePool` tag

---

### Azure Container Registry (ACR)

**Pattern:** `acr<project><environment>`

**Purpose:** Docker image registry for application containers

**Examples:**

- `acrecaredev`
- `acrecaretest`
- `acrecarestage`
- `acrecareprod`

**Notes:**

- **No hyphens allowed** (Azure constraint)
- Lowercase alphanumeric only
- Must be globally unique
- Premium SKU required for Private Endpoints
- Retention policy enabled for Premium SKU

---

## Storage Resources

### Storage Account

**Pattern:** `st<organization><project><environment><hash>`

**Purpose:** Blob storage for application data

**Examples:**

- `sthycomecaredev1a2b`
- `sthycomecaretest3c4d`
- `sthycomecarestage5e6f`
- `sthycomecareprod7g8h`

**Notes:**

- **24 character limit**
- **No hyphens allowed** (Azure constraint)
- Lowercase alphanumeric only
- Must be globally unique
- 4-character hash ensures uniqueness
- Private Endpoint enabled by default

**Containers:**

- `app-data` - Application data
- `logs` - Application logs
- `backups` - Backup files
- Custom containers as needed

---

## Database Resources

### PostgreSQL Flexible Server

**Pattern:** `psql-<project>-<environment>`

**Purpose:** Relational database for application data

**Examples:**

- `psql-ecare-dev`
- `psql-ecare-test`
- `psql-ecare-stage`
- `psql-ecare-prod`

**FQDN Pattern:** `<name>.postgres.database.azure.com`

**Examples:**

- `psql-ecare-dev.postgres.database.azure.com`
- `psql-ecare-prod.postgres.database.azure.com`

**Features:**

- Private Endpoint enabled
- SSL/TLS enforced
- Azure AD authentication enabled
- Backup retention: 7-35 days (environment-dependent)
- High Availability: Zone-redundant (stage/prod)

---

## Security Resources

### Key Vault

**Pattern:** `kv-<project>-<environment>`

**Purpose:** Secrets and certificates management

**Examples:**

- `kv-ecare-dev`
- `kv-ecare-test`
- `kv-ecare-stage`
- `kv-ecare-prod`

**URI Pattern:** `https://<name>.vault.azure.net/`

**Examples:**

- `https://kv-ecare-dev.vault.azure.net/`
- `https://kv-ecare-prod.vault.azure.net/`

**Features:**

- RBAC authorization (not access policies)
- Soft delete enabled (7-90 days)
- Purge protection enabled (stage/prod)
- Private Endpoint enabled
- Network access restricted

**Common Secrets:**

- `postgresql-admin-password`
- `storage-connection-string`
- `service-bus-connection-string`
- Application-specific secrets

---

## Messaging Resources

### Service Bus Namespace

**Pattern:** `sb-<project>-<environment>`

**Purpose:** Message queue and pub/sub for async communication

**Examples:**

- `sb-ecare-dev`
- `sb-ecare-test`
- `sb-ecare-stage`
- `sb-ecare-prod`

**FQDN Pattern:** `<name>.servicebus.windows.net`

**Examples:**

- `sb-ecare-dev.servicebus.windows.net`
- `sb-ecare-prod.servicebus.windows.net`

**Features:**

- Standard/Premium tier (Premium for Private Endpoints)
- Private Endpoint enabled (Premium only)
- Zone redundancy (prod)
- Queues and Topics created by applications

---

## Monitoring Resources

### Log Analytics Workspace

**Pattern:** `log-<project>-<environment>`

**Purpose:** Centralized logging and monitoring

**Examples:**

- `log-ecare-dev`
- `log-ecare-test`
- `log-ecare-stage`
- `log-ecare-prod`

**Features:**

- 30-730 days retention
- Integrates with AKS Container Insights
- Application Insights workspace mode
- Custom log queries and alerts

---

### Application Insights

**Pattern:** `appi-<project>-<environment>`

**Purpose:** Application performance monitoring

**Examples:**

- `appi-ecare-dev`
- `appi-ecare-test`
- `appi-ecare-stage`
- `appi-ecare-prod`

**Features:**

- Workspace-based (linked to Log Analytics)
- Application type: web
- SDK integration for detailed telemetry
- Availability tests
- Custom metrics and events

---

## Management Resources

### Bastion VM

**Pattern:** `vm-bastion-<project>-<environment>`

**Purpose:** Jump host for secure access to private resources

**Examples:**

- `vm-bastion-ecare-dev`
- `vm-bastion-ecare-test`
- `vm-bastion-ecare-stage`
- `vm-bastion-ecare-prod`

**Public IP Pattern:** `pip-bastion-<project>-<environment>`

**Examples:**

- `pip-bastion-ecare-dev`
- `pip-bastion-ecare-prod`

**Network Interface Pattern:** `nic-bastion-<project>-<environment>`

**Examples:**

- `nic-bastion-ecare-dev`
- `nic-bastion-ecare-prod`

**NSG Pattern:** `nsg-bastion-<project>-<environment>`

**Examples:**

- `nsg-bastion-ecare-dev`
- `nsg-bastion-ecare-prod`

**Features:**

- Ubuntu 22.04/24.04 LTS
- Pre-installed tools: kubectl, az cli, psql, docker
- SSH key authentication
- Restricted source IPs (configurable)
- Located in Management subnet

**OS Disk Pattern:** `osdisk-bastion-<project>-<environment>`

---

## Kubernetes Resources

### Namespace

**Pattern:** `<project>-<environment>`

**Purpose:** Kubernetes namespace for application workloads

**Examples:**

- `ecare-dev`
- `ecare-test`
- `ecare-stage`
- `ecare-prod`

**Notes:**

- Created by Terraform
- Workload Identities map to this namespace
- Default namespace for application deployments

---

### Service Accounts

**Pattern:** `sa-<service-name>`

**Purpose:** Kubernetes service account for workload identity

**Examples:**

- `sa-billing`
- `sa-inventory`
- `sa-notification`
- `sa-api-gateway`

**Notes:**

- Created by `workload` phase
- Annotated with Azure Workload Identity client ID
- Labeled with `azure.workload.identity/use=true`
- Maps to User Assigned Managed Identity (UAMI)

---

## Naming Patterns Summary

| Resource Type | Pattern | Example | Hyphens | Length |
|---------------|---------|---------|---------|--------|
| AKS Cluster | `aks-<project>-<env>` | `aks-ecare-dev` | ✅ | 63 |
| ACR | `acr<project><env>` | `acrecaredev` | ❌ | 50 |
| PostgreSQL | `psql-<project>-<env>` | `psql-ecare-dev` | ✅ | 63 |
| Storage Account | `st<org><project><env><hash>` | `sthycomecaredev1a2b` | ❌ | 24 |
| Key Vault | `kv-<project>-<env>` | `kv-ecare-dev` | ✅ | 24 |
| Service Bus | `sb-<project>-<env>` | `sb-ecare-dev` | ✅ | 50 |
| Log Analytics | `log-<project>-<env>` | `log-ecare-dev` | ✅ | 63 |
| App Insights | `appi-<project>-<env>` | `appi-ecare-dev` | ✅ | 63 |
| Bastion VM | `vm-bastion-<project>-<env>` | `vm-bastion-ecare-dev` | ✅ | 64 |
| Bastion Public IP | `pip-bastion-<project>-<env>` | `pip-bastion-ecare-dev` | ✅ | 80 |
| Bastion NIC | `nic-bastion-<project>-<env>` | `nic-bastion-ecare-dev` | ✅ | 80 |
| Bastion NSG | `nsg-bastion-<project>-<env>` | `nsg-bastion-ecare-dev` | ✅ | 80 |
| K8s Namespace | `<project>-<env>` | `ecare-dev` | ✅ | 63 |
| K8s Service Account | `sa-<service>` | `sa-billing` | ✅ | 253 |

---

## Examples by Environment

### Development (dev)

```hcl
# Compute
aks-ecare-dev
acrecaredev

# Storage
sthycomecaredev1a2b

# Database
psql-ecare-dev

# Security
kv-ecare-dev

# Messaging
sb-ecare-dev

# Monitoring
log-ecare-dev
appi-ecare-dev

# Management
vm-bastion-ecare-dev
pip-bastion-ecare-dev
nic-bastion-ecare-dev
nsg-bastion-ecare-dev

# Kubernetes
Namespace: ecare-dev
Service Accounts: sa-billing, sa-inventory, sa-notification
```

### Production (prod)

```hcl
# Compute
aks-ecare-prod
acrecareprod

# Storage
sthycomecareprod7g8h

# Database
psql-ecare-prod

# Security
kv-ecare-prod

# Messaging
sb-ecare-prod

# Monitoring
log-ecare-prod
appi-ecare-prod

# Management
vm-bastion-ecare-prod
pip-bastion-ecare-prod
nic-bastion-ecare-prod
nsg-bastion-ecare-prod

# Kubernetes
Namespace: ecare-prod
Service Accounts: sa-billing, sa-inventory, sa-notification
```

---

## Tags

All resources created by Terraform include these tags:

- `Environment`: dev | test | stage | prod
- `Project`: ecare
- `ManagedBy`: Terraform
- `Phase`: Platform
- `GitRepository`: ecare-infrastructure
- `TerraformPath`: platform/terraform/environments/{env}
- `DeploymentId`: 8-character unique identifier (e.g., a1b2c3d4)

**Example:**

```hcl
tags = {
  Environment   = "dev"
  Project       = "ecare"
  ManagedBy     = "Terraform"
  Phase         = "Platform"
  GitRepository = "ecare-infrastructure"
  TerraformPath = "platform/terraform/environments/dev"
  DeploymentId  = "a1b2c3d4"
}
```

**Module-specific tags:**

Some modules add additional tags:

- AKS nodes: `NodePool: system` or `NodePool: user`
- ACR: `Module: acr`
- PostgreSQL: `Module: postgresql`
- Storage: `Module: storage`
- Key Vault: `Module: key-vault`

---

## Private Endpoints

Private Endpoints follow this naming pattern:

**Pattern:** `pe-<resource>-<project>-<environment>`

**Examples:**

- `pe-psql-ecare-dev` (PostgreSQL)
- `pe-st-ecare-dev` (Storage Account)
- `pe-kv-ecare-dev` (Key Vault)
- `pe-sb-ecare-dev` (Service Bus)
- `pe-acr-ecare-dev` (Container Registry)

**Network Interface Card (NIC) Pattern:** `pe-<resource>-<project>-<environment>-nic`

**Private DNS Zones:**

- PostgreSQL: `privatelink.postgres.database.azure.com`
- Storage (Blob): `privatelink.blob.core.windows.net`
- Key Vault: `privatelink.vaultcore.azure.net`
- Service Bus: `privatelink.servicebus.windows.net`
- ACR: `privatelink.azurecr.io`

---

## Naming Best Practices

1. **Consistency**: Use the same pattern across all environments
2. **Uniqueness**: Include environment in every name
3. **Length**: Keep names under 40 characters when possible (respect Azure limits)
4. **Readability**: Use descriptive prefixes (aks, psql, kv, sb, etc.)
5. **Separators**: Use hyphens for resources that allow them
6. **Case**: Lowercase for all Azure resources
7. **Documentation**: Update this document when adding new resource types
8. **Validation**: Use Terraform variable validation to enforce patterns
9. **Global Uniqueness**: Add hash suffix for globally unique resources (Storage, ACR)
10. **Private Endpoints**: Follow consistent pattern for all private connectivity

---

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Architecture overview and design decisions
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Operational procedures and deployment steps
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common issues and solutions
- **Module READMEs**: `../terraform/modules/<module>/README.md` - Module-specific details

---

## Validation

Naming conventions are enforced through:

1. **Terraform variables**: Variable validation blocks check format and length
2. **Azure Provider**: Rejects invalid names at apply time
3. **Code review**: Manual verification during PR review
4. **Documentation**: This document serves as reference

Example validation:

```hcl
variable "project_name" {
  type        = string
  validation {
    condition     = length(var.project_name) <= 30
    error_message = "project_name must be 30 characters or less."
  }
}
```

---

## Azure Naming Constraints

### Resources That Don't Allow Hyphens

- **Storage Account**: 24 chars, lowercase alphanumeric only
- **ACR**: 50 chars, alphanumeric only

### Globally Unique Resources

These must be unique across all Azure:

- Storage Account names
- ACR names
- Key Vault names (within Azure AD tenant)

**Strategy:** Add organization prefix + hash suffix to ensure uniqueness

---

## Integration with Other Phases

### From Foundation (Phase 1)

Platform uses these resources from foundation:

- Virtual Network: `vnet-ecare-{env}`
- AKS Subnet: `snet-ecare-{env}-aks`
- Data Subnet: `snet-ecare-{env}-data`
- Mgmt Subnet: `snet-ecare-{env}-mgmt`

### To Identity (Phase 3)

Identity phase creates workload identities referencing:

- AKS OIDC Issuer URL
- Kubernetes Namespace: `ecare-{env}`
- Service Accounts: `sa-{service-name}`
- Key Vault: `kv-ecare-{env}`
- Storage Account: `st{org}{project}{env}{hash}`
- Service Bus: `sb-ecare-{env}`
