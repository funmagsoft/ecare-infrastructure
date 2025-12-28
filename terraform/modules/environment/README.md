# Environment Module

Terraform module that encapsulates all workload identity configuration for an environment, eliminating code duplication across environments by providing a single source of truth for identity management.

## Resources Created

- **User Assigned Managed Identities (UAMI)** - One per service (conditional, only if Azure access is needed)
- **Federated Identity Credentials (FIC)** - GitHub OIDC credentials for passwordless deployments (conditional)
- **RBAC Role Assignments** - Conditional role assignments for Key Vault, Storage, and Service Bus access
- **Kubernetes Service Accounts** - Service accounts in the AKS namespace with Workload Identity annotations

## Features

- Single source of truth for all workload identity configuration
- Eliminates ~90% of code duplication across environments
- Automatic propagation of changes to all environments
- Consistent identity configuration across all environments
- Conditional resource creation (only creates UAMI/FIC if Azure access is needed)
- Support for custom RBAC roles
- Integration with AKS Workload Identity

## Usage

```hcl
module "environment" {
  source = "../../modules/environment"

  environment      = var.environment
  project_name     = var.project_name
  organization_name = var.organization_name

  services = local.services
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name | `string` | `"ecare"` | no |
| organization_name | Organization name for resource naming | `string` | `"hycom"` | no |
| services | Map of services to create workload identities for | `map(object)` | `{}` | no |
| additional_tags | Additional tags to merge with required tags. Required tags cannot be overridden. | `map(string)` | `{}` | no |

### Services Object Structure

Each service in the `services` map should have the following structure:

```hcl
services = {
  billing = {
    repo                    = "funmagsoft/billing-service"
    branch                  = "main"
    enable_key_vault_access = true
    enable_storage_access   = true
    enable_service_bus_access = false
    additional_roles = [
      # {
      #   role  = "Reader"
      #   scope = "/subscriptions/<sub-id>/resourceGroups/rg-ecare-dev"
      # }
    ]
  }
}
```

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| workload_identities | Map of workload identities per service with identity_id, identity_client_id, identity_principal_id, and federated_credential_id | no |

## Module-Specific Configuration

### Workload Identity Creation

The module creates User Assigned Managed Identities (UAMI) only when Azure access is needed. A UAMI is created if any of the following conditions are met:

- `enable_key_vault_access = true`
- `enable_storage_access = true`
- `enable_service_bus_access = true`
- `additional_roles` list is not empty

### Federated Identity Credentials

Federated Identity Credentials (FIC) are created for GitHub OIDC authentication. The FIC is configured with:

- **Issuer**: AKS OIDC issuer URL (from platform remote state)
- **Subject**: `system:serviceaccount:{namespace}:sa-{service_name}`
- **Audience**: `api://AzureADTokenExchange`

### RBAC Role Assignments

The module conditionally assigns RBAC roles based on service configuration:

- **Key Vault Secrets User** - Assigned when `enable_key_vault_access = true`
- **Storage Blob Data Contributor** - Assigned when `enable_storage_access = true`
- **Azure Service Bus Data Owner** - Assigned when `enable_service_bus_access = true`
- **Custom Roles** - Assigned from `additional_roles` list

### Kubernetes Service Accounts

Kubernetes Service Accounts are always created in the AKS namespace (from platform remote state). The Service Account is annotated with the Managed Identity client ID when Azure access is enabled.

## Naming Convention

- **Managed Identity**: `mi-{project_name}-{service_name}-{environment}` (e.g., `mi-ecare-billing-dev`)
- **Service Account**: `sa-{service_name}` (e.g., `sa-billing`)
- **Federated Identity Credential**: `fic-{project_name}-{service_name}-{environment}` (e.g., `fic-ecare-billing-dev`)

## Security Features

- Conditional resource creation (only creates UAMI/FIC when needed)
- Precondition checks ensure required IDs are provided when access is enabled
- Tags aligned with platform/foundation conventions
- Workload Identity integration for secure, passwordless authentication

## Examples

### Dev Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment      = "dev"
  project_name     = "ecare"
  organization_name = "hycom"

  services = {
    billing = {
      repo                    = "funmagsoft/billing-service"
      branch                  = "main"
      enable_key_vault_access = true
      enable_storage_access   = true
      enable_service_bus_access = false
    }
  }
}
```

### Prod Environment

```hcl
module "environment" {
  source = "../../modules/environment"

  environment      = "prod"
  project_name     = "ecare"
  organization_name = "hycom"

  services = {
    billing = {
      repo                    = "funmagsoft/billing-service"
      branch                  = "main"
      enable_key_vault_access = true
      enable_storage_access   = true
      enable_service_bus_access = true
      additional_roles = [
        {
          role  = "Reader"
          scope = "/subscriptions/<sub-id>/resourceGroups/rg-ecare-prod"
        }
      ]
    }
  }
}
```

## Integration with Other Modules

This module integrates with:

- **infra-platform** (via remote state) - Retrieves Key Vault, Storage Account, Service Bus, AKS namespace, and OIDC issuer URL
- **infra-foundation** (via remote state) - Retrieves Resource Group and location information
- **workload-identity module** - Creates individual workload identities per service

## Prerequisites

- Resource Group must exist (created in Phase 0)
- AKS cluster must be deployed (via infra-platform)
- Key Vault, Storage Account, and Service Bus must be deployed (via infra-platform) if access is needed
- Remote state from infra-foundation and infra-platform must be accessible

## Terraform Version

- **Terraform**: `>= 1.5.0`
- **AzureRM Provider**: `~> 3.80`
- **Kubernetes Provider**: `~> 2.0`

## Notes

- **Resource Group**: Resource Group name is automatically constructed as `rg-${var.project_name}-${var.environment}`. The Resource Group must exist (created in Phase 0) before deploying this module.
- **Remote State**: This module depends on remote state from `infra-foundation` and `infra-platform`. Ensure these are deployed and accessible before deploying this module.
- **Conditional Resources**: UAMI and FIC are only created when Azure access is needed. This reduces unnecessary resource creation and costs.
- **Service Accounts**: Kubernetes Service Accounts are always created, but Workload Identity annotations are only added when Azure access is enabled.

