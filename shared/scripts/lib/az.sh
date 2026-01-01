#!/usr/bin/env bash
# Azure CLI wrapper: centralizes 'az' execution, dry-run behavior and logging.

az_require_cli() { command -v az >/dev/null 2>&1 || die "Required command not found: az"; }

az_require_login() {
  az_require_cli
  if ! az account show >/dev/null 2>&1; then
    die "Not logged in to Azure CLI. Run: az login"
  fi
}

# Executes az command even during dry-run (use for read-only operations).
az_call() {
  az_require_cli
  az "$@"
}

# Executes az command respecting dry-run (use for mutations).
az_exec() {
  az_require_cli
  cmd_exec az "$@"
}

az_set_subscription() {
  local subscription_id="$1"
  az_exec account set --subscription "$subscription_id"
}
