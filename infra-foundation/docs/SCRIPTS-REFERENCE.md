# Scripts Reference

Complete reference for all operational scripts in the `infra-foundation` repository.

## Overview

Scripts are organized into four categories:

- **Phase 0 Scripts**: Create and manage prerequisites for Terraform (RG, Storage, User Access)
- **Verification Scripts**: Verify infrastructure health at different layers
- **Emergency Scripts**: Handle failure scenarios when Terraform operations fail
- **Cleanup Scripts**: Remove resources by deployment identifier
- **Utility Scripts**: Helper scripts for special scenarios

## Phase 0 Scripts

Scripts for creating foundational infrastructure (prerequisites for Terraform).

### setup-phase0.sh

**Purpose:** Main setup script that creates all Phase 0 infrastructure

**What it does:**

- Calls `setup-rg.sh` to create Resource Groups
- Calls `setup-state-storage.sh` to create Storage Accounts
- Calls `setup-access-user.sh` to grant current user access

**Usage:**

```bash
./scripts/setup-phase0.sh [--dry-run]
```

**Options:**

- `--dry-run` - Preview changes without executing them

**Output:** Creates infrastructure for all 4 environments (dev, test, stage, prod)

**Prerequisites:** `.env` file configured with TENANT_ID, SUBSCRIPTION_ID, LOCATION

**Next step:** Run `./scripts/verify-phase0.sh`

---

### setup-rg.sh

**Purpose:** Create Resource Groups for all environments

**Resources created:**

- `rg-ecare-dev`
- `rg-ecare-test`
- `rg-ecare-stage`
- `rg-ecare-prod`

**Tags applied:**

- Environment
- Project
- ManagedBy (terraform)
- CreatedDate

**Called by:** `setup-phase0.sh`

**Usage:**

```bash
./scripts/setup-rg.sh [--dry-run]
```

---

### setup-state-storage.sh

**Purpose:** Create Storage Accounts for Terraform state

**Resources created:**

- Storage Accounts: `tfstatehycomecaredev`, `tfstatehycomecaretest`, etc.
- Container: `tfstate` (in each Storage Account)

**Features:**

- Blob versioning enabled (30-day retention)
- Soft delete enabled (30-day retention)
- HTTPS only, TLS 1.2 minimum
- Public access disabled
- Shared key access disabled (uses Azure AD)

**Called by:** `setup-phase0.sh`

**Usage:**

```bash
./scripts/setup-state-storage.sh [--dry-run]
```

---

### setup-access-user.sh

**Purpose:** Grant current user access to Terraform state Storage Accounts

**RBAC role assigned:**

- Storage Blob Data Contributor (on all 4 Storage Accounts)

**Called by:** `setup-phase0.sh`

**Usage:**

```bash
./scripts/setup-access-user.sh [--dry-run]
```

**Note:** Required for viewing/managing state files in Azure Portal

---

## Verification Scripts

Scripts for verifying infrastructure health and configuration.

### verify-all.sh

**Purpose:** Complete infrastructure health check (all layers)

**What it verifies:**

- Layer 1 (Phase 0): Resource Groups, Storage Accounts, User Access
- Layer 2 (Terraform Bootstrap): Service Principals, FIC, RBAC
- Layer 3 (Terraform Environment): VNet, Subnets, NSG, VPN

**Calls:**

- `verify-phase0.sh`
- `verify-terraform-bootstrap.sh`
- `verify-terraform-environment.sh`

**Usage:**

```bash
./scripts/verify-all.sh
```

**Exit codes:**

- 0 = All verifications passed
- 1 = One or more verifications failed

---

### verify-phase0.sh

**Purpose:** Verify Phase 0 infrastructure only

**What it verifies:**

- Resource Groups (4 environments)
- Storage Accounts (versioning, soft delete, containers)
- Current user RBAC (Storage Blob Data Contributor)

**Calls:**

- `verify-rg.sh`
- `verify-state-storage.sh`
- `verify-access-user.sh`

**Usage:**

```bash
./scripts/verify-phase0.sh
```

**When to use:** After `setup-phase0.sh`, before Terraform deployment

---

### verify-terraform-bootstrap.sh

**Purpose:** Verify Terraform bootstrap module resources

**What it verifies:**

- Service Principals (4 environments)
- Federated Identity Credentials (12 total: 3 repos × 4 envs)
- RBAC roles (Contributor, User Access Administrator, Storage Blob Data Contributor)

**Usage:**

```bash
./scripts/verify-terraform-bootstrap.sh
```

**When to use:** After Terraform bootstrap deployment

**Exit codes:**

