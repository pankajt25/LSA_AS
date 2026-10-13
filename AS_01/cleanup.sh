#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_01)
# Problem Statement #1: Employee Account Setup
# Focus: User Management & Group Provisioning
# Script: cleanup.sh — Safe Teardown & Environment Restoration
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   This cleanup utility cleanly removes all test user accounts, home directories,
#   and empty departmental groups created during the AS_01 automation sprint.
#   It restores the operating system to its exact pre-test pristine state.
#
# SANDBOXING & SAFETY GUARANTEES:
#   1. Prefix Verification: ONLY usernames starting with 'lsatest_' can ever be
#      targeted for deletion. Any attempt to touch a non-test account is aborted.
#   2. Pre-Deletion Audit: Confirms account existence prior to running userdel.
#   3. Complete Purge: Executes 'sudo userdel -r <user>' to completely remove
#      the user entry from /etc/passwd, /etc/shadow, and /etc/group, while
#      purging the home directory (/home/<user>) and mail spool.
#   4. Post-Deletion Verification: Probes 'id <user>' to prove the account is gone.
#   5. Safe Group Cleanup: Inspects departmental groups and executes 'groupdel'
#      ONLY if no remaining users (supplementary or primary) belong to the group.
#   6. Full Audit Trail: Logs all teardown operations to logs/account_setup.log.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. COLOR & FORMATTING DEFINITIONS
# ------------------------------------------------------------------------------
USE_COLOR=true
init_colors() {
    if [ "${USE_COLOR}" = true ] && [ -t 1 ]; then
        CLR_RESET="\033[0m"
        CLR_BOLD="\033[1m"
        CLR_DIM="\033[2m"
        CLR_GREEN="\033[38;5;82m"
        CLR_CYAN="\033[38;5;51m"
        CLR_YELLOW="\033[38;5;220m"
        CLR_RED="\033[38;5;196m"
        CLR_BLUE="\033[38;5;39m"
        CLR_PURPLE="\033[38;5;141m"
    else
        CLR_RESET=""
        CLR_BOLD=""
        CLR_DIM=""
        CLR_GREEN=""
        CLR_CYAN=""
        CLR_YELLOW=""
        CLR_RED=""
        CLR_BLUE=""
        CLR_PURPLE=""
    fi
}
init_colors

# ------------------------------------------------------------------------------
# 2. PATHS & RUNTIME CONFIGURATION
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/account_setup.log"
DEFAULT_CSV="${SCRIPT_DIR}/employees.csv"

INPUT_CSV="${DEFAULT_CSV}"
DRY_RUN=false
REQUIRED_USER_PREFIX="lsatest_"

# ------------------------------------------------------------------------------
# 3. HELPER & LOGGING FUNCTIONS
# ------------------------------------------------------------------------------
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

mkdir -p "${LOG_DIR}"

log_msg() {
    local level="$1"
    local message="$2"
    local ts
    ts="$(get_timestamp)"
    
    echo "[${ts}] [CLEANUP-${level}] ${message}" >> "${LOG_FILE}"

    case "${level}" in
        "INFO")
            echo -e "${CLR_CYAN}[INFO]${CLR_RESET} ${message}"
            ;;
        "SUCCESS")
            echo -e "${CLR_GREEN}✓ [SUCCESS]${CLR_RESET} ${message}"
            ;;
        "WARN")
            echo -e "${CLR_YELLOW}⚠ [WARN]${CLR_RESET} ${message}"
            ;;
        "ERROR")
            echo -e "${CLR_RED}❌ [ERROR]${CLR_RESET} ${message}" >&2
            ;;
        "STEP")
            echo -e "${CLR_BOLD}${CLR_PURPLE}▶ ${message}${CLR_RESET}"
            ;;
        *)
            echo -e "[${level}] ${message}"
            ;;
    esac
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [CSV_FILE]

Safely removes test employee accounts and empty departmental groups created by AS_01.

ARGUMENTS:
  CSV_FILE                  Path to employee CSV file (default: ./employees.csv)

OPTIONS:
  -f, --file PATH           Specify employee CSV file
  -d, --dry-run             Simulate account deletion without making system modifications
      --no-color            Disable ANSI color escapes in terminal output
  -h, --help                Display this help documentation and exit

SANDBOXING GUARANTEE:
  Only user accounts prefixed with '${REQUIRED_USER_PREFIX}' will ever be deleted.
  Real system users are strictly protected.
EOF
}

