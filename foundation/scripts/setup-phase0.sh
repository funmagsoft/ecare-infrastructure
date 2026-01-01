#!/usr/bin/env bash
# =============================================================================
# Script: setup-phase0.sh
# Component: foundation
# Purpose: Orchestrate Phase 0 setup (resource groups, state storage, user access).
# =============================================================================
# Usage:
#   ./setup-phase0.sh [--dry-run|--execute] [-h|--help]
# =============================================================================

set -Eeuo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/common.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/shared/scripts/globals.sh"


setup_traps
usage() {
  cat <<'EOF'
Usage: ./setup-phase0.sh [--dry-run|--execute] [-h|--help]
       ./setup-phase0.sh [--dry-run|--execute] [--env <env>] [--all-envs] [-h|--help]

Run the Phase 0 setup sequence for foundation:
  1) setup-rg.sh
  2) setup-state-storage.sh
  3) setup-access-user.sh

Options:
  --dry-run     Print planned actions without executing (propagated to child scripts)
  --execute     Execute actions (default)
  --env <env>   Target a single environment (repeatable): dev|test|stage|prod
  --all-envs    Target all environments (default)
  -h, --help    Show this help and exit

EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --dry-run|--execute|--env|--environment|--all-envs) : ;;
    *) usage; exit 1 ;;
  esac
done

# Initialize script (parse args, validate env vars, set subscription)
# Note: setup-phase0 propagates --dry-run to child scripts.
init_script "$@"

parse_env_args "$@"
check_required_commands az
az_require_login

log_info "=== Phase 0 Infrastructure Setup ==="
log_dry_run
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Environments: $(envs_to_string)"
echo ""

TOTAL_ERRORS=0
FAILED_SETUPS=()

# Define setup scripts in order (dependencies must be created first)
# Note: Service Principals, FIC, and RBAC for GitHub Actions are now created by
# Terraform bootstrap module (not by setup scripts).
#
# This setup creates Phase 0 infrastructure (prerequisites for Terraform):
# - Resource Groups (rg-<project>-<env>)
# - Storage Accounts for Terraform state (tfstate<org><project><env>)
# - Current user access to state storage (Storage Blob Data Contributor)
SETUP_SCRIPTS=(
  "setup-rg.sh"
  "setup-state-storage.sh"
  "setup-access-user.sh"
)

# Run each setup script
for setup_script in "${SETUP_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${setup_script}"

  if [ ! -f "$script_path" ]; then
    log_error "Setup script not found: $script_path"
    FAILED_SETUPS+=("$setup_script (not found)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    continue
  fi

  echo ""
  log_info "================================================================================"
  log_info "Running: $setup_script"
  log_info "================================================================================"
  echo ""

  # Run the setup script and pass through common flags (--dry-run/--execute, --env/--all-envs)
  if bash "$script_path" "$@"; then
    log_success "$setup_script completed successfully"
  else
    exit_code=$?
    log_error "$setup_script failed with exit code: $exit_code"
    FAILED_SETUPS+=("$setup_script (exit code: $exit_code)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
  fi

  echo ""
done

# Final Summary
echo ""
log_info "================================================================================"
log_info "=== Setup Summary ==="
log_info "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All setup scripts completed successfully!"
  echo ""
  log_info "Created Phase 0 components:"
  log_success "Resource Groups ($(envs_to_string))"
  log_success "Storage Accounts for Terraform state (with versioning and soft delete)"
  log_success "Current user access to state storage (Storage Blob Data Contributor)"
  echo ""
  log_info "Note: Service Principals, FIC, and RBAC for GitHub Actions are created"
  log_info "      by Terraform bootstrap module (not by these scripts)."
  echo ""
  if [ "$DRY_RUN" != true ]; then
    log_info "Next steps:"
    log_info "  1. Verify Phase 0 setup: ./verify-phase0.sh"
    log_info "  2. Deploy Terraform bootstrap: cd foundation/terraform/environments/<env> && terraform init && terraform apply"
    log_info "  3. Configure GitHub Secrets (see documentation)"
    log_info "  4. Proceed with subsequent phases (platform/workload)"
  fi
  exit 0
else
  log_error "Setup completed with $TOTAL_ERRORS error(s)"
  echo ""
  log_error "Failed setups:"
  for failed in "${FAILED_SETUPS[@]}"; do
    log_error "$failed"
  done
  echo ""
  log_info "Please review the output above and fix the issues before proceeding."
  exit 1
fi
