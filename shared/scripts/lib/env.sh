#!/usr/bin/env bash

dotenv_load_if_exists() {
  local repo_root="$1"
  local env_file="${repo_root}/.env"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source <(grep -v '^#' "$env_file" | grep -v '^$' | sed -E 's/^export[[:space:]]+//')
    set +a
  fi
}

require_env_vars() {
  local missing=()
  local v
  for v in "$@"; do
    if [[ -z "${!v:-}" ]]; then
      missing+=("$v")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required variables:"
    for v in "${missing[@]}"; do
      printf '  - %s\n' "$v" >&2
    done
    die "Aborting due to missing required configuration."
  fi
}
