# Bootstrap Module

Terraform module that creates Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments for Terraform repositories. This module enables GitHub Actions to authenticate to Azure using OIDC (passwordless authentication).

## Resources Created

- **Application Registration** - Azure AD application for Service Principal
- **Service Principal** - Azure AD identity for GitHub Actions (`sp-gha-infra-{project}-{env}-{phase}-{deployment_id}`)
- **Federated Identity Credentials** - OIDC credentials for GitHub Actions (one per repository per environment)
- **RBAC Role Assignments**:
  - **Contributor** on Resource Group (for Service Principal)
  - **User Access Administrator** on Resource Group (for Service Principal)
  - **Storage Blob Data Contributor** on Storage Account (for Service Principal)
  - **Storage Blob Data Contributor** on Storage Account (for specified users, optional)

## Features

- Creates Service Principal for GitHub Actions OIDC authentication
- Creates Federated Identity Credentials for each Terraform repository
- Assigns necessary RBAC roles for Terraform operations
- Configurable list of Terraform repositories
- Optional user access management (Storage Blob Data Contributor for specified users)
- Supports all environments (dev, test, stage, prod)

## Usage

```hcl
module "bootstrap" {
  source = "../../modules/bootstrap"

  environment         = "dev"
  organization_name   = "hycom"
  organization_for_sa = "hycom"
  project_name        = "ecare"

  terraform_repos = [
    "foundation",
    "platform",
    "workload"
  ]

  # Optional: Grant Storage Blob Data Contributor to users
  users_with_state_access = [
    "12345678-1234-1234-1234-123456789012"  # User Object ID
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| organization_name | GitHub organization name | `string` | - | yes |
| organization_for_sa | Organization name for Storage Account naming | `string` | - | yes |
| project_name | Project name | `string` | - | yes |
| terraform_repos | List of Terraform repository names (without organization prefix) | `list(string)` | `["ecare-infrastructure"]` | no |
| users_with_state_access | List of Azure AD user Object IDs with Storage Blob Data Contributor role | `list(string)` | `[]` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| service_principal_app_id | Application (Client) ID of the Service Principal | no |
| service_principal_object_id | Object ID of the Service Principal | no |
| federated_identity_credentials | Map of repository names to their FIC IDs | no |

## Module-Specific Configuration

### Repository Names

Repository names are stored in the module with default values:

- `foundation`
- `platform`
- `workload`

Full repository names are constructed as: `"${var.organization_name}/${repo}"`

For example, with `organization_name = "hycom"` and default repos:

- `hycom/foundation`
- `hycom/platform`
- `hycom/workload`

You can override the default list by providing `terraform_repos` variable:

```hcl
terraform_repos = ["ecare-infrastructure", "custom-repo"]
```

### Important: Bootstrap is for Terraform State, Not Service Deployment

**This bootstrap module creates Service Principals and FIC for Terraform repositories** (`foundation`, `platform`, `workload`) to manage infrastructure via Terraform. These identities are used by GitHub Actions workflows to:

- Run `terraform plan` and `terraform apply`
- Access Terraform state files in Azure Storage Accounts
- Create and manage Azure resources (networks, AKS, databases, etc.)

**For service deployment authentication**, see the [`workload` repository](https://github.com/hycom/workload), which creates User Assigned Managed Identities (UAMI) and FIC for **service repositories** to:

- Push container images to Azure Container Registry (ACR)
- Deploy services to Azure Kubernetes Service (AKS)
- Access Azure resources (Key Vault, Storage, Service Bus) from running services

## Naming Convention

Resources follow this naming pattern:

- **Service Principal**: `sp-gha-infra-{project}-{env}-{phase}-{deployment_id}` (e.g., `sp-gha-infra-ecare-dev-foundation-a1b2c3d4`)
- **Application Registration**: Same as Service Principal (display name)
- **Federated Identity Credential**: `GitHub{RepositoryName}Env-{environment}` (e.g., `GitHubHycomInfraFoundationEnv-dev`)

### Why the `-infra-` Suffix?

The `-infra-` suffix in the Service Principal name (`sp-gha-infra-{project}-{env}-{phase}-{deployment_id}`) distinguishes bootstrap Service Principals from service deployment Service Principals:

- **Bootstrap SPs** (this module): `sp-gha-infra-{project}-{env}-{phase}-{deployment_id}` - for Terraform repositories
- **Service SPs** (`workload`): `sp-gha-{project}-{env}-{phase}-{deployment_id}` - for service repositories

This naming convention makes it immediately clear which Service Principal is used for infrastructure management (Terraform operations) versus application deployment (CI/CD workflows).

## Security Features

- **OIDC Authentication**: Passwordless authentication using OpenID Connect (OIDC)
- **No Secrets Required**: GitHub Actions workflows authenticate without storing credentials
- **Scoped Access**: FIC are scoped to specific repositories and environments
- **Least Privilege**: Service Principals have only the minimum required permissions
- **RBAC Enforcement**: Role assignments follow Azure RBAC best practices

## Examples

### Development Environment

```hcl
module "bootstrap" {
  source = "../../modules/bootstrap"

  environment         = "dev"
  organization_name   = "hycom"
  organization_for_sa = "hycom"
  project_name        = "ecare"

  terraform_repos = [
    "foundation",
    "platform",
    "workload"
  ]

  users_with_state_access = [
    "f714a502-3026-4ef8-b753-00c5b4c00f4a"  # User Object ID
  ]
}
```

### Production Environment

```hcl
module "bootstrap" {
  source = "../../modules/bootstrap"

  environment         = "prod"
  organization_name   = "hycom"
  organization_for_sa = "hycom"
  project_name        = "ecare"

  terraform_repos = [
    "foundation",
    "platform",
    "workload"
  ]

  users_with_state_access = [
    "f714a502-3026-4ef8-b753-00c5b4c00f4a",  # User Object ID
    "c655dbb9-e52b-45c3-8b96-e37a1c35aa7e"   # User Object ID
  ]
}
```

## Integration with Other Modules

This module is standalone and does not depend on other modules. However, it creates resources that are used by:

- Terraform workflows in `foundation`, `platform`, and `workload` repositories
- All Terraform deployments that require access to state Storage Accounts

## Prerequisites

- Resource Group must exist: `rg-{project_name}-{environment}`
- Storage Account must exist: `tfstate{organization_for_sa}{project_name}{environment}`
- Azure AD permissions to create Service Principals and App Registrations
- Azure CLI authenticated (`az login`)

### Federated Identity Credentials

For each repository in `terraform_repos`, the module creates a Federated Identity Credential with:

- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: `repo:{organization_name}/{repo}:environment:{environment}`
- **Audience**: `api://AzureADTokenExchange`

This allows GitHub Actions workflows in the specified repository and environment to authenticate to Azure using OIDC.

### RBAC Roles

The Service Principal is assigned the following roles:

1. **Contributor** on Resource Group
   - Allows Terraform to create/modify/delete resources

2. **User Access Administrator** on Resource Group
   - Allows Terraform to assign roles to Managed Identities it creates

3. **Storage Blob Data Contributor** on Storage Account (for Service Principal)
   - Allows Terraform to read/write state files

4. **Storage Blob Data Contributor** on Storage Account (for specified users, optional)
   - Allows users to view and browse state files in Azure Portal
   - Useful for debugging, auditing, and understanding infrastructure state
   - Configured via `users_with_state_access` variable

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
- AzureAD Provider ~> 2.44
