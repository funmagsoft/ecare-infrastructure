#!/usr/bin/env bash

set -euo pipefail

# verify-deploymentid-azuread.sh
#
# Verifies Entra ID objects named like: <name>-<DeploymentId>
# by comparing Microsoft Graph results with expected objects derived from Terraform state (azuread_*).
#
# Modes:
# - expected: only checks that TF-expected objects exist in Entra (direct lookup by IDs)
# - scan:     scans Entra for objects whose displayName ends with "-<DeploymentId>" and compares with TF
# - both:     expected + scan (default)
#
# Optional behavior:
# - --fail-on-extra true|false (default: true)
#   If false, "extra" objects found during scan will be reported but will NOT fail the script.
#   Missing objects always fail (because TF expected them to exist).

TF_DIR=""
DEPLOYMENT_ID=""
MODE="both"          # expected | scan | both
PREFIX=""            # optional optimization: startswith(displayName,'prefix') AND endswith(...)
FAIL_ON_EXTRA="true"

INCLUDE_APPS="true"
INCLUDE_SPS="true"
INCLUDE_GROUPS="true"

help() {
  cat <<'EOF'
verify-deploymentid-azuread.sh

Compares Entra ID objects named like:
  <name>-<DeploymentId>
against expected objects from Terraform state (azuread provider).

Usage:
  verify-deploymentid-azuread.sh --tf-dir <path> [options]

Required:
  --tf-dir <path>              Path to the Terraform root module directory (required).

Options:
  --deployment-id <id>         DeploymentId value. If omitted, the script will try:
                               terraform output -raw deployment_id
                               terraform output -raw DeploymentId
  --mode <expected|scan|both>  expected: verify TF-expected objects exist in Entra (direct lookup)
                               scan:     list Entra objects by suffix and report missing/extra vs TF
                               both:     do both (default)
  --prefix <string>            Optional optimization: adds startswith(displayName,'<prefix>') to Graph filter.
  --fail-on-extra <true|false> If false, "extra" objects in scan mode do NOT fail the script (reported only).
                               Missing objects always fail.
                               Default: true
  --no-apps                    Skip applications (azuread_application).
  --no-sps                     Skip service principals (azuread_service_principal).
  --no-groups                  Skip groups (azuread_group).
  -h, --help                   Show this help and exit.

Notes:
  - Scan mode uses Microsoft Graph advanced queries (endswith), requiring:
      Header: ConsistencyLevel: eventual
      Query:  $count=true
    If your tenant/policies restrict this, use --mode expected.

Examples:
  ./verify-deploymentid-azuread.sh --tf-dir ./infra-identity/terraform/environments/dev --deployment-id a1b2c3d4
  ./verify-deploymentid-azuread.sh --tf-dir ./infra-foundation/terraform/environments/dev --mode both --fail-on-extra false
EOF
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tf-dir)          TF_DIR="$2"; shift 2 ;;
    --deployment-id)   DEPLOYMENT_ID="$2"; shift 2 ;;
    --mode)            MODE="$2"; shift 2 ;;
    --prefix)          PREFIX="$2"; shift 2 ;;
    --fail-on-extra)   FAIL_ON_EXTRA="$2"; shift 2 ;;
    --no-apps)         INCLUDE_APPS="false"; shift 1 ;;
    --no-sps)          INCLUDE_SPS="false"; shift 1 ;;
    --no-groups)       INCLUDE_GROUPS="false"; shift 1 ;;
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

# Ensure Azure CLI is authenticated
az account show --only-show-errors >/dev/null

# ----------------------------
# DeploymentId
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

SUFFIX="-${DEPLOYMENT_ID}"

echo "Terraform dir:    ${TF_DIR}"
echo "DeploymentId:     ${DEPLOYMENT_ID}"
echo "Suffix match:     *${SUFFIX}"
echo "Mode:             ${MODE}"
echo "Prefix opt:       ${PREFIX:-<none>}"
echo "Fail on extra:    ${FAIL_ON_EXTRA}"
echo

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ----------------------------
# Terraform state (expected)
# ----------------------------
STATE_JSON="$(terraform -chdir="$TF_DIR" show -json)"

