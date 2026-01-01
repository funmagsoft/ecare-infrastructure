#!/usr/bin/env bash

set -euo pipefail

# cleanup-deployment-azuread.sh
#
# Deletes Entra ID objects by displayName suffix:
#   *-<phase>-<deploymentid>
# where phase is lowercase: foundation|platform|workload
#
# Objects:
#  - servicePrincipals
#  - applications
#  - groups
#
# Uses Microsoft Graph advanced queries (endswith) and requires:
#   Header: ConsistencyLevel: eventual
#   Query:  $count=true
# :contentReference[oaicite:4]{index=4}
#
# SAFETY:
#   Default is dry-run. To delete, pass:
#     --apply --confirm "DELETE <deploymentId> <phase>"

TF_DIR=""
DEPLOYMENT_ID=""
PHASE_IN=""
PHASE_ENTRA=""
PHASE_ARM=""

PREFIX=""
APPLY="false"
CONFIRM=""
INCLUDE_APPS="true"
INCLUDE_SPS="true"
INCLUDE_GROUPS="true"

help() {
  cat <<'EOF'
cleanup-deployment-azuread.sh

Deletes Entra ID objects by displayName suffix:
  *-<phase>-<deploymentid>

Usage:
  cleanup-deployment-azuread.sh --deployment-id <id> --phase <foundation|platform|workload> [options]
  cleanup-deployment-azuread.sh --tf-dir <path> --phase <foundation|platform|workload> [options]

Required:
  --phase <value>               Phase scope (case-insensitive): foundation|platform|workload
  AND one of:
    --deployment-id <id>         DeploymentId value
    --tf-dir <path>              Terraform root module dir (reads terraform output -raw deployment_id/DeploymentId)

Options:
  --prefix <string>             Optional optimization: startswith(displayName,'<prefix>') AND endswith(...)
  --apply                        Perform deletions (otherwise dry-run)
  --confirm <string>             Must equal: "DELETE <deploymentId> <phase>"
                                 Example: --confirm "DELETE a1b2c3d4 foundation"
  --no-apps                      Skip applications deletion
  --no-sps                       Skip service principals deletion
  --no-groups                    Skip groups deletion
  -h, --help                     Show help

Examples:
  ./cleanup-deployment-azuread.sh --deployment-id a1b2c3d4 --phase foundation
  ./cleanup-deployment-azuread.sh --tf-dir ./workload/terraform/environments/dev --phase foundation
  ./cleanup-deployment-azuread.sh --deployment-id a1b2c3d4 --phase foundation --apply --confirm "DELETE a1b2c3d4 foundation"
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
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --tf-dir)        TF_DIR="$2"; shift 2 ;;
    --phase)         PHASE_IN="$2"; shift 2 ;;
    --prefix)        PREFIX="$2"; shift 2 ;;
    --apply)         APPLY="true"; shift 1 ;;
    --confirm)       CONFIRM="$2"; shift 2 ;;
    --no-apps)       INCLUDE_APPS="false"; shift 1 ;;
    --no-sps)        INCLUDE_SPS="false"; shift 1 ;;
    --no-groups)     INCLUDE_GROUPS="false"; shift 1 ;;
    -h|--help)       help; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; echo >&2; help >&2; exit 2 ;;
  esac
done

if [[ -z "$PHASE_IN" ]]; then
  echo "ERROR: --phase is required." >&2
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

# Ensure Azure CLI is authenticated
az account show --only-show-errors >/dev/null

# DeploymentId from TF (optional)
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

SUFFIX="-${PHASE_ENTRA}-${DEPLOYMENT_ID}"

echo "DeploymentId:     ${DEPLOYMENT_ID}"
echo "Phase (Entra):    ${PHASE_ENTRA}"
echo "Phase (ARM):      ${PHASE_ARM}"
echo "Suffix match:     *${SUFFIX}"
echo "Prefix opt:       ${PREFIX:-<none>}"
echo "Mode:             $([[ "$APPLY" == "true" ]] && echo APPLY || echo DRY-RUN)"
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

graph_escape_odata() {
  printf "%s" "$1" | sed "s/'/''/g"
}

graph_list_all() {
  local url="$1"
  while [[ -n "$url" ]]; do
    local resp
    resp="$(az rest --method GET --uri "$url" --headers "ConsistencyLevel=eventual" --only-show-errors -o json)"
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

list_apps() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/applications?\$select=id,appId,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" | jq -c '{id:.id, appId:.appId, displayName:.displayName}'
}

list_sps() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/servicePrincipals?\$select=id,appId,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" | jq -c '{id:.id, appId:.appId, displayName:.displayName}'
}

