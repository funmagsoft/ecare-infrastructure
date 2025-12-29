#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

ENVIRONMENT=""
SERVICE_NAME=""
REPO_NAME=""
ENABLE_KV=false
ENABLE_STORAGE=false
ENABLE_SB=false
ENV_LIST=()

usage() {
  cat <<EOF
Usage: $(basename "$0") --env <dev|test|stage|prod|all> --service <name> --repo <org/repo> [--kv] [--storage] [--sb] [--dry-run]

Adds or updates a service entry in terraform/environments/<env>/services.tf (local.services).

Options:
  --env       Environment: dev, test, stage, prod, or all
  --service   Logical service name (e.g. billing)
  --repo      GitHub repo in org/repo format (e.g. funmagsoft/billing-service)
  --kv        Enable Key Vault access flag (enable_key_vault_access = true)
  --storage   Enable Storage access flag (enable_storage_access = true)
  --sb        Enable Service Bus access flag (enable_service_bus_access = true)
  --dry-run   Show changes without modifying files
EOF
}

parse_args() {
  # If no arguments, show help
  if [ $# -eq 0 ]; then
    usage
    exit 1
  fi

  parse_dry_run "$@"
  set -- "${REMAINING_ARGS[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        ENVIRONMENT="$2"
        shift 2
        ;;
      --service)
        SERVICE_NAME="$2"
        shift 2
        ;;
      --repo)
        REPO_NAME="$2"
        shift 2
        ;;
      --kv)
        ENABLE_KV=true
        shift
        ;;
      --storage)
        ENABLE_STORAGE=true
        shift
        ;;
      --sb)
        ENABLE_SB=true
        shift
        ;;
      --dry-run)
        # already handled in parse_dry_run
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

validate_args() {
  if [[ -z "$ENVIRONMENT" || -z "$SERVICE_NAME" || -z "$REPO_NAME" ]]; then
    log_error "Missing required arguments"
    usage
    exit 1
  fi

  case "$ENVIRONMENT" in
    dev|test|stage|prod)
      ENV_LIST=("$ENVIRONMENT")
      ;;
    all)
      ENV_LIST=(dev test stage prod)
      ;;
    *)
      log_error "Invalid environment: $ENVIRONMENT (expected dev|test|stage|prod|all)"
      exit 1
      ;;
  esac
}

update_services_file() {
  local target_env="$1"
  local env_dir="${REPO_ROOT}/terraform/environments/${target_env}"
  local services_tf="${env_dir}/services.tf"

  if [ ! -d "$env_dir" ]; then
    log_error "Environment directory not found: $env_dir"
    exit 1
  fi

  if [ ! -f "$services_tf" ]; then
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY-RUN] services.tf not found; would create with template and add service entry"
      cat <<EOF
locals {
  services = {
    # Example service
    # billing = {
    #   repo                    = "funmagsoft/billing-service"
    #   branch                  = "main"
    #   enable_key_vault_access = true
    #   enable_storage_access   = true
    #   enable_service_bus_access = false
    #   additional_roles = [
    #     # {
    #     #   role  = "Reader"
    #     #   scope = "/subscriptions/<sub-id>/resourceGroups/rg-ecare-${ENVIRONMENT}"
    #     # }
    #   ]
    # }
    # Service: ${SERVICE_NAME}
    ${SERVICE_NAME} = {
      repo                    = "${REPO_NAME}"
      branch                  = "main"
      enable_key_vault_access = ${ENABLE_KV}
      enable_storage_access   = ${ENABLE_STORAGE}
      enable_service_bus_access = ${ENABLE_SB}
      additional_roles        = []
    }
  }
}
EOF
      return 0
    fi

    log_info "services.tf not found, creating template"
    run_cmd cat <<'EOF' > "$services_tf"
locals {
  services = {
    # Example service
    # billing = {
    #   repo                    = "funmagsoft/billing-service"
    #   branch                  = "main"
    #   enable_key_vault_access = true
    #   enable_storage_access   = true
    #   enable_service_bus_access = false
    #   additional_roles = [
    #     # {
    #     #   role  = "Reader"
    #     #   scope = "/subscriptions/<sub-id>/resourceGroups/rg-ecare-<env>"
    #     # }
    #   ]
    # }
  }
}
EOF
  fi

  log_info "Updating services definition in: $services_tf"

  local entry
  entry="    # Service: ${SERVICE_NAME}\n"
  entry+="    ${SERVICE_NAME} = {\n"
  entry+="      repo                    = \"${REPO_NAME}\"\n"
  entry+="      branch                  = \"main\"\n"
  entry+="      enable_key_vault_access = ${ENABLE_KV}\n"
  entry+="      enable_storage_access   = ${ENABLE_STORAGE}\n"
  entry+="      enable_service_bus_access = ${ENABLE_SB}\n"
  entry+="      additional_roles        = []\n"
  entry+="    }\n"

  local tmp="${services_tf}.tmp"
  awk -v svc="${SERVICE_NAME}" -v entry="$entry" '
    BEGIN {
      in_services = 0
      skip = 0
    }
    /^  services = \{/ { in_services = 1 }
    {
    if (in_services && match($0, "^    # Service: " svc "$")) { skip = 1; next }
      if (skip && match($0, "^    }")) { skip = 0; next }
      if (skip) next
      if (in_services && $0 ~ /^  }\s*$/) {
        printf "%s", entry
        print $0
        in_services = 0
        next
      }
      print
    }
  ' "$services_tf" > "$tmp"

  if [ "$DRY_RUN" = true ]; then
    log_info "=== DRY-RUN: resulting services.tf (env: ${target_env}) ==="
    cat "$tmp"
    rm -f "$tmp"
  else
    mv "$tmp" "$services_tf"
  fi
}

main() {
  load_dotenv || log_warn ".env not found in repo root, continuing without it"
  parse_args "$@"
  validate_args
  for env in "${ENV_LIST[@]}"; do
    update_services_file "$env"
  done
}

main "$@"

