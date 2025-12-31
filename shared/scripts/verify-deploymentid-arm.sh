#!/usr/bin/env bash
set -euo pipefail

# cleanup-deployment-arm.sh
#
# Deletes Azure Resource Groups by tags (DeploymentId + Phase) using Azure Resource Graph.
#
# Modes:
#   - Single phase:  --phase foundation|platform|workload
#   - All phases:    --all-phases
#
# SAFETY:
#   Default is dry-run.
#   To delete:
#     --apply --confirm "DELETE <deploymentId> <phase>"         (single phase)
#     --apply --confirm "DELETE-ALL <deploymentId>"            (all phases)
#
# Requirements: az, jq, (optional terraform if --tf-dir used)
# Azure CLI extension: resource-graph (auto-installed, non-interactive)

DEPLOYMENT_TAG_KEY="DeploymentId"
PHASE_TAG_KEY="Phase"

DEPLOYMENT_ID=""
TF_DIR=""
SUBSCRIPTION_ID=""
FIRST=1000

PHASE_IN=""
ALL_PHASES="false"

APPLY="false"
CONFIRM=""

help() {
  cat <<'EOF'
cleanup-deployment-arm.sh

Deletes Azure Resource Groups by tags (DeploymentId + Phase), using Azure Resource Graph.

Usage:
  cleanup-deployment-arm.sh --deployment-id <id> (--phase <foundation|platform|workload> | --all-phases) [options]
  cleanup-deployment-arm.sh --tf-dir <path> (--phase <foundation|platform|workload> | --all-phases) [options]

Required:
  One of:
    --deployment-id <id>        DeploymentId value
    --tf-dir <path>             Terraform root module dir (reads terraform output -raw deployment_id/DeploymentId)

  And one of:
    --phase <value>             Single phase (case-insensitive): foundation|platform|workload
    --all-phases                Run for all phases (foundation, platform, workload)

Options:
  --subscription <id>           Azure subscription id (default: current az account)
  --deployment-tag-key <k>      Deployment tag key (default: DeploymentId)
  --phase-tag-key <k>           Phase tag key (default: Phase)
  --first <n>                   ARG page size (default: 1000)
  --apply                       Perform deletions (otherwise dry-run)
  --confirm <string>            Confirmation phrase:
                                 - single phase: "DELETE <deploymentId> <phase>"
                                   e.g. --confirm "DELETE a1b2c3d4 foundation"
                                 - all phases:   "DELETE-ALL <deploymentId>"
                                   e.g. --confirm "DELETE-ALL a1b2c3d4"
  -h, --help                    Show help

Examples:
  ./cleanup-deployment-arm.sh --deployment-id a1b2c3d4 --phase foundation
  ./cleanup-deployment-arm.sh --deployment-id a1b2c3d4 --all-phases --apply --confirm "DELETE-ALL a1b2c3d4"
EOF
}

normalize_phase_pair() {
  local in="$1"
  local lower
  lower="$(printf "%s" "$in" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    foundation) echo "foundation|Foundation" ;;
    platform)   echo "platform|Platform" ;;
    workload)   echo "workload|Workload" ;;
    *)
      echo "ERROR: invalid phase: $in (allowed: foundation|platform|workload)" >&2
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
    --all-phases)          ALL_PHASES="true"; shift 1 ;;
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

if [[ -z "$DEPLOYMENT_ID" && -z "$TF_DIR" ]]; then
  echo "ERROR: provide --deployment-id or --tf-dir." >&2
  echo >&2
  help >&2
  exit 2
fi

if [[ "$ALL_PHASES" == "false" && -z "$PHASE_IN" ]]; then
  echo "ERROR: provide --phase or --all-phases." >&2
  echo >&2
  help >&2
  exit 2
fi

if [[ "$ALL_PHASES" == "true" && -n "$PHASE_IN" ]]; then
  echo "ERROR: use either --phase or --all-phases (not both)." >&2
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
if [[ -z "$DEPLOYMENT_ID" && -n "$TF_DIR" ]]; then
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

