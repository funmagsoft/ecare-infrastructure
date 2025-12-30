# Infrastructure Foundation

Networking, foundational infrastructure, and Terraform state authentication for the ecare project.

## Purpose

This repository is the **first phase** of the infrastructure setup and provides:

1. **Core Networking Infrastructure**: Virtual Networks, Subnets, Network Security Groups (NSG), and optional VPN Gateway

2. **Terraform State Authentication**: Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments that
enable GitHub Actions workflows to authenticate to Azure and manage infrastructure using Terraform

### Why This Repository Exists

This repository establishes the **foundational layer** that all other infrastructure depends on:

- **Network Foundation**: All Azure resources (AKS, Storage, Key Vault, PostgreSQL) require network connectivity. This repository
creates the Virtual Network, subnets, and network security rules.

- **Terraform State Management**: Before any infrastructure can be deployed via Terraform in GitHub Actions, authentication must be
configured. This repository's `bootstrap` module creates Service Principals and Federated Identity Credentials for Terraform
repositories to authenticate to Azure and manage state files.

## What This Repository Creates

### Infrastructure Resources

- **Virtual Networks** - Base network infrastructure for all environments
- **Subnets** - Segmented network spaces (AKS, Data, Management, Gateway)
- **Network Security Groups (NSG)** - Network traffic filtering and security rules
- **SSH Access Rules** - Configurable SSH access to management subnet
- **VPN Gateway** - Optional site-to-site and point-to-site VPN connectivity

### Authentication & Access (Bootstrap Module)

The `bootstrap` module creates:

- **Service Principals** (`sp-gha-{project}-infra-{env}`) - Azure AD identities for GitHub Actions OIDC authentication
- **Federated Identity Credentials (FIC)** - OIDC credentials for Terraform repositories (one per repository per environment)
- **RBAC Role Assignments**:
  - Contributor on Resource Group
  - User Access Administrator on Resource Group
  - Storage Blob Data Contributor on Storage Account (for Service Principals and users)

## Structure

```console
terraform/
├── modules/
│   ├── bootstrap/      # Bootstrap module (SP, FIC, RBAC for Terraform repos)
│   ├── environment/    # Shared environment module
│   ├── network/        # Network module (VNet, Subnets, NSGs)
│   └── vpn-gateway/    # VPN Gateway module
├── templates/          # Template files for versions.tf and providers.tf
├── environments/
│   ├── dev/
│   ├── test/
│   ├── stage/
│   └── prod/
└── scripts/
    ├── setup-phase0.sh                 # Creates Phase 0 infrastructure (RG, Storage, User Access)
    ├── verify-phase0.sh                # Verifies Phase 0 only
    ├── verify-all.sh                   # Verifies ALL infrastructure (Phase 0 + Terraform)
    ├── cleanup-phase0.sh               # Deletes Phase 0 only
    └── cleanup-terraform-emergency.sh  # Emergency cleanup when terraform destroy fails
```

Each environment directory contains:

- `versions.tf` - Terraform version, backend configuration, and required providers
- `providers.tf` - Provider configuration (AzureRM, AzureAD)
- `bootstrap.tf` - Bootstrap module call (SP, FIC, RBAC)
- `main.tf` - Calls the `environment` module
- `variables.tf` - Environment-specific variables
- `outputs.tf` - Re-exports outputs from modules
- `terraform.tfvars` - Environment-specific values (not committed to git)

## Getting Started

### Quick Start Guide

#### 1. Setup Phase 0 (Prerequisites for Terraform)

```bash
# Configure environment
cp .env.example .env
# Edit .env with your TENANT_ID, SUBSCRIPTION_ID, LOCATION

# Create Phase 0 infrastructure
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh
```

#### 2. Deploy with Terraform

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

