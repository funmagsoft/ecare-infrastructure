# Shared Scripts Library

Common shell functions used across all infrastructure repositories in the ecare-infrastructure monorepo.

## Purpose

This library eliminates code duplication by providing a single source of truth for common shell functions used in:

- `foundation/scripts/` - Foundation infrastructure scripts
- `workload/scripts/` - Identity infrastructure scripts
- `platform/scripts/` - Platform infrastructure scripts

## Files

### `common.sh`

Core helper functions for shell scripts.

**Categories:**

- **Logging Functions**: `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_dry_run()`,
  `log_dry_run_complete()`
- **Command Checks**: `check_command()`, `check_required_commands()`
- **Azure CLI Helpers**: `check_azure_login()`, `get_subscription_id()`, `get_tenant_id()`, `check_resource_exists()`
- **Environment Helpers**: `validate_environment()`, `load_env_file()`, `load_dotenv()`, `get_project_root()`
- **Dry-Run Helpers**: `parse_dry_run()`, `run_cmd()`, `run_cmd_capture()`, `write_file()`, `clear_file()`
- **Script Initialization**: `init_script()`, `init_script_minimal()`
- **Directory Helpers**: `get_script_dir()`, `get_base_dir()`
- **Git Helpers**: `validate_conventional_commit()`

### `globals.sh`

Global project configuration constants shared across all infrastructure components.

**Contents:**

- Organization and project names
- Deployment IDs per environment (for resource tagging and cleanup)

### `cleanup-by-deployment-id.sh`

Cleanup script for removing all resources tagged with a specific deployment ID.

**Purpose:** Delete all Azure and Entra ID resources associated with a deployment

**Usage:**

```bash
# Dry run (preview only) - default behavior
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4

# Actually delete resources
./shared/scripts/cleanup-by-deployment-id.sh a1b2c3d4 --execute
```

**Options:**

- `--dry-run` - Preview changes without executing them (default)
- `--execute` - Actually delete resources

### `validate-commit-msg.sh`

Validates commit messages against Conventional Commits format.

**Purpose:** Ensure all commits follow the project's commit message standards

**Used by:** Pre-commit hooks (`.pre-commit-config.yaml`)

**Format required:**

```text
<type>[optional scope]: <description>
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`

**Examples:**

- ✅ `feat: add new feature`
- ✅ `fix(github-oidc): fix tags handling`
- ✅ `docs: update README`
- ❌ `Add new feature` (missing type)
- ❌ `feat add feature` (missing colon)

**Usage:**

```bash
# Automatically called by pre-commit hook
# Manual validation:
./shared/scripts/validate-commit-msg.sh <commit-message-file>
```

## Usage

### Basic Usage

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared functions
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

# Use functions
log_info "My Script"
check_command az || exit 1
check_azure_login || exit 1
validate_environment "${ENV}" || exit 1

log_success "Script completed successfully!"
```

### Example: Foundation Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# foundation/scripts/setup-phase0.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

log_info "Phase 0 Infrastructure Setup"

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
#!/usr/bin/env bash
set -euo pipefail

# workload/scripts/add-service.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

log_info "Add New Service"

# Use shared functions
check_required_commands terraform || exit 1
validate_conventional_commit "feat(identity): add new service" || exit 1

# ... rest of script
```

## Function Reference

### Logging Functions

#### `log_success <message>`

Prints a success message with checkmark.

```bash
log_success "Resource created successfully"
# Output: ✓ Resource created successfully
```

#### `log_error <message>`

Prints an error message with cross (to stderr).

```bash
log_error "Failed to create resource"
# Output: ✗ Failed to create resource
```

#### `log_warning <message>`

Prints a warning message with warning symbol.

```bash
log_warning "Resource already exists"
# Output: ⚠ Resource already exists
```

#### `log_info <message>`

Prints an informational message.

```bash
log_info "Loading configuration"
# Output: ℹ Loading configuration
```

#### `log_dry_run`

Prints a dry-run header when DRY_RUN is true.

```bash
log_dry_run
```

#### `log_dry_run_complete`

Prints a dry-run completion message when DRY_RUN is true.

```bash
log_dry_run_complete
```

### Command Checks

#### `check_command <command>`

Checks if a command exists. Returns 0 if exists, 1 if not.

```bash
if check_command az; then
  log_success "Azure CLI found"
else
  log_error "Azure CLI not found"
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

#### `check_azure_cli`

Checks that Azure CLI is installed and authenticated.

```bash
check_azure_cli || exit 1
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
  log_success "Resource Group exists"
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

#### `load_dotenv`

Loads `.env` from the repository root and exports variables.

```bash
load_dotenv
```

#### `get_project_root`

Returns the absolute path to the monorepo root.

```bash
PROJECT_ROOT=$(get_project_root)
echo "Project root: $PROJECT_ROOT"
```

### Dry-Run Helpers

#### `parse_dry_run [args]`

Parses `--dry-run` and `--execute` flags and sets `DRY_RUN` accordingly.

```bash
DRY_RUN=true
parse_dry_run "$@"
```

#### `run_cmd <command> [args...]`

Runs a command or echoes it when `DRY_RUN` is true.

```bash
run_cmd az group list
```

#### `run_cmd_capture <command> [args...]`

Runs a command with output capture or prints a dry-run message.

```bash
run_cmd_capture az account show
```

#### `write_file <file> <content>`

Appends content to a file or prints a dry-run message.

```bash
write_file ".env" "SUBSCRIPTION_ID=..."
```

#### `clear_file <file>`

Truncates a file or prints a dry-run message.

```bash
clear_file ".env"
```

### Script Initialization

#### `init_script [args]`

Loads `.env`, parses dry-run flags, validates required variables, and sets the Azure subscription.

```bash
init_script "$@"
```

#### `init_script_minimal [args]`

Loads `.env`, parses dry-run flags, validates minimal variables, and sets the Azure subscription.

```bash
init_script_minimal "$@"
```

### Directory Helpers

#### `get_script_dir`

Returns the directory of the calling script.

```bash
SCRIPT_DIR=$(get_script_dir)
```

#### `get_base_dir <script_dir>`

Returns the monorepo base directory relative to a script directory.

```bash
BASE_DIR=$(get_base_dir "$SCRIPT_DIR")
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
- `DEPLOYMENT_IDS` - Associative array mapping environment names to deployment IDs

**Deployment IDs:**

Each environment has a unique 8-character deployment identifier used for resource tagging and cleanup:

- `dev`: `a1b2c3d4`
- `test`: `e5f6g7h8`
- `stage`: `i9j0k1l2`
- `prod`: `m3n4o5p6`

**Usage:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared functions (which automatically sources globals.sh)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/shared/scripts/common.sh"

# Use global constants
echo "Organization: $ORGANIZATION"
echo "Project: $PROJECT"

# Use deployment ID for environment
ENV="dev"
DEPLOYMENT_ID="${DEPLOYMENT_IDS[$ENV]}"
echo "Deployment ID for $ENV: $DEPLOYMENT_ID"

# Use in resource naming
RESOURCE_GROUP="rg-${PROJECT}-dev"
```

**Note:** The `globals.sh` file is automatically sourced by `common.sh` in foundation. Other components should source it explicitly if needed.

## Version History

### 1.0.0 (2024-12-30)

- Initial release
- Extracted common functions from foundation and workload
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
- Foundation docs: `../../foundation/docs/`
- Identity docs: `../../workload/docs/`