list_groups() {
  local filter url
  filter="$(odata_filter_for_suffix)"
  url="https://graph.microsoft.com/v1.0/groups?\$select=id,displayName&\$count=true&\$filter=${filter}"
  graph_list_all "$url" | jq -c '{id:.id, displayName:.displayName}'
}

delete_graph_object() {
  local kind="$1" id="$2"
  local uri="https://graph.microsoft.com/v1.0/${kind}/${id}"

  if [[ "$APPLY" != "true" ]]; then
    echo "DRY-RUN: would DELETE ${uri}"
    return 0
  fi

  # delete; tolerate 404 (already removed)
  if az rest --method DELETE --uri "$uri" --only-show-errors >/dev/null 2>&1; then
    echo "DELETED: ${uri}"
    return 0
  fi

  # If it failed, try to print error (non-fatal here; we still want to continue)
  echo "WARN: failed to delete ${uri}" >&2
  return 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Collect
if [[ "$INCLUDE_SPS" == "true" ]]; then
  list_sps > "${tmpdir}/sps.jsonl" || true
else
  : > "${tmpdir}/sps.jsonl"
fi

if [[ "$INCLUDE_APPS" == "true" ]]; then
  list_apps > "${tmpdir}/apps.jsonl" || true
else
  : > "${tmpdir}/apps.jsonl"
fi

if [[ "$INCLUDE_GROUPS" == "true" ]]; then
  list_groups > "${tmpdir}/groups.jsonl" || true
else
  : > "${tmpdir}/groups.jsonl"
fi

sps_count="$(wc -l < "${tmpdir}/sps.jsonl" | tr -d ' ')"
apps_count="$(wc -l < "${tmpdir}/apps.jsonl" | tr -d ' ')"
groups_count="$(wc -l < "${tmpdir}/groups.jsonl" | tr -d ' ')"

echo "Found (by suffix):"
echo "  servicePrincipals: ${sps_count}"
echo "  applications:      ${apps_count}"
echo "  groups:            ${groups_count}"
echo

if [[ "$sps_count" -eq 0 && "$apps_count" -eq 0 && "$groups_count" -eq 0 ]]; then
  echo "Nothing to delete."
  exit 0
fi

echo "Objects:"
if [[ "$sps_count" -gt 0 ]]; then
  echo "Service Principals:"
  jq -r '"  - " + .displayName + " | id=" + .id + " | appId=" + (.appId // "-")' "${tmpdir}/sps.jsonl"
  echo
fi
if [[ "$apps_count" -gt 0 ]]; then
  echo "Applications:"
  jq -r '"  - " + .displayName + " | id=" + .id + " | appId=" + (.appId // "-")' "${tmpdir}/apps.jsonl"
  echo
fi
if [[ "$groups_count" -gt 0 ]]; then
  echo "Groups:"
  jq -r '"  - " + .displayName + " | id=" + .id' "${tmpdir}/groups.jsonl"
  echo
fi

if [[ "$APPLY" != "true" ]]; then
  echo "DRY-RUN: no deletions performed. Re-run with --apply and correct --confirm to delete."
  exit 0
fi

# Delete order:
# 1) servicePrincipals
# 2) applications (deleting an application deletes its home-tenant service principal too) :contentReference[oaicite:5]{index=5}
# 3) groups

rc=0

if [[ "$INCLUDE_SPS" == "true" && "$sps_count" -gt 0 ]]; then
  echo "Deleting servicePrincipals..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    id="$(echo "$line" | jq -r '.id')"
    delete_graph_object "servicePrincipals" "$id" || rc=1
  done < "${tmpdir}/sps.jsonl"
  echo
fi

if [[ "$INCLUDE_APPS" == "true" && "$apps_count" -gt 0 ]]; then
  echo "Deleting applications..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    id="$(echo "$line" | jq -r '.id')"
    delete_graph_object "applications" "$id" || rc=1
  done < "${tmpdir}/apps.jsonl"
  echo
fi

if [[ "$INCLUDE_GROUPS" == "true" && "$groups_count" -gt 0 ]]; then
  echo "Deleting groups..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    id="$(echo "$line" | jq -r '.id')"
    delete_graph_object "groups" "$id" || rc=1
  done < "${tmpdir}/groups.jsonl"
  echo
fi

if [[ "$rc" -ne 0 ]]; then
  echo "ERROR: Some deletions failed. Check warnings above." >&2
  exit 1
fi

echo "OK: Entra cleanup complete for suffix *${SUFFIX}"