terraform init
terraform plan
terraform apply
```

#### 3. Verify Complete Deployment

```bash
cd ../../..
./scripts/verify-all.sh
```

**For detailed operational procedures, see [RUNBOOK.md](./docs/RUNBOOK.md)**

## Phase 0 Setup (Prerequisites)

Before running Terraform, you must set up foundational infrastructure using the setup scripts. These scripts create Azure resources
that Terraform requires.

### Quick Setup

```bash
# Run all Phase 0 setup steps
./scripts/setup-phase0.sh
```

This creates:

- Resource Groups for all environments (dev, test, stage, prod)
- Storage Accounts for Terraform state (with versioning and soft delete)
- Current user access to state storage (Storage Blob Data Contributor)

### Phase 0 Components

**Resource Groups** (`rg-{project}-{env}`):

- Containers for all infrastructure resources
- One per environment (dev, test, stage, prod)
- Required before creating any resources

**Storage Accounts** (`tfstate{org}{project}{env}`):

- Store Terraform state files (`.tfstate`)
- Track current state of infrastructure
- Enable Terraform to manage resources correctly
- Blob versioning and soft delete enabled (30-day retention)

**User Access**:

- Storage Blob Data Contributor role for current user
- Allows viewing state files in Azure Portal

### Configuration

Configure environment variables in `.env`:

```bash
TENANT_ID="your-tenant-id"
SUBSCRIPTION_ID="your-subscription-id"
LOCATION="polandcentral"
```

Project constants are defined in `scripts/globals.sh`:

```bash
ORGANIZATION="hycom"
ORGANIZATION_FOR_SA="hycom"
PROJECT="ecare"
```

### Verification

```bash
# Verify Phase 0 only
./scripts/verify-phase0.sh

# Verify complete infrastructure (Phase 0 + Terraform)
./scripts/verify-all.sh
```

### Cleanup

```bash
# Destroy Terraform resources first
cd terraform/environments/dev
terraform destroy

# Then cleanup Phase 0
cd ../../..
./scripts/cleanup-phase0.sh
```

**⚠️ WARNING**: `cleanup-phase0.sh` deletes Terraform state files permanently. Always run `terraform destroy` first.

## Bootstrap Module

The `bootstrap` module creates authentication for Terraform state management. This module provides Infrastructure as Code (IaC) management. Resources created by this module are consumed by GitHub Actions to manage infrastructure repositories.

### What It Creates

- **Service Principals** (one per environment): `sp-gha-{project}-infra-{env}`
- **Federated Identity Credentials**: 12 total (3 repos × 4 environments)
- **RBAC Role Assignments**: Contributor, User Access Administrator, Storage Blob Data Contributor

### Configuration

Configure in `terraform.tfvars`:

```hcl
# Bootstrap Configuration
organization_name   = "hycom"
organization_for_sa = "hycom"
enable_bootstrap    = true

# Users with access to Terraform state Storage Account
users_with_state_access = [
  "f714a502-3026-4ef8-b753-00c5b4c00f4a",  # User Object ID
]
```

`organization_for_sa` - Organization name for Storage Account. It may differ from the `organization` due to Azure Storage account naming constraints.

To get a user's Object ID:

```bash
az ad user show --id user@example.com --query id --output tsv
```

### Bootstrap vs. Service Identity

- **Bootstrap (this repo)**: SP for Terraform repos → Infrastructure management
- **Identity (infra-identity)**: UAMI for service repos → Application deployment

See `terraform/modules/bootstrap/README.md` for detailed documentation.

## Running Terraform

### 1. Navigate to Environment

```bash
cd terraform/environments/dev  # or test, stage, prod
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `environment` - Environment name (dev, test, stage, prod)
- `project_name` - Project name (default: "ecare")
- Network CIDR blocks for VNet and subnets
- `mgmt_subnet_allowed_ssh_ips` - SSH access allowlist
- VPN Gateway settings (if needed)

