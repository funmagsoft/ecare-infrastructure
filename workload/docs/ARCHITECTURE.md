# Infrastructure Identity - Architecture

## Overview

The `workload` component manages identity and access control for applications running on Azure Kubernetes Service (AKS). It creates Azure AD identities and RBAC assignments that enable secure, passwordless authentication from GitHub Actions and Kubernetes workloads to Azure services.

## Purpose

This component serves as **Phase 3** of the infrastructure setup (after foundation and platform) and creates:

1. **GitHub OIDC Integration**: Service Principals and Federated Identity Credentials for GitHub Actions workflows to build, test, and deploy services
2. **Workload Identity**: User Assigned Managed Identities (UAMI) and Federated Identity Credentials for AKS pods to access Azure services (Key Vault, Storage, Service Bus)

## Key Concepts

### Service Principal vs User Assigned Managed Identity

**Service Principal (GitHub OIDC)**:

- Used by: GitHub Actions workflows (CI/CD pipelines)
- Purpose: Build container images, push to ACR, deploy to AKS
- Authentication: OIDC (passwordless)
- One per environment (shared by all service repositories)

**User Assigned Managed Identity (Workload Identity)**:

- Used by: Kubernetes pods running in AKS
- Purpose: Access Azure services (Key Vault, Storage, Service Bus) at runtime
- Authentication: AKS Workload Identity (OIDC)
- One per service per environment

### Authentication Flow

**GitHub Actions → Azure:**

```
GitHub Actions Workflow
        ↓ (OIDC token)
Service Principal (Azure AD)
        ↓ (Azure AD authentication)
Azure Resources (ACR, AKS)
```

**Kubernetes Pod → Azure:**

```
Kubernetes Pod (with Service Account)
        ↓ (projected token)
Azure AD Workload Identity Webhook
        ↓ (exchanges token)
User Assigned Managed Identity (Azure AD)
        ↓ (Azure AD authentication)
Azure Resources (Key Vault, Storage, Service Bus)
```

## Directory Structure

```
workload/
├── docs/
│   ├── ARCHITECTURE.md      # This file - high-level overview
│   ├── DEPLOYMENT.md         # Deployment procedures
│   ├── NAMING-CONVENTIONS.md # Naming patterns
│   └── TROUBLESHOOTING.md    # Common issues and solutions
│
├── scripts/
│   └── add-service.sh       # Helper to add new service
│
└── terraform/
    ├── modules/
    │   ├── environment/     # Orchestrator module
    │   ├── github-oidc/     # SP, FIC for GitHub Actions
    │   └── workload-identity/ # UAMI, FIC for AKS workloads
    │
    ├── environments/
    │   ├── dev/
    │   ├── test/
    │   ├── stage/
    │   └── prod/
    │       ├── versions.tf         # Backend config + required providers
    │       ├── providers.tf        # Azure providers
    │       ├── kubernetes-provider.tf # Kubernetes provider (remote state dependency)
    │       ├── variables.tf        # Environment-specific variables
    │       ├── main.tf             # Calls environment module
    │       ├── outputs.tf          # Re-exports module outputs
    │       └── terraform.tfvars.example
    │
    └── templates/
        ├── backend.tf.template
        └── providers.tf.template
```

## Module Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Environment Module                            │
│                                                                  │
│  ┌────────────────────────┐    ┌───────────────────────────┐   │
│  │  GitHub OIDC Module    │    │  Workload Identity Module │   │
│  │                        │    │  (one per service)         │   │
│  │  Creates:              │    │                            │   │
│  │  - Service Principal   │    │  Creates:                  │   │
│  │  - FIC for repos       │    │  - UAMI                    │   │
│  │  - RBAC (ACR, AKS)     │    │  - FIC for AKS pod         │   │
│  │                        │    │  - RBAC (KV, Storage, SB)  │   │
│  │  Used by:              │    │  - Kubernetes SA           │   │
│  │  - GitHub Actions      │    │                            │   │
│  │    (CI/CD)             │    │  Used by:                  │   │
│  │                        │    │  - Kubernetes pods         │   │
│  │                        │    │    (runtime)               │   │
│  └────────────────────────┘    └───────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Infrastructure Layers

