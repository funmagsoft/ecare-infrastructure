# ecare Infrastructure - Monorepo

This is the unified infrastructure repository for the ecare project, combining:

- **infra-foundation**: Core networking infrastructure (VNet, NSG, VPN Gateway) and Terraform authentication (Service Principals, RBAC)
- **infra-identity**: Identity and access control (GitHub OIDC, Workload Identity for AKS)
- **infra-platform**: Platform services (AKS, ACR, databases, Key Vault) - *(coming soon)*
- **shared**: Common scripts and utilities used across all infrastructure repositories

## Repository Structure

```
ecare-infrastructure/
├── shared/
│   ├── scripts/          # Shared shell functions
│   └── docs/             # Cross-repository documentation
├── infra-foundation/
│   ├── terraform/        # Foundation Terraform modules
│   ├── scripts/          # Foundation-specific scripts
│   └── docs/             # Foundation documentation
├── infra-identity/
│   ├── terraform/        # Identity Terraform modules
│   ├── scripts/          # Identity-specific scripts
│   └── docs/             # Identity documentation
└── infra-platform/
    ├── terraform/        # Platform Terraform modules
    ├── scripts/          # Platform-specific scripts
    └── docs/             # Platform documentation
```

## Terraform State Management

Each infrastructure component maintains **separate Terraform state files**:

- `infra-foundation/terraform.tfstate` - Core networking and Terraform authentication
- `infra-platform/terraform.tfstate` - Platform services (AKS, ACR, databases)
- `infra-identity/terraform.tfstate` - Identity and access control

This separation ensures:
- Independent deployments
- Reduced blast radius
- Clear separation of concerns
- Different lifecycle management

## Quick Start

### Prerequisites

- Azure CLI >= 2.50.0
- Terraform >= 1.5.0
- kubectl >= 1.24
- Git

### Clone Repository

```bash
git clone https://github.com/hycom/ecare-infrastructure.git
cd ecare-infrastructure
```

### Deploy Infrastructure

```bash
# 1. Deploy Foundation (networking, Terraform auth)
cd infra-foundation/terraform/environments/dev
terraform init
terraform apply

# 2. Deploy Platform (AKS, ACR, databases)
cd ../../../infra-platform/terraform/environments/dev
terraform init
terraform apply

# 3. Deploy Identity (GitHub OIDC, Workload Identity)
cd ../../../infra-identity/terraform/environments/dev
terraform init
terraform apply
```

## Documentation

- **[infra-foundation](./infra-foundation/README.md)**: Core networking and Terraform authentication
  - [Architecture](./infra-foundation/docs/ARCHITECTURE.md)
  - [Runbook](./infra-foundation/docs/RUNBOOK.md)
  - [Troubleshooting](./infra-foundation/docs/TROUBLESHOOTING.md)
- **[infra-identity](./infra-identity/README.md)**: Identity and access control
  - [Architecture](./infra-identity/docs/ARCHITECTURE.md)
  - [Deployment](./infra-identity/docs/DEPLOYMENT.md)
  - [Troubleshooting](./infra-identity/docs/TROUBLESHOOTING.md)
  - [Naming Conventions](./infra-identity/docs/NAMING-CONVENTIONS.md)
- **[shared](./shared/README.md)**: Common scripts and utilities

## Migration Notes

This monorepo was created on 2024-12-30 by merging three separate repositories:

- `infra-foundation` - Full git history preserved
- `infra-identity` - Full git history preserved
- `infra-platform` - Full git history preserved

All commit history from the original repositories has been preserved using git subtree merge strategy.

## Contributing

1. Follow the [Conventional Commits](https://www.conventionalcommits.org/) format
2. Run pre-commit hooks before committing
3. Ensure Terraform code is formatted (`terraform fmt`)
4. Update documentation when making changes

## License

Proprietary - Hycom/Magsoft

