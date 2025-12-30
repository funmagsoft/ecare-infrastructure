#!/bin/bash
# Common functions and utilities for phase0 scripts

# ============================================================================
# Load global project configuration
# ============================================================================
# Load project constants from globals.sh (ORGANIZATION, ORGANIZATION_FOR_SA, PROJECT)
# These are project-specific and should not change per deployment
if [ -f "$(dirname "${BASH_SOURCE[0]}")/globals.sh" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/globals.sh"
fi

# ============================================================================
# Load environment-specific configuration from .env
# ============================================================================
load_dotenv() {
  # Find .env file in the repository root (infra-foundation directory)
  # SCRIPT_DIR should be set by the calling script before sourcing common.sh
  local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

  # Go up two levels from scripts/ to repo root
  local repo_root="$(cd "$script_dir/../.." && pwd)"
  local env_file="$repo_root/.env"

  if [ -f "$env_file" ]; then
    # Load .env file (skip comments and empty lines, handle both with and without export)
    set -a
    # Remove comments, empty lines, and optional 'export' keyword
    source <(grep -v '^#' "$env_file" | grep -v '^$' | sed -E 's/^export[[:space:]]+//')
    set +a
    return 0
  else
    return 1
  fi
}

# ============================================================================
# Command line argument parsing
# ============================================================================
parse_dry_run() {
  DRY_RUN=false
  for arg in "$@"; do
    case $arg in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        echo "Unknown option: $arg" >&2
        echo "Usage: $0 [--dry-run]" >&2
        exit 1
        ;;
    esac
  done
}

# ============================================================================
# Dry-run helper functions
# ============================================================================
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*" >&2
  else
    "$@"
  fi
}

run_cmd_capture() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*" >&2
    echo "[DRY-RUN] Output would be captured" >&2
  else
    "$@"
  fi
}

write_file() {
  local file="$1"
  local content="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] echo \"$content\" >> \"$file\"" >&2
  else
    echo "$content" >> "$file"
  fi
}

clear_file() {
  local file="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] > \"$file\"" >&2
  else
    > "$file"
  fi
}

# ============================================================================
# Environment variable validation
# ============================================================================
validate_env_vars() {
  local missing_vars=()

  # Environment-specific variables (loaded from .env)
  if [ -z "$TENANT_ID" ]; then
    missing_vars+=("TENANT_ID")
  fi

  if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_vars+=("SUBSCRIPTION_ID")
  fi

  if [ -z "$LOCATION" ]; then
    missing_vars+=("LOCATION")
  fi

  # Project constants (loaded from globals.sh)
  if [ -z "$ORGANIZATION" ]; then
    missing_vars+=("ORGANIZATION")
  fi

  if [ -z "$ORGANIZATION_FOR_SA" ]; then
    missing_vars+=("ORGANIZATION_FOR_SA")
  fi

  if [ -z "$PROJECT" ]; then
    missing_vars+=("PROJECT")
  fi

  if [ ${#missing_vars[@]} -ne 0 ]; then
    log_error "The following required variables are not set:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    echo "" >&2

    # Check which variables are environment-specific vs project constants
    local env_vars=()
    local project_vars=()

    for var in "${missing_vars[@]}"; do
      case $var in
        TENANT_ID|SUBSCRIPTION_ID|LOCATION)
          env_vars+=("$var")
          ;;
        ORGANIZATION|ORGANIZATION_FOR_SA|PROJECT)
          project_vars+=("$var")
          ;;
      esac
    done

    if [ ${#env_vars[@]} -ne 0 ]; then
      echo "Environment variables (should be in .env file):" >&2
      for var in "${env_vars[@]}"; do
        echo "  $var=\"<your-$var>\"" >&2
      done
      echo "" >&2
      echo "Please add them to .env file in the repository root." >&2
    fi

    if [ ${#project_vars[@]} -ne 0 ]; then
      echo "Project constants (should be in scripts/globals.sh):" >&2
      for var in "${project_vars[@]}"; do
        echo "  $var=\"<your-$var>\"" >&2
      done
      echo "" >&2
      echo "Please add them to scripts/globals.sh file." >&2
    fi

    exit 1
  fi
}

validate_minimal_env_vars() {
  local missing_vars=()

  # Environment-specific variables (loaded from .env)
  if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_vars+=("SUBSCRIPTION_ID")
  fi

  # Project constants (loaded from globals.sh)
  if [ -z "$PROJECT" ]; then
    missing_vars+=("PROJECT")
  fi

  if [ ${#missing_vars[@]} -ne 0 ]; then
    log_error "The following required variables are not set:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    echo "" >&2

    if [[ " ${missing_vars[@]} " =~ " SUBSCRIPTION_ID " ]]; then
      echo "Environment variable (should be in .env file):" >&2
      echo "  SUBSCRIPTION_ID=\"<your-subscription-id>\"" >&2
      echo "" >&2
      echo "Please add it to .env file in the repository root." >&2
    fi

    if [[ " ${missing_vars[@]} " =~ " PROJECT " ]]; then
      echo "Project constant (should be in scripts/globals.sh):" >&2
      echo "  PROJECT=\"<your-project>\"" >&2
      echo "" >&2
      echo "Please add it to scripts/globals.sh file." >&2
    fi

    exit 1
  fi
}

# ============================================================================
# Error handling and logging
# ============================================================================
log_error() {
  echo "Error: $*" >&2
}

log_warning() {
  echo "Warning: $*" >&2
}

log_info() {
  echo "$*"
}

log_success() {
  echo "✓ $*"
}

log_dry_run() {
  if [ "$DRY_RUN" = true ]; then
    echo "*** DRY-RUN MODE: No changes will be made ***"
  fi
}

log_dry_run_complete() {
  if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "*** DRY-RUN MODE: No changes were made ***"
  fi
}

# ============================================================================
# Script initialization
# ============================================================================
init_script() {
  # Load environment-specific variables from .env
  load_dotenv

  # Parse dry-run argument
  parse_dry_run "$@"

  # Only set -e if not in dry-run mode
  if [ "$DRY_RUN" != true ]; then
    set -e
  fi

  # Validate environment variables
  validate_env_vars

  # Set active subscription
  run_cmd az account set --subscription "$SUBSCRIPTION_ID"
}

init_script_minimal() {
  # Load environment-specific variables from .env
  load_dotenv

  # Parse dry-run argument
  parse_dry_run "$@"

  # Only set -e if not in dry-run mode
  if [ "$DRY_RUN" != true ]; then
    set -e
  fi

  # Validate minimal environment variables
  validate_minimal_env_vars

  # Set active subscription
  run_cmd az account set --subscription "$SUBSCRIPTION_ID"
}

# ============================================================================
# Directory helpers
# ============================================================================
get_script_dir() {
  # This should be called from the script itself, not from common.sh
  # Usage: SCRIPT_DIR=$(get_script_dir)
  local script_path="${BASH_SOURCE[1]}"
  if [ -n "$script_path" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
  else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  echo "$SCRIPT_DIR"
}

get_base_dir() {
  local script_dir="$1"
  BASE_DIR="$(cd "$script_dir/../.." && pwd)"
  echo "$BASE_DIR"
}

# ============================================================================
# Environment file loading
# ============================================================================
load_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    # Use set -a to automatically export all variables
    set -a
    # Remove comments, empty lines, and optional 'export' keyword
    source <(grep -v '^#' "$env_file" | grep -v '^$' | sed -E 's/^export[[:space:]]+//')
    set +a
    return 0
  else
    return 1
  fi
}
