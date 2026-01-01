#!/usr/bin/env bash

check_required_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    return 1
  fi
  return 0
}

check_azure_login() {
  if ! az account show >/dev/null 2>&1; then
    log_error "Not logged in to Azure CLI. Run: az login"
    return 1
  fi
  return 0
}

validate_environment() {
  local env="$1"
  case "$env" in
    dev|test|stage|prod) return 0 ;;
    *)
      log_error "Invalid environment: $env. Must be one of: dev, test, stage, prod"
      return 1
      ;;
  esac
}