### Layer 1: GitHub OIDC Integration

**Module:** `modules/github-oidc/`

Creates authentication for GitHub Actions workflows in service repositories.

**Resources Created:**

1. **Service Principal**: `sp-gha-ecare-{env}`
   - One per environment
   - Shared by all service repositories
2. **Federated Identity Credentials (FIC)**:
   - **Service repositories**: Subject format `repo:{org}/{repo}:ref:refs/heads/{branch}`
   - **GitOps repositories**: Subject format `repo:{org}/{repo}:environment:{env}`
3. **RBAC Role Assignments**:
   - **Contributor** on ACR (push/pull images, manage ACR tasks)
   - **Azure Kubernetes Service Cluster User Role** on AKS (get kubeconfig)
   - **Azure Kubernetes Service RBAC Writer** on AKS (deploy resources)

**Purpose:** Enable GitHub Actions to build container images, push to ACR, and deploy to AKS.

**Example FIC configuration:**

```hcl
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

gitops_repos = [
  "hycom/gitops"
]
```

### Layer 2: Workload Identity

**Module:** `modules/workload-identity/`

Creates authentication for Kubernetes pods running in AKS to access Azure services.

**Resources Created:**

1. **User Assigned Managed Identity (UAMI)**: `mi-ecare-{service}-{env}`
   - One per service per environment
   - Used by Kubernetes pods
2. **Federated Identity Credential (FIC)**:
   - Subject: `system:serviceaccount:{namespace}:sa-{service}`
   - Links Kubernetes Service Account to Azure UAMI
3. **Kubernetes Service Account**: `sa-{service}`
   - Annotated with UAMI Client ID
   - Label: `azure.workload.identity/use: "true"`
4. **RBAC Role Assignments** (conditional):
   - **Key Vault Secrets User** on Key Vault (if `enable_key_vault_access = true`)
   - **Storage Blob Data Contributor** on Storage Account (if `enable_storage_access = true`)
   - **Azure Service Bus Data Owner** on Service Bus (if `enable_service_bus_access = true`)
   - **Custom roles** via `additional_roles`

**Purpose:** Enable Kubernetes pods to access Azure services without storing credentials.

**Example configuration:**

```hcl
services = {
  billing = {
    repo                    = "hycom/billing-service"
    branch                  = "main"
    enable_key_vault_access = true
    enable_storage_access   = true
    enable_service_bus_access = true
  }
  inventory = {
    repo                    = "hycom/inventory-service"
    branch                  = "main"
    enable_key_vault_access = true
    enable_service_bus_access = true
  }
}
```

**Conditional Resource Creation:**

The workload-identity module uses smart conditional logic:

```hcl
local.needs_azure_access = (
  var.enable_key_vault_access
  || var.enable_storage_access
  || var.enable_service_bus_access
  || length(var.additional_roles) > 0
)
```

- If service needs NO Azure access → Only Kubernetes Service Account is created (no UAMI, no FIC, no RBAC)
- If service needs Azure access → Full setup (UAMI + FIC + RBAC + Kubernetes SA)

This optimizes resource creation and reduces unnecessary identities.

## Dependencies

### Prerequisites (from other repositories):

**From `foundation`:**

- Resource Groups (`rg-ecare-{env}`)
- Virtual Network and subnets
- Terraform state Storage Account

**From `platform`:**

- Azure Container Registry (ACR)
- Azure Kubernetes Service (AKS) cluster
- AKS OIDC issuer URL
- AKS namespace
- Key Vault (optional, if services need access)
- Storage Account (optional, if services need access)
- Service Bus Namespace (optional, if services need access)

### Remote State Dependencies:

