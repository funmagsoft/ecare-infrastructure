# Ecare Infrastructure Maintenance Notes

## Table Of Contents

- [Ecare Infrastructure Maintenance Notes](#ecare-infrastructure-maintenance-notes)
  - [Table Of Contents](#table-of-contents)
  - [Repository Structure](#repository-structure)
  - [Terraform Layout](#terraform-layout)
    - [Root Modules (Environments)](#root-modules-environments)
    - [Module Layout](#module-layout)
    - [Environment Modules](#environment-modules)
    - [Stack Modules Overview](#stack-modules-overview)
  - [Required Environment Variables](#required-environment-variables)
  - [Environments](#environments)
  - [Phase 0 Bootstrap (Foundation Scripts)](#phase-0-bootstrap-foundation-scripts)
  - [Getting Started](#getting-started)
  - [Remote State Dependencies](#remote-state-dependencies)
  - [Tagging And Deployment Identification](#tagging-and-deployment-identification)
  - [Naming Conventions (Highlights) - TODO](#naming-conventions-highlights---todo)
  - [Verification And Cleanup Tooling](#verification-and-cleanup-tooling)
  - [Terraform Automation Identities (Bootstrap)](#terraform-automation-identities-bootstrap)
  - [Shared Script Library](#shared-script-library)
  - [Stack Scripts Overview](#stack-scripts-overview)
  - [Identity And OIDC Model](#identity-and-oidc-model)
  - [Platform Module Notes](#platform-module-notes)
  - [Pre-Commit And Tooling Notes](#pre-commit-and-tooling-notes)
  - [Pre-Commit Hooks](#pre-commit-hooks)
  - [Conventional Commits](#conventional-commits)
  - [Terraform Versions And Providers](#terraform-versions-and-providers)
  - [Notes](#notes)
  - [Contributing](#contributing)

This document summarizes the repository structure and operational entry points for maintenance.

## Repository Structure

- `foundation/` contains Phase 0 bootstrap scripts and Terraform modules for core networking.
- `platform/` contains Terraform modules for platform services (AKS, ACR, Key Vault, Storage, Service Bus, PostgreSQL).
- `workload/` contains Terraform modules for GitHub OIDC integration and workload identities.
- `shared/` contains script libraries and cross-cutting verification/cleanup tooling.

Repository tree (high level):

```text
.
├── .cursor/                # Cursor rules, commands, and project guidance
├── .github/                # GitHub workflows and metadata
├── .vscode/                # Editor settings and tasks
├── foundation/             # Phase 0/1 networking + bootstrap identities
│   ├── scripts/            # Phase 0 setup/verify/cleanup helpers
│   └── terraform/
│       ├── environments/   # Root modules per env (dev/test/stage/prod)
│       ├── modules/        # Reusable foundation modules
│       └── templates/      # Templates/examples for foundation
├── platform/               # Phase 2 platform services (AKS, ACR, etc.)
│   ├── scripts/            # Platform operational helpers
│   └── terraform/
│       ├── environments/   # Root modules per env
│       ├── modules/        # Reusable platform modules
│       └── templates/      # Templates/examples for platform
├── workload/               # Phase 3 workload identity and OIDC
│   ├── scripts/            # Workload automation helpers
│   └── terraform/
│       ├── environments/   # Root modules per env
│       ├── modules/        # Reusable workload modules
│       └── templates/      # Templates/examples for workload
├── shared/                 # Shared scripts and templates
│   ├── scripts/            # Verification, cleanup, and common helpers
│   │   └── lib/            # Script function library
│   └── templates/          # Shared templates (module docs)
├── .env.example            # Required environment variables template
├── .gitignore              # Git ignore rules for generated/local files
├── .pre-commit-config.yaml # Pre-commit hooks configuration
└── README.md               # Main project overview (this file)
```

## Terraform Layout

Each stack follows the same high-level structure:

- `terraform/environments/<env>` for root modules (per environment).
- `terraform/modules/<module>` for reusable modules.
- `terraform/templates/` for templates and examples.

### Root Modules (Environments)

Root modules live under:

- `foundation/terraform/environments/<env>`
- `platform/terraform/environments/<env>`
- `workload/terraform/environments/<env>`

Each root module wires a stack-specific `environment` module and exposes:

- `main.tf` with module wiring
- `variables.tf` for inputs
- `providers.tf` and `versions.tf` for provider/version pinning
- `outputs.tf` for stack outputs
- `terraform.tfvars` and `terraform.tfvars.example` for environment values

The foundation root module also optionally wires the bootstrap module via `bootstrap.tf`
and can be enabled/disabled using `enable_bootstrap`.

### Module Layout

Most Terraform modules follow a consistent layout:

- `main.tf` for resources and sub-modules
- `variables.tf` for inputs (with validation)
- `locals.tf` for naming, tagging, or derived values
- `outputs.tf` for exported values
- `versions.tf` for required Terraform/provider versions

### Environment Modules

Each stack has a dedicated `environment` module that composes its core resources:

- `foundation/terraform/modules/environment` creates networking and optional VPN gateway
  and looks up the existing resource group from Phase 0.
- `platform/terraform/modules/environment` composes platform modules and reads
  foundation outputs via remote state (VNet and subnet IDs).
- `workload/terraform/modules/environment` composes workload identity modules and
  expands service definitions using platform remote state outputs.

All environment modules enforce required tag keys via `check` blocks and use a
shared tagging model (see Tagging section).

### Stack Modules Overview

Foundation modules:

- `bootstrap` (Entra ID app/SP/FIC + RBAC for Terraform repos)
- `environment` (network baseline and optional VPN gateway)
- `network` (VNet, subnets, NSGs, NSG rules)
- `vpn-gateway` (VPN gateway + public IP, optional)

Platform modules:

- `environment` (composes all platform services)
- `aks`, `aks-namespace`
- `acr`, `key-vault`, `storage`, `service-bus`, `postgresql`
- `monitoring`, `bastion`

Workload modules:

- `environment` (composes workload identity + GitHub OIDC)
- `github-oidc` (Service Principal + FIC for service and GitOps repos)
- `workload-identity` (per-service UAMI + FIC + Kubernetes ServiceAccount)

## Required Environment Variables

| Name | Description |
| --- | --- |
| `TENANT_ID` | Azure tenant ID |
| `SUBSCRIPTION_ID` | Azure subscription ID |
| `LOCATION` | Default Azure region |

Source: `.env.example`.

## Environments

The repository defines four environments per stack:

- `dev`
- `test`
- `stage`
- `prod`

These are used consistently in:

- directory structure under `terraform/environments`
- variable validation for `environment`
- script flags (`--env` or `--all-envs`)

## Phase 0 Bootstrap (Foundation Scripts)

Phase 0 creates prerequisites for Terraform state:

- `foundation/scripts/setup-phase0.sh` runs setup for resource groups, state storage, and access.
- `foundation/scripts/verify-phase0.sh` verifies Phase 0 resources.
- `foundation/scripts/cleanup-phase0.sh` removes Phase 0 resources (requires confirm).

Bootstrap resources are environment-scoped (not deployment-scoped) and are not tagged
with `DeploymentId`. The core objects are:

- Resource Group: `rg-{project}-{env}` (for example, `rg-ecare-dev`)
- Storage Account: `tfstate{org}{project}{env}` (for example, `tfstatehycomecaredev`)
- Container: `tfstate`

Each component uses its own state key in the same container:

- `foundation/terraform.tfstate`
- `platform/terraform.tfstate`
- `workload/terraform.tfstate`

Common flags:

- `--env <dev|test|stage|prod>` (repeatable)
- `--all-envs` (default)
- `--dry-run` or `--execute` for destructive scripts

## Getting Started

1. Export required environment variables or create a local `.env` based on `.env.example`.
2. Run Phase 0 scripts in `foundation/scripts` to set up state and access if needed.
3. Run Terraform from the environment root (`terraform/environments/<env>`).

Basic Terraform workflow:

```bash
terraform init
terraform plan
terraform apply
```

## Remote State Dependencies

Cross-stack dependencies are wired via `data.terraform_remote_state`:

- Platform reads foundation outputs (VNet and subnets).
- Workload reads platform outputs (AKS namespace, OIDC issuer, Key Vault/Storage/Service Bus IDs).
- Workload also reads foundation outputs (resource group/location).

This implies ordering:

1. Foundation
2. Platform
3. Workload

## Tagging And Deployment Identification

All environment modules construct required tags and merge them with `var.tags`.
Required tags take precedence and are validated. The required tag keys are:

- `Environment`
- `Project`
- `ManagedBy`
- `Phase`
- `GitRepository`
- `TerraformPath`
- `DeploymentId`

The `TerraformPath` tag reflects the stack and environment:

- `foundation/terraform/environments/<env>`
- `platform/terraform/environments/<env>`
- `workload/terraform/environments/<env>`

Deployment identity is derived from Terraform outputs or `shared/scripts/globals.sh`:

| Key | Purpose |
| --- | --- |
| `DeploymentId` | Tags Azure resources and Entra ID suffixes |
| `Phase` | One of `Foundation`, `Platform`, `Workload` |

Entra ID objects (Service Principals, App Registrations, FIC) encode `phase` and
`deployment_id` in `displayName` because they are not taggable.

Set of required tags:

```hcl
required_tags = {
  Environment   = var.environment         # dev, test, stage, prod
  Project       = var.project_name        # ecare
  ManagedBy     = "Terraform"
  Phase         = title(var.phase)        # Foundation, Platform, Workload
  GitRepository = "ecare-infrastructure"
  TerraformPath = "platform/terraform/environments/${var.environment}"
  DeploymentId  = var.deployment_id       # a1b2c3d4
}
```

Each module can add its own tags.

Tags should be defined at the root module level. One exception applies: because root modules
within the same phase (e.g., platform) are identical across environments (dev, test, stage, prod),
a technical module called `environment` is used to reduce code duplication. The root module
references only the `environment` module.

## Naming Conventions (Highlights) - TODO

Common Azure resource names:

- Resource Group: `rg-{project}-{env}`
- VNet: `vnet-{project}-{env}`
- Subnets: `snet-{project}-{env}-{purpose}`
- NSGs: `nsg-{project}-{env}-{purpose}`

Identity naming patterns:

- Bootstrap SP: `sp-gha-infra-{project}-{env}-{phase}-{deployment_id}`
- Service deployment SP: `sp-gha-{project}-{env}-{phase}-{deployment_id}`
- Workload UAMI: `mi-{project}-{service}-{env}-{phase}-{deployment_id}`
- Workload FIC: `fic-{project}-{service}-{env}-{phase}-{deployment_id}`

Platform service highlights:

- AKS: `aks-{project}-{env}`
- Key Vault: `kv-{project}-{env}`
- PostgreSQL: `psql-{project}-{env}`
- Service Bus: `sb-{project}-{env}`
- Storage: `st{org}{project}{env}{hash}`
- ACR: `acr{project}{env}`

## Verification And Cleanup Tooling

Azure ARM verification:

```bash
./shared/scripts/verify-deploymentid-arm.sh --tf-dir <path> --phase <foundation|platform|workload>
```

Entra ID verification:

```bash
./shared/scripts/verify-deploymentid-azuread.sh --tf-dir <path> --phase <foundation|platform|workload>
```

Cleanup tooling:

```bash
./shared/scripts/cleanup-deployment-arm.sh --tf-dir <path> --phase <foundation|platform|workload>
./shared/scripts/cleanup-deployment-azuread.sh --tf-dir <path> --phase <foundation|platform|workload>
```

## Terraform Automation Identities (Bootstrap)

Bootstrap creates Entra ID objects for Terraform repositories:

- Service Principal and App Registration for Terraform CI
- FIC per repository and environment:
  - Issuer: `https://token.actions.githubusercontent.com`
  - Subject: `repo:{org}/{repo}:environment:{environment}`
  - Audience: `api://AzureADTokenExchange`

The bootstrap SP is assigned:

- Contributor on the resource group
- User Access Administrator on the resource group
- Storage Blob Data Contributor on the state storage account

Optionally, users can receive Storage Blob Data Contributor to inspect state.

## Shared Script Library

`shared/scripts/common.sh` loads the shared helpers used by component scripts:

- Logging and error handling
- Argument parsing and confirmation checks
- Dry-run support
- Azure CLI wrappers and checks
- Environment variable loading and init

## Stack Scripts Overview

Foundation scripts:

- `setup-*.sh` create Phase 0 resources (resource group, state storage, access user)
- `verify-*.sh` validate Phase 0 resources
- `cleanup-*.sh` remove Phase 0 resources (requires confirmation in destructive scripts)
- `recover-sp-ids.sh` helps recover service principal identifiers

Platform scripts:

- `get-aks-credentials.sh` retrieves AKS credentials for the selected environment

Workload scripts:

- `add-service.sh` registers a new workload service for identity automation

Shared scripts:

- `verify-deploymentid-arm.sh` and `verify-deploymentid-azuread.sh` validate deployment ID ownership
- `cleanup-deployment-arm.sh` and `cleanup-deployment-azuread.sh` remove resources tied to a deployment ID
- `cleanup-terraform-lockfiles.sh` removes lock files outside root modules

## Identity And OIDC Model

There are two identity tracks:

- Terraform automation (foundation bootstrap): Service Principal + FIC for Terraform repos
- Application deployment (workload): Service Principal + FIC for service repos and GitOps repos

Bootstrap identities (foundation) use `sp-gha-infra-{project}-{env}-{phase}-{deployment_id}`
naming to distinguish them from deployment identities. Workload identities (deployment) use
`sp-gha-{project}-{env}-{phase}-{deployment_id}`.

GitHub OIDC subjects differ by repository type:

- Service repos: `repo:{org}/{repo}:ref:refs/heads/{branch}`
- GitOps repos: `repo:{org}/{repo}:environment:{environment}`

AKS Workload Identity (per service) uses:

- Issuer: AKS OIDC issuer URL
- Subject: `system:serviceaccount:{namespace}:sa-{service_name}`
- Audience: `api://AzureADTokenExchange`

Workload identity creation is conditional and only occurs when any Azure access
flag is enabled or additional roles are configured.

## Platform Module Notes

- AKS is configured with OIDC issuer and Workload Identity enabled by default.
- Private Endpoints are used for Storage, PostgreSQL, Key Vault, ACR, and Service Bus.
- Bastion VM is used for jump access and gets RBAC to AKS and ACR.
- Kubernetes provider configuration is expected in root modules after AKS is created.

## Pre-Commit And Tooling Notes

- `terraform_fmt` runs recursively on `.tf` files.
- `terraform_validate` runs on `.tf` files.
- `terraform_tflint` runs with a curated rule set (some rules intentionally excluded).
- Markdown lint runs with several rules disabled (line length, inline HTML, etc.).

## Pre-Commit Hooks

Pre-commit is configured in `.pre-commit-config.yaml` and includes:

- file hygiene hooks (whitespace, EOF, large file checks, YAML/JSON validation)
- Terraform formatting and validation (`terraform_fmt`, `terraform_validate`, `terraform_tflint`)
- Markdown linting with a customized rule set
- Conventional Commits validation at commit-msg stage

Install and run:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

Hooks must also be installed for `commit-msg` to enforce Conventional Commits:

```bash
pre-commit install --hook-type commit-msg
```

## Conventional Commits

Commit messages follow Conventional Commits and are validated by
`shared/scripts/validate-commit-msg.sh`. Valid types include:

| Type | Description |
| --- | --- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style changes (formatting, missing semicolons, etc.) |
| `refactor` | Code refactoring |
| `perf` | Performance improvements |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks (dependencies, build, etc.) |
| `build` | Build system changes |
| `ci` | CI/CD changes |

The repository also uses a `gitcc` workflow documented in `.cursor/commands/gitcc.md`
to produce consistent commit messages:

```text
<type>(optional scope): <subject>

- <change description 1>
- <change description 2>
```

## Terraform Versions And Providers

Across modules, the baseline versions are:

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.80
- AzureAD Provider ~> 2.44 (identity modules)
- Kubernetes Provider ~> 2.0 (AKS and workload modules)

## Notes

Avoid committing generated Terraform working directories (`.terraform/`) and lock files outside environment roots.

## Contributing

- Follow Conventional Commits
- Run `pre-commit run --all-files`
- Run `terraform fmt -recursive` in the changed component
- Keep module README files aligned with `.cursor/rules/module-readme.mdc` and `shared/templates/MODULE-README.mc`
