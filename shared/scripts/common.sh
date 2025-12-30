#!/bin/bash
# Shared Common Functions
# Used by: infra-foundation, infra-identity, infra-platform
# Version: 1.0.0
#
# This file contains common shell functions used across all infrastructure repositories.
# Source this file at the beginning of your scripts:
#
#   REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   source "${REPO_ROOT}/shared/scripts/common.sh"

set -euo pipefail

#------------------------------------------------------------------------------
# Output Functions
#------------------------------------------------------------------------------

print_header() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
  echo ""
}

print_success() {
  echo "✓ $1"
}

print_error() {
  echo "✗ $1" >&2
}

print_warning() {
  echo "⚠ $1"
}

print_info() {
  echo "ℹ $1"
}

#------------------------------------------------------------------------------
# Command Checks
#------------------------------------------------------------------------------

check_command() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    print_error "Required command not found: $cmd"
    return 1
  fi
  return 0
}

check_required_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    print_error "Missing required commands: ${missing[*]}"
    return 1
  fi
  return 0
}

#------------------------------------------------------------------------------
# Azure CLI Helpers
#------------------------------------------------------------------------------

check_azure_login() {
  if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Run: az login"
    return 1
  fi
  return 0
}

get_subscription_id() {
  az account show --query id -o tsv
}

get_tenant_id() {
  az account show --query tenantId -o tsv
}

check_resource_exists() {
  local resource_id="$1"
  az resource show --ids "$resource_id" &> /dev/null
}

#------------------------------------------------------------------------------
# Environment Helpers
#------------------------------------------------------------------------------

validate_environment() {
  local env="$1"
  case "$env" in
    dev|test|stage|prod)
      return 0
      ;;
    *)
      print_error "Invalid environment: $env. Must be one of: dev, test, stage, prod"
      return 1
      ;;
  esac
}

load_env_file() {
  local env_file="${1:-.env}"
  if [ ! -f "$env_file" ]; then
    print_error "Environment file not found: $env_file"
    return 1
  fi
  
  print_info "Loading environment from: $env_file"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
  return 0
}

get_project_root() {
  # Detect project root (location of this script)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Shared scripts are in <root>/shared/scripts/, so go up 2 levels
  echo "$(cd "${script_dir}/../.." && pwd)"
}

#------------------------------------------------------------------------------
# Git Helpers
#------------------------------------------------------------------------------

validate_conventional_commit() {
  local commit_msg="$1"
  local pattern='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'
  
  if [[ ! "$commit_msg" =~ $pattern ]]; then
    print_error "Commit message does not follow Conventional Commits format"
    print_info "Expected format: type(scope): description"
    print_info "Valid types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    return 1
  fi
  return 0
}

#------------------------------------------------------------------------------
# Version Info
#------------------------------------------------------------------------------

print_version() {
  echo "Shared Scripts Library v1.0.0"
  echo "Part of ecare-infrastructure monorepo"
}

