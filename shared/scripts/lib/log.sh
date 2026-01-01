#!/usr/bin/env bash
# Logging helpers.
# All log_* functions write to STDERR so STDOUT can be used for data output.

_log_ts() { date '+%Y-%m-%d %H:%M:%S'; }

_log_color_enabled() {
  # Respect NO_COLOR (https://no-color.org/)
  if [[ -n "${NO_COLOR:-}" ]]; then
    return 1
  fi
  # Allow forcing colors in CI if desired.
  if [[ "${LOG_COLOR:-auto}" == "always" || "${FORCE_COLOR:-0}" == "1" ]]; then
    return 0
  fi
  if [[ "${LOG_COLOR:-auto}" == "never" ]]; then
    return 1
  fi
  # Auto: only if STDERR is a TTY and TERM looks sane.
  [[ -t 2 && "${TERM:-}" != "dumb" ]]
}

_color() {
  local code="$1"
  if _log_color_enabled; then
    printf '\033[%sm' "$code"
  fi
}

_color_reset() {
  if _log_color_enabled; then
    printf '\033[0m'
  fi
}

_level_style() {
  local level="$1"
  case "$level" in
    INFO)    _color '36' ;; # cyan
    WARN)    _color '33' ;; # yellow
    ERROR)   _color '31' ;; # red
    SUCCESS) _color '32' ;; # green
    *)       _color '0'  ;;
  esac
}

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
  # Pad level to keep message column aligned across log levels.
  local padded_level styled_level
  padded_level="$(printf '%-7s' "$level")"
  styled_level="$(_level_style "$level")${padded_level}$(_color_reset)"
  printf '%s [%s] - %s\n' "$(_log_ts)" "$styled_level" "$msg" >&2
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
