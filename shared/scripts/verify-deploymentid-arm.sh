#!/usr/bin/env bash

set -euo pipefail

# verify-deploymentid-arm.sh
#
# Compares Azure ARM resources by tags:
#   DeploymentId == <DeploymentId>
#   Phase        == <Phase> (TitleCase: Foundation|Platform|Workload)
#
# It compares Azure Resource Graph scan results with expected resources derived from Terraform state (azurerm_*).
#
# Modes:
# - expected: verify TF-expected resources exist in ARM (direct lookup by IDs) and enforce tags in ARM
# - scan:     list ARM resources by tags and report missing/extra vs TF
# - both:     do both (default)

TF_DIR=""
DEPLOYMENT_ID=""
PHASE_IN=""
PHASE_LOWER=""   # foundation|platform|workload
PHASE_TAG=""     # Foundation|Platform|Workload
MODE="both"      # expected | scan | both
PREFIX=""        # optional optimization: adds startswith(name,'<prefix>') to ARG filter
FAIL_ON_EXTRA="true"

# How many resources to print as a sample list in each section
PRINT_SAMPLE_LIMIT=25

help() {
  cat <<'EOF'
verify-deploymentid-arm.sh

Compares Azure ARM resources by tags:
  DeploymentId == <DeploymentId>
  Phase        == <Phase> (Foundation|Platform|Workload)
where phase input is lowercase: foundation|platform|workload

Usage:
  verify-deploymentid-arm.sh --tf-dir <path> --phase <foundation|platform|workload> [options]

Required:
  --tf-dir <path>              Path to the Terraform root module directory (required).
  --phase <value>              Phase value identifying the Terraform state scope.
                               Allowed (case-insensitive): foundation|platform|workload

Options:
  --deployment-id <id>         DeploymentId value. If omitted, the script will try:
                               terraform output -raw deployment_id
                               terraform output -raw DeploymentId
  --mode <expected|scan|both>  expected: verify TF-expected resources exist in ARM (direct lookup + tag enforcement)
                               scan:     list ARM resources by tags and report missing/extra vs TF
                               both:     do both (default)
  --prefix <string>            Optional optimization: adds startswith(name,'<prefix>') to Resource Graph filter.
  --fail-on-extra <true|false> If false, "extra" resources in scan mode do NOT fail the script (reported only).
                               Missing resources always fail.
                               Default: true
  -h, --help                   Show this help and exit.

Notes:
  - Scan mode uses Azure Resource Graph (az graph query). If unavailable, install:
      az extension add --name resource-graph
    If your environment restricts Resource Graph, use --mode expected.

Examples:
  ./verify-deploymentid-arm.sh --tf-dir ../../foundation/terraform/environments/dev --phase foundation
  ./verify-deploymentid-arm.sh --tf-dir ../../foundation/terraform/environments/dev --phase platform --fail-on-extra false
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

escape_kusto_string() {
  local s="$1"
  printf "%s" "${s//\'/\'\'}"
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tf-dir)          TF_DIR="$2"; shift 2 ;;
    --deployment-id)   DEPLOYMENT_ID="$2"; shift 2 ;;
    --phase)           PHASE_IN="$2"; shift 2 ;;
    --mode)            MODE="$2"; shift 2 ;;
    --prefix)          PREFIX="$2"; shift 2 ;;
    --fail-on-extra)   FAIL_ON_EXTRA="$2"; shift 2 ;;
    -h|--help)         help; exit 0 ;;
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
if [[ -z "$PHASE_IN" ]]; then
  echo "ERROR: --phase is required (foundation|platform|workload)." >&2
  exit 2
fi

pair="$(normalize_phase "$PHASE_IN")"
PHASE_LOWER="${pair%%|*}"
PHASE_TAG="${pair##*|}"

if [[ "$MODE" != "expected" && "$MODE" != "scan" && "$MODE" != "both" ]]; then
  echo "ERROR: --mode must be one of: expected, scan, both" >&2
  exit 2
fi
if [[ "$FAIL_ON_EXTRA" != "true" && "$FAIL_ON_EXTRA" != "false" ]]; then
  echo "ERROR: --fail-on-extra must be true or false" >&2
  exit 2
fi

command -v terraform >/dev/null
command -v az >/dev/null
command -v jq >/dev/null

az account show --only-show-errors >/dev/null

# ----------------------------
# DeploymentId resolution
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
  exit 2
fi

echo "Terraform dir:    ${TF_DIR}"
echo "DeploymentId:     ${DEPLOYMENT_ID}"
echo "Phase (input):    ${PHASE_LOWER}"
echo "Phase (tag):      ${PHASE_TAG}"
echo "Tag match:        DeploymentId=${DEPLOYMENT_ID} AND Phase=${PHASE_TAG}"
echo "Mode:             ${MODE}"
echo "Prefix opt:       ${PREFIX:-<none>}"
echo "Fail on extra:    ${FAIL_ON_EXTRA}"
echo

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ----------------------------
# Terraform expected resources (taggable azurerm_* with id)
# ----------------------------
STATE_JSON="$(terraform -chdir="$TF_DIR" show -json)"

