#!/usr/bin/env bash

set -euo pipefail

# cleanup-deployment-arm.sh
#
# Deletes Azure Resource Groups in a subscription that match:
#   tags['DeploymentId'] == <deployment_id>
#   tags['Phase'] == <Foundation|Platform|Workload>
#
# Uses Azure Resource Graph (ResourceContainers) to find RGs reliably. :contentReference[oaicite:1]{index=1}
#
# SAFETY:
#   Default is dry-run. To delete, pass:
#     --apply --confirm "DELETE <deploymentId> <phase>"
#
# Requirements: az, jq
# Azure CLI extension: resource-graph (auto-installed, non-interactive)

DEPLOYMENT_TAG_KEY="DeploymentId"
PHASE_TAG_KEY="Phase"

DEPLOYMENT_ID=""
PHASE_IN=""
PHASE_ARM=""
PHASE_ENTRA=""
SUBSCRIPTION_ID=""
FIRST=1000
APPLY="false"
CONFIRM=""
TF_DIR=""

help() {
  cat <<'EOF'
cleanup-deployment-arm.sh

Deletes Azure Resource Groups by tags (DeploymentId + Phase), using Azure Resource Graph.

Usage:
  cleanup-deployment-arm.sh --deployment-id <id> --phase <foundation|platform|workload> [options]
  cleanup-deployment-arm.sh --tf-dir <path> --phase <foundation|platform|workload> [options]

Required:
  --phase <value>              Phase scope (case-insensitive): foundation|platform|workload
  AND one of:
    --deployment-id <id>        DeploymentId value
    --tf-dir <path>             Terraform root module dir (reads terraform output -raw deployment_id/DeploymentId)

Options:
  --subscription <id>           Azure subscription id (default: current az account)
  --deployment-tag-key <k>      Deployment tag key (default: DeploymentId)
  --phase-tag-key <k>           Phase tag key (default: Phase)
  --first <n>                   ARG page size (default: 1000)
  --apply                       Perform deletions (otherwise dry-run)
  --confirm <string>            Must equal: "DELETE <deploymentId> <phase>"
                                Example: --confirm "DELETE a1b2c3d4 foundation"
  -h, --help                    Show help

Examples:
  ./cleanup-deployment-arm.sh --deployment-id a1b2c3d4 --phase foundation
  ./cleanup-deployment-arm.sh --tf-dir ./foundation/terraform/environments/dev --phase foundation
  ./cleanup-deployment-arm.sh --deployment-id a1b2c3d4 --phase foundation --apply --confirm "DELETE a1b2c3d4 foundation"
EOF
}

normalize_phase() {
  local in="$1"
  local lower
  lower="$(printf "%s" "$in" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    foundation) echo "foundation|Foundation" ;;
    platform)   echo "platform|Platform" ;;
    workload)   echo "workload|Workload" ;;
    *)
      echo "ERROR: invalid --phase value: $in (allowed: foundation|platform|workload)" >&2
      exit 2
      ;;
  esac
}

# ----------------------------
# Args
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-id)       DEPLOYMENT_ID="$2"; shift 2 ;;
    --tf-dir)              TF_DIR="$2"; shift 2 ;;
    --phase)               PHASE_IN="$2"; shift 2 ;;
    --subscription)        SUBSCRIPTION_ID="$2"; shift 2 ;;
    --deployment-tag-key)  DEPLOYMENT_TAG_KEY="$2"; shift 2 ;;
    --phase-tag-key)       PHASE_TAG_KEY="$2"; shift 2 ;;
    --first)               FIRST="$2"; shift 2 ;;
    --apply)               APPLY="true"; shift 1 ;;
    --confirm)             CONFIRM="$2"; shift 2 ;;
    -h|--help)             help; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; echo >&2; help >&2; exit 2 ;;
  esac
done

if [[ -z "$PHASE_IN" ]]; then
  echo "ERROR: --phase is required." >&2
  echo >&2
  help >&2
  exit 2
fi

pair="$(normalize_phase "$PHASE_IN")"
PHASE_ENTRA="${pair%%|*}"
PHASE_ARM="${pair##*|}"

if [[ -z "$DEPLOYMENT_ID" && -z "$TF_DIR" ]]; then
  echo "ERROR: provide --deployment-id or --tf-dir." >&2
  echo >&2
  help >&2
  exit 2
fi

if [[ -n "$TF_DIR" ]]; then
  if [[ ! -d "$TF_DIR" ]]; then
    echo "ERROR: --tf-dir does not exist or is not a directory: $TF_DIR" >&2
    exit 2
  fi
  command -v terraform >/dev/null
