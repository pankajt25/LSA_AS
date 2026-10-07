#!/usr/bin/env bash
# ==============================================================================
# Script: department_access.sh
# Purpose: Create a department group and configure a shared directory so that
#          only members of that group can access it (AS_03).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUP_NAME="lsatest_dept_shared"
SHARED_DIR="${SCRIPT_DIR}/sandbox_data/shared"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/department_access.log"
JSON_FILE="${LOG_DIR}/department_access.json"
PERM_MODE="2770"  # rwxrws--- (Owner: rwx, Group: rws with SGID, Others: ---)

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

# Flags
DRY_RUN=false
CHECK_ONLY=false
OUTPUT_JSON=false

# ------------------------------------------------------------------------------
# Logging Helper
# ------------------------------------------------------------------------------
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
    log "INFO" "$*"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
    log "SUCCESS" "$*"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
    log "WARN" "$*"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
    log "ERROR" "$*"
}

# ------------------------------------------------------------------------------
# Usage & Help
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Configure a department group and a secured shared directory for group-only access.

Options:
  --check       Audit and inspect current department group & shared folder state
  --dry-run     Simulate actions without executing groupadd/chmod/chown
  --json        Output machine-readable JSON telemetry to stdout and file
  --help        Display this help message and exit

Environment Defaults:
  Department Group : $GROUP_NAME
  Shared Directory : $SHARED_DIR
  Permissions Mode : $PERM_MODE (SGID drwxrws---)
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            show_help
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Header Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}     DEPARTMENT ACCESS CONFIGURATION ENGINE & PERMISSION AUDIT (AS_03)           ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Group      : ${COLOR_BOLD}${GROUP_NAME}${COLOR_RESET}"
echo -e " Shared Directory  : ${COLOR_BOLD}${SHARED_DIR}${COLOR_RESET}"
echo -e " Target Mode       : ${COLOR_BOLD}${PERM_MODE} (drwxrws---)${COLOR_RESET}"
echo -e " Execution Mode    : $([[ "$DRY_RUN" == true ]] && echo "${COLOR_YELLOW}Dry Run (Simulation)${COLOR_RESET}" || echo "${COLOR_GREEN}Live Execution${COLOR_RESET}")"
echo -e " Timestamp         : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e " Hostname          : $(hostname)"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Step 1: Group Provisioning / Verification
# ------------------------------------------------------------------------------
info "Step 1: Inspecting department group '${GROUP_NAME}'..."

GROUP_EXISTS=false
GROUP_GID=""
GROUP_MEMBERS=""

if getent group "$GROUP_NAME" >/dev/null 2>&1; then
    GROUP_EXISTS=true
    GROUP_ENTRY="$(getent group "$GROUP_NAME")"
    GROUP_GID="$(echo "$GROUP_ENTRY" | cut -d: -f3)"
    GROUP_MEMBERS="$(echo "$GROUP_ENTRY" | cut -d: -f4)"
    success "Department group '${GROUP_NAME}' already exists (GID: ${GROUP_GID})."
