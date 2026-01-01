# Ecare Infrastructure

This repository contains the Infrastructure-as-Code (IaC) for the ecare project, organized into three components:

- **foundation (Phase 1)**: Networking baseline (VNet/Subnets/NSG, optional VPN) and Terraform automation identity (Service Principals, Federated Identity Credentials, RBAC)
- **platform (Phase 2)**: Platform services consumed by workloads (AKS, ACR, Key Vault, Storage, Service Bus, PostgreSQL)
- **workload (Phase 3)**: Workload identities and GitHub OIDC integrations (AKS Workload Identity, repo-to-Azure federation)
- **shared**: Common scripts and utilities used across components (including cleanup tooling)

## Repository Structure

```
ecare-infrastructure/
├── shared/
│   ├── scripts/          # Shared shell library + cleanup tooling
│   └── README.md
├── foundation/
│   ├── terraform/        # Foundation Terraform modules + environments
│   ├── scripts/          # Phase 0 bootstrap + verification
│   ├── docs/             # Foundation documentation
│   └── README.md
├── platform/
│   ├── terraform/
│   ├── scripts/
│   ├── docs/
│   └── README.md
└── workload/
    ├── terraform/
    ├── scripts/
    ├── docs/
    └── README.md
```

## Phases and Bootstrapping Model

### Phase 0 (Bootstrap prerequisites)

Terraform requires a remote backend, so a small set of **per-environment bootstrap resources** is created using shell scripts:

- Resource Group: `rg-{project}-{env}` (e.g., `rg-ecare-dev`)
- Terraform state Storage Account: `tfstate{org}{project}{env}` (e.g., `tfstatehycomecaredev`)
- Container: `tfstate`
- Optional: RBAC assignment for the current user to read/write state

Bootstrap resources are **environment-scoped** (not deployment-scoped). They should not be tagged with `DeploymentId`.

Scripts: `foundation/scripts/setup-phase0.sh`, `verify-phase0.sh`, `cleanup-phase0.sh`.

### Phase 1/2/3 (Terraform-managed components)

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
terraform init / plan / apply
```

Platform:

```bash
cd platform/terraform/environments/dev
terraform init / plan / apply
```

Workload:

```bash
cd workload/terraform/environments/dev
terraform init / plan / apply
```

## Tagging - TODO


## Deployment Identification and Cleanup

Terraform-managed resources are tagged with a unique `deployment_id` (8-character lowercase alphanumeric identifier) to support automated cleanup across Azure and Entra ID. `deployment_id` is unique and the same within one environment.

The second parameter identifying resources is `phase` (often also called `stack` in the context of terraform).

- **Azure resources**: tag `DeploymentId = "<deployment_id>"`, `Phase = "<phase>"`
- **Entra ID objects** (where tags are not queryable): `displayName` suffix includes the `<phase>-<deployment_id?`

Cleanup tooling lives in `shared/scripts/`:

```bash
./shared/scripts/cleanup-deployment-arm.sh
./shared/scripts/cleanup-deployment-azuread.sh
```

See - [README](./shared/scripts/README.md)

## Documentation

- **[foundation](./infra-foundation/README.md)** (Phase 1)
  - [Architecture](./infra-foundation/docs/ARCHITECTURE.md)
  - [Deployment](./infra-foundation/docs/DEPLOYMENT.md)
  - [Scripts Reference](./infra-foundation/docs/SCRIPTS-REFERENCE.md)
  - [Troubleshooting](./infra-foundation/docs/TROUBLESHOOTING.md)
  - [Naming Conventions](./infra-foundation/docs/NAMING-CONVENTIONS.md)
- **[platform](./infra-platform/README.md)** (Phase 2)
  - [Architecture](./infra-platform/docs/ARCHITECTURE.md)
  - [Deployment](./infra-platform/docs/DEPLOYMENT.md)
  - [Troubleshooting](./infra-platform/docs/TROUBLESHOOTING.md)
  - [Naming Conventions](./infra-platform/docs/NAMING-CONVENTIONS.md)
- **[workload](./workload/README.md)** (Phase 3)
  - [Architecture](./infra-identity/docs/ARCHITECTURE.md)
  - [Deployment](./infra-identity/docs/DEPLOYMENT.md)
  - [Troubleshooting](./infra-identity/docs/TROUBLESHOOTING.md)
  - [Naming Conventions](./infra-identity/docs/NAMING-CONVENTIONS.md)
- **[shared](./shared/README.md)**

## Contributing

- Follow Conventional Commits
- Run `pre-commit run --all-files`
- Run `terraform fmt -recursive` in the changed component
- Keep module README files aligned with `.cursor/rules/module-readme.mdc`