fi

command -v az >/dev/null
command -v jq >/dev/null

# ----------------------------
# Azure CLI setup
# ----------------------------
az account show --only-show-errors >/dev/null
az config set extension.use_dynamic_install=yes_without_prompt >/dev/null 2>&1 || true

if ! az extension show --name resource-graph --only-show-errors >/dev/null 2>&1; then
  echo "Installing Azure CLI extension: resource-graph" >&2
  az extension add --name resource-graph --only-show-errors >/dev/null
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --query id -o tsv --only-show-errors)"
fi

# ----------------------------
# DeploymentId from TF (optional)
# ----------------------------
if [[ -z "$DEPLOYMENT_ID" ]]; then
  if terraform -chdir="$TF_DIR" output -raw deployment_id >/dev/null 2>&1; then
    DEPLOYMENT_ID="$(terraform -chdir="$TF_DIR" output -raw deployment_id)"
  elif terraform -chdir="$TF_DIR" output -raw DeploymentId >/dev/null 2>&1; then
    DEPLOYMENT_ID="$(terraform -chdir="$TF_DIR" output -raw DeploymentId)"
  fi
fi

if [[ -z "$DEPLOYMENT_ID" ]]; then
  echo "ERROR: DeploymentId not provided and not found in terraform outputs (deployment_id/DeploymentId)." >&2
  exit 2
fi

echo "Subscription:       ${SUBSCRIPTION_ID}"
echo "Deployment tag key: ${DEPLOYMENT_TAG_KEY}"
echo "Phase tag key:      ${PHASE_TAG_KEY}"
echo "DeploymentId:       ${DEPLOYMENT_ID}"
echo "Phase (ARM):        ${PHASE_ARM}"
echo "Mode:               $([[ "$APPLY" == "true" ]] && echo APPLY || echo DRY-RUN)"
echo

# Safety gate
if [[ "$APPLY" == "true" ]]; then
  expected_confirm="DELETE ${DEPLOYMENT_ID} ${PHASE_ENTRA}"
  if [[ "$CONFIRM" != "$expected_confirm" ]]; then
    echo "ERROR: Missing/invalid --confirm. For deletion you must pass:" >&2
    echo "  --confirm \"${expected_confirm}\"" >&2
    exit 2
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ----------------------------
# Find matching RGs in ARG (ResourceContainers)
# ----------------------------
fetch_rg_rows() {
  local skip=0
  while true; do
    echo "Querying Azure Resource Graph for Resource Groups... (skip=${skip}, first=${FIRST})" >&2

    local kql
    kql="ResourceContainers
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| where isnotempty(tags['${DEPLOYMENT_TAG_KEY}']) and isnotempty(tags['${PHASE_TAG_KEY}'])
| where tostring(tags['${DEPLOYMENT_TAG_KEY}']) == '${DEPLOYMENT_ID}'
| where tostring(tags['${PHASE_TAG_KEY}']) == '${PHASE_ARM}'
| project id, name, location
| order by name asc"

    local rows
    rows="$(az graph query \
      --subscriptions "${SUBSCRIPTION_ID}" \
      -q "${kql}" \
      --first "${FIRST}" \
      --skip "${skip}" \
      --query "data[].{id:id,name:name,location:location}" \
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

fetch_rg_rows > "${tmpdir}/rgs.tsv" || true

rg_count="$(sed '/^$/d' "${tmpdir}/rgs.tsv" | wc -l | tr -d ' ')"
echo "Found Resource Groups: ${rg_count}"
if [[ "$rg_count" -eq 0 ]]; then
  echo "Nothing to delete."
  exit 0
fi
echo

echo "Resource Groups (name | location | id):"
awk -F'\t' '{print "  - " $2 " | " $3 " | " $1}' "${tmpdir}/rgs.tsv"
echo

if [[ "$APPLY" != "true" ]]; then
  echo "DRY-RUN: no deletions performed. Re-run with --apply and correct --confirm to delete."
  exit 0
fi

# ----------------------------
# Delete RGs (blocking)
# ----------------------------
while IFS=$'\t' read -r id name location; do
  [[ -z "$name" ]] && continue
  echo "Deleting RG: ${name}"
  az group delete --subscription "${SUBSCRIPTION_ID}" --name "${name}" --yes --only-show-errors
done < "${tmpdir}/rgs.tsv"

echo "OK: Resource Groups deleted for DeploymentId=${DEPLOYMENT_ID} Phase=${PHASE_ARM}"
