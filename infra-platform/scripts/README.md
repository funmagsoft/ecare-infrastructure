# Infrastructure Platform Scripts

Comprehensive set of helper scripts for managing Azure platform infrastructure deployment and
operations.

---

## Quick Start

### Initial Setup

```bash
# 1. Validate prerequisites (Phase 1 foundation)
./scripts/validate-prerequisites.sh

# 2. Initialize environment
./scripts/init-environment.sh dev

# 3. Deploy environment
./scripts/deploy-environment.sh dev
```

### Validation

```bash
# Validate all deployed environments
./scripts/validate-all.sh

# Validate Azure resources
./scripts/validate-azure-resources.sh
```

---

## Available Scripts

### Deployment Scripts

#### `init-environment.sh`

Initialize Terraform for a specific environment.

**Usage:**

```bash
./scripts/init-environment.sh <environment>
```

**Example:**

```bash
./scripts/init-environment.sh dev
```

**What it does:**

- Validates Azure CLI authentication
- Checks backend Storage Account existence
- Verifies Phase 1 foundation state
- Initializes Terraform with backend configuration
- Validates Terraform configuration
- Checks formatting

---

#### `deploy-environment.sh`

Deploy Terraform configuration for a specific environment.

**Usage:**

```bash
./scripts/deploy-environment.sh <environment> [options]
```

**Options:**

- `--auto-approve` - Skip interactive approval (use with caution)
- `--plan-only` - Only create plan, don't apply

**Examples:**

```bash
# Interactive deployment
./scripts/deploy-environment.sh dev

# Create plan only
./scripts/deploy-environment.sh dev --plan-only

# Auto-approve (use carefully!)
./scripts/deploy-environment.sh dev --auto-approve
```

**What it does:**

- Initializes Terraform if needed
- Validates configuration
- Creates execution plan
- Shows resource changes summary
- Applies changes (with confirmation)
- Exports outputs
- Validates deployment
- Provides detailed progress and timing

**Safety features:**

- Extra confirmation required for production
- Shows detailed plan before applying
- Estimates resource changes
- Preserves plan file if deployment fails

---

#### `plan-all.sh`

Create Terraform plans for multiple environments.

**Usage:**

```bash
./scripts/plan-all.sh [environments]
```

**Examples:**

```bash
# Plan all environments
./scripts/plan-all.sh

# Plan specific environments
./scripts/plan-all.sh dev test
```

**What it does:**

- Creates execution plans for specified environments
- Shows resource change summary for each
- Saves plan files for later use
- Provides summary of successful/failed plans

---

#### `destroy-environment.sh`

Destroy all Terraform-managed resources in an environment.

**Usage:**

```bash
./scripts/destroy-environment.sh <environment> [--force]
```

**Options:**

- `--force` - Skip confirmation prompts (DANGEROUS!)

**Examples:**

```bash
# Interactive destruction
./scripts/destroy-environment.sh dev

# Force destruction (use with extreme caution!)
./scripts/destroy-environment.sh dev --force
```

**What it does:**

- Creates destruction plan
- Shows resources to be destroyed
- Requires multiple confirmations (especially for production)
- Destroys all platform resources
- Reports destruction time
- Lists resources NOT destroyed (managed outside Terraform)

**Safety features:**

- Multiple confirmation prompts
- Special protection for production
- Shows destruction plan before executing
- Requires typing "destroy-production" for PROD

⚠️ **WARNING:** This is irreversible! All data will be lost.

---

### Validation Scripts

#### `validate-prerequisites.sh`

Validate Phase 1 foundation is deployed and accessible.

**Usage:**

```bash
./scripts/validate-prerequisites.sh
```

**What it checks:**

- infra-foundation repository exists
- DEV VNet is deployed
- Phase 1 Terraform state is accessible

---

#### `validate-azure-resources.sh`

Validate Phase 1 foundation resources in Azure.

**Usage:**

```bash
./scripts/validate-azure-resources.sh
```

**What it checks:**

- VNet exists
- Required subnets configured (minimum 3)
- Private DNS Zones configured (expected 6)
- Phase 1 Terraform state exists

---

#### `validate-all.sh`

Comprehensive validation of all Phase 2 platform resources.

**Usage:**

```bash
./scripts/validate-all.sh
```

**What it checks per environment:**

- Monitoring: Log Analytics, Application Insights
- Storage: Storage Account, containers, private endpoints
- Key Vault and private endpoint
- ACR and private endpoint
- PostgreSQL and private endpoint
- Service Bus and private endpoint
- AKS cluster, nodes, OIDC issuer
- Bastion VM and power state
- Private Endpoints count
- Terraform state

**Output:**

- Color-coded results (✓ passed, ✗ failed, ⚠ warnings)
- Detailed validation summary
- Total/passed/failed counts
- Exit code 0 if all pass, 1 if any fail

---

### Utility Scripts

#### `export-outputs.sh`

Export Terraform outputs to JSON files.

**Usage:**

```bash
./scripts/export-outputs.sh [environments]
```

**Examples:**

