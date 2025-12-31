#!/usr/bin/env bash
# Error handling helpers.

die() {
  local msg="$1"
  local code="${2:-1}"
  log_error "$msg"
  exit "$code"
}

_on_err() {
  local exit_code="$1"
  local line_no="$2"
  local cmd="$3"
  log_error "Command failed (exit=${exit_code}) at line ${line_no}: ${cmd}"
}

_on_exit() {
  local exit_code="$1"
  if [[ "${exit_code}" -ne 0 ]]; then
    log_error "Exiting with code ${exit_code}"
  fi
}

setup_traps() {
  trap '_on_err "$?" "$LINENO" "$BASH_COMMAND"' ERR
  trap '_on_exit "$?"' EXIT
}
