#!/usr/bin/env bash
# =============================================================================
# Script: verify-phase0.sh
# Component: infra-foundation
# Purpose: Run Phase 0 verification checks (resource groups, state storage, user access).
# =============================================================================
# Usage:
#   ./verify-phase0.sh [-h|--help]
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
Usage: ./verify-phase0.sh [-h|--help]

Run Phase 0 verification checks (resource groups, state storage, user access).

Options:
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).

EOF
}

if [ $# -gt 0 ]; then
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

# Verify scripts do not modify resources; dry-run is not applicable.
DRY_RUN=false
init_script

log_info "=== Phase 0 Infrastructure Verification ==="
log_info "This script verifies Phase 0 setup (created by setup-phase0.sh):"
log_info "  - Resource Groups"
log_info "  - Storage Accounts for Terraform state"
log_info "  - Current user access to state storage"
echo ""
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
FAILED_VERIFICATIONS=()

# Define verification scripts for Phase 0 only
# These correspond to setup scripts: setup-rg.sh, setup-state-storage.sh, setup-access-user.sh
VERIFY_SCRIPTS=(
  "verify-rg.sh"
  "verify-state-storage.sh"
  "verify-access-user.sh"
)

# Run each verification script
for verify_script in "${VERIFY_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${verify_script}"

  if [ ! -f "$script_path" ]; then
    log_error "Verification script not found: $script_path"
    FAILED_VERIFICATIONS+=("$verify_script (not found)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    continue
  fi

  echo ""
  log_info "================================================================================"
  log_info "Running: $verify_script"
  log_info "================================================================================"
  echo ""

  # Run the verification script and capture exit code
  if bash "$script_path"; then
    log_success "$verify_script completed successfully"
  else
    exit_code=$?
    log_error "$verify_script failed with exit code: $exit_code"
    FAILED_VERIFICATIONS+=("$verify_script (exit code: $exit_code)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
  fi

  echo ""
done

# Final Summary
echo ""
log_info "================================================================================"
log_info "=== Phase 0 Verification Summary ==="
log_info "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All Phase 0 verifications passed!"
  echo ""
  log_info "Verified Phase 0 components:"
  log_success "Resource Groups (dev, test, stage, prod)"
  log_success "Storage Accounts for Terraform state (with versioning and soft delete)"
  log_success "Current user access (Storage Blob Data Contributor)"
  echo ""
  log_info "Next step: Deploy Terraform bootstrap to create Service Principals and GitHub OIDC"
  log_info "  cd terraform/environments/dev && terraform init && terraform apply"
  echo ""
  exit 0
else
  log_error "Phase 0 verification completed with $TOTAL_ERRORS error(s)"
  echo ""
  log_error "Failed verifications:"
  for failed in "${FAILED_VERIFICATIONS[@]}"; do
    log_error "$failed"
  done
  echo ""
  log_info "Please review the output above and fix the issues before proceeding."
  exit 1
fi
