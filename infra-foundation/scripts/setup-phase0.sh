#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: setup-all supports --dry-run and passes it to all setup scripts
init_script "$@"

echo "=== Complete Infrastructure Setup ==="
log_dry_run
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
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
  echo "================================================================================"
  echo "Running: $setup_script"
  echo "================================================================================"
  echo ""

  # Run the setup script and pass through --dry-run if set
  if [ "$DRY_RUN" = true ]; then
    if bash "$script_path" --dry-run; then
      log_success "$setup_script completed successfully"
    else
      exit_code=$?
      log_error "$setup_script failed with exit code: $exit_code"
      FAILED_SETUPS+=("$setup_script (exit code: $exit_code)")
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
  else
    if bash "$script_path"; then
      log_success "$setup_script completed successfully"
    else
      exit_code=$?
      log_error "$setup_script failed with exit code: $exit_code"
      FAILED_SETUPS+=("$setup_script (exit code: $exit_code)")
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
  fi

  echo ""
done

# Final Summary
echo ""
echo "================================================================================"
echo "=== Complete Setup Summary ==="
echo "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All setup scripts completed successfully!"
  echo ""
  echo "Created Phase 0 components:"
  echo "  ✓ Resource Groups (dev, test, stage, prod)"
  echo "  ✓ Storage Accounts for Terraform state (with versioning and soft delete)"
  echo "  ✓ Current user access to state storage (Storage Blob Data Contributor)"
  echo ""
  echo "Note: Service Principals, FIC, and RBAC for GitHub Actions are created"
  echo "      by Terraform bootstrap module (not by these scripts)."
  echo ""
  if [ "$DRY_RUN" != true ]; then
    echo "Next steps:"
    echo "  1. Verify Phase 0 setup: ./scripts/verify-phase0.sh"
    echo "  2. Deploy Terraform bootstrap: cd terraform/environments/dev && terraform apply"
    echo "  3. Verify complete setup: ./scripts/verify-all.sh"
    echo "  4. Configure GitHub Secrets (see documentation)"
    echo "  5. Proceed with Phase 1 deployment (network, VPN, etc.)"
  fi
  exit 0
else
  log_error "Setup completed with $TOTAL_ERRORS error(s)"
  echo ""
  echo "Failed setups:"
  for failed in "${FAILED_SETUPS[@]}"; do
    echo "  ✗ $failed" >&2
  done
  echo ""
  echo "Please review the output above and fix the issues before proceeding."
  exit 1
fi
