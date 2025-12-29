# Infrastructure Foundation

Networking, foundational infrastructure, and Terraform state authentication for the ecare project.

## Purpose

This repository is the **first phase** of the infrastructure setup and serves as the foundation for all subsequent infrastructure deployments. It provides:

1. **Core Networking Infrastructure**: Virtual Networks, Subnets, Network Security Groups (NSG), and optional VPN Gateway that form the network foundation for all Azure resources in the project.

2. **Terraform State Authentication**: Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments that enable GitHub Actions workflows in Terraform repositories (`infra-foundation`, `infra-platform`, `infra-identity`) to authenticate to Azure and manage infrastructure using Terraform.

### Why This Repository Exists

This repository establishes the **foundational layer** that all other infrastructure depends on:

- **Network Foundation**: All Azure resources (AKS, Storage, Key Vault, PostgreSQL, etc.) require network connectivity. This repository creates the Virtual Network, subnets, and network security rules that enable secure communication between resources.

- **Terraform State Management**: Before any infrastructure can be deployed via Terraform in GitHub Actions, authentication must be configured. This repository's `bootstrap` module creates Service Principals and Federated Identity Credentials specifically for **Terraform state management** - allowing GitHub Actions workflows in Terraform repositories to:
  - Authenticate to Azure using OIDC (passwordless)
  - Read and write Terraform state files stored in Azure Storage Accounts
  - Create, modify, and delete Azure resources via Terraform

### Important Distinction: Bootstrap vs. Service Identity

**This repository's `bootstrap` module** creates Service Principals and FIC for **Terraform repositories** (`infra-foundation`, `infra-platform`, `infra-identity`) to manage infrastructure. These Service Principals are used by GitHub Actions workflows to:

- Run `terraform plan` and `terraform apply`
- Access Terraform state files in Storage Accounts
- Manage Azure resources (networks, AKS, databases, etc.)

