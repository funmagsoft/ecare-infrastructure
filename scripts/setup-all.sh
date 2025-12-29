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
# Note: setup-access.sh, setup-access-sp.sh, and setup-access-user.sh are now replaced
# by Terraform bootstrap module. They are kept for backward compatibility but should
# not be used in new deployments.
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
  echo "Created components:"
  echo "  ✓ Resource Groups (all environments)"
  echo "  ✓ Storage Accounts and containers (with versioning and soft delete)"
  echo ""
  echo "Note: Service Principals, FIC, RBAC for GitHub Actions, and user access"
  echo "      are now created by Terraform bootstrap module. Run Terraform to create them:"
  echo "      cd terraform/environments/dev && terraform init && terraform apply"
  echo ""
  echo "      To grant users access to state files, configure users_with_state_access"
  echo "      in terraform.tfvars with user Object IDs."
  echo ""
  if [ "$DRY_RUN" != true ]; then
    echo "Next steps:"
    echo "  1. Verify setup with: ./verify-all.sh"
    echo "  2. Deploy bootstrap with Terraform: cd terraform/environments/dev && terraform apply"
    echo "  3. Configure GitHub Secrets (see documentation)"
    echo "  4. Proceed with Phase 1 deployment"
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