extract_expected_apps_jsonl() {
  echo "$STATE_JSON" | jq -c --arg suffix "$SUFFIX" '
    def collect_resources(m):
      (m.resources // []) + ((m.child_modules // []) | map(collect_resources(.)) | add);

    collect_resources(.values.root_module)
    | map(select(.mode == "managed"))
    | map(select(.type == "azuread_application"))
    | map({
        kind: "application",
        object_id: (.values.object_id // empty),
        app_id:    (.values.client_id // .values.application_id // empty),
        display_name: (.values.display_name // empty)
      })
    | map(select(.display_name != "" and (.display_name | endswith($suffix))))
    | unique_by(.object_id, .app_id, .display_name)
    | .[]
  '
}

extract_expected_sps_jsonl() {
  echo "$STATE_JSON" | jq -c --arg suffix "$SUFFIX" '
    def collect_resources(m):
      (m.resources // []) + ((m.child_modules // []) | map(collect_resources(.)) | add);

    collect_resources(.values.root_module)
    | map(select(.mode == "managed"))
    | map(select(.type == "azuread_service_principal"))
    | map({
        kind: "servicePrincipal",
        object_id: (.values.object_id // empty),
        app_id:    (.values.client_id // .values.application_id // empty),
        display_name: (.values.display_name // empty)
      })
    | map(select(.display_name != "" and (.display_name | endswith($suffix))))
    | unique_by(.object_id, .app_id, .display_name)
    | .[]
  '
}

extract_expected_groups_jsonl() {
  echo "$STATE_JSON" | jq -c --arg suffix "$SUFFIX" '
    def collect_resources(m):
      (m.resources // []) + ((m.child_modules // []) | map(collect_resources(.)) | add);

    collect_resources(.values.root_module)
    | map(select(.mode == "managed"))
    | map(select(.type == "azuread_group"))
    | map({
        kind: "group",
        object_id: (.values.object_id // empty),
        display_name: (.values.display_name // empty)
      })
    | map(select(.display_name != "" and (.display_name | endswith($suffix))))
    | unique_by(.object_id, .display_name)
    | .[]
  '
}

: > "${tmpdir}/expected_apps.jsonl"
: > "${tmpdir}/expected_sps.jsonl"
: > "${tmpdir}/expected_groups.jsonl"

if [[ "$INCLUDE_APPS" == "true" ]]; then
  extract_expected_apps_jsonl   > "${tmpdir}/expected_apps.jsonl"
fi
if [[ "$INCLUDE_SPS" == "true" ]]; then
  extract_expected_sps_jsonl    > "${tmpdir}/expected_sps.jsonl"
fi
if [[ "$INCLUDE_GROUPS" == "true" ]]; then
  extract_expected_groups_jsonl > "${tmpdir}/expected_groups.jsonl"
fi

# ----------------------------
# Graph helpers
# ----------------------------
graph_escape_odata() {
  printf "%s" "$1" | sed "s/'/''/g"
}

graph_list_all() {
  local url="$1"
  local mode="${2:-normal}"

  while [[ -n "$url" ]]; do
    local resp
    if [[ "$mode" == "advanced" ]]; then
      resp="$(az rest --method GET --uri "$url" --headers "ConsistencyLevel=eventual" --only-show-errors -o json)"
    else
      resp="$(az rest --method GET --uri "$url" --only-show-errors -o json)"
    fi

    echo "$resp" | jq -c '.value[]?'
    url="$(echo "$resp" | jq -r '."@odata.nextLink" // empty')"
  done
}

odata_filter_for_suffix() {
  local suffix_escaped prefix_escaped
  suffix_escaped="$(graph_escape_odata "$SUFFIX")"

  if [[ -n "$PREFIX" ]]; then
    prefix_escaped="$(graph_escape_odata "$PREFIX")"
    printf "startswith(displayName,'%s') and endswith(displayName,'%s')" "$prefix_escaped" "$suffix_escaped"
  else
    printf "endswith(displayName,'%s')" "$suffix_escaped"
  fi
}

# ----------------------------
# Scan actual objects (Graph advanced query)
# ----------------------------
scan_actual_apps() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/applications?\$select=id,appId,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" "advanced" \
    | jq -c '{kind:"application", object_id:.id, app_id:.appId, display_name:.displayName}'
}

scan_actual_sps() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/servicePrincipals?\$select=id,appId,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" "advanced" \
    | jq -c '{kind:"servicePrincipal", object_id:.id, app_id:.appId, display_name:.displayName}'
}

scan_actual_groups() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/groups?\$select=id,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" "advanced" \
    | jq -c '{kind:"group", object_id:.id, display_name:.displayName}'
}

# ----------------------------
# Direct existence checks (no advanced queries required)
# ----------------------------
graph_get_application_by_object_id() {
  local oid="$1"
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications/${oid}?\$select=id,appId,displayName" \
    --only-show-errors -o json >/dev/null
}

graph_get_application_by_app_id() {
  local appid="$1"
  local appid_escaped
  appid_escaped="$(graph_escape_odata "$appid")"
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications?\$select=id,appId,displayName&\$filter=appId eq '${appid_escaped}'" \
    --only-show-errors -o json
}

graph_get_sp_by_object_id() {
  local oid="$1"
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/${oid}?\$select=id,appId,displayName" \
    --only-show-errors -o json >/dev/null
}

graph_get_group_by_object_id() {
  local oid="$1"
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/groups/${oid}?\$select=id,displayName" \
    --only-show-errors -o json >/dev/null
}

expected_direct_check() {
  local label="$1" expected_file="$2" kind="$3"
  local missing=0

  local count
  count="$(wc -l < "$expected_file" | tr -d ' ')"
  echo "${label}: expected ${count} (direct Graph existence check)"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local oid appid dname
    oid="$(echo "$line" | jq -r '.object_id // empty')"
    appid="$(echo "$line" | jq -r '.app_id // empty')"
    dname="$(echo "$line" | jq -r '.display_name // empty')"

    local ok="false"
    if [[ "$kind" == "application" ]]; then
      if [[ -n "$oid" ]] && graph_get_application_by_object_id "$oid"; then
        ok="true"
      elif [[ -n "$appid" ]]; then
        if graph_get_application_by_app_id "$appid" | jq -e '.value | length > 0' >/dev/null 2>&1; then
          ok="true"
        fi
      fi
    elif [[ "$kind" == "servicePrincipal" ]]; then
      if [[ -n "$oid" ]] && graph_get_sp_by_object_id "$oid"; then
        ok="true"
      fi
    elif [[ "$kind" == "group" ]]; then
      if [[ -n "$oid" ]] && graph_get_group_by_object_id "$oid"; then
        ok="true"
      fi
    fi

    if [[ "$ok" != "true" ]]; then
      missing=$((missing + 1))
      if [[ "$kind" == "application" ]]; then
        echo "  MISSING: ${dname} | object_id=${oid:-"-"} | app_id=${appid:-"-"}"
      else
        echo "  MISSING: ${dname} | object_id=${oid:-"-"}"
      fi
    fi
  done < "$expected_file"

  if [[ "$missing" -gt 0 ]]; then
    echo "${label}: missing ${missing}"
    return 1
  fi

  echo "${label}: OK"
  return 0
}

# ----------------------------
# Scan compare (with --fail-on-extra behavior)
# Missing always fails; extra fails only if FAIL_ON_EXTRA=true
# ----------------------------
compare_scan_sets() {
  local label="$1" expected_file="$2" actual_file="$3"
  local fail=0

  jq -r '.object_id // empty' "$expected_file" | sed '/^$/d' | sort -u > "${tmpdir}/${label}_expected_ids.txt"
  jq -r '.object_id // empty' "$actual_file"   | sed '/^$/d' | sort -u > "${tmpdir}/${label}_actual_ids.txt"

  comm -23 "${tmpdir}/${label}_expected_ids.txt" "${tmpdir}/${label}_actual_ids.txt" > "${tmpdir}/${label}_missing_scan.txt" || true
  comm -13 "${tmpdir}/${label}_expected_ids.txt" "${tmpdir}/${label}_actual_ids.txt" > "${tmpdir}/${label}_extra_scan.txt"   || true

  local missing extra
  missing="$(wc -l < "${tmpdir}/${label}_missing_scan.txt" | tr -d ' ')"
  extra="$(wc -l < "${tmpdir}/${label}_extra_scan.txt" | tr -d ' ')"

  echo "${label} (scan compare):"
  echo "  expected: $(wc -l < "${tmpdir}/${label}_expected_ids.txt" | tr -d ' ')"
  echo "  actual:   $(wc -l < "${tmpdir}/${label}_actual_ids.txt" | tr -d ' ')"
  echo "  missing:  ${missing}"
  echo "  extra:    ${extra}"
  echo

  if [[ "$missing" -gt 0 ]]; then
    echo "  Missing ${label} (in TF state, not found by suffix scan):"
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      jq -r --arg id "$id" '
        select(.object_id==$id)
        | "    - \(.display_name) | object_id=\(.object_id) | app_id=\(.app_id // "-")"
      ' "$expected_file" 2>/dev/null || true
      echo "    - ${id}"
    done < "${tmpdir}/${label}_missing_scan.txt"
    echo
    fail=1
  fi

  if [[ "$extra" -gt 0 ]]; then
    echo "  Extra ${label} (found in Entra by suffix scan, not present in TF state):"
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      jq -r --arg id "$id" '
        select(.object_id==$id)
        | "    - \(.display_name) | object_id=\(.object_id) | app_id=\(.app_id // "-")"
      ' "$actual_file" 2>/dev/null || true
      echo "    - ${id}"
    done < "${tmpdir}/${label}_extra_scan.txt"
    echo
    if [[ "$FAIL_ON_EXTRA" == "true" ]]; then
      fail=1
    fi
  fi

  return "$fail"
}

rc=0

# 1) expected existence
if [[ "$MODE" == "expected" || "$MODE" == "both" ]]; then
  if [[ "$INCLUDE_APPS" == "true" ]]; then
    expected_direct_check "apps" "${tmpdir}/expected_apps.jsonl" "application" || rc=1
    echo
  fi
  if [[ "$INCLUDE_SPS" == "true" ]]; then
    expected_direct_check "service_principals" "${tmpdir}/expected_sps.jsonl" "servicePrincipal" || rc=1
    echo
  fi
  if [[ "$INCLUDE_GROUPS" == "true" ]]; then
    expected_direct_check "groups" "${tmpdir}/expected_groups.jsonl" "group" || rc=1
    echo
  fi
fi

# 2) scan & compare
if [[ "$MODE" == "scan" || "$MODE" == "both" ]]; then
  echo "Scanning Entra (Microsoft Graph) for objects with suffix ${SUFFIX} ..." >&2

  : > "${tmpdir}/actual_apps.jsonl"
  : > "${tmpdir}/actual_sps.jsonl"
  : > "${tmpdir}/actual_groups.jsonl"

  if [[ "$INCLUDE_APPS" == "true" ]]; then
    scan_actual_apps   > "${tmpdir}/actual_apps.jsonl"
  fi
  if [[ "$INCLUDE_SPS" == "true" ]]; then
    scan_actual_sps    > "${tmpdir}/actual_sps.jsonl"
  fi
  if [[ "$INCLUDE_GROUPS" == "true" ]]; then
    scan_actual_groups > "${tmpdir}/actual_groups.jsonl"
  fi

  if [[ "$INCLUDE_APPS" == "true" ]]; then
    compare_scan_sets "apps" "${tmpdir}/expected_apps.jsonl" "${tmpdir}/actual_apps.jsonl" || rc=1
  fi
  if [[ "$INCLUDE_SPS" == "true" ]]; then
    compare_scan_sets "service_principals" "${tmpdir}/expected_sps.jsonl" "${tmpdir}/actual_sps.jsonl" || rc=1
  fi
  if [[ "$INCLUDE_GROUPS" == "true" ]]; then
    compare_scan_sets "groups" "${tmpdir}/expected_groups.jsonl" "${tmpdir}/actual_groups.jsonl" || rc=1
  fi
fi

if [[ "$rc" -ne 0 ]]; then
  echo "ERROR: Entra DeploymentId verification failed."
  exit 1
fi

echo "OK: Entra objects with suffix ${SUFFIX} match Terraform state (within selected object kinds)."
exit 0
