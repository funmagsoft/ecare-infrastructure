# Troubleshooting Guide - Infrastructure Foundation

## Overview

This document provides solutions to common issues encountered when working with the `infra-foundation` repository.

For operational procedures (deployment, verification, cleanup), see **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

---

## Common Issues

### Problem: `terraform destroy` fails

**Symptoms:**

```
Error: Error deleting Virtual Network: ... Resource is locked
Error: ... cannot be deleted because they are in use
```

**Causes:**

1. Resource locks preventing deletion
2. Resources still in use by other services
3. Terraform state corruption
4. Network dependencies (VNet has subnets in use)

**Solution:**

Use the emergency cleanup script:

```bash
cd /path/to/infra-foundation
./scripts/cleanup-terraform-emergency.sh
```

This script bypasses Terraform and deletes resources directly via Azure CLI.

**⚠️ Warning:** This is destructive and bypasses Terraform state management. Use only when `terraform destroy` fails.

**See also:** [DEPLOYMENT.md - Emergency Teardown](./DEPLOYMENT.md#procedure-2-emergency-teardown-terraform-destroy-failed)

---

### Problem: Lost Service Principal IDs

**Symptoms:**

- File `scripts/service-principals.env` is missing or empty
- Cannot find Service Principal App IDs for GitHub Actions secrets

**Solution:**

Recover Service Principal IDs from Azure AD:

```bash
cd /path/to/infra-foundation
./scripts/recover-sp-ids.sh
```

This script queries Azure AD and recreates `scripts/service-principals.env`.

**Output example:**

```bash
SP_APP_ID_DEV="12345678-1234-1234-1234-123456789abc"
SP_APP_ID_TEST="..."
SP_APP_ID_STAGE="..."
SP_APP_ID_PROD="..."
```

---

### Problem: Backend initialization fails

**Symptoms:**

```
Error: Failed to get existing workspaces: storage: service returned error: StatusCode=404
Error: Backend initialization required
```

**Causes:**

1. Phase 0 not set up (Resource Group or Storage Account missing)
2. Wrong backend configuration in `versions.tf`
3. Authentication issues (not logged in via `az login`)

**Solution:**

**Step 1:** Verify Phase 0 infrastructure:

```bash
./scripts/verify-phase0.sh
```

Expected output: All checks pass ✓

**Step 2:** If Phase 0 is missing, run setup:

```bash
./scripts/setup-phase0.sh
```

**Step 3:** Verify authentication:

```bash
az account show
```

**Step 4:** Try `terraform init` again:

```bash
cd terraform/environments/dev
terraform init
```

---

### Problem: Resource locks prevent deletion

**Symptoms:**

```
Error: Error deleting Resource Group: ... Resource is locked
```

**Causes:**

- Resource locks applied manually (not by Terraform)
- Azure Policy enforcement

**Solution:**

**Step 1:** List resource locks:

```bash
az lock list --resource-group rg-ecare-dev --output table
```

**Step 2:** Delete locks:

```bash
# Get lock IDs
LOCK_IDS=$(az lock list --resource-group rg-ecare-dev --query "[].id" -o tsv)

# Delete each lock
echo "$LOCK_IDS" | while read lock_id; do
  az lock delete --ids "$lock_id"
done
```

**Step 3:** Retry `terraform destroy`:

```bash
terraform destroy
```

---

### Problem: `terraform apply` fails due to existing resources

**Symptoms:**

```
Error: A resource with the ID "/subscriptions/.../resourceGroups/rg-ecare-dev" already exists
```

**Causes:**

1. Resources created manually or by scripts
2. Terraform state out of sync with reality
3. Previous `terraform apply` partially completed

**Solution:**

**Option A:** Import existing resources into Terraform state:

```bash
# Example: Import Resource Group
terraform import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/rg-ecare-dev

# Example: Import Storage Account
terraform import azurerm_storage_account.state /subscriptions/{subscription-id}/resourceGroups/rg-ecare-dev/providers/Microsoft.Storage/storageAccounts/tfstatefmsecaredev
```

**Option B:** Delete existing resources and let Terraform recreate them:

```bash
# ⚠️ WARNING: This is destructive!
az group delete --name rg-ecare-dev --yes
terraform apply
```

**Option C:** Use emergency cleanup and redeploy:

```bash
./scripts/cleanup-phase0.sh  # Deletes Phase 0 resources
./scripts/setup-phase0.sh    # Recreates Phase 0
cd terraform/environments/dev
terraform apply              # Creates Terraform-managed resources
```

---

### Problem: `terraform init` fails

**Symptoms:**

```
Error: Failed to query available provider packages
Error: Could not retrieve the list of available versions
```

**Causes:**

1. Network connectivity issues
2. Provider registry unreachable
3. Incorrect provider version constraints

**Solution:**

**Step 1:** Check network connectivity:

```bash
curl -I https://registry.terraform.io
```

**Step 2:** Verify provider version constraints in `versions.tf`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"  # ✓ Correct
    }
  }
}
```

**Step 3:** Clear Terraform cache and retry:

```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

**Step 4:** If behind corporate proxy, configure:

```bash
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
terraform init
```

---

### Problem: Azure CLI authentication issues

**Symptoms:**

```
Error: building account: could not acquire access token
Error: The client ... does not have authorization to perform action
```

**Causes:**

1. Not logged in via `az login`
2. Wrong subscription selected
3. Insufficient permissions

