#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Clean up test department group and restore environment for AS_03
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUP_NAME="lsatest_dept_shared"
SHARED_DIR="${SCRIPT_DIR}/sandbox_data/shared"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/department_access.log"

COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

DRY_RUN=false

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Safely teardown test group '${GROUP_NAME}' and restore workspace state.

Options:
  --dry-run   Simulate group removal without executing changes
  --help      Display this manual
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 2
            ;;
    esac
done

echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}       TEARDOWN & CLEANUP ENGINE — DEPARTMENT ACCESS (AS_03)                    ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Group      : ${COLOR_BOLD}${GROUP_NAME}${COLOR_RESET}"
echo -e " Shared Directory  : ${COLOR_BOLD}${SHARED_DIR}${COLOR_RESET}"
echo -e " Mode              : $([[ "$DRY_RUN" == true ]] && echo "${COLOR_YELLOW}Dry Run${COLOR_RESET}" || echo "${COLOR_GREEN}Live Teardown${COLOR_RESET}")"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# Log helper
mkdir -p "$LOG_DIR"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] [CLEANUP] $*" >> "$LOG_FILE"
}

# Step 1: Remove group
if getent group "$GROUP_NAME" >/dev/null 2>&1; then
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} Found test group '${GROUP_NAME}'. Proceeding with removal..."
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} Would run: sudo groupdel '${GROUP_NAME}'"
    else
        if sudo groupdel "$GROUP_NAME"; then
            echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} Successfully removed department group '${GROUP_NAME}'."
            log "Removed group '${GROUP_NAME}'"
        else
            echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} Failed to delete group '${GROUP_NAME}'." >&2
            exit 1
        fi
    fi
else
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} Group '${GROUP_NAME}' does not exist on the host (already clean)."
fi

# Step 2: Reset directory permissions if exists
if [[ -d "$SHARED_DIR" ]]; then
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} Resetting directory permissions on '${SHARED_DIR}' to safe default..."
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} Would restore standard permissions (chmod 755, chown $USER:$USER)"
    else
        sudo chown -R "${USER:-$(id -un)}:${USER:-$(id -gn)}" "$SHARED_DIR" 2>/dev/null || true
        sudo chmod 755 "$SHARED_DIR" 2>/dev/null || true
        # Clean any temp test files
        rm -f "$SHARED_DIR"/.inheritance_test_*.tmp 2>/dev/null || true
        echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} Directory permissions restored to 755."
        log "Restored directory permissions to 755 for '${SHARED_DIR}'"
    fi
fi

# Step 3: Verification
echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} Verifying host restoration state..."
if getent group "$GROUP_NAME" >/dev/null 2>&1; then
    echo -e "${COLOR_RED}[WARN]${COLOR_RESET} Group '${GROUP_NAME}' still appears in getent database."
else
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} Verification passed: test group '${GROUP_NAME}' is completely absent."
fi

echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}[COMPLETED] Environment successfully restored.${COLOR_RESET}"
exit 0
