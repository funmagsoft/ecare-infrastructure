#!/usr/bin/env bash

init_script() {
  dotenv_load_if_exists "$REPO_ROOT"
  parse_dry_run "$@"
  require_env_vars TENANT_ID SUBSCRIPTION_ID LOCATION ORGANIZATION ORGANIZATION_FOR_SA PROJECT
  az_set_subscription "$SUBSCRIPTION_ID"
}

init_script_minimal() {
  dotenv_load_if_exists "$REPO_ROOT"
  parse_dry_run "$@"
  require_env_vars SUBSCRIPTION_ID PROJECT
  az_set_subscription "$SUBSCRIPTION_ID"
}
