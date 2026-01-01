#!/usr/bin/env bash
# Confirmation / safety helpers for destructive operations.

require_confirm() {
  local expected="$1"
  local provided="${CONFIRM:-}"

  if [[ "${DRY_RUN:-false}" == true ]]; then
    return 0
  fi

  if [[ "${provided}" != "${expected}" ]]; then
    log_error "Missing/invalid --confirm for destructive operation."
    log_error "To proceed, pass: --confirm \"${expected}\""
    exit 2
  fi
}
