#!/usr/bin/env bash
# Dry-run helpers.

parse_dry_run() {
  if [[ -z "${DRY_RUN+x}" ]]; then
    DRY_RUN=false
  fi
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=true ;;
      --execute) DRY_RUN=false ;;
    esac
  done
}

is_dry_run() { [[ "${DRY_RUN:-false}" == true ]]; }

format_cmd() {
  local out=()
  local a
  for a in "$@"; do
    out+=("$(printf '%q' "$a")")
  done
  local IFS=' '
  printf '%s' "${out[*]}"
}

cmd_exec() {
  if is_dry_run; then
    log_info "[DRY-RUN]" "$(format_cmd "$@")"
    return 0
  fi
  "$@"
}