else
    if [[ "$CHECK_ONLY" == true ]]; then
        warn "Group '${GROUP_NAME}' does not exist on the host."
    elif [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would execute: sudo groupadd '${GROUP_NAME}'"
        GROUP_GID="<simulated>"
        GROUP_EXISTS=true
    else
        info "Creating department group '${GROUP_NAME}' using groupadd..."
        if sudo groupadd "$GROUP_NAME"; then
            GROUP_ENTRY="$(getent group "$GROUP_NAME")"
            GROUP_GID="$(echo "$GROUP_ENTRY" | cut -d: -f3)"
            GROUP_MEMBERS="$(echo "$GROUP_ENTRY" | cut -d: -f4)"
            GROUP_EXISTS=true
            success "Successfully provisioned department group '${GROUP_NAME}' (GID: ${GROUP_GID})."
        else
            error "Failed to create group '${GROUP_NAME}'."
            exit 1
        fi
    fi
fi

# ------------------------------------------------------------------------------
# Step 2: Configure Shared Directory
# ------------------------------------------------------------------------------
info "Step 2: Configuring shared directory '${SHARED_DIR}'..."

if [[ "$DRY_RUN" == false && "$CHECK_ONLY" == false ]]; then
    mkdir -p "$SHARED_DIR"

    # Assign directory ownership: current user as owner, department group as group
    TARGET_OWNER="${USER:-$(id -un)}"
    info "Setting directory ownership to '${TARGET_OWNER}:${GROUP_NAME}'..."
    sudo chown "${TARGET_OWNER}:${GROUP_NAME}" "$SHARED_DIR"

    # Set SGID and restrictive group permissions: 2770 (rwxrws---)
    # 2 = SGID (new files inherit directory's group)
    # 7 = Owner has rwx
    # 7 = Group has rwx
    # 0 = Others have NO permissions (strictly locked out)
    info "Setting restrictive permissions '${PERM_MODE}' on '${SHARED_DIR}'..."
    sudo chmod "$PERM_MODE" "$SHARED_DIR"
    success "Directory ownership and permissions applied successfully."
fi

# ------------------------------------------------------------------------------
# Step 3: Deep Permission & Access Audit
# ------------------------------------------------------------------------------
info "Step 3: Auditing shared directory permissions & access isolation..."

CURRENT_PERM_OCTAL=""
CURRENT_PERM_HUMAN=""
CURRENT_OWNER=""
CURRENT_GROUP=""
OTHERS_BLOCKED=false
SGID_ACTIVE=false
INHERITANCE_VERIFIED=false
NON_MEMBER_DENIED=false

if [[ -d "$SHARED_DIR" ]]; then
    CURRENT_PERM_OCTAL="$(stat -c "%a" "$SHARED_DIR" 2>/dev/null || stat -f "%OLp" "$SHARED_DIR" 2>/dev/null || echo "unknown")"
    CURRENT_PERM_HUMAN="$(stat -c "%A" "$SHARED_DIR" 2>/dev/null || stat -f "%Sp" "$SHARED_DIR" 2>/dev/null || echo "unknown")"
    CURRENT_OWNER="$(stat -c "%U" "$SHARED_DIR" 2>/dev/null || stat -f "%Su" "$SHARED_DIR" 2>/dev/null || echo "unknown")"
    CURRENT_GROUP="$(stat -c "%G" "$SHARED_DIR" 2>/dev/null || stat -f "%Sg" "$SHARED_DIR" 2>/dev/null || echo "unknown")"

    echo -e "  - Path        : ${COLOR_BOLD}${SHARED_DIR}${COLOR_RESET}"
    echo -e "  - Octal Mode  : ${COLOR_BOLD}${CURRENT_PERM_OCTAL}${COLOR_RESET}"
    echo -e "  - Symbolic    : ${COLOR_BOLD}${CURRENT_PERM_HUMAN}${COLOR_RESET}"
    echo -e "  - Owner       : ${COLOR_BOLD}${CURRENT_OWNER}${COLOR_RESET}"
    echo -e "  - Group       : ${COLOR_BOLD}${CURRENT_GROUP}${COLOR_RESET}"

    # Audit Others bit (must be 0 or ---)
    if [[ "${CURRENT_PERM_OCTAL: -1}" == "0" ]] || [[ "$CURRENT_PERM_HUMAN" =~ ---$ ]]; then
        OTHERS_BLOCKED=true
        success "Others Access Audit: STRICTLY BLOCKED (0 / '---'). Non-members cannot read, write, or enter."
    else
        warn "Others Access Audit: OPEN (${CURRENT_PERM_OCTAL: -1}). Non-members may have access."
    fi

    # Audit SGID bit
    if [[ "$CURRENT_PERM_OCTAL" =~ ^2 ]] || [[ "$CURRENT_PERM_HUMAN" =~ ^d...r.s ]]; then
        SGID_ACTIVE=true
        success "SGID Bit Audit: ACTIVE (SetGID). Files created inside will inherit group '${GROUP_NAME}'."
    else
        warn "SGID Bit Audit: INACTIVE. SGID bit is not set."
    fi

    # Test file inheritance inside shared folder
    if [[ "$DRY_RUN" == false && "$CHECK_ONLY" == false ]]; then
        TEST_FILE="${SHARED_DIR}/.inheritance_test_$(date +%s).tmp"
        if touch "$TEST_FILE" 2>/dev/null || sudo touch "$TEST_FILE" 2>/dev/null; then
            CREATED_FILE_GROUP="$(stat -c "%G" "$TEST_FILE" 2>/dev/null || echo "unknown")"
            if [[ "$CREATED_FILE_GROUP" == "$GROUP_NAME" ]]; then
                INHERITANCE_VERIFIED=true
                success "Group Inheritance Test: PASSED (New file inherited group '${CREATED_FILE_GROUP}')."
            else
                warn "Group Inheritance Test: File created with group '${CREATED_FILE_GROUP}', expected '${GROUP_NAME}'."
            fi
            rm -f "$TEST_FILE" 2>/dev/null || sudo rm -f "$TEST_FILE" 2>/dev/null
        fi

        # Test non-member access denial using 'nobody' account
        info "Testing access enforcement: attempting non-member read/exec via 'nobody' account..."
        if sudo -u nobody test -r "$SHARED_DIR" 2>/dev/null || sudo -u nobody ls "$SHARED_DIR" >/dev/null 2>&1; then
            warn "Non-Member Access Test: 'nobody' was able to read directory. Check permissions!"
            NON_MEMBER_DENIED=false
        else
            NON_MEMBER_DENIED=true
            success "Non-Member Access Test: ACCESS DENIED (as expected). User 'nobody' blocked by kernel."
        fi
    fi
else
    warn "Shared directory '${SHARED_DIR}' does not exist on disk."
fi

# ------------------------------------------------------------------------------
# Step 4: Generate JSON Telemetry
# ------------------------------------------------------------------------------
SCAN_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
SCAN_EPOCH="$(date +%s)"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_03",
  "title": "Department Access",
  "timestamp": "$SCAN_TIME",
  "timestamp_epoch": $SCAN_EPOCH,
  "hostname": "$(hostname)",
  "os": "$(uname -s)",
  "kernel": "$(uname -r)",
  "department_group": {
    "name": "$GROUP_NAME",
    "exists": $GROUP_EXISTS,
    "gid": "$GROUP_GID",
    "members": "$GROUP_MEMBERS"
  },
  "shared_directory": {
    "path": "$SHARED_DIR",
    "octal_mode": "$CURRENT_PERM_OCTAL",
    "symbolic_mode": "$CURRENT_PERM_HUMAN",
    "owner": "$CURRENT_OWNER",
    "group": "$CURRENT_GROUP",
    "target_mode": "$PERM_MODE",
    "sgid_active": $SGID_ACTIVE,
    "others_blocked": $OTHERS_BLOCKED,
    "inheritance_verified": $INHERITANCE_VERIFIED,
    "non_member_denied": $NON_MEMBER_DENIED
  },
  "status": "$([[ "$OTHERS_BLOCKED" == true && "$SGID_ACTIVE" == true ]] && echo "CONFIGURED" || echo "NEEDS_ATTENTION")"
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}SUMMARY RESULTS:${COLOR_RESET}"
echo -e "  Group Status        : $([[ "$GROUP_EXISTS" == true ]] && echo -e "${COLOR_GREEN}PROVISIONED (${GROUP_NAME}:${GROUP_GID})${COLOR_RESET}" || echo -e "${COLOR_RED}MISSING${COLOR_RESET}")"
echo -e "  Directory Mode      : ${COLOR_BOLD}${CURRENT_PERM_HUMAN} (${CURRENT_PERM_OCTAL})${COLOR_RESET}"
echo -e "  SGID Inheritance    : $([[ "$SGID_ACTIVE" == true ]] && echo -e "${COLOR_GREEN}ENABLED (2xxx)${COLOR_RESET}" || echo -e "${COLOR_RED}DISABLED${COLOR_RESET}")"
echo -e "  Others Locked Out   : $([[ "$OTHERS_BLOCKED" == true ]] && echo -e "${COLOR_GREEN}ENFORCED (--- / 0)${COLOR_RESET}" || echo -e "${COLOR_RED}VULNERABLE${COLOR_RESET}")"
echo -e "  Non-Member Blocked  : $([[ "$NON_MEMBER_DENIED" == true ]] && echo -e "${COLOR_GREEN}CONFIRMED (Kernel EACCES)${COLOR_RESET}" || echo -e "${COLOR_YELLOW}UNTESTED / FAILED${COLOR_RESET}")"
echo -e "  Audit Telemetry     : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Audit Log File      : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