### 3. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
cd ../../..
./scripts/verify-all.sh
terraform output
```

## Network Security Configuration

### Management Subnet SSH Access

To allow SSH access from specific IP addresses:

```hcl
# terraform.tfvars
mgmt_subnet_allowed_ssh_ips = ["91.150.222.105", "203.0.113.0/24"]
```

This creates an NSG rule `AllowSSHInbound` (priority 200) for SSH (port 22).

**Security Note**: Always restrict SSH access to trusted IPs. For production, consider VPN Gateway or Azure Bastion.

SSH access is simpler and cheaper than access via a VPN Gateway. If the VPN Gateway is enabled (`enable_vpn_gateway = true`), there is no need to open SSH access—just leave the `mgmt_subnet_allowed_ssh_ips` list empty.

## Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality:

- Validate Conventional Commits format
- Format Terraform files (`terraform fmt`)
- Validate Terraform syntax (`terraform validate`)
- Lint Terraform code (`tflint`)
- Ensure files end with newline
- Remove trailing whitespace
- Validate YAML/JSON syntax

### Installation

```bash
# Install pre-commit
pip install pre-commit
# Or: brew install pre-commit

# Install hooks
cd infra-foundation
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install-hooks
```

### Usage

```bash
# Hooks run automatically on git commit

# Run manually
pre-commit run --all-files

# Update hooks
pre-commit autoupdate
```

### Conventional Commits Format

All commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(optional scope): <description>

- Feature 1
- Feature 2
```

**Valid types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`

**Examples**:

- `feat: add new feature`
- `fix(github-oidc): fix tags handling`
- `docs: update README`

## Scripts Reference

### Phase 0 Scripts

| Script | Purpose |
|--------|---------|
| `setup-phase0.sh` | Create Phase 0 infrastructure (RG, Storage, User Access) |
| `verify-phase0.sh` | Verify Phase 0 only |
| `cleanup-phase0.sh` | Delete Phase 0 only (requires Terraform destroy first) |

### Verification Scripts

| Script | Purpose |
|--------|---------|
| `verify-all.sh` | Verify ALL infrastructure (Phase 0 + Terraform) |
| `verify-terraform-bootstrap.sh` | Verify Bootstrap module only |
| `verify-terraform-environment.sh` | Verify Environment module only |

### Emergency Scripts

| Script | Purpose |
|--------|---------|
| `cleanup-terraform-emergency.sh` | Emergency cleanup when `terraform destroy` fails |

All scripts support `--dry-run` option to preview changes.

## Troubleshooting

### Common Issues

#### Problem: `terraform destroy` fails

```bash
# Use emergency cleanup
./scripts/cleanup-terraform-emergency.sh
```

#### Problem: Lost Service Principal IDs

```bash
# Recover from Azure
./scripts/recover-sp-ids.sh
```

#### Problem: Backend initialization fails

```bash
# Phase 0 not set up
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh
```

**For detailed troubleshooting, see [RUNBOOK.md](./docs/RUNBOOK.md)**

## Important Notes

- **State Management**: Terraform state is stored remotely in Azure Storage. Never commit `.tfstate` files to git.
- **Environment Isolation**: Each environment has separate state files and Resource Groups for complete isolation.
- **Authentication**: Terraform uses Azure AD authentication (`use_azuread_auth = true`). Ensure you're logged in via `az login`.
- **Shared State**: Bootstrap and Environment modules share the same state file per environment.
- **Module Architecture**: All environments use the shared `environment` module to eliminate code duplication.

## Documentation

### Operational Documentation

- **[RUNBOOK.md](./docs/RUNBOOK.md)** - Complete operational procedures
  - Deployment procedures (5 scenarios)
  - Verification procedures
  - Destruction procedures (normal, emergency, partial)
  - Troubleshooting guide
  - Security notes

- **[SCRIPTS-REFERENCE.md](./docs/SCRIPTS-REFERENCE.md)** - Complete scripts reference
  - Detailed description of each script
  - Usage examples and options
  - Script dependencies
  - Quick reference guide

### Module Documentation

- **[Bootstrap Module](./terraform/modules/bootstrap/README.md)** - Service Principals, FIC, RBAC for Terraform
- **[Environment Module](./terraform/modules/environment/README.md)** - Shared environment infrastructure
- **[Network Module](./terraform/modules/network/README.md)** - VNet, Subnets, NSGs
- **[VPN Gateway Module](./terraform/modules/vpn-gateway/README.md)** - Site-to-site and point-to-site VPN

### External Resources

- **[Infra Documentation](https://github.com/funmagsoft/infra-documentation)** - Project-wide infrastructure documentation
