# Naming Conventions - Infrastructure Identity

## Overview

This document defines the naming conventions used in the `workload` repository for Azure AD identities, Kubernetes resources, and related components.

For architecture overview, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

---

## Table of Contents

1. [General Rules](#general-rules)
2. [Azure AD Resources](#azure-ad-resources)
3. [Kubernetes Resources](#kubernetes-resources)
4. [Naming Patterns](#naming-patterns)
5. [Examples by Environment](#examples-by-environment)

---

## General Rules

### Casing and Separators

- **Lowercase only**: Required for Azure resource names (Storage Accounts, DNS names, etc.)
- **Hyphens for separation**: Use `-` not `_` (e.g., `mi-ecare-billing-dev`, not `mi_ecare_billing_dev`)
- **CamelCase for display names**: Azure AD applications use CamelCase (e.g., `GitHubBillingServiceBranch`)

### Environment Suffix

All resources include environment suffix:

- Development: `-dev`
- Testing: `-test`
- Staging: `-stage`
- Production: `-prod`

### Component Order

Standard pattern: `<prefix>-<project>-<component>-<environment>`

Example: `mi-ecare-billing-dev`

- Prefix: `mi` (Managed Identity)
- Project: `ecare`
- Component: `billing` (service name)
- Environment: `dev`

### Length Limits

Respect Azure resource limits:

- **Service Principal display name**: 120 characters (practical limit: 50)
- **Managed Identity name**: 128 characters (practical limit: 60)
- **Kubernetes Service Account**: 253 characters (practical limit: 40)
- **Federated Identity Credential**: 120 characters

---

## Azure AD Resources

### Service Principal (GitHub OIDC)

**Pattern:** `sp-gha-<project>-<environment>`

**Purpose:** GitHub Actions authentication for service repositories (CI/CD)

**Examples:**

- `sp-gha-ecare-dev`
- `sp-gha-ecare-test`
- `sp-gha-ecare-stage`
- `sp-gha-ecare-prod`

**Note:** This is different from Terraform Service Principal:

- Terraform SP: `sp-gha-ecare-infra-dev` (created by `foundation`)
- Services SP: `sp-gha-ecare-dev` (created by this repo)

### Application Registration

Same as Service Principal (Azure AD Application backs the Service Principal):

- `sp-gha-ecare-dev`

### User Assigned Managed Identity (Workload Identity)

**Pattern:** `mi-<project>-<service>-<environment>`

**Purpose:** AKS pod authentication to Azure services

**Examples:**

- `mi-ecare-billing-dev`
- `mi-ecare-inventory-test`
- `mi-ecare-notification-stage`
- `mi-ecare-api-gateway-prod`

**Service name guidelines:**

- Lowercase
- Single word preferred (e.g., `billing`, not `billing-service`)
- Hyphenated if needed (e.g., `api-gateway`)
- Max 20 characters recommended

### Federated Identity Credential (FIC)

#### For GitHub OIDC (Service Repos - Branch-based)

**Pattern:** `GitHub<RepositoryNameCamelCase>Branch-<branch>-<hash>`

**Examples:**

- `GitHubBillingServiceBranch-main-a1b2`
- `GitHubInventoryServiceBranch-main-c3d4`
- `GitHubApiGatewayBranch-develop-e5f6`

**Components:**

- `GitHub`: Static prefix
- `BillingService`: Repository name in CamelCase (removes hyphens, capitalizes)
- `Branch`: Static keyword
- `main`: Branch name
- `a1b2`: Short hash for uniqueness (first 4 chars of SHA256)

#### For GitHub OIDC (GitOps Repos - Environment-based)

**Pattern:** `GitHub<RepositoryNameCamelCase>Env-<environment>-<hash>`

**Examples:**

- `GitHubGitopsEnv-dev-c3d4`
- `GitHubGitopsEnv-prod-e5f6`

**Components:**

- `GitHub`: Static prefix
- `Gitops`: Repository name in CamelCase
- `Env`: Static keyword (indicates environment-based)
- `dev`: Environment name
- `c3d4`: Short hash for uniqueness

#### For Workload Identity (AKS Pods)

**Pattern:** `fic-<project>-<service>-<environment>`

**Examples:**

- `fic-ecare-billing-dev`
- `fic-ecare-inventory-test`

**Note:** Simpler pattern than GitHub FIC (no CamelCase, no hash needed)

---

## Kubernetes Resources

### Service Account

**Pattern:** `sa-<service>`

**Purpose:** Kubernetes identity for pods (annotated with Azure UAMI Client ID)

**Examples:**

- `sa-billing`
- `sa-inventory`
- `sa-notification`
- `sa-api-gateway`

**No environment suffix** because Service Accounts are namespace-scoped. Different environments use different AKS clusters or namespaces.

### Namespace

**Pattern:** `<project>` or `<project>-<component>`

**Examples:**

- `ecare` (default, all services)
- `ecare-system` (system components)
- `ecare-monitoring` (observability stack)

**Note:** This Terraform configuration does **not** create namespaces. Namespaces should be created by:

- `platform` (if responsible for cluster setup)
- GitOps repository (ArgoCD, Flux)
- Manual `kubectl create namespace ecare`

---

## Naming Patterns

### Service Names

Service names are used throughout the configuration and must be consistent:

**Rules:**

- Lowercase only
- Alphanumeric and hyphens only
- Start with letter
- Max 20 characters recommended
- Must match between `service_repos` and `services` in `terraform.tfvars`

**Examples:**

| Service | Name | Managed Identity | Service Account | FIC (GitHub) | FIC (Workload) |
|---------|------|------------------|-----------------|--------------|----------------|
| Billing Service | `billing` | `mi-ecare-billing-dev` | `sa-billing` | `GitHubBillingServiceBranch-main-a1b2` | `fic-ecare-billing-dev` |
| Inventory Service | `inventory` | `mi-ecare-inventory-dev` | `sa-inventory` | `GitHubInventoryServiceBranch-main-c3d4` | `fic-ecare-inventory-dev` |
| API Gateway | `api-gateway` | `mi-ecare-api-gateway-dev` | `sa-api-gateway` | `GitHubApiGatewayBranch-main-e5f6` | `fic-ecare-api-gateway-dev` |
| Notification Service | `notification` | `mi-ecare-notification-dev` | `sa-notification` | `GitHubNotificationServiceBranch-main-g7h8` | `fic-ecare-notification-dev` |

### Repository Names

GitHub repository names used in `terraform.tfvars`:

**Pattern:** `<organization>/<repository-name>`

**Examples:**

- `hycom/billing-service`
- `hycom/inventory-service`
- `hycom/gitops`

**Branch Names:**

- Production: `main` (recommended) or `master`
- Development: `develop`, `dev`
- Feature branches: `feature/*`, `fix/*` (not typically used for FIC)

---

## Examples by Environment

### Development Environment

**Service Principal:**

- Display name: `sp-gha-ecare-dev`
- App ID (example): `12345678-1234-1234-1234-123456789abc`

**Workload Identities (Billing Service):**

- Managed Identity: `mi-ecare-billing-dev`
- Client ID (example): `abcdef01-2345-6789-abcd-ef0123456789`
- Service Account: `sa-billing` (namespace: `ecare`)
- FIC (GitHub): `GitHubBillingServiceBranch-main-a1b2`
  - Subject: `repo:hycom/billing-service:ref:refs/heads/main`
- FIC (Workload): `fic-ecare-billing-dev`
  - Subject: `system:serviceaccount:ecare:sa-billing`

**RBAC Roles:**

- Service Principal:
  - Contributor on `acr-ecare-dev`
  - Azure Kubernetes Service Cluster User Role on `aks-ecare-dev`
  - Azure Kubernetes Service RBAC Writer on `aks-ecare-dev`
- Managed Identity (Billing):
  - Key Vault Secrets User on `kv-ecare-dev`
  - Storage Blob Data Contributor on `st-ecare-dev`
  - Azure Service Bus Data Owner on `sb-ecare-dev`

### Production Environment

**Service Principal:**

- Display name: `sp-gha-ecare-prod`
- App ID (example): `87654321-4321-4321-4321-cba987654321`

**Workload Identities (Billing Service):**

- Managed Identity: `mi-ecare-billing-prod`
- Client ID (example): `fedcba09-8765-4321-dcba-fe9876543210`
- Service Account: `sa-billing` (namespace: `ecare`)
- FIC (GitHub): `GitHubBillingServiceBranch-main-a1b2`
  - Subject: `repo:hycom/billing-service:ref:refs/heads/main`
- FIC (Workload): `fic-ecare-billing-prod`
  - Subject: `system:serviceaccount:ecare:sa-billing`

**Note:** Service Account and FIC GitHub names are the same across environments. What differs:

- Managed Identity name includes environment suffix
- FIC is associated with environment-specific Managed Identity
- RBAC roles are scoped to environment-specific resources (e.g., `kv-ecare-prod`)

---

## Configuration Examples

### Terraform Configuration

```hcl
# terraform/environments/dev/terraform.tfvars

environment  = "dev"
project_name = "ecare"
organization_name = "hycom"

# GitHub OIDC: Service Repositories
service_repos = {
  billing = {
    repo   = "hycom/billing-service"
    branch = "main"
  }
  inventory = {
    repo   = "hycom/inventory-service"
    branch = "main"
  }
}

# Workload Identities: Services Configuration
services = {
  billing = {
    repo                      = "hycom/billing-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_storage_access     = true
    enable_service_bus_access = true
    namespace                 = "ecare"
  }
  inventory = {
    repo                      = "hycom/inventory-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_service_bus_access = false
    namespace                 = "ecare"
  }
}
```

**Resulting Resources:**

**Service Principal:** `sp-gha-ecare-dev` (shared by billing and inventory)

**Billing Service:**

- Managed Identity: `mi-ecare-billing-dev`
- Service Account: `sa-billing`
- FIC (GitHub): `GitHubBillingServiceBranch-main-<hash>`
- FIC (Workload): `fic-ecare-billing-dev`

**Inventory Service:**

- Managed Identity: `mi-ecare-inventory-dev`
- Service Account: `sa-inventory`
- FIC (GitHub): `GitHubInventoryServiceBranch-main-<hash>`
- FIC (Workload): `fic-ecare-inventory-dev`

---

## Validation Rules

### Service Name Validation

Service names are validated in Terraform:

```hcl
variable "services" {
  validation {
    condition = alltrue([
      for name in keys(var.services) :
      can(regex("^[a-z][a-z0-9-]*$", name)) && length(name) <= 30
    ])
    error_message = "Service names must start with letter, contain only lowercase alphanumeric and hyphens, max 30 chars."
  }
}
```

### Environment Validation

Environment names are validated:

```hcl
variable "environment" {
  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}
```

---

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Architecture overview
- **[DEPLOYMENT.md](./DEPLOYMENT.md)**: Deployment procedures
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**: Common issues

---

## Naming Convention Summary

| Resource Type | Pattern | Example | Environment Suffix |
|---------------|---------|---------|-------------------|
| Service Principal (GitHub OIDC) | `sp-gha-<project>-<env>` | `sp-gha-ecare-dev` | Yes |
| User Assigned Managed Identity | `mi-<project>-<service>-<env>` | `mi-ecare-billing-dev` | Yes |
| Federated Identity Credential (GitHub) | `GitHub<Repo>Branch-<branch>-<hash>` | `GitHubBillingServiceBranch-main-a1b2` | No |
| Federated Identity Credential (Workload) | `fic-<project>-<service>-<env>` | `fic-ecare-billing-dev` | Yes |
| Kubernetes Service Account | `sa-<service>` | `sa-billing` | No |
| Kubernetes Namespace | `<project>` | `ecare` | No |

**Key Takeaway:** Azure resources use environment suffixes; Kubernetes resources rely on namespace isolation instead.