# ----------------------------
# Safety gate
# ----------------------------
if [[ "$APPLY" == "true" ]]; then
  if [[ "$ALL_PHASES" == "true" ]]; then
    expected_confirm="DELETE-ALL ${DEPLOYMENT_ID}"
    if [[ "$CONFIRM" != "$expected_confirm" ]]; then
      echo "ERROR: Missing/invalid --confirm. For deletion you must pass:" >&2
      echo "  --confirm \"${expected_confirm}\"" >&2
      exit 2
    fi
  else
    phase_pair="$(normalize_phase_pair "$PHASE_IN")"
    phase_entra="${phase_pair%%|*}"
    expected_confirm="DELETE ${DEPLOYMENT_ID} ${phase_entra}"
    if [[ "$CONFIRM" != "$expected_confirm" ]]; then
      echo "ERROR: Missing/invalid --confirm. For deletion you must pass:" >&2
      echo "  --confirm \"${expected_confirm}\"" >&2
      exit 2
    fi
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fetch_rg_rows_for_phase_arm() {
  local phase_arm="$1"
  local out_tsv="$2"

  local skip=0
  : > "$out_tsv"

  while true; do
    echo "Querying ARG for RGs... (Phase=${phase_arm}, skip=${skip}, first=${FIRST})" >&2

    local kql
    kql="ResourceContainers
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| where isnotempty(tags['${DEPLOYMENT_TAG_KEY}']) and isnotempty(tags['${PHASE_TAG_KEY}'])
| where tostring(tags['${DEPLOYMENT_TAG_KEY}']) == '${DEPLOYMENT_ID}'
| where tostring(tags['${PHASE_TAG_KEY}']) == '${phase_arm}'
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

    printf "%s\n" "${rows}" >> "$out_tsv"

    if [[ "$n" -lt "$FIRST" ]]; then
      break
    fi
    skip=$((skip + FIRST))
  done
}

delete_rgs_from_tsv() {
  local tsv="$1"
  local phase_arm="$2"

  local cnt
  cnt="$(sed '/^$/d' "$tsv" | wc -l | tr -d ' ')"
  echo "Phase ${phase_arm}: Found RGs: ${cnt}"
  if [[ "$cnt" -eq 0 ]]; then
    return 0
  fi

  echo "Phase ${phase_arm}: RGs (name | location | id):"
  awk -F'\t' '{print "  - " $2 " | " $3 " | " $1}' "$tsv"
  echo

  if [[ "$APPLY" != "true" ]]; then
    echo "DRY-RUN: no deletions performed for Phase ${phase_arm}."
    echo
    return 0
  fi

  while IFS=$'\t' read -r id name location; do
    [[ -z "$name" ]] && continue
    echo "Deleting RG (Phase ${phase_arm}): ${name}"
    az group delete --subscription "${SUBSCRIPTION_ID}" --name "${name}" --yes --only-show-errors
  done < "$tsv"
  echo
}

echo "Subscription:       ${SUBSCRIPTION_ID}"
echo "Deployment tag key: ${DEPLOYMENT_TAG_KEY}"
echo "Phase tag key:      ${PHASE_TAG_KEY}"
echo "DeploymentId:       ${DEPLOYMENT_ID}"
echo "Mode:               $([[ "$APPLY" == "true" ]] && echo APPLY || echo DRY-RUN)"
echo

phases=("foundation")
if [[ "$ALL_PHASES" == "true" ]]; then
  phases=("foundation" "platform" "workload")
else
  phases=("$PHASE_IN")
fi

overall_rc=0
for p in "${phases[@]}"; do
  pair="$(normalize_phase_pair "$p")"
  phase_arm="${pair##*|}"

  tsv="${tmpdir}/rgs_${phase_arm}.tsv"
  fetch_rg_rows_for_phase_arm "$phase_arm" "$tsv" || true
  delete_rgs_from_tsv "$tsv" "$phase_arm" || overall_rc=1
done

if [[ "$overall_rc" -ne 0 ]]; then
  echo "ERROR: ARM cleanup encountered errors." >&2
  exit 1
fi

echo "OK: ARM cleanup complete for DeploymentId=${DEPLOYMENT_ID} ($([[ "$ALL_PHASES" == "true" ]] && echo "ALL phases" || echo "Phase=${PHASE_IN}"))."
