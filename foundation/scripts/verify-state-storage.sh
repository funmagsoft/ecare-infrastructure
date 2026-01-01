#!/usr/bin/env bash
# =============================================================================
# Script: verify-state-storage.sh
# Component: foundation
# Purpose: Verify Terraform state Storage Accounts and containers exist and are configured.
# =============================================================================
# Usage:
#   ./verify-state-storage.sh [--env <env>] [--all-envs] [-h|--help]
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
Usage: ./verify-state-storage.sh [--env <env>] [--all-envs] [-h|--help]

Verify Terraform state Storage Accounts and containers exist and are configured.

Options:
  --env <env>   Target a single environment (repeatable): dev|test|stage|prod
  --all-envs    Target all environments (default)
  -h, --help    Show this help and exit

Notes:
  - Requires Azure CLI (az) and an active login (az login).
  - Uses Azure AD auth ("--auth-mode login") for container checks.

EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --env|--environment|--all-envs) : ;;
    *) usage; exit 1 ;;
  esac
done

# Verify scripts do not modify resources; dry-run is not applicable.
DRY_RUN=false
init_script

parse_env_args "$@"
check_required_commands az jq
az_require_login

log_info "=== Terraform State Storage Verification ==="
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location:     $LOCATION"
log_info "Environments: $(envs_to_string)"
echo ""

ERRORS=0
VERIFIED=0

for ENV in "${TARGET_ENVS[@]}"; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  log_info "=== Verifying ${SA_NAME} (${ENV}) ==="

  # Storage Account exists
  if az_call storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name, Kind:kind}" \
    --output json >/dev/null 2>&1; then
    log_success "Storage Account exists"
  else
    log_error "Storage Account missing or not accessible"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # Container exists
  if az_call storage container show \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --query "{Name:name, PublicAccess:properties.publicAccess}" \
    --output json >/dev/null 2>&1; then
    log_success "Container 'tfstate' exists"
  else
    log_error "Container 'tfstate' missing"
    ERRORS=$((ERRORS + 1))
  fi

  # Versioning enabled
  VERSIONING="$(az_call storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "isVersioningEnabled" \
    --output tsv 2>/dev/null || echo "")"

  if [[ "$VERSIONING" == "true" ]]; then
    log_success "Blob versioning enabled"
  else
    log_error "Blob versioning not enabled"
    ERRORS=$((ERRORS + 1))
  fi

  # Soft delete enabled
  SOFT_DELETE="$(az_call storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "deleteRetentionPolicy.enabled" \
    --output tsv 2>/dev/null || echo "")"

  if [[ "$SOFT_DELETE" == "true" ]]; then
    log_success "Soft delete enabled"
  else
    log_error "Soft delete not enabled"
    ERRORS=$((ERRORS + 1))
  fi

  # Tag sanity (best-effort; warnings only to avoid breaking existing state backends)
  TAGS="$(az_call storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "tags" \
    --output json 2>/dev/null || echo "")"

  if [[ -n "$TAGS" && "$TAGS" != "null" ]]; then
    MANAGED_BY_TAG="$(echo "$TAGS" | jq -r '.ManagedBy // "missing"')"
    PHASE_TAG="$(echo "$TAGS" | jq -r '.Phase // "missing"')"
    PURPOSE_TAG="$(echo "$TAGS" | jq -r '.Purpose // "missing"')"

    case "$MANAGED_BY_TAG" in
      Terraform|terraform|Bootstrap|bootstrap)
        log_success "Tag ManagedBy: $MANAGED_BY_TAG"
        ;;
      *)
        log_warning "Tag ManagedBy: $MANAGED_BY_TAG (expected: Terraform|Bootstrap)"
        ;;
    esac

    if [[ "$PHASE_TAG" == "Foundation" ]]; then
      log_success "Tag Phase: $PHASE_TAG"
    else
      log_warning "Tag Phase: $PHASE_TAG (expected: Foundation)"
    fi

    if [[ "$PURPOSE_TAG" == "terraform-state" ]]; then
      log_success "Tag Purpose: $PURPOSE_TAG"
    else
      log_warning "Tag Purpose: $PURPOSE_TAG (expected: terraform-state)"
    fi
  else
    log_warning "No tags found on Storage Account"
  fi

  VERIFIED=$((VERIFIED + 1))
  echo ""
done

log_info "=== Verification Summary ==="
log_info "Storage Accounts verified: ${VERIFIED}/${#TARGET_ENVS[@]}"

if [[ $ERRORS -eq 0 ]]; then
  log_success "All verifications passed!"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s)"
  exit 1
fi
