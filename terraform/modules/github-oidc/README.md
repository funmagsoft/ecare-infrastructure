# GitHub OIDC Azure Integration Module

Terraform module that creates Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments for service repositories. This module enables GitHub Actions workflows in service repositories to authenticate to Azure using OIDC (passwordless authentication) for building container images and deploying to AKS.

## Resources Created

- **Application Registration** - Azure AD application for Service Principal
- **Service Principal** - Azure AD identity for GitHub Actions (`sp-gha-{project_name}-{environment}`)
- **Federated Identity Credentials** - OIDC credentials for GitHub Actions (one per service repository)
- **RBAC Role Assignments**:
  - **Contributor** on Azure Container Registry (for Service Principal)
  - **Azure Kubernetes Service Cluster User Role** on AKS (for Service Principal)
  - **Azure Kubernetes Service RBAC Writer** on AKS (for Service Principal, optional)

## Features

- Creates Service Principal for GitHub Actions OIDC authentication
- Creates Federated Identity Credentials for each service repository
- Assigns necessary RBAC roles for ACR build and AKS deployment operations
- Configurable list of service repositories
- Optional AKS RBAC Writer role for deployments
- Supports all environments (dev, test, stage, prod)

## Usage

```hcl
module "github_oidc_integration" {
  source = "../../modules/github-oidc"

  environment         = "dev"
  project_name        = "ecare"
  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"

  acr_id = data.terraform_remote_state.platform.outputs.acr_id
  aks_id = data.terraform_remote_state.platform.outputs.aks_id

  service_repos = {
    billing = {
      repo   = "hycom/billing-service"
      branch = "main"
    }
    payment = {
      repo   = "hycom/payment-service"
      branch = "main"
    }
  }

  enable_aks_rbac_writer = true

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name | `string` | - | yes |
| resource_group_name | Name of the Resource Group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| acr_id | ID of the Azure Container Registry | `string` | - | yes |
| aks_id | ID of the Azure Kubernetes Service cluster | `string` | - | yes |
| service_repos | Map of service repositories for GitHub OIDC integration | `map(object({repo=string, branch=optional(string, "main")}))` | `{}` | no |
| enable_aks_rbac_writer | Enable Azure Kubernetes Service RBAC Writer role | `bool` | `false` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| service_principal_app_id | Application (Client) ID of the Service Principal | no |
| service_principal_object_id | Object ID of the Service Principal | no |
| federated_identity_credentials | Map of service names to their FIC IDs | no |

## Module-Specific Configuration

### Service Repository Configuration

The module creates Federated Identity Credentials for each service repository defined in `service_repos`. Each FIC is scoped to a specific GitHub repository and branch:

- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: `repo:{org}/{repo}:ref:refs/heads/{branch}`
- **Audience**: `api://AzureADTokenExchange`

This allows GitHub Actions workflows in the specified repository and branch to authenticate to Azure using OIDC.

### Important: This Module is for Service Deployment, Not Terraform State

**This module creates Service Principals and FIC for service repositories** to build container images and deploy to AKS. These identities are used by GitHub Actions workflows to:

- Build container images using `az acr build`
- Push images to Azure Container Registry (ACR)
- Deploy services to Azure Kubernetes Service (AKS) using Helm or kubectl
- Retrieve AKS credentials using `az aks get-credentials`

**For Terraform state authentication**, see the [`infra-foundation` repository](https://github.com/hycom/infra-foundation) bootstrap module, which creates Service Principals and FIC for Terraform repositories (`infra-foundation`, `infra-platform`, `infra-identity`) to manage infrastructure via Terraform.

## Naming Convention

Resources follow this naming pattern:

- **Service Principal**: `sp-gha-{project_name}-{environment}` (e.g., `sp-gha-ecare-dev`)
- **Application Registration**: Same as Service Principal (display name)
- **Federated Identity Credential**: `GitHub{RepositoryName}Branch-{branch}` (e.g., `GitHubHycomBillingServiceBranch-main`)

## Security Features

- **OIDC Authentication**: Passwordless authentication using OpenID Connect (OIDC)
- **No Secrets Required**: GitHub Actions workflows authenticate without storing credentials
- **Scoped Access**: FIC are scoped to specific repositories and branches
- **Least Privilege**: Service Principals have only the minimum required permissions
- **RBAC Enforcement**: Role assignments follow Azure RBAC best practices

## Examples

### Development Environment

```hcl
module "github_oidc_integration" {
  source = "../../modules/github-oidc"

  environment         = "dev"
  project_name        = "ecare"
  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"

  acr_id = data.terraform_remote_state.platform.outputs.acr_id
  aks_id = data.terraform_remote_state.platform.outputs.aks_id

  service_repos = {
    billing = {
      repo   = "hycom/billing-service"
      branch = "main"
    }
  }

  enable_aks_rbac_writer = true

  tags = local.common_tags
}
```

### Production Environment

```hcl
module "github_oidc_integration" {
  source = "../../modules/github-oidc"

  environment         = "prod"
  project_name        = "ecare"
  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"

  acr_id = data.terraform_remote_state.platform.outputs.acr_id
  aks_id = data.terraform_remote_state.platform.outputs.aks_id

  service_repos = {
    billing = {
      repo   = "hycom/billing-service"
      branch = "main"
    }
    payment = {
      repo   = "hycom/payment-service"
      branch = "main"
    }
  }

  enable_aks_rbac_writer = true

  tags = local.common_tags
}
```

## Integration with Other Modules

This module integrates with:

- **Platform Module** (`infra-platform`): Retrieves ACR and AKS IDs from remote state
- **Workload Identity Module**: Complements workload identity by providing GitHub Actions authentication (this module) vs. AKS pod authentication (workload-identity module)

## Prerequisites

From Phase 1 (infra-foundation) and Phase 2 (infra-platform):

- Resource Group must exist: `rg-{project_name}-{environment}`
- Azure Container Registry (ACR) must exist (created by infra-platform)
- Azure Kubernetes Service (AKS) cluster must exist (created by infra-platform)
- Azure AD permissions to create Service Principals and App Registrations
- Azure CLI authenticated (`az login`)

## RBAC Roles

The Service Principal is assigned the following roles:

1. **Contributor** on Azure Container Registry
   - Required for `az acr build` (managing ACR Tasks)
   - Allows building container images in ACR

2. **Azure Kubernetes Service Cluster User Role** on AKS
   - Required for `az aks get-credentials` (retrieving kubeconfig)
   - Allows GitHub Actions to authenticate to AKS cluster

3. **Azure Kubernetes Service RBAC Writer** on AKS (optional)
   - Required for deployments (creating deployments, services, configmaps, etc.)
   - Allows GitHub Actions to deploy resources to AKS
   - Enable via `enable_aks_rbac_writer = true`

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
- AzureAD Provider ~> 2.40


