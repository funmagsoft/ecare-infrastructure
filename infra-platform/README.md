# Infrastructure Platform

Platform infrastructure (AKS, PostgreSQL, Storage, Key Vault, Service Bus, ACR, Bastion) for the ecare project.

## Purpose

This repository contains Terraform code for:

- AKS (with Workload Identity and OIDC)
- PostgreSQL (Flexible Server) with Private Endpoint
- Storage Accounts with Private Endpoint
- Key Vault with Private Endpoint
- Service Bus (Standard/Premium) with Private Endpoint (when supported)
- ACR with Private Endpoint
- Bastion VM
- Shared AKS namespace `ecare`
- Monitoring (Log Analytics + Application Insights)

## Structure

```console
terraform/
├── modules/
│   ├── environment/      # Shared environment module (eliminates code duplication)
│   ├── aks/              # AKS cluster module
│   ├── aks-namespace/    # Kubernetes namespace module
│   ├── bastion/          # Bastion VM module
│   ├── acr/              # Container Registry module
│   ├── key-vault/        # Key Vault module
│   ├── monitoring/       # Monitoring module
│   ├── postgresql/       # PostgreSQL module
│   ├── service-bus/      # Service Bus module
│   └── storage/          # Storage Account module
├── templates/            # Template files for backend.tf and providers.tf
└── environments/
    ├── dev/
    ├── test/
    ├── stage/
    └── prod/
```

Each environment directory contains:

- `backend.tf` - Backend configuration (state storage)
- `providers.tf` - Provider configuration (AzureRM, Kubernetes)
- `kubernetes-provider.tf` - Kubernetes provider configuration
- `main.tf` - Calls the `platform` module
- `variables.tf` - Environment-specific variables
- `outputs.tf` - Re-exports outputs from the `platform` module
- `terraform.tfvars` - Environment-specific values (not committed to git)

## Getting Started

1. Review infra documentation [README.md](https://github.com/funmagsoft/infra-documentation/blob/main/README.md)

## Architecture

This repository uses a modular architecture to eliminate code duplication:

- **Environment Module** (`modules/environment/`): Shared module that encapsulates all common platform infrastructure configuration for an environment. This module eliminates ~95% of code duplication across environments by providing a single source of truth. The module is organized into topic-specific files:
  - `data.tf` - Data sources (resource group, remote state, client config)
  - `locals.tf` - Local variables, tags, and validation checks
  - `monitoring.tf` - Monitoring module (Log Analytics + Application Insights)
  - `compute.tf` - AKS, AKS Namespace, and Bastion modules
  - `storage.tf` - Storage Account and PostgreSQL modules
  - `security.tf` - Key Vault module and RBAC role assignments
  - `container-registry.tf` - ACR module
  - `messaging.tf` - Service Bus module
- **Individual Modules**: Each service has its own module (AKS, PostgreSQL, Storage, Key Vault, Service Bus, ACR, Bastion, Monitoring, AKS Namespace) that can be reused independently.

Each environment directory (`environments/{dev,test,stage,prod}/`) contains:

- `backend.tf` - Backend configuration pointing to environment-specific state storage
- `providers.tf` - Provider configuration (required in root module)
- `kubernetes-provider.tf` - Kubernetes provider configuration (required for AKS namespace creation)
- `main.tf` - Calls the `platform` module with environment-specific variables
- `variables.tf` - Environment-specific input variables
- `outputs.tf` - Re-exports outputs from the `platform` module
- `terraform.tfvars` - Environment-specific values (not committed to git)

**Templates**: The `terraform/templates/` directory contains template files for `backend.tf` and `providers.tf` to help set up new environments.

## Prerequisites

Make sure Phase 0 (infra-foundation) is deployed (RG, state storage, access). You need:

- Azure CLI logged in (`az login`)
- Correct subscription selected (`az account set --subscription <id>`)
- Terraform >= 1.5.0 installed
- Phase 1 (infra-foundation) must be deployed first:
  - Virtual Network must exist
  - AKS subnet must exist
  - Data subnet must exist (for Private Endpoints)
  - Management subnet must exist (for Bastion VM)
  - Network Security Groups must be configured

## Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality and consistency. The hooks automatically:

- **Validate Conventional Commits format** - Ensures all commit messages follow the Conventional Commits standard
- Format Terraform files (`terraform fmt`)
- Validate Terraform syntax (`terraform validate`)
- Check for security issues (`checkov`)
- Lint Terraform code (`tflint`)
- Ensure files end with exactly one newline
- Remove trailing whitespace
- Validate YAML/JSON syntax

### Installation

1. Install pre-commit:

```bash
# Using pip (recommended)
pip install pre-commit

# Or using Homebrew (macOS)
brew install pre-commit
```

1. Install the hooks in this repository:

```bash
cd /path/to/infra-platform
pre-commit install
pre-commit install --hook-type commit-msg
```

1. Install hook dependencies (downloads tools automatically):

```bash
pre-commit install-hooks
```

### Usage

Hooks run automatically on `git commit`. To run manually:

```bash
# Run on all files
pre-commit run --all-files

# Run only on staged files
pre-commit run

# Run a specific hook
pre-commit run terraform_fmt --all-files
```

### Updating Hooks

To update hooks to the latest versions:

```bash
pre-commit autoupdate
```

### Conventional Commits Format

All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```text
<type>[optional scope]: <description>
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`

**Examples:**

- `feat: add new feature`
- `fix(github-oidc): fix tags handling`
- `docs: update README`
- `refactor(code-quality): implement improvements`

Invalid commit messages will be rejected by the pre-commit hook.

### Skipping Hooks (Not Recommended)

Only skip hooks in exceptional circumstances:

```bash
git commit --no-verify -m "message"
```

## Running Terraform

### 1. Navigate to the environment directory

```bash
cd terraform/environments/dev  # or test, stage, prod
```

### 2. Configure Terraform variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and configure (per environment):

- AKS settings (kubernetes version, node pool sizes/counts, network)
- PostgreSQL sizing and HA/backup
- Storage settings (replication, soft-delete, containers)
- Key Vault settings (SKU, purge protection)
- Service Bus SKU/capacity (Standard/Premium)
- Bastion settings (vm_size, SSH source IPs)
- Monitoring settings (retention days, application insights type)

**Important**: `terraform.tfvars` is in `.gitignore` and should not be committed. Use `terraform.tfvars.example` as a template.

### 3. Initialize Terraform

```bash
terraform init
```

This will:

- Download required providers
- Configure the backend to use the Storage Account from Phase 0
- Use Azure AD auth (`use_azuread_auth = true`) if you are logged in with `az login`

### 4. Review the execution plan

```bash
terraform plan
```

### 5. Apply the configuration

```bash
terraform apply
```

### 6. Verify deployment

- Check Azure Portal for created resources
- Review Terraform outputs: `terraform output`

## Important Notes

- **State Management**: Terraform state is stored remotely in the Storage Account configured in `backend.tf`. Never commit `.tfstate` files to git.
- **Environment Isolation**: Each environment (dev, test, stage, prod) has separate state files and Resource Groups.
- **Authentication**: Terraform uses Azure AD authentication (backend `use_azuread_auth = true`). Ensure `az login` or GitHub OIDC is configured.
- **Backend Configuration**: `backend.tf` points to the Storage Accounts created by Phase 0. If names change, update `backend.tf`.
- **Provider Configuration**: Provider configuration is in `providers.tf` (root module). Modules inherit provider configuration from the root module.
- **Resource Group**: Resource Group name is automatically constructed as `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`). The Resource Group must exist (created in Phase 0).