```hcl
# foundation remote state
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    key = "foundation/terraform.tfstate"
  }
}

# platform remote state
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    key = "platform/terraform.tfstate"
  }
}
```

## Key Design Decisions

### 1. Separate Service Principal for Services

Services use a **different Service Principal** than Terraform repositories:

- **Terraform SP**: `sp-gha-ecare-infra-{env}` (created by `foundation`)
  - Purpose: Manage infrastructure via Terraform
  - Repos: `foundation`, `platform`, `workload`
- **Services SP**: `sp-gha-ecare-{env}` (created by this repo)
  - Purpose: Build and deploy application services
  - Repos: Service repositories (e.g., `billing-service`, `inventory-service`)

**Why separate?**

- Security: Different permissions (infrastructure vs application)
- Isolation: Terraform repos can't deploy services, service repos can't manage infrastructure
- Clarity: Naming convention makes purpose obvious

### 2. Shared Service Principal for All Services

All service repositories in an environment share **one Service Principal**.

**Why shared?**

- Simplicity: Fewer Service Principals to manage
- Consistency: Same permissions for all services (Contributor on ACR, RBAC Writer on AKS)
- Cost: Azure AD limits on number of Service Principals

**Alternative not chosen:** One SP per service repository (would create 10+ SPs per environment)

### 3. Per-Service Workload Identities

Each service gets its **own User Assigned Managed Identity**.

**Why per-service?**

- Security: Least privilege principle (each service only gets access it needs)
- Isolation: Service A cannot access Service B's secrets
- Flexibility: Different services need different Azure resources

### 4. Conditional Resource Creation

Workload Identity module only creates UAMI/FIC if service needs Azure access.

**Why conditional?**

- Optimization: Don't create unnecessary Azure AD objects
- Cost: Azure AD has soft limits on number of identities
- Clarity: If service has no UAMI, it's clear it doesn't access Azure services

### 5. Kubernetes Provider in Environment

Kubernetes provider is configured in **environment directory**, not in modules.

**Why?**

- Provider constraints: Providers should be configured in root module
- Remote state dependency: Kubernetes provider needs AKS config from `platform` remote state
- Flexibility: Different environments can use different AKS clusters

**File:** `kubernetes-provider.tf` in each environment directory

## Naming Conventions

### Service Principal