extract_expected_resources_jsonl() {
  echo "$STATE_JSON" | jq -c '
    def collect_resources(m):
      (m.resources // []) + ((m.child_modules // []) | map(collect_resources(.)) | add);

    collect_resources(.values.root_module)
    | map(select(.mode == "managed"))
    | map(select(.type | startswith("azurerm_")))
    | map({
        address: .address,
        tf_type: .type,
        id: (.values.id // empty),
        tags: (.values.tags_all? // .values.tags? // null)
      })
    | map(select(.id != "" and (.tags != null)))
    | unique_by(.id)
    | .[]
  '
}

: > "${tmpdir}/expected_resources.jsonl"
extract_expected_resources_jsonl > "${tmpdir}/expected_resources.jsonl"

# ----------------------------
# Helpers for "what and how many"
# ----------------------------
print_tf_expected_summary() {
  local total
  total="$(wc -l < "${tmpdir}/expected_resources.jsonl" | tr -d ' ')"
  echo "Expected (TF state): ${total} taggable azurerm_* resources"
  echo "Expected breakdown (TF resource types):"
  jq -r '.tf_type' "${tmpdir}/expected_resources.jsonl" | sort | uniq -c | sort -nr | sed 's/^/  /'
  echo

  if [[ "$total" -gt 0 ]]; then
    echo "Expected sample (up to ${PRINT_SAMPLE_LIMIT}):"
    jq -r '.tf_type + " | " + .address + " | " + .id' "${tmpdir}/expected_resources.jsonl" \
      | head -n "${PRINT_SAMPLE_LIMIT}" | sed 's/^/  /'
    echo
  fi
}

print_arg_actual_summary() {
  local total
  total="$(wc -l < "${tmpdir}/actual_resources.jsonl" | tr -d ' ')"
  echo "Actual (ARG): ${total} resources"
  echo "Actual breakdown (ARM types):"
  jq -r '.type' "${tmpdir}/actual_resources.jsonl" | sort | uniq -c | sort -nr | sed 's/^/  /'
  echo

  if [[ "$total" -gt 0 ]]; then
    echo "Actual sample (up to ${PRINT_SAMPLE_LIMIT}):"
    jq -r '.type + " | " + .name + " | " + .id' "${tmpdir}/actual_resources.jsonl" \
      | head -n "${PRINT_SAMPLE_LIMIT}" | sed 's/^/  /'
    echo
  fi
}

# ----------------------------
# Tag checking (DeploymentId + Phase only; case-insensitive keys)
# ----------------------------
validate_two_tags() {
  jq -c --arg dep "$DEPLOYMENT_ID" --arg phase "$PHASE_TAG" '
    def norm_keys:
      to_entries
      | map({( .key | ascii_downcase): (if .value == null then "" else (.value|tostring) end)})
      | add;

    ((.tags // {}) | norm_keys) as $t
    | {
        ok: (
          ($t["deploymentid"]? // "") == $dep
          and
          ($t["phase"]? // "") == $phase
        ),
        actualDeploymentId: ($t["deploymentid"]? // "<missing>"),
        actualPhase:        ($t["phase"]? // "<missing>")
      }
  '
}

arm_get_resource_json() {
  local rid="$1"
  az resource show --ids "$rid" --only-show-errors -o json
}

expected_check() {
  print_tf_expected_summary

  local missing=0
  local tag_errors=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local rid addr rtype
    rid="$(echo "$line" | jq -r '.id')"
    addr="$(echo "$line" | jq -r '.address')"
    rtype="$(echo "$line" | jq -r '.tf_type')"

    local res_json
    if ! res_json="$(arm_get_resource_json "$rid" 2>/dev/null)"; then
      missing=$((missing + 1))
      echo "  MISSING: ${addr} (${rtype})"
      echo "    id: ${rid}"
      continue
    fi

    local verdict_arm
    verdict_arm="$(echo "$res_json" | jq -c '{tags:(.tags // {})}' | validate_two_tags)"
    if [[ "$(echo "$verdict_arm" | jq -r '.ok')" != "true" ]]; then
      tag_errors=$((tag_errors + 1))
      echo "  TAG_ERROR: ${addr} (${rtype})"
      echo "    id: ${rid}"
      echo "    DeploymentId: expected=${DEPLOYMENT_ID} actual=$(echo "$verdict_arm" | jq -r '.actualDeploymentId')"
      echo "    Phase:        expected=${PHASE_TAG} actual=$(echo "$verdict_arm" | jq -r '.actualPhase')"
    fi
  done < "${tmpdir}/expected_resources.jsonl"

  echo
  echo "Expected check summary:"
  echo "  missing resources: ${missing}"
  echo "  tag errors:        ${tag_errors}"
  echo

  [[ "$missing" -eq 0 && "$tag_errors" -eq 0 ]]
}

arg_scan() {
  if ! az graph query -h >/dev/null 2>&1; then
    echo "ERROR: 'az graph query' is not available. Install the Azure Resource Graph extension:" >&2
    echo "  az extension add --name resource-graph" >&2
    echo "Or run with --mode expected." >&2
    return 2
  fi

  local current_sub
  current_sub="$(az account show --query id -o tsv)"

  local dep_esc phase_esc
  dep_esc="$(escape_kusto_string "$DEPLOYMENT_ID")"
  phase_esc="$(escape_kusto_string "$PHASE_TAG")"

  local kusto
  kusto=$(
    cat <<EOF
Resources
| where tostring(tags['DeploymentId']) == '${dep_esc}'
| where tostring(tags['Phase']) == '${phase_esc}'
EOF
  )

  if [[ -n "$PREFIX" ]]; then
    local pref_esc
    pref_esc="$(escape_kusto_string "$PREFIX")"
    kusto+=$'\n'"| where name startswith '${pref_esc}'"
  fi

  kusto+=$'\n'"| project id, name, type, tags"

  : > "${tmpdir}/actual_resources.jsonl"

  local skip=0
  while :; do
    local resp
    resp="$(az graph query -q "$kusto" --first 1000 --skip "$skip" --subscriptions "$current_sub" --only-show-errors -o json)"

    echo "$resp" | jq -c '.data[]? | {id:.id, name:.name, type:.type, tags:(.tags // {})}' \
      >> "${tmpdir}/actual_resources.jsonl"

    local count total
    count="$(echo "$resp" | jq -r '.count // (.data|length)')"
    total="$(echo "$resp" | jq -r '.totalRecords // 0')"

    [[ "$count" -eq 0 ]] && break
    skip=$((skip + count))
    [[ "$skip" -ge "$total" ]] && break
  done

  echo "Scanning ARM (Azure Resource Graph) for resources with tags DeploymentId=${DEPLOYMENT_ID}, Phase=${PHASE_TAG} ..."
  echo
  print_arg_actual_summary

  jq -r '.id' "${tmpdir}/expected_resources.jsonl" | sed '/^$/d' | sort -u > "${tmpdir}/expected_ids.txt"
  jq -r '.id' "${tmpdir}/actual_resources.jsonl"   | sed '/^$/d' | sort -u > "${tmpdir}/actual_ids.txt"

  comm -23 "${tmpdir}/expected_ids.txt" "${tmpdir}/actual_ids.txt" > "${tmpdir}/missing_scan.txt" || true
  comm -13 "${tmpdir}/expected_ids.txt" "${tmpdir}/actual_ids.txt" > "${tmpdir}/extra_scan.txt"   || true

  local missing extra
  missing="$(wc -l < "${tmpdir}/missing_scan.txt" | tr -d ' ')"
  extra="$(wc -l < "${tmpdir}/extra_scan.txt" | tr -d ' ')"

  echo "scan compare:"
  echo "  expected: $(wc -l < "${tmpdir}/expected_ids.txt" | tr -d ' ')"
  echo "  actual:   $(wc -l < "${tmpdir}/actual_ids.txt" | tr -d ' ')"
  echo "  missing:  ${missing}"
  echo "  extra:    ${extra}"
  echo

  local fail=0

  if [[ "$missing" -gt 0 ]]; then
    echo "Missing resources (in TF state, not found in ARM scan by DeploymentId+Phase):"
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      local info
      info="$(jq -r --arg id "$id" 'select(.id==$id) | (.tf_type + " | " + .address + " | " + .id)' "${tmpdir}/expected_resources.jsonl" 2>/dev/null || true)"
      if [[ -n "$info" ]]; then
        echo "  - ${info}"
      else
        echo "  - ${id}"
      fi
    done < "${tmpdir}/missing_scan.txt"
    echo
    fail=1
  fi

  if [[ "$extra" -gt 0 ]]; then
    echo "Extra resources (found in ARM scan by DeploymentId+Phase, not present in TF state):"
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      local info
      info="$(jq -r --arg id "$id" 'select(.id==$id) | (.type + " | " + .name + " | " + .id)' "${tmpdir}/actual_resources.jsonl" 2>/dev/null || true)"
      if [[ -n "$info" ]]; then
        echo "  - ${info}"
      else
        echo "  - ${id}"
      fi
    done < "${tmpdir}/extra_scan.txt"
    echo
    if [[ "$FAIL_ON_EXTRA" == "true" ]]; then
      fail=1
    fi
  fi

  return "$fail"
}

rc=0

if [[ "$MODE" == "expected" || "$MODE" == "both" ]]; then
  if ! expected_check; then
    rc=1
  fi
fi

if [[ "$MODE" == "scan" || "$MODE" == "both" ]]; then
  if ! arg_scan; then
    rc=1
  fi
fi

if [[ "$rc" -ne 0 ]]; then
  echo "ERROR: ARM tag verification failed."
  exit 1
fi

echo "OK: ARM resources with tags DeploymentId=${DEPLOYMENT_ID} and Phase=${PHASE_TAG} match Terraform state."
exit 0
