#!/usr/bin/env bash
# =============================================================================
# Script: verify-all.sh
# Component: infra-foundation
# Purpose: Run complete infra-foundation verification checks (Phase 0 + Terraform modules).
# =============================================================================
# Usage:
#   ./verify-all.sh [-h|--help]
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
Usage: ./verify-all.sh [-h|--help]

Run complete infra-foundation verification checks (Phase 0 + Terraform modules).

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

log_info "=== Complete Infrastructure Verification ==="
log_info "This script verifies ALL infrastructure layers:"
log_info "  Layer 1 (Phase 0): Resource Groups, Storage Accounts, User Access"
log_info "  Layer 2 (Terraform Bootstrap): Service Principals, FIC, RBAC for GitHub Actions"
log_info "  Layer 3 (Terraform Environment): VNet, Subnets, NSG, VPN"
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
log_info "================================================================================"
log_info "Layer 1: Phase 0 Infrastructure"
log_info "================================================================================"
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
log_info "================================================================================"
log_info "Layer 2: Terraform Bootstrap Module"
log_info "================================================================================"
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
log_info "================================================================================"
log_info "Layer 3: Terraform Environment Module"
log_info "================================================================================"
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
log_info "================================================================================"
log_info "=== Complete Verification Summary ==="
log_info "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All infrastructure verifications passed!"
  echo ""
  log_info "✓ Layer 1 - Phase 0 Infrastructure:"
  log_info "    - Resource Groups (dev, test, stage, prod)"
  log_info "    - Storage Accounts for Terraform state (with versioning and soft delete)"
  log_info "    - Current user access (Storage Blob Data Contributor)"
  echo ""
  log_info "✓ Layer 2 - Terraform Bootstrap:"
  log_info "    - Service Principals for GitHub Actions (4 environments)"
  log_info "    - Federated Identity Credentials (12 total: 3 repos × 4 environments)"
  log_info "    - RBAC roles (Contributor, User Access Administrator, Storage Blob Data Contributor)"
  echo ""
  log_info "✓ Layer 3 - Terraform Environment:"
  log_info "    - Virtual Networks with subnets (aks, data, mgmt, gateway)"
  log_info "    - Network Security Groups (aks, data, mgmt)"
  log_info "    - VPN Gateway (if enabled)"
  log_info "    - Route Tables"
  echo ""
  log_info "Infrastructure is healthy and ready for use."
  exit 0
else
  log_error "Verification completed with $TOTAL_ERRORS error(s)"
  echo ""
  log_info "Failed verifications:"
  for failed in "${FAILED_VERIFICATIONS[@]}"; do
    log_error "$failed"
  done
  echo ""
  log_warning "Please review the output above and fix the issues."
  echo ""
  log_info "Troubleshooting hints:"
  log_info "  - If Phase 0 failed: Run ./scripts/setup-phase0.sh"
  log_info "  - If Bootstrap failed: Run terraform apply (bootstrap module)"
  log_info "  - If Environment failed: Run terraform apply (environment module)"
  log_info "  - For detailed help: See RUNBOOK.md"
  exit 1
fi