**Solution:**

**Step 1:** Login to Azure CLI:

```bash
az login
```

**Step 2:** Select correct subscription:

```bash
# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "Your Subscription Name"

# Verify
az account show
```

**Step 3:** Verify permissions:

```bash
# Check your role assignments
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --output table
```

Required roles:

- Contributor (or Owner) on subscription or Resource Group
- User Access Administrator (if assigning RBAC roles)

---

### Problem: Script execution permissions

**Symptoms:**

```bash
-bash: ./scripts/setup-phase0.sh: Permission denied
```

**Solution:**

Add execute permissions:

```bash
chmod +x scripts/*.sh
```

Or run with `bash`:

```bash
bash scripts/setup-phase0.sh
```

---

### Problem: VPN Gateway deployment takes too long

**Symptoms:**

- `terraform apply` runs for 30-45 minutes
- VPN Gateway creation stuck at "Creating..."

**Expected behavior:**

VPN Gateway creation takes **20-45 minutes** - this is normal Azure behavior.

**Solution:**

**Be patient** - this is expected. VPN Gateway deployment is slow due to:

1. Complex networking setup
2. Multiple VMs provisioned behind the scenes
3. HA configuration (if enabled)

**Workaround for dev/test:**

Disable VPN Gateway and use SSH access instead:

```hcl
# terraform.tfvars
enable_vpn_gateway = false

mgmt_subnet_allowed_ssh_ips = [
  "YOUR_PUBLIC_IP/32"
]
```

---

### Problem: Cannot connect to VPN

**Symptoms:**

- VPN client shows "Connecting..." but never connects
- Connection timeout

**Causes:**

1. Incorrect VPN client configuration
2. Root certificate not installed
3. Firewall blocking VPN protocols

**Solution:**

**Step 1:** Verify VPN Gateway is running:

```bash
az network vnet-gateway show \
  --name vpn-gw-ecare-dev \
  --resource-group rg-ecare-dev \
  --query "provisioningState" -o tsv
```

Expected: `Succeeded`

**Step 2:** Download VPN client configuration:

```bash
az network vnet-gateway vpn-client generate \
  --name vpn-gw-ecare-dev \
  --resource-group rg-ecare-dev \
  --processor-architecture Amd64
```

**Step 3:** Install root certificate on client machine (Windows/macOS)

**Step 4:** Import VPN profile from downloaded configuration

**Step 5:** Test connectivity:

```bash
# After connecting to VPN
ping 10.1.0.1  # Test VNet connectivity
```

---

### Problem: Pre-commit hooks fail

**Symptoms:**

```
terraform_validate...Failed
markdownlint.........Failed
```

**Causes:**

1. Terraform modules not initialized (`terraform init` not run)
2. Markdown formatting issues
3. Missing pre-commit dependencies

**Solution:**

**For terraform_validate:**

```bash
# Skip validation temporarily
SKIP=terraform_validate git commit -m "message"

# Or initialize Terraform first
cd terraform/environments/dev
terraform init
cd ../../..
git commit -m "message"
```

**For markdownlint:**

Fix reported issues:

```bash
# Install markdownlint
npm install -g markdownlint-cli

# Check issues
markdownlint docs/

# Auto-fix (if possible)
markdownlint --fix docs/
```

---

### Problem: SSH access to management subnet blocked

**Symptoms:**

```
ssh: connect to host 10.1.17.4 port 22: Connection timed out
```

**Causes:**

1. Your IP not in `mgmt_subnet_allowed_ssh_ips`
2. NSG rule not applied
3. VM not running

**Solution:**

**Step 1:** Add your IP to allowed list:

```hcl
# terraform.tfvars
mgmt_subnet_allowed_ssh_ips = [
  "YOUR_PUBLIC_IP/32"
]
```

**Step 2:** Apply changes:

```bash
terraform apply
```

**Step 3:** Verify NSG rule:

```bash
az network nsg rule show \
  --resource-group rg-ecare-dev \
  --nsg-name nsg-mgmt-ecare-dev \
  --name AllowSSHInbound \
  --output table
```

**Step 4:** Get your public IP:

```bash
curl ifconfig.me
```

---

## Getting Help

### Check Documentation

1. **[RUNBOOK.md](./RUNBOOK.md)**: Operational procedures
2. **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Architecture overview
3. **[SCRIPTS-REFERENCE.md](./SCRIPTS-REFERENCE.md)**: Scripts documentation
4. **Module READMEs**: `terraform/modules/*/README.md`

### Verification Commands

```bash
# Verify Phase 0
./scripts/verify-phase0.sh

# Verify Terraform Bootstrap
./scripts/verify-terraform-bootstrap.sh

# Verify Terraform Environment
./scripts/verify-terraform-environment.sh

# Verify everything
./scripts/verify-all.sh
```

### Azure Portal Checks

1. Navigate to Azure Portal → Resource Groups
2. Check `rg-ecare-{env}` exists
3. Verify resources: Storage Account, VNet, NSG, etc.
4. Check Activity Log for errors

### Support Channels

- **Internal Documentation**: `docs/` directory
- **Azure Documentation**: [docs.microsoft.com/azure](https://docs.microsoft.com/en-us/azure/)
- **Terraform Documentation**: [terraform.io](https://www.terraform.io/docs)
- **Team**: Contact DevOps team for assistance
