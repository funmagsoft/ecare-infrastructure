#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script with minimal validation (parse args, validate minimal env vars, set subscription)
init_script_minimal "$@"

echo "=== Recovering Service Principal IDs from Azure ==="
log_dry_run
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Project: $PROJECT"
echo ""

# Initialize service-principals.env file
SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"

# Add header comment to the file (only in non-dry-run mode)
if [ "$DRY_RUN" != true ]; then
  cat > "$SP_IDS_FILE" <<EOF
# Service Principal IDs for GitHub Actions
# Recovered from Azure by recover-sp-ids.sh - DO NOT EDIT MANUALLY
# Format: KEY=value (standard .env format)

EOF
else
  log_info "[DRY-RUN] Would create/overwrite: ${SP_IDS_FILE}"
fi

ERRORS=0
RECOVERED=0

# Recover Service Principal IDs for each environment
for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  OBJECT_ID_VAR="${ENV_UPPER}_SP_OBJECT_ID"

  log_info "--- Recovering ${SP_NAME} ---"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] az ad sp list --filter \"displayName eq '${SP_NAME}'\" --query \"[0].{AppId:appId, ObjectId:id}\" --output json" >&2
    APP_ID="<app-id-would-be-retrieved>"
    OBJECT_ID="<object-id-would-be-retrieved>"
    log_success "App ID (Client ID): $APP_ID"
    log_success "Object ID: $OBJECT_ID"
    write_file "$SP_IDS_FILE" "${APP_ID_VAR}=$APP_ID"
    write_file "$SP_IDS_FILE" "${OBJECT_ID_VAR}=$OBJECT_ID"
    RECOVERED=$((RECOVERED + 1))
  else
    # Get Service Principal details
    SP_INFO=$(az ad sp list \
      --filter "displayName eq '${SP_NAME}'" \
      --query "[0].{AppId:appId, ObjectId:id, DisplayName:displayName}" \
      --output json)

    if [ "$SP_INFO" != "null" ] && [ -n "$SP_INFO" ] && [ "$SP_INFO" != "{}" ]; then
      APP_ID=$(echo "$SP_INFO" | jq -r '.AppId')
      OBJECT_ID=$(echo "$SP_INFO" | jq -r '.ObjectId')

      # Verify we got valid IDs
      if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ -n "$OBJECT_ID" ] && [ "$OBJECT_ID" != "null" ]; then
        log_success "App ID (Client ID): $APP_ID"
        log_success "Object ID: $OBJECT_ID"

        # Write to file
        write_file "$SP_IDS_FILE" "${APP_ID_VAR}=$APP_ID"
        write_file "$SP_IDS_FILE" "${OBJECT_ID_VAR}=$OBJECT_ID"

        RECOVERED=$((RECOVERED + 1))
      else
        log_error "Could not retrieve valid IDs for ${SP_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_error "Service Principal ${SP_NAME} not found in Azure"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  echo ""
done

# Summary
echo "=== Recovery Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would recover Service Principals: 4 (one per environment)"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Recovered ${RECOVERED} Service Principal(s)"
    log_success "Service Principal IDs saved to: ${SP_IDS_FILE}"
  else
    log_error "Recovery completed with ${ERRORS} error(s)"
    log_warning "Only ${RECOVERED} Service Principal(s) were recovered"
    log_info "Service Principal IDs saved to: ${SP_IDS_FILE}"
    exit 1
  fi
fi

echo ""
log_info "Next steps:"
log_info "  1. Verify service-principals.env file contains all Service Principal IDs"
log_info "  2. Load the file: source <(grep -v '^#' service-principals.env | xargs -I {} echo 'export {}')"
log_info "  3. Or use load_env_file from common.sh: load_env_file service-principals.env"
