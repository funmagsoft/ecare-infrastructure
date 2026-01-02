#!/usr/bin/env bash

set -euo pipefail

# Keeps lockfiles only in root modules (by path allowlist),
# deletes lockfiles generated in module directories.
#
# Adjust ROOT_LOCKFILE_REGEX if your roots live elsewhere.

ROOT_LOCKFILE_REGEX='(^|/)(foundation|platform|workload)/terraform/environments/[^/]+/\.terraform\.lock\.hcl$'

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

found=0
kept=0
deleted=0

# Find all lockfiles in repo
while IFS= read -r -d '' f; do
  found=$((found + 1))

  # make path relative
  rel="${f#"$repo_root"/}"

  if [[ "$rel" =~ $ROOT_LOCKFILE_REGEX ]]; then
    kept=$((kept + 1))
    continue
  fi

  rm -f "$f"
  deleted=$((deleted + 1))
done < <(find "$repo_root" -name ".terraform.lock.hcl" -type f -print0)

echo "cleanup_terraform_lockfiles:"
echo "  found:   $found"
echo "  kept:    $kept"
echo "  deleted: $deleted"

exit 0
