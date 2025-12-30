# Shared Components

This directory contains shared components used across all infrastructure repositories in the ecare-infrastructure monorepo.

## Contents

### `scripts/`

Common shell functions and utilities.

- **`common.sh`**: Core helper functions (output, checks, Azure CLI, environment, Git)
- **`globals.sh`**: Global project configuration (ORGANIZATION, PROJECT)
- See [scripts/README.md](./scripts/README.md) for detailed documentation

## Purpose

The shared components eliminate code duplication and ensure consistency across:

- **infra-foundation**: Core networking and Terraform authentication
- **infra-identity**: Identity and access control
- **infra-platform**: Platform services (AKS, ACR, databases)

## Usage

### In Shell Scripts

```bash
#!/bin/bash
set -euo pipefail

# Source shared functions (from any infrastructure repo)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

# Use shared functions
print_header "My Script"
check_azure_login || exit 1
# ...
```

### In Terraform (future)

```hcl
# Shared Terraform modules (if needed in future)
module "common_tags" {
  source = "../../shared/terraform/modules/common-tags"
  # ...
}
```

## Versioning

Shared components follow semantic versioning:

- **Major**: Breaking changes (require updates in all repos)
- **Minor**: New features (backward compatible)
- **Patch**: Bug fixes

Current version: **1.0.0**

## Development Workflow

### Adding New Shared Components

1. Identify duplicated code in 2+ repositories
2. Extract to `shared/`
3. Document in README
4. Update all repositories to use shared version
5. Test in all environments
6. Commit with conventional commit message

### Updating Shared Components

1. Make changes in `shared/`
2. Test in all affected repositories
3. Update version number
4. Document breaking changes (if any)
5. Update all repositories if needed
6. Commit as atomic change (shared + usage in one commit)

## Benefits of Monorepo for Shared Code

✅ **Atomic commits**: Change shared code + usage in all repos in one commit  
✅ **No version conflicts**: Always using the latest version  
✅ **Easy refactoring**: IDE can find all usages across repos  
✅ **Simplified testing**: Test shared code changes with all repos at once  
✅ **Single source of truth**: No confusion about which version to use  

## See Also

- [Main README](../README.md)
- [Scripts Documentation](./scripts/README.md)
- [Foundation README](../infra-foundation/README.md)
- [Identity README](../infra-identity/README.md)
- [Platform README](../infra-platform/README.md)

