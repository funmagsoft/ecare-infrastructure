# Infrastructure Platform - Deployment Guide

## Prerequisites

Before deploying platform infrastructure, ensure:

1. **Phase 0 (Scripts)** is completed:
   - Resource Group exists
   - Terraform state storage account exists
   - Current user has access to state storage

2. **Phase 1 (infra-foundation)** is deployed:
   - Virtual Network with subnets
   - Network Security Groups
   - Service Principal for GitHub Actions (if using bootstrap)

3. **Phase 2 (infra-identity)** is deployed:
   - Workload Identities for services
   - GitHub OIDC integration

4. **Tools installed**:
   - Terraform >= 1.5.0
   - Azure CLI
   - kubectl (for post-deployment verification)

## Deployment Steps

### 1. Prepare Environment Configuration

Navigate to the environment directory:

```bash
cd infra-platform/terraform/environments/dev
```

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Core Configuration
environment       = "dev"
deployment_id     = "a1b2c3d4"  # Same as foundation/identity
subscription_id   = null         # Optional, recommended in CI/CD
organization_name = "hycom"
project_name      = "ecare"

# PostgreSQL Configuration
postgresql_admin_password = "YourSecurePassword123!"  # REQUIRED

# Bastion Configuration
bastion_allowed_ssh_source_ips = ["YOUR.IP.ADDRESS/32"]

# Optional: Additional tags
# tags = {
#   CostCenter = "Engineering"
#   Owner      = "Platform Team"
# }
```

**Important:** Never commit `terraform.tfvars` to git (it's in `.gitignore`).

### 2. Initialize Terraform

Initialize the Terraform working directory:

```bash
terraform init
```

This will:
- Download required providers (AzureRM, Kubernetes)
- Configure remote state backend
- Initialize modules

### 3. Validate Configuration

Validate the Terraform configuration:

```bash
terraform validate
```

### 4. Plan Deployment

Review the execution plan:

```bash
terraform plan
```

Review the plan carefully. It should show:
- ~20-30 resources to create (depending on configuration)
- No resources to destroy (first deployment)
- Correct resource names and configurations

### 5. Apply Configuration

Deploy the infrastructure:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

**Deployment time:** Approximately 15-20 minutes (AKS cluster takes the longest).

### 6. Verify Deployment

After successful deployment, verify outputs:

```bash
terraform output
```

Expected outputs:
- `aks_cluster_name`
- `aks_oidc_issuer_url`
- `postgresql_fqdn`
- `storage_account_name`
- `key_vault_uri`
- `acr_login_server`
- `bastion_public_ip`
- And more...

## Post-Deployment Configuration

### 1. Configure kubectl

Get AKS credentials:

```bash
az aks get-credentials \
  --resource-group rg-ecare-dev \
  --name aks-ecare-dev \
  --overwrite-existing
```

Verify cluster access:

```bash
kubectl get nodes
kubectl get namespaces
```

### 2. Access Bastion VM

SSH to Bastion:

```bash
ssh azureuser@<bastion_public_ip>
```

From Bastion, you can:
- Access PostgreSQL: `psql -h psql-ecare-dev.postgres.database.azure.com -U psqladmin`
- Access AKS: `kubectl get nodes`
- Use Azure CLI: `az account show`

### 3. Store Secrets in Key Vault

Store PostgreSQL password in Key Vault:

```bash
az keyvault secret set \
  --vault-name kv-ecare-dev \
  --name postgresql-admin-password \
  --value "YourSecurePassword123!"
```

### 4. Configure ACR Integration

AKS should automatically have access to ACR. Verify:

```bash
kubectl run test --image=acrecaredev.azurecr.io/test:latest --dry-run=client
```

## Environment-Specific Configurations

### Development (dev)

- **AKS**: Standard tier, 1-3 user nodes, auto-scaling enabled
- **PostgreSQL**: Basic tier, no HA, 7-day backup retention
- **Storage**: LRS replication
- **Key Vault**: Standard SKU
- **Service Bus**: Standard tier
- **ACR**: Premium (for Private Endpoint)

### Test (test)

Similar to dev, but with:
- Separate deployment_id
- Potentially different node sizes
- Same backup/retention policies

### Staging (stage)

Pre-production configuration:
- **AKS**: Standard tier, 2-5 user nodes
- **PostgreSQL**: Zone-redundant HA, 14-day backup retention
- **Storage**: ZRS replication
- **Key Vault**: Standard SKU, purge protection enabled
- **Service Bus**: Premium tier (if needed)

### Production (prod)

Production-grade configuration:
- **AKS**: Standard/Premium tier, 3-10 user nodes, auto-scaling
- **PostgreSQL**: Zone-redundant HA, 35-day backup retention
- **Storage**: GZRS replication
- **Key Vault**: Premium SKU, purge protection enabled
- **Service Bus**: Premium tier with zone redundancy
- **ACR**: Premium with geo-replication
- **Bastion**: Restricted SSH access (specific IPs only)

## Updating Infrastructure

### Making Changes

1. Edit `terraform.tfvars` or Terraform files
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

### Common Updates

#### Scale AKS User Node Pool

Edit `terraform.tfvars`:

```hcl
aks_user_node_pool_min_count = 2
aks_user_node_pool_max_count = 5
```

Apply:

```bash
terraform apply
```

#### Update Bastion Allowed IPs

Edit `terraform.tfvars`:

```hcl
bastion_allowed_ssh_source_ips = ["NEW.IP.ADDRESS/32"]
```

Apply:

```bash
terraform apply
```

#### Enable PostgreSQL High Availability

Edit `terraform.tfvars`:

```hcl
postgresql_high_availability_enabled = true
postgresql_high_availability_mode    = "ZoneRedundant"
```

Apply:

```bash
terraform apply
```

## Destroying Infrastructure

**Warning:** This will delete all platform resources. Data will be lost unless backups exist.

### Destroy Specific Environment

```bash
cd infra-platform/terraform/environments/dev
terraform destroy
```

### Cleanup by Deployment ID

Use the cleanup script to remove all resources (including Entra ID):

```bash
# Preview (dry-run)
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4

# Execute
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4 --execute
```

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.

## CI/CD Deployment

For GitHub Actions deployment:

1. Service Principal is created in Phase 1 (foundation)
2. Federated Identity Credentials are configured
3. GitHub Actions workflow uses OIDC authentication
4. Terraform runs with `subscription_id` variable set

Example workflow snippet:

```yaml
- name: Terraform Apply
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
    TF_VAR_subscription_id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    TF_VAR_postgresql_admin_password: ${{ secrets.POSTGRESQL_PASSWORD }}
  run: |
    cd infra-platform/terraform/environments/dev
    terraform init
    terraform apply -auto-approve
```

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Use separate deployment_id for each environment**
3. **Store sensitive values in Key Vault, not in code**
4. **Enable soft delete and purge protection in production**
5. **Restrict Bastion SSH access to specific IPs**
6. **Use zone redundancy for production databases**
7. **Enable auto-scaling for AKS user node pools**
8. **Monitor costs and set up budget alerts**
9. **Regularly review and update Kubernetes versions**
10. **Test changes in dev/test before production**

