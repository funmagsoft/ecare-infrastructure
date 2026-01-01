#!/usr/bin/env bash
# Logging helpers.
# All log_* functions write to STDERR so STDOUT can be used for data output.

_log_ts() { date '+%Y-%m-%d %H:%M:%S'; }

_join_args_space() {
  if [[ "$#" -eq 0 ]]; then
    printf '%s' ""
    return 0
  fi
  local s
  s="$(printf '%s ' "$@")"
  printf '%s' "${s% }"
}

_log_line() {
  local level="$1"
  shift
  local msg
  msg="$(_join_args_space "$@")"
  printf '%s [%s] %s
' "$(_log_ts)" "$level" "$msg" >&2
}

log_info() { _log_line INFO "$@"; }
log_warn() { _log_line WARN "$@"; }
log_warning() { log_warn "$@"; }
log_error() { _log_line ERROR "$@"; }
log_success() { _log_line SUCCESS "$@"; }

log_dry_run_banner() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    _log_line INFO "DRY-RUN MODE: no changes will be made"
  fi
}

log_dry_run_complete() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    _log_line INFO "DRY-RUN MODE: no changes were made"
  fi
}
