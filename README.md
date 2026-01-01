# Ecare Infrastructure

This repository contains the Infrastructure-as-Code (IaC) for the ecare project, organized into four components:

- **foundation (Phase 1)**: Networking baseline (VNet/Subnets/NSG, optional VPN) and Terraform automation identity (service principals, federated identity credentials, RBAC)
- **platform (Phase 2)**: Platform services consumed by workloads (AKS, ACR, Key Vault, Storage, Service Bus, PostgreSQL)
- **workload (Phase 3)**: Workload identities and GitHub OIDC integrations (AKS Workload Identity, repo-to-Azure federation)
- **shared**: Common scripts and utilities used across components (including cleanup tooling)

## Repository Structure

```text
ecare-infrastructure/
├── shared/               # Shared shell library + cleanup tooling
│   └── scripts/
├── foundation/           # Foundation Terraform modules + environments
│   ├── terraform/
│   └── scripts/
├── platform/             # Platform Terraform modules + environments
│   ├── terraform/
│   └── scripts/
└── workload/             # Workload Terraform modules + environments
    ├── terraform/
    └── scripts/
```

## Phases and Bootstrapping Model

### Phase 0 (Bootstrap Prerequisites)

Terraform requires a remote backend, so a small set of **per-environment bootstrap resources** is created using shell scripts:

- Resource Group: `rg-{project}-{env}` (e.g., `rg-ecare-dev`)
- Terraform state Storage Account: `tfstate{org}{project}{env}` (e.g., `tfstatehycomecaredev`)
- Container: `tfstate`
- Optional: RBAC assignment for the current user to read and write state

Bootstrap resources are **environment-scoped** (not deployment-scoped). They should not be tagged with `DeploymentId`.

Scripts: `foundation/scripts/setup-phase0.sh`, `verify-phase0.sh`, `cleanup-phase0.sh`.

### Phase 1/2/3 (Terraform-managed Components)

Everything else is managed by Terraform in environment roots:

- `foundation/terraform/environments/{env}`
- `platform/terraform/environments/{env}`
- `workload/terraform/environments/{env}`

Each component uses a separate Terraform state key (same Storage Account and container):

- `foundation/terraform.tfstate`
- `platform/terraform.tfstate`
- `workload/terraform.tfstate`

## Quick Start

### Prerequisites

- Azure CLI (logged in via `az login`)
- Terraform >= 1.5.0
- Git

### 1) Configure environment

Copy and edit `.env.example`:

```bash
cp .env.example .env
# set: TENANT_ID, SUBSCRIPTION_ID, LOCATION
```

### 2) Create Phase 0 bootstrap resources

```bash
cd foundation
./scripts/setup-phase0.sh
./scripts/verify-phase0.sh
```

### 3) Deploy Terraform components (per environment)

Foundation:

```bash
cd foundation/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Platform:

```bash
cd platform/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Workload:

```bash
cd workload/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## Tagging

All Azure resources (except resources created in Azure AD / Entra) should be consistently tagged as follows:

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

Tags should be defined at the root module level. One exception applies: because root modules within the same phase (e.g., platform) are identical across environments (dev, test, stage, prod), a technical module called `environment` is used to reduce code duplication. The root module references only the `environment` module.

## Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality:

- Validate Conventional Commits format
- Format Terraform files (`terraform fmt`)
- Validate Terraform syntax (`terraform validate`)
- Lint Terraform code (`tflint`)
- Ensure files end with a newline
- Remove trailing whitespace
- Validate YAML/JSON syntax

### Installation

```bash
# Install pre-commit
pip install pre-commit
# Or: brew install pre-commit

# Install hooks
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit install-hooks
```

### Usage

Hooks should run automatically on `git commit`. They can also be run manually:

```bash
pre-commit run --all-files
```

Update:

```bash
pre-commit autoupdate
```

## Conventional Commits

All commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Valid Types

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

### Examples

Long commit message (subject and body):

```text
docs: improve README and RUNBOOK formatting and clarity

- Simplify README by removing redundant Bootstrap vs Service Identity section
- Improve structure tree formatting in README
- Add clarification about organization_for_sa variable
- Add note about SSH access vs VPN Gateway
- Fix Conventional Commits format example (parentheses instead of brackets)
- Improve RUNBOOK formatting (access control list, proper markdown links for Additional Resources)
```

Short commit message (only subject):

```text
refactor(scripts): restructure with phase0 separation and comprehensive docs
```

## Deployment Identification and Cleanup

Terraform-managed resources are tagged with a unique `deployment_id` (an 8-character, lowercase alphanumeric identifier) to support automated cleanup across Azure and Entra ID. The `deployment_id` is unique within a single environment (`dev`, `test`, `stage`, `prod`).

A second identifier is `phase` (sometimes called a stack in Terraform context). `phase` can have one of the following values: `foundation`, `platform`, or `workload`.

- **Azure resources**: tags `DeploymentId = "<deployment_id>"`, `Phase = "<phase>"`
- **Entra ID objects** (where tags are not queryable): `displayName` suffix includes `<phase>-<deployment_id>`

Cleanup tooling lives in `shared/scripts/`:

```bash
./shared/scripts/cleanup-deployment-arm.sh
./shared/scripts/cleanup-deployment-azuread.sh
```

## Contributing

- Follow Conventional Commits
- Run `pre-commit run --all-files`
- Run `terraform fmt -recursive` in the changed component
- Keep module README files aligned with `.cursor/rules/module-readme.mdc`