## Networking and Private Access

- AKS, PostgreSQL, Storage, Key Vault, Service Bus, and ACR use Private Endpoints (where supported).
- DNS for Private Endpoints is managed inside each resource module (per-service Private DNS Zones in platform modules).
- Bastion is placed in the mgmt subnet; NSG allows SSH only from configured source IPs.

## AKS Namespace

- Shared namespace `ecare` created in every environment (module `aks-namespace`).
- Intended for workload identity-enabled workloads and application services.
- Kubernetes provider must be configured in the root module (`kubernetes-provider.tf`) for namespace creation.

## Modules Overview

- **platform**: Shared module that encapsulates all platform infrastructure (eliminates ~95% code duplication)
- **aks**: AKS with OIDC, Workload Identity, monitoring, RBAC to ACR
- **postgresql**: Flexible Server + Private Endpoint + Private DNS
- **storage**: Storage Account + Private Endpoint + Private DNS
- **key-vault**: Key Vault + Private Endpoint + Private DNS + RBAC authorization
- **service-bus**: Standard/Premium; Private Endpoint for Premium; public network access auto-adjusted by SKU
- **acr**: Container Registry + Private Endpoint + Private DNS
- **bastion**: Bastion VM (SSH key, tooling), NSG with allowed source IP list
- **monitoring**: Log Analytics Workspace + Application Insights
- **aks-namespace**: Creates the shared `ecare` namespace

## Tag Validation

The `platform` module enforces tag validation to ensure all required tags are present:

- **Required Tags** (automatically set, cannot be overridden):
  - `Environment`, `Project`, `ManagedBy`, `Phase`, `GitRepository`, `TerraformPath`
- **Additional Tags**: Use `additional_tags` variable to add custom tags
- **Validation**: `check` blocks validate all required tags are present and non-empty

## Cleanup

Use `terraform destroy` in a given environment if you need to remove platform resources. Be careful with shared components (e.g., ACR, Service Bus) and dependencies with workload identity.
