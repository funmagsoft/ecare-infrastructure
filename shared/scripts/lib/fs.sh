#!/usr/bin/env bash

file_clear() {
  local file="$1"
  if is_dry_run; then
    log_info "[DRY-RUN] > $(printf '%q' "$file")"
    return 0
  fi
  : >"$file"
}

file_append_line() {
  local file="$1"
  local line="$2"
  if is_dry_run; then
    log_info "[DRY-RUN] append line to $(printf '%q' "$file")"
    return 0
  fi
  printf '%s
' "$line" >>"$file"
}
