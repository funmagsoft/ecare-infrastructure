#!/usr/bin/env bash
# Common argument parsing helpers for project scripts.

# parse_env_args
#
# Extracts environment selection flags from argv and populates TARGET_ENVS.
#
# Supported flags:
#   --env <dev|test|stage|prod>   (repeatable)
#   --all-envs                   (explicitly select all)
#
# Defaults to all environments when no --env is provided.
parse_env_args() {
  TARGET_ENVS=()
  local all=false

  local i=1
  while [[ $i -le $# ]]; do
    local arg="${!i}"
    case "$arg" in
      --all-envs)
        all=true
        ;;
      --env|--environment)
        i=$((i + 1))
        local env="${!i:-}"
        if [[ -z "$env" ]]; then
          die "Missing value for --env. Allowed: dev|test|stage|prod" 2
        fi
        validate_environment "$env" || exit 2
        TARGET_ENVS+=("$env")
        ;;
    esac
    i=$((i + 1))
  done

  if [[ "${#TARGET_ENVS[@]}" -eq 0 || "$all" == true ]]; then
    TARGET_ENVS=(dev test stage prod)
  fi
}

envs_to_string() {
  local IFS=","; printf '%s' "${TARGET_ENVS[*]}";
}

# parse_confirm_args
#
# Extracts --confirm "..." from argv and populates CONFIRM.
# Used by destructive scripts that require an explicit confirmation string.
parse_confirm_args() {
  CONFIRM=""
  local i=1
  while [[ $i -le $# ]]; do
    local arg="${!i}"
    case "$arg" in
      --confirm)
        i=$((i + 1))
        CONFIRM="${!i:-}"
        ;;
    esac
    i=$((i + 1))
  done
}
