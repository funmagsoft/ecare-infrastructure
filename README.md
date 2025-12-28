# Infra Workload Identity

Workload Identities (UAMI), Federated Identity Credentials (FIC), and RBAC for application services running on AKS in the ecare project.

## Purpose

This repository contains Terraform code and helper scripts to:

- Create Service Principals and GitHub OIDC Federated Identity Credentials (FIC) for service repositories to enable passwordless deployments from GitHub Actions (building container images and deploying to AKS).
- Create User Assigned Managed Identities (UAMI) per service for AKS pods to access Azure resources.
- Create AKS Workload Identity Federated Identity Credentials (FIC) per service to enable pods to authenticate to Azure resources.
- Assign RBAC for services to Azure resources (Key Vault, Storage, Service Bus, plus optional custom roles).
- Keep configuration per environment (dev, test, stage, prod).

## Structure

```
terraform/
├── modules/
│   ├── environment/                  # Shared environment module (eliminates code duplication)
│   ├── github-oidc/                  # SP + FIC + RBAC for service repositories (GitHub Actions)
│   └── workload-identity/            # UAMI + FIC + RBAC per service (AKS pods)
├── templates/                        # Template files for backend.tf and providers.tf
└── environments/
    ├── dev/
    ├── test/
    ├── stage/
    └── prod/

scripts/
├── common.sh
└── add-service.sh
```

Each environment directory contains:

- `backend.tf` - Backend configuration (state storage)
- `providers.tf` - Provider configuration (AzureRM, AzureAD, Kubernetes)
- `main.tf` - Calls the `environment` module
- `services.tf` - Service configuration (environment-specific)
- `variables.tf` - Environment-specific variables
- `outputs.tf` - Re-exports outputs from the `environment` module

**Templates**: The `terraform/templates/` directory contains template files for `backend.tf` and `providers.tf` to help set up new environments.

## What is created

### Per Environment (GitHub OIDC Integration)

The `github-oidc` module creates:

- **Service Principal** (one per environment)  
  Name: `sp-gha-{project_name}-{environment}` (e.g., `sp-gha-ecare-dev`)
- **Federated Identity Credentials (FIC)** for GitHub OIDC:
  - One per service repository (branch-based: `repo:{org}/{repo}:ref:refs/heads/{branch}`, default branch = `main`)
  - One per GitOps repository (environment-based: `repo:{org}/{repo}:environment:{environment}`)
  Issuer: `https://token.actions.githubusercontent.com`  
- **RBAC Role Assignments**:
  - **Contributor** on Azure Container Registry (ACR) - Required for `az acr build`
  - **Azure Kubernetes Service Cluster User Role** on AKS - Required for `az aks get-credentials`
  - **Azure Kubernetes Service RBAC Writer** on AKS (optional) - Required for deployments

### Per Service (Workload Identity)

For each service declared in `terraform/environments/<env>/services.tf`, the `workload-identity` module creates:

- **User Assigned Managed Identity (UAMI)**  
  Name: `mi-ecare-<service>-<env>`
- **Federated Identity Credential (FIC)** for AKS Workload Identity  
  Issuer: AKS OIDC Issuer URL  
  Subject: `system:serviceaccount:{namespace}:sa-{service}`
- **RBAC assignments** (conditional, based on flags):
  - Key Vault: `Key Vault Secrets User` on `key_vault_id`
  - Storage: `Storage Blob Data Contributor` on `storage_account_id`
  - Service Bus: `Azure Service Bus Data Owner` on `service_bus_namespace_id`
  - Additional roles: any custom `{ role, scope }` entries

All tags are aligned with the platform/foundation conventions (`Environment`, `Project`, `ManagedBy`, `Phase`, `GitRepository`, `Service`).

## Configuration per environment

Each environment has a `services.tf` with a `local.services` map. Example (dev):

```hcl
locals {
  services = {
    billing = {
      repo                    = "funmagsoft/billing-service"
      branch                  = "main"
      enable_key_vault_access = true
      enable_storage_access   = true
      enable_service_bus_access = false
      additional_roles        = []
    }
  }
}
```

The `environment` module automatically:
- Creates Service Principal and FIC for GitHub Actions (via `github-oidc` module) using `repo` and `branch` from each service
- Creates UAMI and FIC for AKS pods (via `workload-identity` module) using service configuration
- Pulls IDs of ACR, AKS, KV/Storage/SB from `infra-platform` remote state
- Assigns RBAC roles based on service flags

