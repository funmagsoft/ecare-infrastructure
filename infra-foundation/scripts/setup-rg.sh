#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
init_script "$@"

echo "=== Creating Resource Groups ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Location: $LOCATION"
echo ""

ERRORS=0
CREATED=0

# Create Resource Groups for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"

  echo "--- Creating Resource Group for ${ENV} environment ---"
  echo "Resource Group: $RG_NAME"
  echo "Location: $LOCATION"

  # Check if Resource Group already exists
  if [ "$DRY_RUN" != true ]; then
    if az group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_warning "Resource Group $RG_NAME already exists, skipping..."
      CREATED=$((CREATED + 1))
      echo ""
      continue
    fi
  fi

  # Create Resource Group
  echo "Creating Resource Group..."
  if run_cmd az group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --tags \
      Environment="${ENV}" \
      Project="${PROJECT}" \
      ManagedBy="terraform" \
      CreatedDate="$(date +%Y-%m-%d)" \
    --output none; then
    log_success "Resource Group ${RG_NAME} created successfully"
    CREATED=$((CREATED + 1))
  else
    log_error "Failed to create Resource Group ${RG_NAME}"
    ERRORS=$((ERRORS + 1))
  fi

  echo ""
done

# Summary
echo "=== Resource Group Creation Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would create Resource Groups: 4 (one per environment)"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Resource Groups created/verified: ${CREATED}/4"
  else
    log_error "Resource Group creation completed with ${ERRORS} error(s)"
    log_warning "Only ${CREATED}/4 Resource Groups were created/verified"
    exit 1
  fi
fi

echo ""
log_info "Resource Groups are ready for use."
