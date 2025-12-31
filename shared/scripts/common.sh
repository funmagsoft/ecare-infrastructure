#!/usr/bin/env bash
# Shared Common Library (modular)
# Public API consumed by infra-*/scripts/*.sh

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"

# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/log.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/error.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/dry_run.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/env.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/fs.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/az.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/checks.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/git.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/init.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/naming.sh"
# shellcheck source=/dev/null
source "${SCRIPT_LIB_DIR}/vpn.sh"

# Backward-compatible names
load_dotenv() { dotenv_load_if_exists "$REPO_ROOT"; }
run_cmd() { cmd_exec "$@"; }
run_cmd_capture() { cmd_exec "$@"; }
write_file() { file_append_line "$1" "$2"; }
clear_file() { file_clear "$1"; }
log_dry_run() { log_dry_run_banner; }

print_version() {
  echo "Shared Scripts Library (modular)"
}
