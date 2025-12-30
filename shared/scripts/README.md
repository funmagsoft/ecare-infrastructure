# Shared Scripts Library

Common shell functions used across all infrastructure repositories in the ecare-infrastructure monorepo.

## Purpose

This library eliminates code duplication by providing a single source of truth for common shell functions used in:

- `infra-foundation/scripts/` - Foundation infrastructure scripts
- `infra-identity/scripts/` - Identity infrastructure scripts
- `infra-platform/scripts/` - Platform infrastructure scripts

## Files

### `common.sh`

Core helper functions for shell scripts.

### `globals.sh`

Global project configuration constants shared across all infrastructure components.

**Categories:**

- **Output Functions**: `print_header()`, `print_success()`, `print_error()`, `print_warning()`, `print_info()`
- **Command Checks**: `check_command()`, `check_required_commands()`
- **Azure CLI Helpers**: `check_azure_login()`, `get_subscription_id()`, `get_tenant_id()`, `check_resource_exists()`
- **Environment Helpers**: `validate_environment()`, `load_env_file()`, `get_project_root()`
- **Git Helpers**: `validate_conventional_commit()`

## Usage

### Basic Usage

```bash
#!/bin/bash
set -euo pipefail

# Source shared functions
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

# Use functions
print_header "My Script"
check_command az || exit 1
check_azure_login || exit 1
validate_environment "${ENV}" || exit 1

print_success "Script completed successfully!"
```

### Example: Foundation Script

```bash
#!/bin/bash
set -euo pipefail

# infra-foundation/scripts/setup-phase0.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

print_header "Phase 0 Infrastructure Setup"

# Check prerequisites
check_required_commands az jq || exit 1
check_azure_login || exit 1

# Load environment
load_env_file || exit 1
validate_environment "${ENV}" || exit 1

# ... rest of script
```

### Example: Identity Script

```bash
#!/bin/bash
set -euo pipefail

# infra-identity/scripts/add-service.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

print_header "Add New Service"

# Use shared functions
check_required_commands terraform || exit 1
validate_conventional_commit "feat(identity): add new service" || exit 1

# ... rest of script
```

## Function Reference

### Output Functions

#### `print_header <message>`

Prints a formatted header with separators.

```bash
print_header "Deploying Infrastructure"
# Output:
# ==========================================
# Deploying Infrastructure
# ==========================================
```

#### `print_success <message>`

Prints a success message with checkmark.

```bash
print_success "Resource created successfully"
# Output: ✓ Resource created successfully
```

#### `print_error <message>`

Prints an error message with cross (to stderr).

```bash
print_error "Failed to create resource"
# Output: ✗ Failed to create resource
```

#### `print_warning <message>`

Prints a warning message with warning symbol.

```bash
print_warning "Resource already exists"
# Output: ⚠ Resource already exists
```

#### `print_info <message>`

Prints an informational message.

```bash
print_info "Loading configuration"
# Output: ℹ Loading configuration
```

### Command Checks

#### `check_command <command>`

Checks if a command exists. Returns 0 if exists, 1 if not.

```bash
if check_command az; then
  print_success "Azure CLI found"
else
  print_error "Azure CLI not found"
  exit 1
fi
```

#### `check_required_commands <command1> [command2] ...`

Checks multiple commands at once. Exits with error if any are missing.

```bash
check_required_commands az terraform kubectl || exit 1
```

### Azure CLI Helpers

#### `check_azure_login`

Checks if logged in to Azure CLI. Returns 0 if logged in, 1 if not.

```bash
check_azure_login || exit 1
```

#### `get_subscription_id`

Returns the current Azure subscription ID.

```bash
SUBSCRIPTION_ID=$(get_subscription_id)
echo "Subscription: $SUBSCRIPTION_ID"
```

#### `get_tenant_id`

Returns the current Azure tenant ID.

```bash
TENANT_ID=$(get_tenant_id)
echo "Tenant: $TENANT_ID"
```

#### `check_resource_exists <resource_id>`

Checks if an Azure resource exists. Returns 0 if exists, 1 if not.

```bash
if check_resource_exists "/subscriptions/.../resourceGroups/rg-ecare-dev"; then
  print_success "Resource Group exists"
fi
```

### Environment Helpers

#### `validate_environment <env>`

Validates environment name. Returns 0 if valid (dev/test/stage/prod), 1 if not.

```bash
validate_environment "$ENV" || exit 1
```

#### `load_env_file [file]`

Loads environment variables from a file. Default: `.env`

```bash
load_env_file              # Loads .env
load_env_file ".env.dev"   # Loads .env.dev
```

#### `get_project_root`

Returns the absolute path to the monorepo root.

```bash
PROJECT_ROOT=$(get_project_root)
echo "Project root: $PROJECT_ROOT"
```

### Git Helpers

#### `validate_conventional_commit <message>`

Validates a commit message against Conventional Commits format.

```bash
validate_conventional_commit "feat(identity): add new service" || exit 1
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`

### Version Info

#### `print_version`

Prints the version of the shared scripts library.

```bash
print_version
# Output: Shared Scripts Library v1.0.0
#         Part of ecare-infrastructure monorepo
```

## Global Configuration (globals.sh)

The `globals.sh` file contains project-wide constants that should remain consistent across all infrastructure components.

**Variables:**

- `ORGANIZATION` - GitHub organization name (e.g., "hycom")
- `ORGANIZATION_FOR_SA` - Organization name for Storage Account naming (may differ due to Azure constraints)
- `PROJECT` - Project name used in resource naming (e.g., "ecare")

**Usage:**

```bash
#!/bin/bash
set -euo pipefail

# Source shared functions (which automatically sources globals.sh)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

# Use global constants
echo "Organization: $ORGANIZATION"
echo "Project: $PROJECT"

# Use in resource naming
RESOURCE_GROUP="rg-${PROJECT}-dev"
```

**Note:** The `globals.sh` file is automatically sourced by `common.sh` in infra-foundation. Other components should source it explicitly if needed.

## Version History

### 1.0.0 (2024-12-30)

- Initial release
- Extracted common functions from infra-foundation and infra-identity
- Added comprehensive documentation
- Categories: Output, Command Checks, Azure CLI, Environment, Git

## Contributing

When adding new shared functions:

1. Add the function to `common.sh`
2. Document it in this README
3. Update version number in `common.sh`
4. Update version history
5. Test in all affected repositories

## Support

For issues or questions about shared scripts, see:

- Main README: `../../README.md`
- Foundation docs: `../../infra-foundation/docs/`
- Identity docs: `../../infra-identity/docs/`

