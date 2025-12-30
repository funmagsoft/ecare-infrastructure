#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Complete Infrastructure Verification ==="
echo "This script verifies ALL infrastructure layers:"
echo "  Layer 1 (Phase 0): Resource Groups, Storage Accounts, User Access"
echo "  Layer 2 (Terraform Bootstrap): Service Principals, FIC, RBAC for GitHub Actions"
echo "  Layer 3 (Terraform Environment): VNet, Subnets, NSG, VPN"
echo ""
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
FAILED_VERIFICATIONS=()

# ============================================================================
# Layer 1: Phase 0 Verification
# ============================================================================
echo "================================================================================"
echo "Layer 1: Phase 0 Infrastructure"
echo "================================================================================"
echo ""

if bash "${SCRIPT_DIR}/verify-phase0.sh"; then
  log_success "Phase 0 verification completed successfully"
else
  exit_code=$?
  log_error "Phase 0 verification failed with exit code: $exit_code"
  FAILED_VERIFICATIONS+=("verify-phase0.sh (exit code: $exit_code)")
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

echo ""

# ============================================================================
# Layer 2: Terraform Bootstrap Verification
# ============================================================================
echo "================================================================================"
echo "Layer 2: Terraform Bootstrap Module"
echo "================================================================================"
echo ""

if bash "${SCRIPT_DIR}/verify-terraform-bootstrap.sh"; then
  log_success "Terraform Bootstrap verification completed successfully"
else
  exit_code=$?
  log_error "Terraform Bootstrap verification failed with exit code: $exit_code"
  FAILED_VERIFICATIONS+=("verify-terraform-bootstrap.sh (exit code: $exit_code)")
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

echo ""

# ============================================================================
# Layer 3: Terraform Environment Verification
# ============================================================================
echo "================================================================================"
echo "Layer 3: Terraform Environment Module"
echo "================================================================================"
echo ""

if bash "${SCRIPT_DIR}/verify-terraform-environment.sh"; then
  log_success "Terraform Environment verification completed successfully"
else
  exit_code=$?
  log_error "Terraform Environment verification failed with exit code: $exit_code"
  FAILED_VERIFICATIONS+=("verify-terraform-environment.sh (exit code: $exit_code)")
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi

echo ""

# ============================================================================
# Final Summary
# ============================================================================
echo "================================================================================"
echo "=== Complete Verification Summary ==="
echo "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All infrastructure verifications passed!"
  echo ""
  echo "✓ Layer 1 - Phase 0 Infrastructure:"
  echo "    - Resource Groups (dev, test, stage, prod)"
  echo "    - Storage Accounts for Terraform state (with versioning and soft delete)"
  echo "    - Current user access (Storage Blob Data Contributor)"
  echo ""
  echo "✓ Layer 2 - Terraform Bootstrap:"
  echo "    - Service Principals for GitHub Actions (4 environments)"
  echo "    - Federated Identity Credentials (12 total: 3 repos × 4 environments)"
  echo "    - RBAC roles (Contributor, User Access Administrator, Storage Blob Data Contributor)"
  echo ""
  echo "✓ Layer 3 - Terraform Environment:"
  echo "    - Virtual Networks with subnets (aks, data, mgmt, gateway)"
  echo "    - Network Security Groups (aks, data, mgmt)"
  echo "    - VPN Gateway (if enabled)"
  echo "    - Route Tables"
  echo ""
  log_info "Infrastructure is healthy and ready for use."
  exit 0
else
  log_error "Verification completed with $TOTAL_ERRORS error(s)"
  echo ""
  echo "Failed verifications:"
  for failed in "${FAILED_VERIFICATIONS[@]}"; do
    echo "  ✗ $failed" >&2
  done
  echo ""
  log_warning "Please review the output above and fix the issues."
  echo ""
  log_info "Troubleshooting hints:"
  echo "  - If Phase 0 failed: Run ./scripts/setup-phase0.sh"
  echo "  - If Bootstrap failed: Run terraform apply (bootstrap module)"
  echo "  - If Environment failed: Run terraform apply (environment module)"
  echo "  - For detailed help: See RUNBOOK.md"
  exit 1
fi
