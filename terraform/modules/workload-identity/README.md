# Workload Identity Module

Terraform module for creating User Assigned Managed Identity (UAMI), GitHub OIDC Federated Identity Credential (FIC), Kubernetes ServiceAccount, and optional RBAC role assignments for a single service.

## Resources Created

- **User Assigned Managed Identity (UAMI)** - Azure Managed Identity for service authentication (conditional, created only if any access/role is needed)
- **Federated Identity Credential (FIC)** - GitHub OIDC credential bound to the UAMI for passwordless authentication
- **Kubernetes ServiceAccount** - ServiceAccount in the specified namespace for workload identity binding
- **RBAC Role Assignments** - Conditional role assignments:
  - Key Vault: `Key Vault Secrets User` role
  - Storage: `Storage Blob Data Contributor` role
  - Service Bus: `Azure Service Bus Data Owner` role
  - Additional custom roles (configurable via `additional_roles`)

## Features

- Creates User Assigned Managed Identity only when needed (conditional creation)
- GitHub OIDC Federated Identity Credential for passwordless authentication
- Kubernetes ServiceAccount creation with proper annotations for workload identity
- Conditional RBAC role assignments based on service requirements
- Support for additional custom RBAC roles with flexible scope
- Automatic tagging with environment, project, and service information
- Integration with AKS OIDC issuer for workload identity

## Usage

```hcl
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_name        = "ecare"
  service_name        = "billing"
  environment         = "dev"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  namespace       = data.terraform_remote_state.platform.outputs.aks_namespace_name
  aks_oidc_issuer = data.terraform_remote_state.platform.outputs.aks_oidc_issuer_url

  repo   = "funmagsoft/billing-service"
  branch = "main"

  enable_key_vault_access   = true
  enable_storage_access     = true
  enable_service_bus_access = false

  key_vault_id             = data.terraform_remote_state.platform.outputs.key_vault_id
  storage_account_id       = data.terraform_remote_state.platform.outputs.storage_account_id
  service_bus_namespace_id = null

  additional_roles = []

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name (e.g. ecare) | `string` | - | yes |
| service_name | Logical service name (e.g. billing) | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| resource_group_name | Resource group where the User Assigned Managed Identity will be created | `string` | - | yes |
| location | Azure region | `string` | - | yes |
| repo | GitHub repository in org/repo format (e.g. funmagsoft/billing-service) | `string` | - | yes |
| branch | Git branch used for deployments (for OIDC subject) | `string` | `"main"` | no |
| namespace | Kubernetes namespace for the service account | `string` | `"ecare"` | no |
| aks_oidc_issuer | AKS OIDC issuer URL (from AKS output) | `string` | - | yes |
| enable_key_vault_access | If true, assign Key Vault Secrets User role on key_vault_id | `bool` | `false` | no |
| enable_storage_access | If true, assign Storage Blob Data Contributor role on storage_account_id | `bool` | `false` | no |
| enable_service_bus_access | If true, assign Azure Service Bus Data Owner role on service_bus_namespace_id | `bool` | `false` | no |
| key_vault_id | Key Vault ID for RBAC (required if enable_key_vault_access = true) | `string` | `null` | no |
| storage_account_id | Storage Account ID for RBAC (required if enable_storage_access = true) | `string` | `null` | no |
| service_bus_namespace_id | Service Bus Namespace ID for RBAC (required if enable_service_bus_access = true) | `string` | `null` | no |
| additional_roles | Additional RBAC roles to assign to the managed identity | `list(object({role=string, scope=string}))` | `[]` | no |
| tags | Additional tags to apply to the managed identity | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| identity_id | ID of the User Assigned Managed Identity | no |
| managed_identity_name | Name of the Managed Identity (null if Azure access is not enabled) | no |
| identity_client_id | Client ID of the User Assigned Managed Identity | no |
| identity_principal_id | Principal ID of the User Assigned Managed Identity | no |
| service_account_name | Name of the Kubernetes ServiceAccount | no |
| service_account_namespace | Namespace of the Kubernetes ServiceAccount | no |
| federated_credential_id | ID of the Federated Identity Credential | no |
| federated_credential_name | Name of the Federated Identity Credential (null if Azure access is not enabled) | no |
| enabled_services | Information about which Azure services are enabled for this identity | no |

## Module-Specific Configuration

### Conditional Resource Creation

The module creates the User Assigned Managed Identity and Federated Identity Credential only when at least one of the following conditions is met:

- `enable_key_vault_access = true`
- `enable_storage_access = true`
- `enable_service_bus_access = true`
- `length(additional_roles) > 0`

If none of these conditions are met, the Managed Identity and FIC are not created, and the corresponding outputs will be `null`.

### GitHub OIDC Configuration

The Federated Identity Credential uses GitHub OIDC with the following configuration:

- **Issuer:** `https://token.actions.githubusercontent.com`
- **Subject:** `repo:{repo}:ref:refs/heads/{branch}` (for GitHub Actions)
- **Audience:** `api://AzureADTokenExchange`

### Kubernetes ServiceAccount

The module creates a Kubernetes ServiceAccount with the following characteristics:

- **Name:** `sa-{service_name}` (e.g., `sa-billing`)
- **Namespace:** Specified via `namespace` variable (default: `ecare`)
- **Annotations:** Automatically configured for Azure Workload Identity:
  - `azure.workload.identity/client-id`: Set to the Managed Identity Client ID
  - `azure.workload.identity/use`: Set to `"true"`

### RBAC Role Assignments

The module supports three standard RBAC roles:

- **Key Vault:** `Key Vault Secrets User` (allows reading secrets)
- **Storage:** `Storage Blob Data Contributor` (allows read/write access to blobs)
- **Service Bus:** `Azure Service Bus Data Owner` (allows full access to Service Bus)

Additional custom roles can be assigned via the `additional_roles` variable, which accepts a list of objects with `role` (role definition name) and `scope` (resource scope) fields.

### Preconditions

The module includes preconditions to ensure data consistency:

- If `enable_key_vault_access = true`, then `key_vault_id` must not be null
- If `enable_storage_access = true`, then `storage_account_id` must not be null
- If `enable_service_bus_access = true`, then `service_bus_namespace_id` must not be null

## Naming Convention

Resources follow this naming pattern:

- **Managed Identity:** `mi-{project_name}-{service_name}-{environment}` (e.g., `mi-ecare-billing-dev`)
- **Federated Identity Credential:** `fic-{project_name}-{service_name}-{environment}` (e.g., `fic-ecare-billing-dev`)
- **Kubernetes ServiceAccount:** `sa-{service_name}` (e.g., `sa-billing`)

**Note:** Azure naming constraints apply to Managed Identities (3-128 characters, alphanumeric, hyphens, and underscores).

## Security Features

- **Passwordless Authentication:** Uses GitHub OIDC Federated Identity Credentials for secure, secret-free authentication
- **Least Privilege:** RBAC roles are assigned only when explicitly enabled
- **Conditional Creation:** Managed Identity is created only when needed, reducing unnecessary resources
- **Workload Identity Integration:** Kubernetes ServiceAccount is automatically configured for Azure Workload Identity
- **Tagging:** All resources are tagged with environment, project, service, and management information
- **Precondition Validation:** Ensures required resource IDs are provided when access is enabled

## Examples

### Development Environment

```hcl
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_name        = "ecare"
  service_name        = "billing"
  environment         = "dev"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  namespace       = data.terraform_remote_state.platform.outputs.aks_namespace_name
  aks_oidc_issuer = data.terraform_remote_state.platform.outputs.aks_oidc_issuer_url

  repo   = "funmagsoft/billing-service"
  branch = "main"

  enable_key_vault_access = true
  enable_storage_access   = true

  key_vault_id       = data.terraform_remote_state.platform.outputs.key_vault_id
  storage_account_id = data.terraform_remote_state.platform.outputs.storage_account_id

  tags = local.common_tags
}
```

### Production Environment

```hcl
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_name        = "ecare"
  service_name        = "billing"
  environment         = "prod"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  namespace       = data.terraform_remote_state.platform.outputs.aks_namespace_name
  aks_oidc_issuer = data.terraform_remote_state.platform.outputs.aks_oidc_issuer_url

  repo   = "funmagsoft/billing-service"
  branch = "main"

  enable_key_vault_access   = true
  enable_storage_access     = true
  enable_service_bus_access  = true

  key_vault_id             = data.terraform_remote_state.platform.outputs.key_vault_id
  storage_account_id       = data.terraform_remote_state.platform.outputs.storage_account_id
  service_bus_namespace_id = data.terraform_remote_state.platform.outputs.service_bus_namespace_id

  additional_roles = [
    {
      role  = "Reader"
      scope = "/subscriptions/<sub-id>/resourceGroups/rg-ecare-prod"
    }
  ]

  tags = local.common_tags
}
```

## Integration with Other Modules

This module integrates with:

- **infra-platform AKS module:** Requires AKS OIDC issuer URL and namespace name from platform outputs
- **infra-platform Key Vault module:** Uses Key Vault ID for RBAC role assignment
- **infra-platform Storage module:** Uses Storage Account ID for RBAC role assignment
- **infra-platform Service Bus module:** Uses Service Bus Namespace ID for RBAC role assignment

The module reads outputs from `data.terraform_remote_state.platform` to obtain:
- `aks_oidc_issuer_url` - Required for FIC configuration
- `aks_namespace_name` - Required for Kubernetes ServiceAccount namespace
- `key_vault_id` - Required if `enable_key_vault_access = true`
- `storage_account_id` - Required if `enable_storage_access = true`
- `service_bus_namespace_id` - Required if `enable_service_bus_access = true`

## Prerequisites

From Phase 1 (infra-foundation):

- Resource Group must exist
- AKS cluster must be deployed with OIDC issuer enabled

From Phase 2 (infra-platform):

- AKS cluster with Workload Identity enabled
- AKS namespace (default: `ecare`) must exist
- Key Vault (if `enable_key_vault_access = true`)
- Storage Account (if `enable_storage_access = true`)
- Service Bus Namespace (if `enable_service_bus_access = true`)

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
- Kubernetes Provider ~> 2.0