```bash
# Export all environments
./scripts/export-outputs.sh

# Export specific environments
./scripts/export-outputs.sh dev test
```

**What it does:**

- Exports Terraform outputs to JSON files
- Creates individual files per environment
- Creates combined all-environments file
- Shows key outputs summary (AKS, PostgreSQL, Key Vault, ACR, etc.)

**Output location:**

- `outputs/terraform-outputs-<env>.json`
- `outputs/all-environments-outputs.json`

**Usage examples:**

```bash
# View all outputs for dev
cat outputs/terraform-outputs-dev.json | jq

# Extract specific output
jq -r '.aks_oidc_issuer_url.value' outputs/terraform-outputs-dev.json

# Get PostgreSQL FQDN
jq -r '.postgresql_fqdn.value' outputs/terraform-outputs-prod.json
```

---

#### `get-aks-credentials.sh`

Get AKS credentials for kubectl access.

**Usage:**

```bash
./scripts/get-aks-credentials.sh <environment> [--admin]
```

**Options:**

- `--admin` - Get admin credentials (cluster-admin role)

**Examples:**

```bash
# Get user credentials
./scripts/get-aks-credentials.sh dev

# Get admin credentials
./scripts/get-aks-credentials.sh prod --admin
```

**What it does:**

- Checks cluster existence and state
- Retrieves and configures kubeconfig
- Tests cluster connectivity
- Shows cluster information (nodes, namespaces, system pods)
- Provides health check summary

**Post-execution:**

- kubectl is configured and ready to use
- Cluster context is set
- Provides useful kubectl commands

---

#### `setup-bastion.sh`

Setup and configure Bastion VM with required tools.

**Usage:**

```bash
./scripts/setup-bastion.sh <environment>
```

**Example:**

```bash
./scripts/setup-bastion.sh dev
```

**What it does:**

- Checks VM existence and starts it if needed
- Installs required tools:
  - Azure CLI
  - kubectl
  - PostgreSQL client (psql)
  - Helm
  - jq, git, curl, wget
- Configures shell environment with useful aliases
- Sets up kubectl autocompletion
- Configures AKS access

**Installed aliases:**

- `k` - kubectl
- `kgp` - kubectl get pods
- `kgs` - kubectl get services
- `kgn` - kubectl get nodes
- `kd` - kubectl describe
- `kl` - kubectl logs

**Installed functions:**

- `kexec <pod>` - Execute shell in pod
- `kport <pod> <port>` - Port forward

---

## Script Organization

### By Lifecycle Phase

**Setup:**

1. `validate-prerequisites.sh`
2. `init-environment.sh`
3. `deploy-environment.sh`

**Operations:**

1. `validate-all.sh`
2. `export-outputs.sh`
3. `get-aks-credentials.sh`
4. `setup-bastion.sh`

**Planning:**

1. `plan-all.sh`

**Cleanup:**

1. `destroy-environment.sh`

---

## Common Workflows

### Deploy New Environment

```bash
# 1. Validate prerequisites
./scripts/validate-prerequisites.sh

# 2. Initialize
./scripts/init-environment.sh dev

# 3. Create plan
./scripts/deploy-environment.sh dev --plan-only

# 4. Review plan, then deploy
./scripts/deploy-environment.sh dev

# 5. Validate deployment
./scripts/validate-all.sh

# 6. Setup Bastion
./scripts/setup-bastion.sh dev

# 7. Get AKS credentials
./scripts/get-aks-credentials.sh dev
```

---

### Update Existing Environment

```bash
# 1. Navigate to environment
cd terraform/environments/dev

# 2. Make configuration changes
# ... edit terraform files ...

# 3. Plan changes
../../scripts/deploy-environment.sh dev --plan-only

# 4. Review plan, then apply
../../scripts/deploy-environment.sh dev
```

---

### Validate All Environments

```bash
# Run comprehensive validation
./scripts/validate-all.sh

# Export outputs for review
./scripts/export-outputs.sh

# View specific outputs
cat outputs/terraform-outputs-dev.json | jq '.aks_oidc_issuer_url'
```

---

### Troubleshooting Deployment

```bash
# 1. Validate prerequisites
./scripts/validate-prerequisites.sh

# 2. Check Azure resources
./scripts/validate-azure-resources.sh

# 3. Initialize clean state
cd terraform/environments/dev
rm -rf .terraform
cd ../../..
./scripts/init-environment.sh dev

# 4. Try deployment again
./scripts/deploy-environment.sh dev
```

---

## Environment Variables

Scripts automatically detect environment from argument, but you can set these for customization:

```bash
# Azure subscription (auto-detected from az account show)
export ARM_SUBSCRIPTION_ID="<subscription-id>"

# Terraform log level (for debugging)
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log
```

---

## Exit Codes

All scripts follow standard exit code conventions:

- `0` - Success
- `1` - General error
- `2` - Invalid arguments

---

## Safety Features

### Production Protection

- Multiple confirmation prompts for PROD
- Special confirmation string required for destructive operations
- Extra warnings for `--auto-approve` on PROD
- No `--force` flag support for PROD in critical operations

