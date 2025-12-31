#!/usr/bin/env bash

build_fic_display_name() {
  local repo="$1"   # np. "hycom/ecare-infrastructure"
  local env="$2"

  # substitute "/" na "-"
  local name="${repo//\//-}"

  # title-case of separated segments "-"
  local part
  local titled=""
  IFS='-' read -ra parts <<< "$name"
  for part in "${parts[@]}"; do
    if [[ -n "$part" ]]; then
      titled+="${part^}"
    fi
  done

  # hash: first 4 characters SHA256(repo)
  local hash
  hash=$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,4)}')

  printf 'GitHub%sEnv-%s-%s\n' "$titled" "$env" "$hash"
}
