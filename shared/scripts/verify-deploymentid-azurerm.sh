#!/usr/bin/env bash

set -euo pipefail

# verify-deploymentid-arg.sh
#
# Verifies (via Azure Resource Graph) that:
# 1) All TAGGABLE ARM resources managed by the Terraform state in --tf-dir AND tagged with DeploymentId
#    are present in Azure Resource Graph for the same DeploymentId.
# 2) There are no "extra" ARM resources in Azure Resource Graph with the same DeploymentId
#    that are not present in Terraform state.
#
# Requirements: terraform, az, jq
# Azure CLI extension: resource-graph (installed automatically, non-interactive)
#
# Usage:
#   ./verify-deploymentid-arg.sh --tf-dir <path> [--deployment-id <id>] [--subscription <subId>]
#   ./verify-deploymentid-arg.sh -h|--help

TAG_KEY="DeploymentId"
DEPLOYMENT_ID=""
SUBSCRIPTION_ID=""
FIRST=1000
TF_DIR=""

help() {
  cat <<'EOF'
verify-deploymentid-arg.sh

Verifies Terraform-managed, taggable ARM resources against Azure Resource Graph using a DeploymentId tag.

It checks:
  - Missing: resources present in Terraform state (taggable + tagged with DeploymentId) but not found in Azure ARG.
  - Extra:   resources found in Azure ARG with DeploymentId but not present in Terraform state.

IMPORTANT:
  - This script verifies only TAGGABLE ARM resources (those with 'tags' in Terraform state).
  - Non-taggable resources require an additional "ARM id existence" check (separate script/variant).

Usage:
  verify-deploymentid-arg.sh --tf-dir <path> [options]

Options:
  --tf-dir <path>         Path to the Terraform root module directory (required).
  --deployment-id <id>    DeploymentId value. If omitted, the script will try:
                          terraform output -raw deployment_id
                          terraform output -raw DeploymentId
  --subscription <id>     Azure subscription id. If omitted, uses current az account.
  --tag-key <name>        Tag key to use (default: DeploymentId).
  --first <n>             Page size for ARG queries (default: 1000).
  -h, --help              Show this help and exit.

Examples:
  ./verify-deploymentid-arg.sh --tf-dir infra-platform/terraform/environments/dev --deployment-id a1b2c3d4
  ./verify-deploymentid-arg.sh --tf-dir ./terraform/environments/prod
EOF
}

# ----------------------------
# Argument parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tf-dir)        TF_DIR="$2"; shift 2 ;;
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --subscription)  SUBSCRIPTION_ID="$2"; shift 2 ;;
    --tag-key)       TAG_KEY="$2"; shift 2 ;;
    --first)         FIRST="$2"; shift 2 ;;
    -h|--help)       help; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; echo >&2; help >&2; exit 2 ;;
  esac
done

if [[ -z "$TF_DIR" ]]; then
  echo "ERROR: --tf-dir is required." >&2
  echo >&2
  help >&2
  exit 2
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "ERROR: --tf-dir does not exist or is not a directory: $TF_DIR" >&2
  exit 2
fi

command -v terraform >/dev/null
command -v az >/dev/null
command -v jq >/dev/null

# ----------------------------
# Azure CLI setup
# ----------------------------
az account show --only-show-errors >/dev/null

# Prevent hanging on extension install prompts
az config set extension.use_dynamic_install=yes_without_prompt >/dev/null 2>&1 || true

# Ensure Resource Graph extension exists
if ! az extension show --name resource-graph --only-show-errors >/dev/null 2>&1; then
  echo "Installing Azure CLI extension: resource-graph" >&2
  az extension add --name resource-graph --only-show-errors >/dev/null
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --query id -o tsv --only-show-errors)"
fi

# ----------------------------
# Terraform: read DeploymentId (if not provided) and load state JSON
# ----------------------------
if [[ -z "${DEPLOYMENT_ID}" ]]; then
  if terraform -chdir="$TF_DIR" output -raw deployment_id >/dev/null 2>&1; then
    DEPLOYMENT_ID="$(terraform -chdir="$TF_DIR" output -raw deployment_id)"
  elif terraform -chdir="$TF_DIR" output -raw DeploymentId >/dev/null 2>&1; then
    DEPLOYMENT_ID="$(terraform -chdir="$TF_DIR" output -raw DeploymentId)"
  fi
fi

if [[ -z "${DEPLOYMENT_ID}" ]]; then
  echo "ERROR: DeploymentId not provided and no terraform output 'deployment_id'/'DeploymentId' found in --tf-dir." >&2
  echo "Provide it via: --deployment-id <value> or add a terraform output." >&2
  exit 2
fi

echo "Terraform dir:  ${TF_DIR}"
echo "Subscription:   ${SUBSCRIPTION_ID}"
echo "Tag key:        ${TAG_KEY}"
echo "DeploymentId:   ${DEPLOYMENT_ID}"
echo