### Validation

- Prerequisite checks before operations
- Configuration validation before applying
- Post-deployment validation
- State file verification

### Error Handling

- `set -e` in all scripts (fail fast)
- Clear error messages with context
- Preservation of plan files on failure
- Rollback instructions when applicable

---

## Color Coding

Scripts use color-coded output for better readability:

- 🟢 **Green (✓)** - Success, passed checks
- 🔴 **Red (✗)** - Failure, errors
- 🟡 **Yellow (⚠)** - Warnings, important notices
- 🔵 **Blue (ℹ)** - Information, metadata

---

## Prerequisites

### Required Tools

- Bash 4.0+
- Azure CLI (`az`) - latest version
- Terraform 1.5+
- kubectl (installed by bastion script)
- jq (for JSON parsing)

### Required Permissions

- **Azure RBAC:**
  - Contributor on Resource Groups
  - Storage Blob Data Contributor on state Storage Accounts
  - AKS Cluster User on AKS clusters

- **Azure AD:**
  - Permissions to create Service Principals (Phase 0)
  - Permissions to assign roles (Phase 0)

### Required Phase Completion

- **Phase 0:** Foundation setup (RGs, Storage Accounts, Service Principals)
- **Phase 1:** Network infrastructure (VNets, Subnets, DNS Zones, NSGs)

---

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/*.sh
```

### Azure CLI Not Authenticated

```bash
az login
az account set --subscription <subscription-id>
```

### Terraform State Locked

```bash
# Force unlock (use with caution!)
cd terraform/environments/<env>
terraform force-unlock <lock-id>
```

### Backend Initialization Failed

```bash
# Check Storage Account access
az storage account show --name tfstatehycomecaredev --resource-group rg-ecare-dev

# Verify RBAC role
az role assignment list --scope /subscriptions/<sub-id>/resourceGroups/rg-ecare-dev
```

---

#### `list-by-repository.sh`

List resources grouped by GitRepository tag.

**Usage:**

```bash
./scripts/list-by-repository.sh <environment>
```

**Example:**

```bash
./scripts/list-by-repository.sh dev
```

**What it does:**

- Lists all resources in the environment
- Groups them by GitRepository tag (infra-foundation, infra-platform, etc.)
- Shows untagged resources
- Provides summary counts per repository

**Output:**

```
=== infra-foundation ===
  3 resources:
    - vnet-ecare-dev (Microsoft.Network/virtualNetworks)
    - snet-ecare-dev-aks (Microsoft.Network/virtualNetworks/subnets)
    - nsg-ecare-dev-aks (Microsoft.Network/networkSecurityGroups)

=== infra-platform ===
  12 resources:
    - aks-ecare-dev (Microsoft.ContainerService/managedClusters)
    - psql-ecare-dev (Microsoft.DBforPostgreSQL/flexibleServers)
    - st

ecaredev (Microsoft.Storage/storageAccounts)
    ...
```

---

#### `delete-by-repository.sh`

Selectively delete resources by GitRepository tag (useful for cleanup).

**Usage:**

```bash
./scripts/delete-by-repository.sh <environment> <repository>
```

**Options:**

- `environment` - dev, test, stage, prod
- `repository` - infra-foundation, infra-platform, infra-identity

**Examples:**

```bash
# Delete only infra-platform resources (keeps infra-foundation intact!)
./scripts/delete-by-repository.sh dev infra-platform

# Delete only workload identity resources
./scripts/delete-by-repository.sh prod infra-identity
```

**What it does:**

- Finds all resources with GitRepository=<repository> tag
- Shows what will be deleted
- Requires confirmation
- Deletes resources one by one
- Shows summary of deleted/failed resources
- Lists remaining resources

**Safety features:**

- Interactive confirmation required
- Shows exactly what will be deleted before deletion
- Won't delete resources from other repositories
- Can be used to cleanup failed deployments without affecting other phases

**Use case:**

When you want to redeploy infra-platform but keep infra-foundation network resources:

```bash
# List what you have
./scripts/list-by-repository.sh dev

# Delete only platform resources
./scripts/delete-by-repository.sh dev infra-platform

# Network resources from infra-foundation remain intact!
# Now redeploy platform:
./scripts/deploy-environment.sh dev
```

---

## Contributing

When adding new scripts:

1. Use bash shebang: `#!/bin/bash`
2. Enable fail-fast: `set -e`
3. Add color output for better UX
4. Include comprehensive error messages
5. Add usage instructions
6. Document in this README
7. Make executable: `chmod +x scripts/new-script.sh`

---

## Related Documentation

- [Phase 2 Platform Plan](../docs/02-PLATFORM-PLAN.md)
- [Infrastructure Design](../docs/INFRASTRUCTURE-DESIGN.md)
- [Terraform Modules](../terraform/modules/README.md)

---

## Support

For issues or questions:

1. Check troubleshooting section
2. Review script output carefully (often contains helpful hints)
3. Verify prerequisites are met
4. Check Azure Portal for resource state
5. Review Terraform logs (`TF_LOG=DEBUG`)
