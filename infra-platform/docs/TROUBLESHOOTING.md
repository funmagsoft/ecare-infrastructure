# Infrastructure Platform - Troubleshooting

## Common Issues

### AKS Deployment Issues

#### Issue: AKS cluster creation fails with subnet error

**Symptoms:**
```
Error: creating Managed Kubernetes Cluster: subnet is not valid
```

**Cause:** AKS subnet from foundation phase doesn't exist or has insufficient IP addresses.

**Solution:**
1. Verify foundation phase is deployed:
   ```bash
   cd ../infra-foundation/terraform/environments/dev
   terraform output aks_subnet_id
   ```
2. Check subnet CIDR has enough IPs (minimum /24 for small clusters)
3. Ensure NSG allows AKS required ports

#### Issue: AKS node pool fails to create

**Symptoms:**
```
Error: waiting for creation of Node Pool: context deadline exceeded
```

**Cause:** Network connectivity issues or insufficient quota.

**Solution:**
1. Check Azure quota for VM family:
   ```bash
   az vm list-usage --location westeurope --output table
   ```
2. Verify NSG rules allow AKS control plane communication
3. Check for Azure service outages

### PostgreSQL Issues

#### Issue: Cannot connect to PostgreSQL from Bastion

**Symptoms:**
```
psql: could not connect to server: Connection timed out
```

**Cause:** Private Endpoint DNS resolution or NSG rules.

**Solution:**
1. Verify Private Endpoint exists:
   ```bash
   az network private-endpoint list --resource-group rg-ecare-dev
   ```
2. Check DNS resolution from Bastion:
   ```bash
   nslookup psql-ecare-dev.postgres.database.azure.com
   # Should resolve to 10.1.2.x (private IP)
   ```
3. Verify NSG allows port 5432 from Management subnet to Data subnet

#### Issue: PostgreSQL admin password not found

**Symptoms:**
```
Error: postgresql_admin_password variable not set
```

**Cause:** Sensitive variable not provided.

**Solution:**
1. Set in terraform.tfvars (not committed to git):
   ```hcl
   postgresql_admin_password = "YourSecurePassword123!"
   ```
2. Or set via environment variable:
   ```bash
   export TF_VAR_postgresql_admin_password="YourSecurePassword123!"
   ```
3. Or use Azure Key Vault data source (recommended for CI/CD)

### Storage Account Issues

#### Issue: Cannot access storage from AKS pods

**Symptoms:**
```
Error: failed to get storage account: authorization failed
```

**Cause:** Workload Identity not configured or RBAC missing.

**Solution:**
1. Verify Workload Identity is deployed (Phase 2):
   ```bash
   cd ../../infra-identity/terraform/environments/dev
   terraform output workload_identities
   ```
2. Check pod has correct service account and labels
3. Verify RBAC role assignment on storage account

### Key Vault Issues

#### Issue: Cannot read secrets from Key Vault

**Symptoms:**
```
Error: access denied - user does not have get permission
```

**Cause:** Missing RBAC role or access policy.

**Solution:**
1. Verify RBAC role assignment:
   ```bash
   az role assignment list --scope /subscriptions/.../resourceGroups/rg-ecare-dev/providers/Microsoft.KeyVault/vaults/kv-ecare-dev
   ```
2. Check if using RBAC authorization (not access policies):
   ```bash
   az keyvault show --name kv-ecare-dev --query properties.enableRbacAuthorization
   ```
3. Assign "Key Vault Secrets User" role if needed

### ACR Issues

#### Issue: AKS cannot pull images from ACR

**Symptoms:**
```
Error: ErrImagePull - failed to pull image
```

**Cause:** Missing RBAC role or network connectivity.

**Solution:**
1. Verify AKS has AcrPull role on ACR:
   ```bash
   az role assignment list --scope /subscriptions/.../resourceGroups/rg-ecare-dev/providers/Microsoft.ContainerRegistry/registries/acrecaredev
   ```
2. Check Private Endpoint DNS resolution from AKS:
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup acrecaredev.azurecr.io
   ```
3. Verify Private DNS Zone is linked to VNet

### Bastion VM Issues

#### Issue: Cannot SSH to Bastion

**Symptoms:**
```
ssh: connect to host X.X.X.X port 22: Connection refused
```

**Cause:** NSG rules or public IP not assigned.

**Solution:**
1. Verify public IP exists and is assigned:
   ```bash
   az network public-ip show --name pip-bastion-ecare-dev --resource-group rg-ecare-dev
   ```
2. Check NSG allows SSH from your IP:
   ```bash
   az network nsg rule list --nsg-name nsg-bastion-ecare-dev --resource-group rg-ecare-dev
   ```
3. Update allowed_ssh_source_ips in terraform.tfvars

#### Issue: Bastion tools not installed

**Symptoms:**
```
bash: kubectl: command not found
```

**Cause:** Cloud-init script failed or not completed.

**Solution:**
1. Check cloud-init status:
   ```bash
   sudo cloud-init status
   ```
2. Review cloud-init logs:
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```
3. Manually install tools if needed or redeploy Bastion

### Terraform State Issues

#### Issue: State lock timeout

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Cause:** Previous Terraform run didn't release lock.

**Solution:**
1. Check if another Terraform process is running
2. If stuck, force unlock (use with caution):
   ```bash
   terraform force-unlock <LOCK_ID>
   ```
3. Verify storage account is accessible

#### Issue: Cannot read remote state from foundation

**Symptoms:**
```
Error: error reading terraform remote state: blob not found
```

**Cause:** Foundation phase not deployed or state file missing.

**Solution:**
1. Deploy foundation phase first:
   ```bash
   cd ../../infra-foundation/terraform/environments/dev
   terraform apply
   ```
2. Verify state file exists in storage account
3. Check backend configuration in data.tf

## Validation Commands

### Pre-deployment Checks

```bash
# Check foundation outputs
cd ../../infra-foundation/terraform/environments/dev
terraform output

# Check identity outputs
cd ../../infra-identity/terraform/environments/dev
terraform output

# Validate platform configuration
cd ../../infra-platform/terraform/environments/dev
terraform validate
terraform plan
```

### Post-deployment Verification

```bash
# Verify AKS cluster
az aks show --name aks-ecare-dev --resource-group rg-ecare-dev

# Get AKS credentials
az aks get-credentials --name aks-ecare-dev --resource-group rg-ecare-dev --overwrite-existing

# Check nodes
kubectl get nodes

# Verify PostgreSQL
az postgres flexible-server show --name psql-ecare-dev --resource-group rg-ecare-dev

# Check storage account
az storage account show --name <storage-name> --resource-group rg-ecare-dev

# Verify Key Vault
az keyvault show --name kv-ecare-dev

# Check ACR
az acr show --name acrecaredev --resource-group rg-ecare-dev
```

## Getting Help

1. Check Azure Activity Log for detailed error messages
2. Review Terraform debug logs: `TF_LOG=DEBUG terraform apply`
3. Consult Azure documentation for service-specific issues
4. Check project README and architecture documentation

## Known Limitations

- Storage Account names must be globally unique (24 chars, lowercase alphanumeric)
- ACR names must be globally unique (5-50 chars, alphanumeric)
- Key Vault names must be globally unique (3-24 chars, alphanumeric + hyphens)
- Private Endpoints require Premium SKU for some services (Service Bus)
- AKS requires minimum /24 subnet for small clusters
- PostgreSQL Flexible Server requires minimum /28 delegated subnet (if using VNet integration)