# ------------------------------------------------------------------------------
# 4. PARSE COMMAND LINE ARGUMENTS
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--file)
            if [ -n "${2:-}" ]; then
                INPUT_CSV="$2"
                shift 2
            else
                log_msg "ERROR" "Option --file requires an argument."
                exit 1
            fi
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-color)
            USE_COLOR=false
            init_colors
            shift
            ;;
        -*)
            log_msg "ERROR" "Unknown command-line argument: $1"
            show_help
            exit 1
            ;;
        *)
            INPUT_CSV="$1"
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 5. ENVIRONMENT & PRIVILEGE VERIFICATION
# ------------------------------------------------------------------------------
OS_NAME="$(uname -s 2>/dev/null || echo 'Unknown')"
HOST_NAME="$(hostname 2>/dev/null || echo 'localhost')"

log_msg "STEP" "Initiating Safe Teardown & Environment Restoration (AS_01)"
log_msg "INFO" "Host: ${HOST_NAME} | OS: ${OS_NAME} | Target Inventory: ${INPUT_CSV}"

if [[ "${OS_NAME}" == "Darwin" ]]; then
    log_msg "ERROR" "macOS detected. Standard Linux userdel/groupdel tools are not available on macOS."
    exit 2
fi

if [ "${EUID}" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
        log_msg "ERROR" "Root privileges or passwordless sudo required for userdel/groupdel."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

if [ ! -f "${INPUT_CSV}" ]; then
    log_msg "ERROR" "Input employee CSV file not found: ${INPUT_CSV}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. TEARDOWN STATE TRACKING
# ------------------------------------------------------------------------------
USERS_REMOVED=0
USERS_NOT_FOUND=0
USERS_FAILED=0
GROUPS_REMOVED=0
GROUPS_PRESERVED=0
GROUPS_NOT_FOUND=0

declare -A UNIQUE_DEPTS=()
declare -a TARGET_USERS=()

# ------------------------------------------------------------------------------
# 7. PARSE CSV & TARGET USER REMOVAL
# ------------------------------------------------------------------------------
log_msg "STEP" "Stage 1: Removing Test User Accounts & Home Directories..."

while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
    line="$(echo "${raw_line}" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ -z "${line}" ]] || [[ "${line}" =~ ^# ]]; then
        continue
    fi

    IFS=',' read -r raw_user raw_name raw_dept <<< "${line}"
    user="$(echo "${raw_user:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    dept="$(echo "${raw_dept:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z "${user}" ]]; then
        continue
    fi

    # Record department for group cleanup phase
    if [[ -n "${dept}" ]]; then
        UNIQUE_DEPTS["${dept}"]=1
    fi

    # STRICT SAFETY CHECK: Refuse to touch any user not starting with lsatest_
    if [[ ! "${user}" =~ ^${REQUIRED_USER_PREFIX}[a-zA-Z0-9_]+$ ]]; then
        log_msg "ERROR" "Safety abort: '${user}' does not match prefix '${REQUIRED_USER_PREFIX}'. Skipping deletion!"
        USERS_FAILED=$(( USERS_FAILED + 1 ))
        continue
    fi

    TARGET_USERS+=("${user}")

    # Check if user account actually exists on this system
    if ! id "${user}" &>/dev/null && ! getent passwd "${user}" &>/dev/null; then
        log_msg "INFO" "User account '${user}' does not exist on this host; nothing to remove."
        USERS_NOT_FOUND=$(( USERS_NOT_FOUND + 1 ))
        continue
    fi

    # Execute removal
    log_msg "INFO" "Targeting test account: '${user}' (Safety prefix '${REQUIRED_USER_PREFIX}' verified)"
    
    if [ "${DRY_RUN}" = true ]; then
        log_msg "INFO" "[DRY-RUN] Would execute: ${SUDO} userdel -r ${user}"
        USERS_REMOVED=$(( USERS_REMOVED + 1 ))
        continue
    fi

    # userdel -r removes user, /home/<user>, and /var/mail/<user>
    if ${SUDO} userdel -r "${user}" 2>/dev/null; then
        # Post-deletion verification
        if ! id "${user}" &>/dev/null; then
            log_msg "SUCCESS" "User '${user}' and home directory successfully deleted."
            USERS_REMOVED=$(( USERS_REMOVED + 1 ))
        else
            log_msg "ERROR" "User '${user}' still exists according to 'id' command!"
            USERS_FAILED=$(( USERS_FAILED + 1 ))
        fi
    else
        # Try fallback userdel without mail spool error or force home directory cleanup
        log_msg "WARN" "userdel -r returned non-zero. Attempting force cleanup..."
        ${SUDO} userdel "${user}" 2>/dev/null || true
        if [ -d "/home/${user}" ]; then
            ${SUDO} rm -rf "/home/${user}" 2>/dev/null || true
        fi

        if ! id "${user}" &>/dev/null; then
            log_msg "SUCCESS" "User '${user}' removed via fallback cleanup."
            USERS_REMOVED=$(( USERS_REMOVED + 1 ))
        else
            log_msg "ERROR" "Failed to remove user account '${user}'!"
            USERS_FAILED=$(( USERS_FAILED + 1 ))
        fi
    fi

done < "${INPUT_CSV}"

# ------------------------------------------------------------------------------
# 8. STAGE 2: DEPARTMENT GROUPS AUDIT & CLEANUP
# ------------------------------------------------------------------------------
log_msg "STEP" "Stage 2: Auditing & Removing Empty Departmental Groups..."

for dept in "${!UNIQUE_DEPTS[@]}"; do
    # Check if group exists
    if ! getent group "${dept}" &>/dev/null; then
        log_msg "INFO" "Group '${dept}' does not exist; no removal required."
        GROUPS_NOT_FOUND=$(( GROUPS_NOT_FOUND + 1 ))
        continue
    fi

    dept_gid="$(getent group "${dept}" | cut -d: -f3)"

    # Audit remaining members in supplementary group list
    group_members="$(getent group "${dept}" | cut -d: -f4)"

    # Audit users who have this GID as their primary login group in /etc/passwd
    primary_users="$(awk -F: -v gid="${dept_gid}" '$4 == gid {print $1}' /etc/passwd | tr '\n' ' ')"

    # If any users remain, DO NOT delete group (could be real users or pre-existing system group)
    if [[ -n "${group_members}" ]] || [[ -n "${primary_users// /}" ]]; then
        log_msg "WARN" "Group '${dept}' (GID: ${dept_gid}) still contains users (Members: '${group_members}', Primary: '${primary_users}'). Preserving group to maintain system stability."
        GROUPS_PRESERVED=$(( GROUPS_PRESERVED + 1 ))
        continue
    fi

    # Group is empty and was introduced by the sprint
    log_msg "INFO" "Targeting empty test departmental group: '${dept}' (GID: ${dept_gid})"

    if [ "${DRY_RUN}" = true ]; then
        log_msg "INFO" "[DRY-RUN] Would execute: ${SUDO} groupdel ${dept}"
        GROUPS_REMOVED=$(( GROUPS_REMOVED + 1 ))
        continue
    fi

    if ${SUDO} groupdel "${dept}"; then
        if ! getent group "${dept}" &>/dev/null; then
            log_msg "SUCCESS" "Department group '${dept}' deleted successfully."
            GROUPS_REMOVED=$(( GROUPS_REMOVED + 1 ))
        else
            log_msg "ERROR" "Group '${dept}' still resolves via getent!"
        fi
    else
        log_msg "ERROR" "Failed to delete group '${dept}' via groupdel."
    fi
done

# ------------------------------------------------------------------------------
# 9. FINAL VERIFICATION & RESTORATION AUDIT
# ------------------------------------------------------------------------------
log_msg "STEP" "Stage 3: Verification of Pristine Environment..."

RESTORATION_CLEAN=true
for u in "${TARGET_USERS[@]}"; do
    if id "${u}" &>/dev/null; then
        log_msg "ERROR" "Pristine check failed: Test user '${u}' is STILL present!"
        RESTORATION_CLEAN=false
    fi
    if [ -d "/home/${u}" ]; then
        log_msg "ERROR" "Pristine check failed: Home directory '/home/${u}' still exists!"
        RESTORATION_CLEAN=false
    fi
done

echo "================================================================================"
echo -e "${CLR_BOLD}Summary of Teardown Operations:${CLR_RESET}"
echo -e "  User Accounts Removed        : ${CLR_GREEN}${CLR_BOLD}${USERS_REMOVED}${CLR_RESET}"
echo -e "  User Accounts Not Present    : ${CLR_DIM}${USERS_NOT_FOUND}${CLR_RESET}"
echo -e "  User Accounts Failed         : ${CLR_RED}${USERS_FAILED}${CLR_RESET}"
echo -e "  Department Groups Removed    : ${CLR_CYAN}${CLR_BOLD}${GROUPS_REMOVED}${CLR_RESET}"
echo -e "  Department Groups Preserved  : ${CLR_YELLOW}${GROUPS_PRESERVED}${CLR_RESET}"
echo -e "  Department Groups Not Present: ${CLR_DIM}${GROUPS_NOT_FOUND}${CLR_RESET}"
echo "================================================================================"

if [ "${RESTORATION_CLEAN}" = true ] && [ "${USERS_FAILED}" -eq 0 ]; then
    log_msg "SUCCESS" "Host environment has been cleanly restored to pristine pre-test state."
    exit 0
else
    log_msg "WARN" "Teardown finished with warnings or lingering entities. Please inspect logs."
    exit 1
fi