- Format: `sp-gha-{project}-{env}`
- Example: `sp-gha-ecare-dev`
- **Note:** No `-infra-` suffix (that's for Terraform SP)

### User Assigned Managed Identity

- Format: `mi-{project}-{service}-{env}`
- Example: `mi-ecare-billing-dev`

### Kubernetes Service Account

- Format: `sa-{service}`
- Example: `sa-billing`
- Namespace: Configured via `var.namespace` (default: `ecare`)

### Federated Identity Credential

**For GitHub OIDC (service repos):**

- Format: `GitHub{RepositoryName}Branch-{branch}-{hash}`
- Example: `GitHubBillingServiceBranch-main-a1b2`

**For GitHub OIDC (gitops repos):**

- Format: `GitHub{RepositoryName}Env-{env}-{hash}`
- Example: `GitHubGitopsEnv-dev-c3d4`

**For Workload Identity:**

- Format: `fic-{project}-{service}-{env}`
- Example: `fic-ecare-billing-dev`

## Security Architecture

### OIDC Authentication (No Secrets)

**GitHub Actions → Azure:**

- No Client Secrets stored
- No Service Principal passwords
- OIDC token issued by GitHub Actions
- Azure AD validates token against FIC configuration

**Kubernetes → Azure:**

- No secrets in pod manifests
- No credential files in container images
- Service Account token projected by AKS
- Azure AD Workload Identity webhook exchanges token for Azure AD token

### Least Privilege RBAC

Each service gets **only the permissions it needs**:

```hcl
# Service needs Key Vault access
enable_key_vault_access = true   # → Gets "Key Vault Secrets User" role

# Service needs Storage access
enable_storage_access = true     # → Gets "Storage Blob Data Contributor" role

# Service needs Service Bus access
enable_service_bus_access = true # → Gets "Azure Service Bus Data Owner" role
```

Services without Azure access get **no RBAC assignments**.

### Resource Isolation

- Each service has its own UAMI (no shared identities for workloads)
- Kubernetes Service Accounts are namespace-scoped
- FIC subject claims are precise (exact namespace, service account, repo, branch)

## Technology Stack

- **Terraform**: >= 1.5.0
- **Providers**:
  - `azurerm` ~> 3.0 (Azure Resource Manager)
  - `azuread` ~> 2.0 (Azure Active Directory)
  - `kubernetes` ~> 2.0 (Kubernetes resources)
- **Azure Services**:
  - Azure AD (Service Principals, Managed Identities)
  - AKS Workload Identity (OIDC integration)
- **Kubernetes**: >= 1.24 (Workload Identity support)

## Deployment Flow

```
1. Prerequisites deployed:
   - foundation (VNet, RG, Storage)
   - platform (AKS, ACR, Key Vault, etc.)
        ↓
2. Configure services in terraform.tfvars
        ↓
3. cd terraform/environments/dev
        ↓
4. terraform init
   (configures backend, downloads providers)
        ↓
5. terraform plan
   (preview: SP, UAMIs, FICs, RBAC, Kubernetes SAs)
        ↓
6. terraform apply
   (creates identities and access)
        ↓
7. Configure GitHub Actions secrets:
   - AZURE_CLIENT_ID: from SP output
   - AZURE_TENANT_ID: from Azure
   - AZURE_SUBSCRIPTION_ID: from Azure
        ↓
8. Deploy services via GitHub Actions
   (CI/CD pipelines use Service Principal)
        ↓
9. Pods use Kubernetes Service Accounts
   (automatically get Azure AD tokens via Workload Identity)
```

## Integration Points

### Used by:

1. **Service repositories** (e.g., `billing-service`, `inventory-service`):
   - GitHub Actions workflows authenticate using Service Principal
   - Build container images, push to ACR
   - Deploy manifests to AKS
2. **GitOps repositories** (e.g., `gitops`):
   - GitHub Actions workflows authenticate using Service Principal
   - Apply Kubernetes manifests (ArgoCD, Flux, etc.)
3. **Kubernetes pods**:
   - Use Kubernetes Service Accounts (annotated with UAMI Client ID)
   - Automatically get Azure AD access tokens
   - Access Azure services (Key Vault, Storage, Service Bus)

### Outputs:

See `terraform/modules/environment/outputs.tf` for complete list. Key outputs:

- `github_oidc_service_principal_app_id`: App ID for GitHub Actions secrets
- `workload_identities`: Map of service names to identity information

## Related Documentation

- **[DEPLOYMENT.md](./DEPLOYMENT.md)**: Step-by-step deployment procedures
- **[NAMING-CONVENTIONS.md](./NAMING-CONVENTIONS.md)**: Naming patterns and examples
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**: Common issues and solutions
- **[Main README](../README.md)**: Quick start guide
- **Module READMEs**: See `terraform/modules/*/README.md`

## Security Considerations

1. **Service Principal App ID**: Safe to store as GitHub Actions secret (not sensitive)
2. **No secrets stored**: All authentication uses OIDC (passwordless)
3. **FIC subject claims**: Must exactly match GitHub repo/branch or Kubernetes SA/namespace
4. **RBAC scope**: Roles assigned at resource level (Key Vault, Storage Account, Service Bus Namespace), not subscription
5. **Workload Identity enabled**: Requires AKS cluster with `workload_identity_enabled = true` and `oidc_issuer_enabled = true`

## Troubleshooting

For common issues and solutions, see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

Quick links:

- GitHub Actions authentication fails → Check FIC subject claim
- Pod cannot access Key Vault → Verify Kubernetes SA annotation and RBAC role
- Service Principal not found → Check `platform` outputs
