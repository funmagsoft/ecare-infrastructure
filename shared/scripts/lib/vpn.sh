#!/usr/bin/env bash

get_enable_vpn_gateway() {
  local env_dir="$1"
  local tfvars_file
  local value

  tfvars_file="${env_dir}/terraform.tfvars"

  if [[ ! -f "$tfvars_file" ]]; then
    echo "false"
    return 0
  fi

  value="$(awk -F= '/^[[:space:]]*enable_vpn_gateway[[:space:]]*=/{sub(/#.*/, "", $2); sub(/\/\/.*/, "", $2); gsub(/[[:space:]]/, "", $2); print tolower($2); exit}' "$tfvars_file")"

  if [[ "$value" == "true" ]]; then
    echo "true"
  else
    echo "false"
  fi
}