STATE_JSON="$(terraform -chdir="$TF_DIR" show -json)"

# Expected resources from Terraform state:
# - managed only
# - ARM id only
# - taggable only (values.tags object present)
# - must already have the DeploymentId tag in state (detects tagging bugs early)
mapfile -t EXPECTED_IDS < <(
  echo "$STATE_JSON" | jq -r --arg tagKey "$TAG_KEY" --arg depId "$DEPLOYMENT_ID" '
    def collect_resources(m):
      (m.resources // []) + ((m.child_modules // []) | map(collect_resources(.)) | add);

    collect_resources(.values.root_module)
    | map(select(.mode == "managed"))
    | map(select(.values.id? and (.values.id | type=="string") and (.values.id | startswith("/subscriptions/"))))
    | map(select(.values.tags? and (.values.tags | type=="object")))
    | map(select(.values.tags[$tagKey]? == $depId))
    | map(.values.id)
    | unique
    | .[]
  '
)

EXPECTED_COUNT="${#EXPECTED_IDS[@]}"

echo "Terraform state: found ${EXPECTED_COUNT} taggable ARM resources with ${TAG_KEY}=${DEPLOYMENT_ID}"
if [[ "$EXPECTED_COUNT" -eq 0 ]]; then
  echo "Nothing to verify (no taggable resources in state matching DeploymentId)."
  exit 0
fi
echo

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ----------------------------
# Azure Resource Graph query (with pagination)
# ----------------------------
fetch_arg_rows() {
  local skip=0
  while true; do
    echo "Querying Azure Resource Graph... (skip=${skip}, first=${FIRST})" >&2

    local kql
    kql="Resources
| where isnotempty(tags['${TAG_KEY}'])
| where tostring(tags['${TAG_KEY}']) == '${DEPLOYMENT_ID}'
| project id, name, type, resourceGroup
| order by id asc"

    # Output TSV with columns: id, name, type, rg
    local rows
    rows="$(az graph query \
      --subscriptions "${SUBSCRIPTION_ID}" \
      -q "${kql}" \
      --first "${FIRST}" \
      --skip "${skip}" \
      --query "data[].{id:id,name:name,type:type,rg:resourceGroup}" \
      -o tsv \
      --only-show-errors)"

    local n
    n="$(printf "%s\n" "${rows}" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [[ "$n" -eq 0 ]]; then
      break
    fi

    printf "%s\n" "${rows}"

    if [[ "$n" -lt "$FIRST" ]]; then
      break
    fi

    skip=$((skip + FIRST))
  done
}

# 1) Pull actual ARG rows and IDs
fetch_arg_rows > "${tmpdir}/actual_rows.tsv"
cut -f1 "${tmpdir}/actual_rows.tsv" | sed '/^$/d' | sort -u > "${tmpdir}/actual_ids.txt"

ACTUAL_COUNT="$(wc -l < "${tmpdir}/actual_ids.txt" | tr -d ' ')"
echo "Azure Resource Graph: found ${ACTUAL_COUNT} ARM resources with ${TAG_KEY}=${DEPLOYMENT_ID}"
echo

# 2) Expected IDs
printf "%s\n" "${EXPECTED_IDS[@]}" | sed '/^$/d' | sort -u > "${tmpdir}/expected_ids.txt"

# 3) Compare sets
comm -23 "${tmpdir}/expected_ids.txt" "${tmpdir}/actual_ids.txt" > "${tmpdir}/missing.txt" || true
comm -13 "${tmpdir}/expected_ids.txt" "${tmpdir}/actual_ids.txt" > "${tmpdir}/extra.txt" || true

missing_count="$(wc -l < "${tmpdir}/missing.txt" | tr -d ' ')"
extra_count="$(wc -l < "${tmpdir}/extra.txt" | tr -d ' ')"

if [[ "$missing_count" -eq 0 && "$extra_count" -eq 0 ]]; then
  echo "OK: Resource Graph matches Terraform state for taggable resources (DeploymentId scope)."
  exit 0
fi

echo "MISMATCH detected."
echo

if [[ "$missing_count" -gt 0 ]]; then
  echo "Missing in Azure (present in TF state but not found by ARG tag query): ${missing_count}"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    echo "  - $id"
  done < "${tmpdir}/missing.txt"
  echo
fi

if [[ "$extra_count" -gt 0 ]]; then
  echo "Unexpected extras in Azure (found by ARG tag query but not present in TF state): ${extra_count}"
  echo "Extras details (id | name | type | resourceGroup):"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    awk -v target="$id" -F'\t' '$1==target {print "  - " $1 " | " $2 " | " $3 " | " $4}' \
      "${tmpdir}/actual_rows.tsv"
  done < "${tmpdir}/extra.txt"
  echo
fi

echo "ERROR: DeploymentId verification failed."
exit 1