If a flag is `true` but the corresponding ID is missing, a precondition will fail.

### Important: Two Types of Identities

**GitHub OIDC Integration** (`github-oidc` module):
- Creates **one Service Principal per environment** (`sp-gha-{project}-{env}`)
- Creates **FIC per service repository** for GitHub Actions workflows
- Used for: building container images (`az acr build`), deploying to AKS (`az aks get-credentials`, Helm/kubectl)
- RBAC: Contributor on ACR, Azure Kubernetes Service Cluster User Role on AKS, optional RBAC Writer

**Workload Identity** (`workload-identity` module):
- Creates **one UAMI per service** (`mi-{project}-{service}-{env}`)
- Creates **FIC per service** for AKS pods (Workload Identity)
- Used for: AKS pods accessing Azure resources (Key Vault, Storage, Service Bus)
- RBAC: Key Vault Secrets User, Storage Blob Data Contributor, Service Bus Data Owner (per service needs)

## Scripts

### add-service.sh

Add or update a service entry in `services.tf`:

```
scripts/add-service.sh --env dev --service billing --repo funmagsoft/billing-service --kv --storage --sb
```

Options:

- `--env dev|test|stage|prod|all` – target environment(s)
- `--service <name>` – logical service name
- `--repo <org/repo>` – GitHub repo for OIDC subject
- `--kv` – enable Key Vault access
- `--storage` – enable Storage access
- `--sb` – enable Service Bus access
- `--dry-run` – show the resulting `services.tf` without writing

Behavior:

- Updates `terraform/environments/<env>/services.tf` (inserts/replaces a block `# Service: <name>`).
- In `--dry-run` mode, prints the would-be file content and does not write.
- If `services.tf` is missing and `--dry-run`, it only prints a template; otherwise it creates a template and appends the service.

### common.sh

Shared helpers: `parse_dry_run`, logging, optional `.env` loading (ignored if missing).

## Running Terraform

1. Go to the environment directory, e.g.:

   ```bash
   cd terraform/environments/dev
   ```

2. Configure services in `services.tf` (or via `add-service.sh`).
3. Initialize:

   ```bash
   terraform init
   ```

4. Plan / apply:

   ```bash
   terraform plan
   terraform apply
   ```

## Backends and Remote State

- Backends use the same naming as foundation/platform: `tfstatehycomecare{env}` in `rg-ecare-{env}`, container `tfstate`.
- Remote states (accessed by the `environment` module):
  - `infra-foundation/terraform.tfstate` - Provides Resource Group and location
  - `infra-platform/terraform.tfstate` - Provides IDs of KV/Storage/SB and AKS configuration
- **Resource Group**: Resource Group name is automatically constructed as `rg-{project_name}-{environment}` (e.g., `rg-ecare-dev`). The Resource Group must exist (created in Phase 0).

## Architecture

This repository uses a modular architecture to eliminate code duplication:

- **Environment Module** (`modules/environment/`): Shared module that encapsulates all common identity configuration for an environment. This module eliminates ~90% of code duplication across environments by providing a single source of truth.
- **GitHub OIDC Azure Integration Module** (`modules/github-oidc/`): Creates Service Principal, Federated Identity Credentials for service repositories, and RBAC role assignments for GitHub Actions workflows (ACR build, AKS deployment).
- **Workload Identity Module** (`modules/workload-identity/`): Creates User Assigned Managed Identities, Federated Identity Credentials for AKS pods, RBAC role assignments, and Kubernetes Service Accounts per service.

## Important Notes

- Do not commit `terraform.tfvars` or `.tfstate`. State is remote; config stays in `services.tf`.
- Ensure `az login` and correct subscription before running Terraform, or use GitHub OIDC in CI.
- RBAC scopes rely on outputs from `infra-platform`. Keep platform deployed and outputs available for each env.
- **Provider Configuration**: Each environment must have a `providers.tf` file with the AzureRM, AzureAD, and Kubernetes provider configuration. This is required in the root module (environment directory), not in child modules. See `terraform/templates/providers.tf.template` for the template.
- **Module Architecture**: All environments use the shared `environment` module, which eliminates code duplication. Changes to the module automatically propagate to all environments.

## Cleanup

To remove identities/RBAC for an environment:

```
cd terraform/environments/<env>
terraform destroy
```

Be mindful of shared platform resources; the destroy will remove only the identities/RBAC created here.