- 0 = All bootstrap resources verified
- 1 = One or more resources missing or misconfigured

---

### verify-terraform-environment.sh

**Purpose:** Verify Terraform environment module resources

**What it verifies:**

- Virtual Networks (4 environments)
- Subnets (aks, data, mgmt, gateway)
- Network Security Groups (aks, data, mgmt)
- VPN Gateway (if enabled)
- Route Tables (if exist)

**Usage:**

```bash
./scripts/verify-terraform-environment.sh
```

**When to use:** After Terraform environment deployment

**Exit codes:**

- 0 = All environment resources verified
- 1 = One or more resources missing or misconfigured

---

### verify-rg.sh

**Purpose:** Verify Resource Groups

**Called by:** `verify-phase0.sh`

**Checks:**

- Resource Group exists
- Location matches expected
- Provisioning state is Succeeded
- Tags are correct

---

### verify-state-storage.sh

**Purpose:** Verify Storage Accounts and containers

**Called by:** `verify-phase0.sh`

**Checks:**

- Storage Account exists
- Container `tfstate` exists
- Blob versioning enabled
- Soft delete enabled

---

### verify-access-user.sh

**Purpose:** Verify current user access to Storage Accounts

**Called by:** `verify-phase0.sh`

**Checks:**

- Storage Blob Data Contributor role assigned on all 4 Storage Accounts

---

## Cleanup Scripts

Scripts for destroying infrastructure.

### cleanup-by-deployment-id.sh

**Purpose:** Delete all Azure and Entra ID resources tagged with a specific deployment ID

**Location:** `shared/scripts/cleanup-by-deployment-id.sh`

**What it deletes:**

- Azure Resource Groups (tagged with DeploymentId)
- Entra ID Applications (display name ending with `-{deployment_id}`)
- Service Principals (display name ending with `-{deployment_id}`)
- Managed Identities (tagged with DeploymentId)

**Usage:**

```bash
# Dry run (preview only) - default behavior
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4 --dry-run

# Actually delete resources
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4 --execute
```

**Arguments:**

- `deployment_id` - 8-character deployment identifier (e.g., `a1b2c3d4`)

**Options:**

- `--dry-run` - Preview changes without executing them (default)
- `--execute` - Actually delete resources

**Environment-specific deployment IDs:**

- dev: `a1b2c3d4`
- test: `e5f6g7h8`
- stage: `i9j0k1l2`
- prod: `m3n4o5p6`

**Prerequisites:**

- Azure CLI installed and authenticated
- Appropriate permissions to delete resources

**Safety features:**

- Dry run mode by default
- Confirmation prompt before deletion
- Clear output showing what will be deleted

**Example:**

```bash
# Preview what would be deleted for dev environment
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4

# Delete all dev environment resources
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4 --execute
```

---

### cleanup-phase0.sh

**Purpose:** Delete Phase 0 infrastructure only

**⚠️ WARNING:** This deletes Terraform state files permanently!

**What it deletes:**

- Current user RBAC assignments
- Storage Accounts (including all state files!)
- Resource Groups (dev, test, stage, prod)

**What it does NOT delete:**

- Terraform-managed resources (SP, VNet, NSG, VPN)

**Usage:**

```bash
./scripts/cleanup-phase0.sh [--dry-run]
```

**Confirmation required:** Type `DELETE-PHASE0` to confirm

**Prerequisites:** Run `terraform destroy` first to delete Terraform resources

**When to use:**

- Complete teardown after Terraform destroy
- Resetting Phase 0 infrastructure

---

### cleanup-terraform-emergency.sh

**Purpose:** Emergency cleanup when `terraform destroy` fails

**⚠️ DANGER:** Bypasses Terraform state management!

**What it deletes:**

- Resource locks
- VPN Gateway
- Network Security Groups
- Route Tables
- Virtual Network
- RBAC role assignments (for Service Principals)
- Federated Identity Credentials
- Service Principals
- service-principals.env file

**What it does NOT delete:**

- Phase 0 infrastructure (RG, Storage Accounts)

**Usage:**

```bash
./scripts/cleanup-terraform-emergency.sh [--dry-run]
```

**Confirmation required:** Type `DELETE-TERRAFORM-RESOURCES` to confirm

**When to use:**

- `terraform destroy` fails with state corruption
- Resource locks prevent deletion
- Circular dependency errors
- Partial destroy leaves orphaned resources

**Recovery:**

After emergency cleanup, Terraform state will be out of sync. Either:

1. Clean state manually: `terraform state rm <resource>`
2. Or reinitialize: `rm -rf .terraform terraform.tfstate*; terraform init`

---

## Utility Scripts