**The `infra-identity` repository** (see [infra-identity](https://github.com/hycom/infra-identity)) creates **analogous objects** (User Assigned Managed Identities, FIC, RBAC) but for a **different purpose**: enabling GitHub Actions workflows in **service repositories** to deploy application services to AKS and push container images to ACR. These identities are used by:

- Application build and deployment pipelines
- Container image push operations to Azure Container Registry (ACR)
- Service deployments to Azure Kubernetes Service (AKS)

**Summary**:

- **`infra-foundation` bootstrap**: SP/FIC for Terraform repositories → Infrastructure management
- **`infra-identity`**: UAMI/FIC for service repositories → Application deployment to AKS/ACR

### Service Principal Naming Convention

The naming convention for Service Principals reflects their purpose:

- **Bootstrap Service Principals** (created by this repository): `sp-gha-{project_name}-infra-{environment}`
  - Example: `sp-gha-ecare-infra-dev`
  - The `-infra-` suffix distinguishes these SPs as infrastructure management identities
  - Used by Terraform repositories (`infra-foundation`, `infra-platform`, `infra-identity`)

- **Service Deployment Service Principals** (created by `infra-identity`): `sp-gha-{project_name}-{environment}`
  - Example: `sp-gha-ecare-dev`
  - No `-infra-` suffix, as these are for application service deployments
  - Used by service repositories (application code repositories)

**Why the difference?**

- The `-infra-` suffix in bootstrap SPs makes it clear these are for infrastructure management (Terraform operations)
- Service SPs without `-infra-` are for application build and deployment workflows
- This naming distinction helps identify the purpose of each Service Principal at a glance

## What This Repository Creates

### Infrastructure Resources

- **Virtual Networks** - Base network infrastructure for all environments
- **Subnets** - Segmented network spaces (AKS, Data, Management, Gateway)
- **Network Security Groups (NSG)** - Network traffic filtering and security rules
- **SSH Access Rules** - Configurable SSH access to management subnet
- **VPN Gateway** - Optional site-to-site and point-to-site VPN connectivity

### Authentication & Access (Bootstrap Module)

The `bootstrap` module creates Service Principals and authentication for **Terraform state management**:

- **Service Principals** - Azure AD identities for GitHub Actions OIDC authentication (`sp-gha-{project}-infra-{env}`)
- **Federated Identity Credentials (FIC)** - OIDC credentials for Terraform repositories (one per repository per environment)
- **RBAC Role Assignments**:

  - **Contributor** on Resource Group - Allows Terraform to manage infrastructure resources
  - **User Access Administrator** on Resource Group - Allows Terraform to assign roles to Managed Identities
  - **Storage Blob Data Contributor** on Storage Account - Allows Terraform to read/write state files
  - **Storage Blob Data Contributor** for users (optional) - Allows users to view state files in Azure Portal

## Structure

```console
terraform/
├── modules/
│   ├── bootstrap/      # Bootstrap module (SP, FIC, RBAC for Terraform repos)
│   ├── environment/    # Shared environment module (eliminates code duplication)
│   ├── network/        # Network module (VNet, Subnets, NSGs)
│   └── vpn-gateway/    # VPN Gateway module
├── templates/          # Template files for versions.tf and providers.tf
└── environments/
    ├── dev/
    ├── test/
    ├── stage/
    └── prod/
```

Each environment directory contains:

- `versions.tf` - Terraform version, backend configuration, and required providers
- `providers.tf` - Provider configuration (AzureRM, AzureAD)
- `bootstrap.tf` - Bootstrap module call (SP, FIC, RBAC for Terraform repos)
- `main.tf` - Calls the `environment` module
- `variables.tf` - Environment-specific variables
- `outputs.tf` - Re-exports outputs from the `environment` and `bootstrap` modules
- `terraform.tfvars` - Environment-specific values (not committed to git)

## Getting Started

1. Review infra documentation [README.md](https://github.com/funmagsoft/infra-documentation/blob/main/README.md)

## Bootstrap Module

The `bootstrap` module (located in `terraform/modules/bootstrap/`) is a critical component that creates authentication and access control for **Terraform state management**. This module replaces the deprecated bash scripts (`setup-access.sh`, `setup-access-sp.sh`, `setup-access-user.sh`) and provides Infrastructure as Code (IaC) management of these foundational resources.

### What the Bootstrap Module Creates

**Service Principals** (one per environment):

- Azure AD identities for GitHub Actions OIDC authentication
- Named: `sp-gha-{project}-infra-{env}` (e.g., `sp-gha-ecare-infra-dev`)
- Used by GitHub Actions workflows in Terraform repositories to authenticate to Azure

**Federated Identity Credentials (FIC)**:

- Enables passwordless authentication using OpenID Connect (OIDC)
- Creates one FIC per Terraform repository per environment (12 total: 3 repos × 4 environments)
- Scoped to: `repo:{organization_name}/{repo}:environment:{environment}`
- Allows GitHub Actions workflows to request Azure access tokens without storing secrets

**RBAC Role Assignments**:

- **Contributor** on Resource Group - Allows Terraform to create/modify/delete infrastructure resources
- **User Access Administrator** on Resource Group - Allows Terraform to assign roles to Managed Identities it creates
- **Storage Blob Data Contributor** on Storage Account (for Service Principal) - Allows Terraform to read/write state files
- **Storage Blob Data Contributor** on Storage Account (for users, optional) - Allows users to view state files in Azure Portal

### Important: Bootstrap is for Terraform State, Not Service Deployment

**The bootstrap module in this repository creates Service Principals and FIC for Terraform repositories** (`infra-foundation`, `infra-platform`, `infra-identity`) to manage infrastructure via Terraform. These identities are used by GitHub Actions workflows to:

- Run `terraform plan` and `terraform apply`
- Access Terraform state files in Azure Storage Accounts
- Create and manage Azure resources (networks, AKS, databases, etc.)

**For service deployment authentication**, see the [`infra-identity` repository](https://github.com/hycom/infra-identity), which creates User Assigned Managed Identities (UAMI) and FIC for **service repositories** to:

- Push container images to Azure Container Registry (ACR)
- Deploy services to Azure Kubernetes Service (AKS)
- Access Azure resources (Key Vault, Storage, Service Bus) from running services

### Configuration

The bootstrap module is configured in each environment's `terraform.tfvars`:

```hcl
# Bootstrap Configuration
organization_name   = "hycom"
organization_for_sa = "hycom"
enable_bootstrap    = true

# Users with access to Terraform state Storage Account
users_with_state_access = [
  "f714a502-3026-4ef8-b753-00c5b4c00f4a",  # User Object ID
  "c655dbb9-e52b-45c3-8b96-e37a1c35aa7e"   # User Object ID
]
```

See `terraform/environments/{env}/bootstrap.tf` and `terraform/modules/bootstrap/README.md` for detailed documentation.

## Architecture

This repository uses a modular architecture to eliminate code duplication:

- **Environment Module** (`modules/environment/`): Shared module that encapsulates all common infrastructure configuration for an environment. This module eliminates ~90% of code duplication across environments by providing a single source of truth.
- **Network Module** (`modules/network/`): Creates Virtual Network, subnets, NSGs, and NSG rules.
- **VPN Gateway Module** (`modules/vpn-gateway/`): Creates optional VPN Gateway for site-to-site and point-to-site connectivity.

Each environment directory (`environments/{dev,test,stage,prod}/`) contains:

- `versions.tf` - Terraform version, backend configuration, and required providers
- `providers.tf` - Provider configuration (required in root module)
- `main.tf` - Calls the `environment` module with environment-specific variables
- `variables.tf` - Environment-specific input variables
- `outputs.tf` - Re-exports outputs from the `environment` module
- `terraform.tfvars` - Environment-specific values (not committed to git)

**Note on File Duplication:** The `outputs.tf` and `variables.tf` files are intentionally duplicated across all environments. While they contain nearly identical content, this design decision provides:

- **Environment-specific visibility** - Each environment's outputs and variables are clearly visible when working within that environment directory
- **Environment-specific defaults** - Variables can have different default values per environment (e.g., `environment = "dev"` vs `environment = "prod"`)
- **Clarity and maintainability** - Developers working on a specific environment can see all relevant configuration without navigating to shared modules
- **Flexibility** - Future environment-specific customizations can be made without affecting other environments

This minimal duplication (~56 lines per `outputs.tf`, ~80 lines per `variables.tf`) is acceptable and provides better developer experience than attempting to eliminate it through shared templates or complex abstractions.

**Templates**: The `terraform/templates/` directory contains template files for `versions.tf` and `providers.tf` to help set up new environments.

## Prerequisites: Setup Phase 0 Infrastructure

Before running Terraform, you must set up the foundational infrastructure using the setup scripts in the `scripts/` directory. These scripts create the necessary Azure resources that Terraform requires.

### Required Steps (in order)

1. **Configure environment variables**
   - Copy `.env.example` to `.env` and fill in your values:
     - `TENANT_ID` - Your Azure AD Tenant ID
     - `SUBSCRIPTION_ID` - Your Azure Subscription ID
     - `LOCATION` - Azure region (e.g., "polandcentral")
   - Project constants are defined in `scripts/globals.sh` (ORGANIZATION, ORGANIZATION_FOR_SA, PROJECT)

2. **Run setup scripts** (in order):
   - `scripts/setup-rg.sh` - Creates Resource Groups for all environments (dev, test, stage, prod)
   - `scripts/setup-state-storage.sh` - Creates Terraform State Storage Accounts with containers, versioning, and soft delete enabled
   - `scripts/setup-access.sh` - Creates Service Principals for GitHub Actions, Federated Identity Credentials (FIC), and RBAC role assignments
   - `scripts/setup-access-user.sh` - Grants Storage Blob Data Contributor role to current user for viewing state files in Azure Portal
   - `scripts/setup-access-sp.sh` - Grants Storage Blob Data Contributor role to Service Principals for accessing state files

   **Or use the convenience script:**
   - `scripts/setup-all.sh` - Runs all setup scripts in the correct order automatically

3. **Verify setup**:
   - `scripts/verify-all.sh` - Verifies all resources were created correctly

4. **Cleanup (if needed)**:
   - `scripts/cleanup-all.sh` - Removes all resources created by setup scripts (RBAC, FIC, Service Principals, Storage Accounts, Resource Groups)
   - Supports `--dry-run` option to preview what will be deleted

### Setup Scripts Description

- **`setup-rg.sh`** - Creates 4 Resource Groups (one per environment) with proper tags for Terraform management. These Resource Groups serve as containers for all infrastructure resources that Terraform will create and manage. Each Resource Group is scoped to a specific environment (dev, test, stage, prod) and is required before creating any resources within it.

- **`setup-state-storage.sh`** - Creates Storage Accounts for Terraform state with blob versioning, soft delete, and secure access settings. These Storage Accounts store Terraform's state files (`.tfstate`) which track the current state of your infrastructure. The state files are critical - they allow Terraform to know what resources exist, their configuration, and dependencies. Without proper state storage, Terraform cannot manage your infrastructure correctly. Each environment has its own Storage Account with a dedicated `tfstate` container.

- **`setup-access.sh`** - **DEPRECATED**: This script's functionality has been replaced by the Terraform `bootstrap` module. The bootstrap module creates Service Principals, Federated Identity Credentials (FIC), and RBAC role assignments for Terraform repositories. See the [Bootstrap Module](#bootstrap-module) section below for details.

- **`setup-access-user.sh`** - **DEPRECATED**: This script's functionality has been replaced by the Terraform `bootstrap` module. User access to state Storage Accounts is now managed via the `users_with_state_access` variable in the bootstrap module configuration.

- **`setup-access-sp.sh`** - **DEPRECATED**: This script's functionality has been replaced by the Terraform `bootstrap` module. Service Principal access to state Storage Accounts is now automatically configured by the bootstrap module.

All setup scripts support `--dry-run` option to preview changes without executing them.

## Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality and consistency. The hooks automatically:

- **Validate Conventional Commits format** - Ensures all commit messages follow the Conventional Commits standard
- Format Terraform files (`terraform fmt`)
- Validate Terraform syntax (`terraform validate`)
- Lint Terraform code (`tflint`)
- Ensure files end with exactly one newline
- Remove trailing whitespace
- Validate YAML/JSON syntax
- Lint Markdown documentation

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
cd /path/to/infra-foundation
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

### Cleanup Scripts

- **`cleanup-all.sh`** - Comprehensive cleanup script that removes all resources created by setup scripts in the correct order:
  1. RBAC role assignments (to avoid dependency issues)
  2. Federated Identity Credentials (FIC)
  3. Service Principals
  4. Storage Accounts (and all containers within them)
  5. Resource Groups
  6. `service-principals.env` file (if exists)
  
  This script is useful for:
  - Resetting the infrastructure setup
  - Cleaning up test environments
  - Removing resources before recreating them
  
  **Warning**: This script will delete all Phase 0 infrastructure. Use with caution and always test with `--dry-run` first.

## Running Terraform

After completing the Phase 0 setup, you can proceed with Terraform deployment:

### 1. Navigate to the environment directory

```bash
cd terraform/environments/dev  # or test, stage, prod
```

### 2. Configure Terraform variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and configure:

- `environment` - Environment name (dev, test, stage, prod)
- `organization_name` - Organization name for resource naming (default: "hycom")
- `project_name` - Project name (default: "ecare")
- Network CIDR blocks for VNet and subnets
- `mgmt_subnet_allowed_ssh_ips` - List of IP addresses/CIDR blocks allowed for SSH access to management subnet (e.g., `["91.150.222.105"]`)
- VPN Gateway settings (if needed)

**Note**: Resource Group name is automatically constructed as `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`). The Resource Group must exist (created in Phase 0).

**Important**: `terraform.tfvars` is in `.gitignore` and should not be committed. Use `terraform.tfvars.example` as a template.

### 3. Initialize Terraform

```bash
terraform init
```

This will:

- Download required providers (azurerm)
- Configure the backend to use the Storage Account created in Phase 0
- Set up authentication using Azure AD (no credentials needed if logged in via `az login`)

### 4. Review the execution plan

```bash
terraform plan
```

This shows what resources Terraform will create, modify, or destroy without making any changes.

### 5. Apply the configuration

```bash
terraform apply
```

This will create the infrastructure resources defined in your Terraform configuration. Terraform will prompt for confirmation before making changes.

### 6. Verify deployment

After successful deployment, you can verify the resources:

- Use `scripts/verify-all.sh` to verify all Phase 0 resources
- Check Azure Portal for created resources
- Review Terraform outputs: `terraform output`

## Network Security Configuration

### Management Subnet SSH Access

The management subnet (mgmt) is used for bastion hosts and other management VMs. By default, SSH access from the internet is blocked by NSG rules. To allow SSH access from specific IP addresses:

1. Configure `mgmt_subnet_allowed_ssh_ips` in `terraform.tfvars`:

   ```hcl
   mgmt_subnet_allowed_ssh_ips = ["91.150.222.105", "203.0.113.0/24"]
   ```

2. Apply the Terraform configuration:

   ```bash
   terraform apply
   ```

This will create an NSG rule `AllowSSHInbound` (priority 200) that allows SSH (port 22) from the specified IP addresses/CIDR blocks. If the list is empty, SSH from the internet remains blocked.

**Security Note**: Always restrict SSH access to trusted IP addresses. For production environments, consider using VPN Gateway or Azure Bastion service instead of direct SSH access.

### Important Notes

- **State Management**: Terraform state is stored remotely in the Storage Account configured in `versions.tf`. Never commit `.tfstate` files to git.
- **Environment Isolation**: Each environment (dev, test, stage, prod) has separate state files and Resource Groups, ensuring complete isolation.
- **Authentication**: Terraform uses Azure AD authentication (configured via `use_azuread_auth = true` in `versions.tf`). Ensure you're logged in via `az login` or that GitHub Actions has proper OIDC configuration.
- **Backend Configuration**: The backend configuration in `versions.tf` points to the Storage Accounts created by `setup-state-storage.sh`. If you change the Storage Account names, update `versions.tf` accordingly.
- **Provider Configuration**: Each environment must have `versions.tf` (with backend and required_providers) and `providers.tf` (with provider definitions). These are required in the root module (environment directory), not in child modules. See `terraform/templates/` for templates.
- **Module Architecture**: All environments use the shared `environment` module, which eliminates code duplication. Changes to the module automatically propagate to all environments.
