# Naming Conventions - Infrastructure Foundation

## Overview

This document defines the naming conventions used in the `infra-foundation` repository for Azure infrastructure resources (networking, VPN, GitHub OIDC integration).

For architecture overview, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

For deployment procedures, see **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

---

## Table of Contents

1. [General Rules](#general-rules)
2. [Azure Resources](#azure-resources)
3. [Azure AD Resources](#azure-ad-resources)
4. [Naming Patterns](#naming-patterns)
5. [Examples by Environment](#examples-by-environment)

---

## General Rules

### Casing and Separators

- **Lowercase only**: Required for Azure resource names (Storage Accounts, DNS names, etc.)
- **Hyphens for separation**: Use `-` not `_` (e.g., `vnet-ecare-dev`, not `vnet_ecare_dev`)
- **CamelCase for display names**: Azure AD applications use CamelCase (e.g., `GitHubInfraFoundationEnv`)

### Environment Suffix

All resources include environment suffix:

- Development: `-dev`
- Testing: `-test`
- Staging: `-stage`
- Production: `-prod`

### Component Order

Standard pattern: `<prefix>-<project>-<environment>[-<component>]`

Example: `vnet-ecare-dev`

- Prefix: `vnet` (Virtual Network)
- Project: `ecare`
- Environment: `dev`

### Length Limits

Respect Azure resource limits:

- **Resource Group**: 90 characters (practical limit: 40)
- **Virtual Network**: 64 characters (practical limit: 40)
- **Subnet**: 80 characters (practical limit: 40)
- **NSG**: 80 characters (practical limit: 40)
- **Storage Account**: 24 characters, lowercase alphanumeric only
- **Service Principal display name**: 120 characters (practical limit: 60)

---

## Azure Resources

### Resource Group

**Pattern:** `rg-<project>-<environment>`

**Purpose:** Container for all resources in an environment

**Examples:**

- `rg-ecare-dev`
- `rg-ecare-test`
- `rg-ecare-stage`
- `rg-ecare-prod`

**Notes:**

- Created by Phase 0 scripts (not Terraform)
- One Resource Group per environment
- Contains all foundation resources (networking, VPN, state storage)

---

### Storage Account (Terraform State)

**Pattern:** `tfstate<organization><project><environment>`

**Purpose:** Store Terraform state files for all phases

**Examples:**

- `tfstatehycomecaredev`
- `tfstatehycomecaretest`
- `tfstatehycomecarestage`
- `tfstatehycomecareprod`

**Notes:**

- Must be globally unique
- Lowercase alphanumeric only (no hyphens)
- 24 character limit
- Created by Phase 0 scripts (not Terraform)
- Uses Azure AD authentication (no access keys)

---

### Virtual Network

**Pattern:** `vnet-<project>-<environment>`

**Purpose:** Main virtual network for all services

**Examples:**

- `vnet-ecare-dev`
- `vnet-ecare-test`
- `vnet-ecare-stage`
- `vnet-ecare-prod`

**CIDR Ranges:**

- Dev: `10.1.0.0/16`
- Test: `10.2.0.0/16`
- Stage: `10.3.0.0/16`
- Prod: `10.4.0.0/16`

---

### Subnets

**Pattern:** `snet-<project>-<environment>-<purpose>`

**Examples:**

- `snet-ecare-dev-aks` (AKS cluster nodes)
- `snet-ecare-dev-data` (Data services with Private Endpoints)
- `snet-ecare-dev-mgmt` (Management/Bastion)
- `GatewaySubnet` (VPN Gateway - fixed Azure name)

**CIDR Ranges (example for dev - 10.1.0.0/16):**

- AKS: `10.1.1.0/24` (254 IPs)
- Data: `10.1.2.0/24` (254 IPs)
- Management: `10.1.3.0/24` (254 IPs)
- Gateway: `10.1.4.0/27` (30 IPs - VPN only)

**Notes:**

- AKS subnet requires `/24` or larger
- Data subnet hosts Private Endpoints
- Management subnet for Bastion VM
- GatewaySubnet has fixed name (Azure requirement)

---

### Network Security Groups

**Pattern:** `nsg-<project>-<environment>-<subnet>`

**Purpose:** Firewall rules for subnet traffic

**Examples:**

- `nsg-ecare-dev-aks`
- `nsg-ecare-dev-data`
- `nsg-ecare-dev-mgmt`

**Notes:**

- One NSG per subnet (except GatewaySubnet)
- Rules configured per subnet purpose
- Deny-by-default with explicit allow rules

---

### VPN Gateway

**Pattern:** `vgw-<project>-<environment>`

**Purpose:** Point-to-Site VPN for remote access

**Examples:**

- `vgw-ecare-dev`
- `vgw-ecare-test`
- `vgw-ecare-stage`
- `vgw-ecare-prod`

**Public IP Pattern:** `pip-vgw-<project>-<environment>`

**Examples:**

- `pip-vgw-ecare-dev`
- `pip-vgw-ecare-prod`

**Notes:**

- Optional (disabled by default in dev/test)
- Uses `GatewaySubnet` (fixed name)
- OpenVPN protocol
- Certificate-based authentication

---

## Azure AD Resources

### Service Principal (Terraform OIDC)

**Pattern:** `sp-gha-<project>-infra-<environment>-<deployment_id>`

**Purpose:** GitHub Actions authentication for infrastructure repositories (passwordless OIDC)

**Examples:**

- `sp-gha-ecare-infra-dev-a1b2c3d4`
- `sp-gha-ecare-infra-test-e5f6g7h8`
- `sp-gha-ecare-infra-stage-i9j0k1l2`
- `sp-gha-ecare-infra-prod-m3n4o5p6`

**Notes:**

- Created by Terraform bootstrap module
- `-infra-` indicates Terraform repository (not service repo)
- `deployment_id` suffix for easy cleanup
- OIDC authentication (no secrets/passwords)
- Three repositories use this SP:
  - `infra-foundation`
  - `infra-platform`
  - `infra-identity`

---

### Application Registration

Same as Service Principal (Azure AD Application backs the Service Principal):

- `sp-gha-ecare-infra-dev-a1b2c3d4`

---

### Federated Identity Credentials

**Pattern (Display Name):** `GitHub<RepositoryName>Env-<environment>-<hash>`

**Purpose:** OIDC trust configuration for GitHub Actions

**Examples:**

- `GitHubInfraFoundationEnv-dev-a1b2`
- `GitHubInfraPlatformEnv-dev-c3d4`
- `GitHubInfraIdentityEnv-dev-e5f6`

**Subject Claim Pattern:** `repo:<org>/<repo>:environment:<environment>`

**Examples:**

- `repo:hycom/infra-foundation:environment:dev`
- `repo:hycom/infra-platform:environment:test`
- `repo:hycom/infra-identity:environment:prod`

**Notes:**

- One FIC per repository per environment
- 4-character hash ensures uniqueness
- Environment-based OIDC (not branch-based)
- CamelCase display name for readability

---

## Naming Patterns

### Summary Table

| Resource Type | Pattern | Example | Created By |
|---------------|---------|---------|------------|
| Resource Group | `rg-<project>-<env>` | `rg-ecare-dev` | Phase 0 Scripts |
| Storage Account | `tfstate<org><project><env>` | `tfstatehycomecaredev` | Phase 0 Scripts |
| Virtual Network | `vnet-<project>-<env>` | `vnet-ecare-dev` | Terraform |
| Subnet | `snet-<project>-<env>-<purpose>` | `snet-ecare-dev-aks` | Terraform |
| NSG | `nsg-<project>-<env>-<subnet>` | `nsg-ecare-dev-aks` | Terraform |
| VPN Gateway | `vgw-<project>-<env>` | `vgw-ecare-dev` | Terraform |
| Public IP | `pip-vgw-<project>-<env>` | `pip-vgw-ecare-dev` | Terraform |
| Service Principal | `sp-gha-<project>-infra-<env>-<id>` | `sp-gha-ecare-infra-dev-a1b2c3d4` | Terraform |
| FIC Display Name | `GitHub<Repo>Env-<env>-<hash>` | `GitHubInfraFoundationEnv-dev-a1b2` | Terraform |

---

## Examples by Environment

### Development (dev)

```hcl
# Resource Group (Phase 0)
rg-ecare-dev

# Storage Account (Phase 0)
tfstatehycomecaredev

# Networking (Terraform)
vnet-ecare-dev              # 10.1.0.0/16
snet-ecare-dev-aks          # 10.1.1.0/24
snet-ecare-dev-data         # 10.1.2.0/24
snet-ecare-dev-mgmt         # 10.1.3.0/24
GatewaySubnet               # 10.1.4.0/27 (if VPN enabled)

# NSGs (Terraform)
nsg-ecare-dev-aks
nsg-ecare-dev-data
nsg-ecare-dev-mgmt

# VPN (Terraform - optional)
vgw-ecare-dev
pip-vgw-ecare-dev

# Azure AD (Terraform Bootstrap)
sp-gha-ecare-infra-dev-a1b2c3d4
GitHubInfraFoundationEnv-dev-a1b2
GitHubInfraPlatformEnv-dev-c3d4
GitHubInfraIdentityEnv-dev-e5f6
```

### Production (prod)

```hcl
# Resource Group (Phase 0)
rg-ecare-prod

# Storage Account (Phase 0)
tfstatehycomecareprod

# Networking (Terraform)
vnet-ecare-prod             # 10.4.0.0/16
snet-ecare-prod-aks         # 10.4.1.0/24
snet-ecare-prod-data        # 10.4.2.0/24
snet-ecare-prod-mgmt        # 10.4.3.0/24
GatewaySubnet               # 10.4.4.0/27 (if VPN enabled)

# NSGs (Terraform)
nsg-ecare-prod-aks
nsg-ecare-prod-data
nsg-ecare-prod-mgmt

# VPN (Terraform - typically enabled)
vgw-ecare-prod
pip-vgw-ecare-prod

# Azure AD (Terraform Bootstrap)
sp-gha-ecare-infra-prod-m3n4o5p6
GitHubInfraFoundationEnv-prod-m3n4
GitHubInfraPlatformEnv-prod-o5p6
GitHubInfraIdentityEnv-prod-q7r8
```

---

## Tags

All resources created by Terraform include these tags:

- `Environment`: dev | test | stage | prod
- `Project`: ecare
- `ManagedBy`: Terraform
- `Phase`: Foundation
- `GitRepository`: ecare-infrastructure
- `TerraformPath`: foundation/terraform/environments/{env}
- `DeploymentId`: 8-character unique identifier (e.g., a1b2c3d4)

**Example:**

```hcl
tags = {
  Environment   = "dev"
  Project       = "ecare"
  ManagedBy     = "Terraform"
  Phase         = "Foundation"
  GitRepository = "ecare-infrastructure"
  TerraformPath = "foundation/terraform/environments/dev"
  DeploymentId  = "a1b2c3d4"
}
```

---

## Azure AD Tags

Azure AD resources (Service Principals, Applications) use string tags in format `Key=Value`:

```hcl
tags = [
  "Environment=dev",
  "Project=ecare",
  "ManagedBy=Terraform",
  "Phase=Foundation",
  "GitRepository=ecare-infrastructure",
  "TerraformPath=foundation/terraform/environments/dev",
  "DeploymentId=a1b2c3d4"
]
```

---

## Naming Best Practices

1. **Consistency**: Use the same pattern across all environments
2. **Uniqueness**: Include environment in every name
3. **Length**: Keep names under 40 characters when possible
4. **Readability**: Use descriptive prefixes (vnet, snet, nsg, etc.)
5. **Separators**: Always use hyphens, never underscores
6. **Case**: Lowercase for Azure resources, CamelCase for Azure AD display names
7. **Documentation**: Update this document when adding new resource types
8. **Validation**: Use Terraform variable validation to enforce patterns

---

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Architecture overview and design decisions
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Operational procedures and deployment steps
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common issues and solutions
- **[SCRIPTS-REFERENCE.md](./SCRIPTS-REFERENCE.md)** - Complete scripts reference

---

## Validation

Naming conventions are enforced through:

1. **Terraform variables**: Variable validation blocks check format
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
