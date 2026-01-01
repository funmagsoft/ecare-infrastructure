# Deployment Guide - Infrastructure Foundation

This document describes operational procedures for deploying, verifying, and destroying infrastructure in the `foundation` component of the ecare-infrastructure monorepo.

## Table of Contents

- [Overview](#overview)
- [Infrastructure Layers](#infrastructure-layers)
- [Scripts Reference](#scripts-reference)
- [Deployment Procedures](#deployment-procedures)
- [Verification Procedures](#verification-procedures)
- [Destruction Procedures](#destruction-procedures)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

## Overview

The `foundation` component contains infrastructure code for Phase 0 prerequisites and Terraform modules for
foundational Azure infrastructure (networking, VPN, GitHub OIDC integration).

**Key Principles:**

- **Phase 0** (bash scripts): Creates prerequisites for Terraform (Resource Groups, Storage Accounts, user access)
- **Terraform**: Manages all other infrastructure (bootstrap, network, VPN)
- **Separation of Concerns**: Terraform destroys Terraform resources; scripts destroy Phase 0 resources

## Infrastructure Layers

### Layer 1: Phase 0 (Managed by Bash Scripts)

**Purpose:** Prerequisites for Terraform state management

**Resources:**

- Resource Groups (`rg-<project>-<env>`)
- Storage Accounts for Terraform state (`tfstate<org><project><env>`)
- Current user RBAC access (Storage Blob Data Contributor)

**Scripts:** `setup-phase0.sh`, `verify-phase0.sh`, `cleanup-phase0.sh`

### Layer 2: Terraform Bootstrap (Managed by Terraform)

**Purpose:** GitHub Actions integration with Azure (OIDC, passwordless authentication)

**Resources:**

- Service Principals for GitHub Actions (`sp-gha-<project>-infra-<env>`)
- Federated Identity Credentials (OIDC)
- RBAC role assignments (Contributor, User Access Administrator, Storage Blob Data Contributor)

**Terraform Module:** `terraform/modules/bootstrap`

### Layer 3: Terraform Environment (Managed by Terraform)

**Purpose:** Foundational network infrastructure

**Resources:**

- Virtual Network and Subnets (aks, data, mgmt, gateway)
- Network Security Groups
- VPN Gateway (optional)
- Route Tables

**Terraform Module:** `terraform/modules/environment`

## Scripts Reference

### Phase 0 Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `setup-phase0.sh` | Create Phase 0 infrastructure | First-time setup, environment bootstrap |
| `verify-phase0.sh` | Verify Phase 0 only | After Phase 0 setup, before Terraform |
| `cleanup-phase0.sh` | Delete Phase 0 only | Complete teardown (after Terraform destroy) |

**Helper Scripts (called by setup-phase0.sh):**

- `setup-rg.sh` - Creates Resource Groups
- `setup-state-storage.sh` - Creates Storage Accounts
- `setup-access-user.sh` - Grants current user access

### Verification Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `verify-all.sh` | Verify ALL infrastructure | Health check after complete deployment |
| `verify-terraform-bootstrap.sh` | Verify Bootstrap module only | After Terraform bootstrap deployment |
| `verify-terraform-environment.sh` | Verify Environment module only | After Terraform environment deployment |

**Helper Scripts (called by verify-phase0.sh):**

- `verify-rg.sh` - Verifies Resource Groups
- `verify-state-storage.sh` - Verifies Storage Accounts
- `verify-access-user.sh` - Verifies current user RBAC

### Emergency Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `cleanup-terraform-emergency.sh` | Emergency Terraform cleanup | When `terraform destroy` fails |

### Utility Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `recover-sp-ids.sh` | Recover Service Principal IDs from Azure | Lost `service-principals.env` file |

## Deployment Procedures

### Procedure 1: First-Time Setup (Complete Infrastructure)

**Use Case:** Deploying to a new environment for the first time

**Steps:**

```bash
# 1. Phase 0 Setup
cd foundation
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh

# 2. Terraform Deployment (Bootstrap + Environment)
cd terraform/environments/dev
terraform init
terraform plan     # Review changes
terraform apply    # Creates SP, FIC, RBAC, VNet, NSG, VPN

# 3. Complete Verification
cd ../../..
./scripts/verify-all.sh
```

**Expected Duration:**

- Phase 0: 5-10 minutes
- Terraform apply: 15-30 minutes (60+ minutes if VPN enabled)
- Total: 20-40 minutes (65-100 minutes with VPN)

**Success Criteria:**

- `verify-all.sh` exits with code 0
- All resources visible in Azure Portal
- GitHub Actions can authenticate (test with workflow run)

### Procedure 2: Bootstrap Only Deployment

**Use Case:** Setting up GitHub Actions authentication without deploying network infrastructure

**Steps:**

```bash
# 1. Phase 0 (if not exists)
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh

# 2. Bootstrap Module Only
cd terraform/environments/dev
terraform init
terraform plan -target=module.bootstrap
terraform apply -target=module.bootstrap

# 3. Verify Bootstrap
cd ../../..
./scripts/verify-terraform-bootstrap.sh
```

**Expected Duration:** 5-10 minutes

**Use Cases:**

- Initial GitHub Actions setup
- Updating RBAC roles without touching network
- Debugging bootstrap configuration

### Procedure 3: Environment Only Deployment

**Use Case:** Deploying network infrastructure when bootstrap already exists

**Prerequisites:** Phase 0 + Bootstrap must already exist

**Steps:**

```bash
# 1. Environment Module Only
cd terraform/environments/dev
terraform init
terraform plan -target=module.environment
terraform apply -target=module.environment

# 2. Verify Environment
cd ../../..
./scripts/verify-terraform-environment.sh
```

**Expected Duration:** 10-20 minutes (45-60 minutes if VPN enabled)

**Use Cases:**

- Deploying network after bootstrap
- Updating network configuration
- Debugging environment module

### Procedure 4: Configuration Update

**Use Case:** Updating existing infrastructure (changing variables, adding resources)

**Steps:**

```bash
# 1. Edit Configuration
cd terraform/environments/dev
# Edit terraform.tfvars or Terraform code

# 2. Review and Apply Changes
terraform plan     # Review changes carefully
terraform apply

# 3. Verify
cd ../../..
./scripts/verify-all.sh
```

**Expected Duration:** 5-60 minutes (depends on changes)

## Verification Procedures

### Quick Health Check

**Use Case:** Verify all infrastructure is working correctly

```bash
cd foundation
./scripts/verify-all.sh
```

**What It Checks:**

- Phase 0: 4 Resource Groups, 4 Storage Accounts, User Access
- Bootstrap: 4 Service Principals, 12 FIC, RBAC roles
- Environment: VNet, 16 Subnets, 12 NSGs, VPN (if enabled)

**Expected Output:**

```
✓ Phase 0 (4 Resource Groups, 4 Storage Accounts, User Access)
✓ Bootstrap (4 Service Principals, 12 FIC, RBAC roles)
✓ Environment (VNet, Subnets, NSG, VPN)
```

### Granular Verification

**Use Case:** Verify specific layer after targeted deployment

**Phase 0 Only:**

```bash
./scripts/verify-phase0.sh
```

**Bootstrap Only:**

```bash
./scripts/verify-terraform-bootstrap.sh
```

**Environment Only:**

```bash
./scripts/verify-terraform-environment.sh
```

### Verification Failure Handling

**If verification fails:**

1. **Review Error Messages:** Scripts provide detailed error messages with hints
2. **Check Azure Portal:** Manually verify resource existence and state
3. **Review Terraform State:**

```bash
cd terraform/environments/dev
terraform state list
terraform show
```

4. **Re-run Terraform Apply:**

```bash
terraform apply
```

## Destruction Procedures

### Procedure 1: Normal Teardown (Terraform Works)

**Use Case:** Clean environment teardown when Terraform is functional

**Steps:**

```bash
# 1. Destroy Terraform Resources
cd terraform/environments/dev
terraform plan -destroy    # Review what will be deleted
terraform destroy          # Confirm with 'yes'

# 2. Cleanup Phase 0
cd ../../..
./scripts/cleanup-phase0.sh

# 3. Verify Complete Cleanup
az group list --query "[?starts_with(name, 'rg-ecare-')]"
# Should return: []
```

**Expected Duration:** 20-40 minutes (60+ minutes if VPN exists)

**What Gets Deleted:**

- Terraform: VPN, NSG, VNet, SP, FIC, RBAC
- Phase 0: Storage Accounts (including state!), Resource Groups

**⚠️ WARNING:** This deletes Terraform state files permanently. Cannot be undone.

### Procedure 2: Emergency Teardown (Terraform Destroy Failed)

**Use Case:** When `terraform destroy` fails due to state corruption, locks, or other errors

**Steps:**

```bash
# 1. Attempt Normal Destroy First
cd terraform/environments/dev
terraform destroy
# ❌ FAILS

# 2. Emergency Cleanup (deletes Terraform resources via Azure API)
cd ../../..
./scripts/cleanup-terraform-emergency.sh
# Type: DELETE-TERRAFORM-RESOURCES to confirm

# 3. Cleanup Phase 0
./scripts/cleanup-phase0.sh

# 4. Verify Cleanup
./scripts/verify-all.sh
# Should fail (all resources deleted)
```

**Expected Duration:** 30-60 minutes (VPN takes longest)

**When to Use:**

- `terraform destroy` fails with state corruption
- Resource locks prevent deletion
- Circular dependency errors
- Partial destroy leaves orphaned resources

**⚠️ DANGER:** Bypasses Terraform state management. Use only as last resort.

### Procedure 3: Partial Teardown (Bootstrap Only)

**Use Case:** Remove GitHub Actions integration but keep network

**Steps:**

```bash
cd terraform/environments/dev

# Destroy bootstrap resources
terraform destroy -target=module.bootstrap

# Verify
cd ../../..
./scripts/verify-terraform-bootstrap.sh
# Should fail (bootstrap deleted)
```

### Procedure 4: Partial Teardown (Environment Only)

**Use Case:** Remove network infrastructure but keep bootstrap

**Steps:**

```bash
cd terraform/environments/dev

# Destroy environment resources
terraform destroy -target=module.environment

# Verify
cd ../../..
./scripts/verify-terraform-environment.sh
# Should fail (environment deleted)
```

## Troubleshooting

### Problem: `terraform destroy` Fails with State Corruption

**Symptoms:**

```
Error: Failed to load state
Error: state file is corrupt or invalid
```

**Solution:**

```bash
# Use emergency cleanup
./scripts/cleanup-terraform-emergency.sh
```

**Prevention:** Regular state backups, blob versioning enabled

### Problem: Resource Locks Prevent Deletion

**Symptoms:**

```
Error: Cannot delete resource: CanNotDelete lock exists
```

**Solution:**

Emergency cleanup script automatically removes locks:

```bash
./scripts/cleanup-terraform-emergency.sh
```

**Manual Alternative:**

```bash
# List locks
az lock list --resource-group rg-ecare-dev

# Delete lock
az lock delete --name <lock-name> --resource-group rg-ecare-dev
```

### Problem: Lost `service-principals.env` File

**Symptoms:** Verification scripts fail to find Service Principal IDs

**Solution:**

```bash
# Recover IDs from Azure
./scripts/recover-sp-ids.sh

# Verify recovery
cat scripts/service-principals.env
```

### Problem: VPN Gateway Deployment Takes Too Long

**Symptoms:** `terraform apply` runs for 45+ minutes on VPN Gateway

**Solution:**

This is **normal**. VPN Gateway deployment takes 30-60 minutes.

**Workaround:**

- Deploy without VPN initially (`enable_vpn_gateway = false`)
- Add VPN in separate apply after network is verified

### Problem: `terraform init` Fails with Backend Error

**Symptoms:**

```
Error: Failed to get existing workspaces
Error: storage account does not exist
```

**Solution:**

Phase 0 not set up. Run:

```bash
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh
```

### Problem: GitHub Actions Cannot Authenticate

**Symptoms:** Workflow fails with `OIDC token validation failed`

**Checklist:**

1. **Verify Service Principal:**

```bash
./scripts/verify-terraform-bootstrap.sh
```

2. **Verify FIC Subject:**

Expected format: `repo:<org>/<repo>:environment:<env>`

```bash
az ad app federated-credential show \
  --id <sp-app-id> \
  --federated-credential-id <fic-id>
```

3. **Verify GitHub Secrets:**

Required secrets in GitHub repository:
- `AZURE_CLIENT_ID_<ENV>` = Service Principal App ID
- `AZURE_TENANT_ID` = Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` = Azure Subscription ID

4. **Verify Workflow Configuration:**

```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read
```

### Problem: Terraform State Drift

**Symptoms:** `terraform plan` shows unexpected changes

**Solution:**

1. **Review Drift:**

```bash
terraform plan
```

2. **Refresh State:**

```bash
terraform apply -refresh-only
```

3. **Import Missing Resources:**

```bash
terraform import <resource_type>.<name> <azure_resource_id>
```

## Security Notes

### Phase 0 Cleanup is Destructive

**⚠️ DANGER:** `cleanup-phase0.sh` deletes Terraform state files

**Before Running:**

- Always run `terraform destroy` first
- Backup state files if needed:

```bash
az storage blob download \
  --account-name tfstatehycomecaredev \
  --container-name tfstate \
  --name foundation/terraform.tfstate \
  --file backup-$(date +%Y%m%d).tfstate \
  --auth-mode login
```

### Emergency Cleanup Bypasses Terraform

**⚠️ DANGER:** `cleanup-terraform-emergency.sh` bypasses Terraform state management

**Consequences:**

- Terraform state becomes out of sync
- Cannot use Terraform to manage resources after emergency cleanup
- Orphaned state entries may remain

**Recovery:**

1. Clean state manually:

```bash
cd terraform/environments/dev
terraform state rm <orphaned_resource>
```

2. Or reinitialize:

```bash
rm -rf .terraform terraform.tfstate*
terraform init
```

### Service Principal Permissions

Service Principals have **privileged access**:

- Contributor (can create/delete most resources)
- User Access Administrator (can assign roles)
- Storage Blob Data Contributor (can modify state)

**Best Practices:**

- Rotate Service Principal credentials regularly
- Audit RBAC assignments periodically
- Use separate Service Principals per environment
- Monitor Service Principal activity in Azure AD logs

### State File Security

Terraform state files contain **sensitive data**:

- Resource IDs
- Connection strings (if stored)
- Service Principal IDs

**Protection Measures:**

- Stored in private Storage Account (no public access)
- Authentication required (Azure AD, no shared keys)
- Versioning enabled (30-day retention)
- Soft delete enabled (30-day recovery)

**Access Control:**

Only these identities have access:

- Users in `users_with_state_access` (from terraform.tfvars)
- Service Principals (from bootstrap module)

### Shared State File

**Important:** Bootstrap and Environment modules **share the same state file**:

```
Storage Account: tfstate<org><project><env>
Container: tfstate
Blob: foundation/terraform.tfstate
```

**Implications:**

- Both modules must use same backend configuration
- `terraform init` only once per environment
- Cannot independently manage state
- State contains both bootstrap and environment resources

**Why Shared State:**

- Simplifies backend configuration
- Enables cross-module dependencies
- Single source of truth per environment

## Additional Resources

- **[Main README](../README.md)** - Architecture overview and getting started
- **[Bootstrap Module](./terraform/modules/bootstrap/README.md)** - Service Principals, FIC, RBAC for Terraform
- **[Environment Module](./terraform/modules/environment/README.md)** - Shared environment infrastructure
- **[Network Module](./terraform/modules/network/README.md)** - VNet, Subnets, NSGs
- **[VPN Gateway Module](./terraform/modules/vpn-gateway/README.md)** - Site-to-site and point-to-site VPN
- **Terraform Documentation:** [terraform.io](https://www.terraform.io/)
- **Azure CLI Reference:** [docs.microsoft.com/cli/azure](https://docs.microsoft.com/en-us/cli/azure/)