Helper scripts for special scenarios.

### recover-sp-ids.sh

**Purpose:** Recover Service Principal IDs from Azure AD

**What it does:**

- Queries Azure AD for Service Principals by name
- Writes APP_ID and OBJECT_ID to `service-principals.env`

**Usage:**

```bash
./scripts/recover-sp-ids.sh [--dry-run]
```

**When to use:**

- Lost or deleted `service-principals.env` file
- Need to verify Service Principal IDs

**Output file:** `scripts/service-principals.env`

---

### validate-commit-msg.sh

**Purpose:** Validate commit messages follow Conventional Commits format

**Used by:** Pre-commit hook (`.git/hooks/commit-msg`)

**Format required:**

```text
<type>[optional scope]: <description>
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`

**Examples:**

- ✅ `feat: add new feature`
- ✅ `fix(github-oidc): fix tags handling`
- ✅ `docs: update README`
- ❌ `Add new feature` (missing type)
- ❌ `feat add feature` (missing colon)

**Usage:**

```bash
# Automatically called by pre-commit hook
# Manual validation:
./scripts/validate-commit-msg.sh <commit-message-file>
```

---

## Helper Scripts

Scripts that are called by other scripts (not intended for direct use).

### common.sh

**Purpose:** Common functions and utilities used by all scripts

**Functions:**

- `load_dotenv()` - Load environment variables from `.env`
- `parse_dry_run()` - Parse `--dry-run` argument
- `run_cmd()` - Execute command with dry-run support
- `validate_env_vars()` - Validate required environment variables
- `log_error()`, `log_warning()`, `log_info()`, `log_success()` - Logging functions
- `init_script()` - Initialize script (load env, validate, set subscription)

**Usage:** `source "${SCRIPT_DIR}/common.sh"` at the beginning of each script

---

### globals.sh

**Purpose:** Project-specific constants

**Variables:**

```bash
ORGANIZATION="hycom"
ORGANIZATION_FOR_SA="hycom"
PROJECT="ecare"
```

**Usage:** Sourced by `common.sh` automatically

---

## Files (Not Scripts)

### service-principals.env

**Type:** Configuration file (generated)

**Format:**

```bash
DEV_SP_APP_ID=xxx
DEV_SP_OBJECT_ID=xxx
TEST_SP_APP_ID=xxx
# ... etc
```

**Generated by:**

- Terraform bootstrap module outputs
- `recover-sp-ids.sh` script

**Used by:**

- `verify-terraform-bootstrap.sh`
- `cleanup-terraform-emergency.sh`

**Location:** `scripts/service-principals.env`

**Note:** This file is in `.gitignore` and should not be committed

---

## Script Dependencies

### Dependency Graph

```
setup-phase0.sh
├── setup-rg.sh
├── setup-state-storage.sh
└── setup-access-user.sh

verify-all.sh
├── verify-phase0.sh
│   ├── verify-rg.sh
│   ├── verify-state-storage.sh
│   └── verify-access-user.sh
├── verify-terraform-bootstrap.sh
└── verify-terraform-environment.sh

cleanup-phase0.sh
  (standalone - deletes Phase 0 resources)

cleanup-terraform-emergency.sh
  (standalone - deletes Terraform resources)
```

### Common Dependencies

All scripts depend on:

- `common.sh` - Common functions and utilities
- `globals.sh` - Project constants (sourced by common.sh)
- `.env` file - Environment-specific configuration

---

## Quick Reference

### Complete Deployment

```bash
# 1. Phase 0
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh

# 2. Terraform
cd terraform/environments/dev
terraform init && terraform apply

# 3. Verify
cd ../../..
./scripts/verify-all.sh
```

### Complete Teardown

```bash
# 1. Terraform destroy
cd terraform/environments/dev
terraform destroy

# 2. Phase 0 cleanup
cd ../../..
./scripts/cleanup-phase0.sh
```

### Emergency Teardown

```bash
# When terraform destroy fails
./scripts/cleanup-terraform-emergency.sh
./scripts/cleanup-phase0.sh
```

### Verification Only

```bash
# All layers
./scripts/verify-all.sh

# Phase 0 only
./scripts/verify-phase0.sh

# Bootstrap only
./scripts/verify-terraform-bootstrap.sh

# Environment only
./scripts/verify-terraform-environment.sh
```

---

## Additional Resources

- **Operational Procedures**: [RUNBOOK.md](./RUNBOOK.md) - Detailed deployment and troubleshooting
- **Main README**: [../README.md](../README.md) - Architecture overview and getting started
- **Module Documentation**: `../terraform/modules/<name>/README.md` - Module-specific details
