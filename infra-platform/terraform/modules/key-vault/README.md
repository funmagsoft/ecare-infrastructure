# Key Vault Module

Terraform module for deploying Azure Key Vault with Private Endpoint for secure secrets, keys, and
certificates management.

## Resources Created

- **Key Vault** - Azure Key Vault for secrets, keys, and certificates
- **Private Endpoint** - Private network access to Key Vault

## Features

- RBAC-based authorization (recommended over access policies)
- Soft delete with configurable retention (7-90 days)
- Optional purge protection for production
- Public network access disabled by default
- Private Endpoint integration
- Network ACLs with deny-by-default policy

## Usage

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  project_name        = "ecare"

  sku_name                   = "standard"
  purge_protection_enabled   = false  # true for production
  soft_delete_retention_days = 7      # 90 for production

  # Private Endpoint configuration
  subnet_id = data.terraform_remote_state.foundation.outputs.data_subnet_id
  vnet_id   = data.terraform_remote_state.foundation.outputs.vnet_id
  vnet_name = data.terraform_remote_state.foundation.outputs.vnet_name

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name for resource naming | `string` | `"ecare"` | no |
| sku_name | SKU name for Key Vault (standard or premium) | `string` | `"standard"` | no |
| enabled_for_deployment | Enable Azure Virtual Machines to retrieve certificates | `bool` | `false` | no |
| enabled_for_disk_encryption | Enable Azure Disk Encryption to retrieve secrets | `bool` | `false` | no |
| enabled_for_template_deployment | Enable Azure Resource Manager to retrieve secrets | `bool` | `true` | no |
| rbac_authorization_enabled | Use RBAC for authorization instead of access policies | `bool` | `true` | no |
| soft_delete_retention_days | Retention days for soft delete (7-90) | `number` | `90` | no |
| purge_protection_enabled | Enable purge protection (cannot be disabled once enabled) | `bool` | `false` | no |
| public_network_access_enabled | Enable public network access | `bool` | `true` | no |
| subnet_id | Subnet ID for Private Endpoint | `string` | - | yes |
| vnet_id | Virtual Network ID for Private DNS Zone link | `string` | - | no |
| vnet_name | Virtual Network name for Private DNS Zone link | `string` | - | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| key_vault_id | ID of the Key Vault | no |
| key_vault_name | Name of the Key Vault | no |
| key_vault_uri | URI of the Key Vault | no |
| private_endpoint_id | ID of the Private Endpoint | no |
| private_endpoint_ip | Private IP address of the Private Endpoint | no |
| private_dns_zone_id | ID of the Private DNS Zone for Key Vault | no |

## Module-Specific Configuration

### RBAC Authorization

This module uses RBAC by default. Grant access using Azure role assignments:

#### Common Roles

| Role | Purpose | Use Case |
|------|---------|----------|
| Key Vault Administrator | Full management | Admins, Terraform service principal |
| Key Vault Secrets Officer | Manage secrets | CI/CD pipelines |
| Key Vault Secrets User | Read secrets | Applications, services |
| Key Vault Certificates Officer | Manage certificates | Certificate automation |
| Key Vault Crypto Officer | Manage keys | Encryption operations |

#### Grant Access Example

```bash
# Grant application identity access to read secrets
az role assignment create \
  --assignee <app-identity-object-id> \
  --role "Key Vault Secrets User" \
  --scope <key-vault-id>

# Grant Terraform service principal full access
az role assignment create \
  --assignee <terraform-sp-object-id> \
  --role "Key Vault Administrator" \
  --scope <key-vault-id>
```

### Soft Delete and Purge Protection

#### Soft Delete

- **Enabled by default** (Azure requirement)
- Deleted vaults/secrets recoverable within retention period
- Retention: 7-90 days (configurable)
- Free feature

#### Purge Protection

- **Prevents permanent deletion** during retention period
- **Cannot be disabled once enabled** (irreversible!)
- Recommended for production
- Additional safety layer

#### Configuration Examples

```hcl
# Development: Short retention, no purge protection
soft_delete_retention_days = 7
purge_protection_enabled   = false

# Production: Long retention, purge protection enabled
soft_delete_retention_days = 90
purge_protection_enabled   = true
```

### SKU Comparison

| Feature | Standard | Premium |
|---------|----------|---------|
| Secrets | ✓ | ✓ |
| Keys | ✓ | ✓ |
| Certificates | ✓ | ✓ |
| HSM-backed keys | ✗ | ✓ |
| Price | Lower | Higher |

**Recommendation**: Use `standard` unless you need HSM-protected keys.

## Naming Convention

Resources follow this naming pattern:

- Key Vault: `kv-{project_name}-{environment}` (e.g., `kv-ecare-dev`)
- Private Endpoint: `{key_vault_name}-pe`

## Security Features

### Network Isolation

- `public_network_access_enabled = false`
- Access only via Private Endpoint
- Network ACLs: Deny by default, Allow Azure Services

### Access Control

- RBAC-based authorization (recommended)
- Fine-grained permissions per secret/key/certificate
- Azure AD integration
- Managed Identity support

## Examples

### Development Environment

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  sku_name                   = "standard"
  purge_protection_enabled   = false  # Flexible for dev
  soft_delete_retention_days = 7      # Short retention

  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

### Production Environment

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"
  
  sku_name                   = "premium"  # HSM support
  purge_protection_enabled   = true       # Extra protection
  soft_delete_retention_days = 90         # Maximum retention

  subnet_id = var.data_subnet_id
  vnet_id   = var.vnet_id
  vnet_name = var.vnet_name
}
```

## Storing Secrets

### Using Azure CLI

```bash
# Store a secret
az keyvault secret set \
  --vault-name kv-ecare-dev \
  --name "database-password" \
  --value "SecurePassword123!"

# Retrieve a secret
az keyvault secret show \
  --vault-name kv-ecare-dev \
  --name "database-password" \
  --query "value" -o tsv
```

### Using Terraform

```hcl
resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = var.database_password
  key_vault_id = module.key_vault.key_vault_id
}
```

### From Applications (Managed Identity)

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url="https://kv-ecare-prod.vault.azure.net/",
    credential=credential
)

secret = client.get_secret("database-password")
print(secret.value)
```

## Integration with Other Modules

### Phase 3 (Workload Identity)

Key Vault will be used to store:

- Service Principal credentials
- Database connection strings
- API keys and tokens
- Certificates for TLS

Workload Identity will access secrets using Federated Identity Credentials (no secrets needed!).

## Prerequisites

From Phase 1 (infra-foundation):

- Data subnet for Private Endpoint
- Virtual Network ID and name for Private DNS Zone link

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
