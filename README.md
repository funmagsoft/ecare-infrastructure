# Infrastructure Foundation

Networking and foundational infrastructure for the ecare project.

## Purpose

This repository contains Terraform code for:

- Virtual Networks
- Subnets
- Network Security Groups (NSG) with SSH access rules for management subnet
- VPN Gateway (optional)

## Structure

```console
terraform/
├── modules/
│   ├── environment/    # Shared environment module (eliminates code duplication)
│   ├── network/        # Network module (VNet, Subnets, NSGs)
│   └── vpn-gateway/    # VPN Gateway module
├── templates/          # Template files for backend.tf and providers.tf
└── environments/
    ├── dev/
    ├── test/
    ├── stage/
    └── prod/
```

Each environment directory contains:

- `backend.tf` - Backend configuration (state storage)
- `providers.tf` - Provider configuration (AzureRM)
- `main.tf` - Calls the `environment` module
- `variables.tf` - Environment-specific variables
- `outputs.tf` - Re-exports outputs from the `environment` module
- `terraform.tfvars` - Environment-specific values (not committed to git)

## Getting Started

1. Review infra documentation [README.md](https://github.com/funmagsoft/infra-documentation/blob/main/README.md)

## Architecture

This repository uses a modular architecture to eliminate code duplication:

- **Environment Module** (`modules/environment/`): Shared module that encapsulates all common infrastructure configuration for an environment. This module eliminates ~90% of code duplication across environments by providing a single source of truth.
- **Network Module** (`modules/network/`): Creates Virtual Network, subnets, NSGs, and NSG rules.
- **VPN Gateway Module** (`modules/vpn-gateway/`): Creates optional VPN Gateway for site-to-site and point-to-site connectivity.

Each environment directory (`environments/{dev,test,stage,prod}/`) contains:

- `backend.tf` - Backend configuration pointing to environment-specific state storage
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

**Templates**: The `terraform/templates/` directory contains template files for `backend.tf` and `providers.tf` to help set up new environments.

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

- **`setup-access.sh`** - Creates Service Principals for GitHub Actions OIDC authentication, configures Federated Identity Credentials (FIC) for all repos, and assigns RBAC roles.
  
  **Service Principals:**
  - Creates 4 Service Principals (one per environment: dev, test, stage, prod)
  - Azure AD identities that allow automated access to Azure resources
  - GitHub Actions workflows use these to authenticate to Azure
  - Named: `sp-gha-${PROJECT}-infra-${ENV}`
  
  **Federated Identity Credentials (FIC):**
  - Enables passwordless authentication using OpenID Connect (OIDC)
  - GitHub Actions can request Azure access tokens without storing secrets
  - Creates 12 FIC total (3 repos × 4 environments):
    - `infra-foundation` repository for each environment
    - `infra-platform` repository for each environment
    - `infra-identity` repository for each environment
  - Each FIC is scoped to a specific GitHub repository and environment
  
  **RBAC Role Assignments:**
  - **Contributor** (on Resource Group and Subscription):
    - Allows Terraform to create/modify/delete resources
    - Required for all Terraform operations on infrastructure
  - **User Access Administrator** (on Resource Group):
    - Allows Terraform to assign roles to Managed Identities it creates
    - Required when Terraform creates resources that need role assignments (e.g., Managed Identities)
  - **Storage Blob Data Contributor** (on Storage Account):
    - Allows reading/writing Terraform state files
    - Required for Terraform to access and update state in remote backend
  
  These roles are essential for Terraform to manage infrastructure and state files in GitHub Actions workflows.

- **`setup-access-user.sh`** - Grants the current user Storage Blob Data Contributor role on all state storage accounts for Azure Portal access. This allows you (the subscription owner) to view and browse Terraform state files directly in Azure Portal, which is useful for debugging, auditing, and understanding the current infrastructure state. Without this role, you cannot access the state files through the portal, even though you own the subscription.

- **`setup-access-sp.sh`** - Grants Service Principals Storage Blob Data Contributor role on their respective state storage accounts for Terraform state access. This is a critical role assignment - it allows the Service Principals created by `setup-access.sh` to read and write Terraform state files stored in the Storage Accounts. When Terraform runs in GitHub Actions, it needs to authenticate as the Service Principal and access the state files to track infrastructure changes. Without this role, Terraform cannot read or update the state, causing deployments to fail.

All setup scripts support `--dry-run` option to preview changes without executing them.

## Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality and consistency. The hooks automatically:

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

- **State Management**: Terraform state is stored remotely in the Storage Account configured in `backend.tf`. Never commit `.tfstate` files to git.
- **Environment Isolation**: Each environment (dev, test, stage, prod) has separate state files and Resource Groups, ensuring complete isolation.
- **Authentication**: Terraform uses Azure AD authentication (configured via `use_azuread_auth = true` in `backend.tf`). Ensure you're logged in via `az login` or that GitHub Actions has proper OIDC configuration.
- **Backend Configuration**: The backend configuration in `backend.tf` points to the Storage Accounts created by `setup-state-storage.sh`. If you change the Storage Account names, update `backend.tf` accordingly.
- **Provider Configuration**: Each environment must have a `providers.tf` file with the AzureRM provider configuration. This is required in the root module (environment directory), not in child modules. See `terraform/templates/providers.tf.template` for the template.
- **Module Architecture**: All environments use the shared `environment` module, which eliminates code duplication. Changes to the module automatically propagate to all environments.
