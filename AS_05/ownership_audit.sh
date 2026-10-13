#!/usr/bin/env bash
# ==============================================================================
# Script: ownership_audit.sh
# Purpose: Audit a project directory to identify all files not owned by the
#          designated project administrator (AS_05).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_DIR="${SCRIPT_DIR}/sandbox_data/project_alpha"
DEFAULT_ADMIN_USER="${USER:-$(id -un)}"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/ownership_audit.log"
JSON_FILE="${LOG_DIR}/ownership_audit.json"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_MAGENTA="\033[35m"

# Flags & Variables
TARGET_DIR=""
ADMIN_USER=""
VERBOSE=false
OUTPUT_JSON=false
REMEDIATE=false

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

# ------------------------------------------------------------------------------
# Usage / Help
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY] [ADMIN_USER]

Find files in a project directory that are not owned by the designated project administrator.

Arguments:
  DIRECTORY             Target project directory to audit (default: ${DEFAULT_PROJECT_DIR})
  ADMIN_USER            Designated administrator username (default: ${DEFAULT_ADMIN_USER})

Options:
  -a, --admin <USER>    Specify designated project administrator explicitly
  -d, --dir <PATH>      Specify target project directory explicitly
  -r, --remediate       Simulate or execute ownership correction (chown <ADMIN_USER>)
  -v, --verbose         Display verbose scanning progress
  --json                Output structured JSON telemetry
  -h, --help            Show this usage manual and exit

Examples:
  ./ownership_audit.sh                                  # Audits sandbox project with current user
  ./ownership_audit.sh /var/log root                   # Audits /var/log expecting owner root
  ./ownership_audit.sh --dir ./sandbox_data --admin bob # Audits sandbox with designated admin bob
  ./ownership_audit.sh --json                           # Emits JSON telemetry
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--admin)
            ADMIN_USER="$2"
            shift 2
            ;;
        -d|--dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -r|--remediate)
            REMEDIATE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${COLOR_RED}[ERROR] Unknown option: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Resolve positional parameters
if [[ -z "$TARGET_DIR" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
        TARGET_DIR="${POSITIONAL[0]}"
    else
        TARGET_DIR="$DEFAULT_PROJECT_DIR"
    fi
fi

if [[ -z "$ADMIN_USER" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
        ADMIN_USER="${POSITIONAL[1]}"
    else
        ADMIN_USER="$DEFAULT_ADMIN_USER"
    fi
fi

# Validation: Admin user
if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    echo -e "${COLOR_RED}[ERROR] Designated admin user '${ADMIN_USER}' is not a valid user on this system.${COLOR_RESET}" >&2
    log "ERROR" "Designated admin user '${ADMIN_USER}' does not exist."
    exit 1
fi
ADMIN_UID="$(id -u "$ADMIN_USER")"

# Validation: Target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Target directory '${TARGET_DIR}' does not exist or is not a directory.${COLOR_RESET}" >&2
    log "ERROR" "Target directory '${TARGET_DIR}' not found."
    exit 1
fi
TARGET_DIR_CANONICAL="$(cd "$TARGET_DIR" && pwd)"

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}           PROJECT FILE OWNERSHIP AUDIT & COMPLIANCE ENGINE (AS_05)              ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Directory   : ${COLOR_BOLD}${TARGET_DIR_CANONICAL}${COLOR_RESET}"
echo -e " Designated Admin   : ${COLOR_BOLD}${ADMIN_USER}${COLOR_RESET} (UID: ${ADMIN_UID})"
echo -e " Audit Policy       : ${COLOR_BOLD}Enforce Single-Admin File Ownership (! -user ${ADMIN_USER})${COLOR_RESET}"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e " Hostname           : $(hostname)"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# File Ownership Scan
# ------------------------------------------------------------------------------
log "INFO" "Scanning '${TARGET_DIR_CANONICAL}' for files not owned by '${ADMIN_USER}'"

RAW_ALL="$(mktemp)"
RAW_FLAGGED="$(mktemp)"

find "$TARGET_DIR_CANONICAL" -type f 2>/dev/null > "$RAW_ALL" || true
TOTAL_FILES="$(wc -l < "$RAW_ALL" | tr -d ' ')"

# Find files NOT owned by the designated admin
find "$TARGET_DIR_CANONICAL" -type f ! -user "$ADMIN_USER" 2>/dev/null > "$RAW_FLAGGED" || true
FLAGGED_COUNT="$(wc -l < "$RAW_FLAGGED" | tr -d ' ')"
COMPLIANT_COUNT=$(( TOTAL_FILES - FLAGGED_COUNT ))

echo -e "[INFO] Total regular files scanned  : ${COLOR_BOLD}${TOTAL_FILES}${COLOR_RESET}"
echo -e "[INFO] Compliant files (${ADMIN_USER}) : ${COLOR_GREEN}${COLOR_BOLD}${COMPLIANT_COUNT}${COLOR_RESET}"
echo -e "[INFO] Non-compliant files flagged  : $([[ $FLAGGED_COUNT -gt 0 ]] && echo -e "${COLOR_RED}${COLOR_BOLD}${FLAGGED_COUNT}${COLOR_RESET}" || echo -e "${COLOR_GREEN}0 (CLEAN)${COLOR_RESET}")"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

ROOT_OWNED=0
FOREIGN_USER=0
ORPHAN_UID=0
JSON_ITEMS=()

if [[ $FLAGGED_COUNT -gt 0 ]]; then
    printf "${COLOR_BOLD}%-12s %-6s %-10s %-10s %-16s %s${COLOR_RESET}\n" \
        "ACTUAL OWNER" "UID" "PERMS" "SIZE" "CATEGORY" "FILE PATH"
    echo "--------------------------------------------------------------------------------"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        owner="$(stat -c "%U" "$file" 2>/dev/null || echo "UNKNOWN")"
        uid_num="$(stat -c "%u" "$file" 2>/dev/null || echo "???")"
        group="$(stat -c "%G" "$file" 2>/dev/null || echo "???")"
        perms="$(stat -c "%A" "$file" 2>/dev/null || echo "???")"
        octal="$(stat -c "%a" "$file" 2>/dev/null || echo "???")"
        size="$(stat -c "%s" "$file" 2>/dev/null || echo "0")"
        mod_date="$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 || echo "???")"

        category="FOREIGN_USER"
        color_cat="$COLOR_YELLOW"

        if [[ "$owner" == "root" || "$uid_num" == "0" ]]; then
            category="ROOT_PRIVILEGE"
            color_cat="$COLOR_RED"
            (( ROOT_OWNED++ )) || true
        elif [[ "$owner" == "UNKNOWN" || "$owner" =~ ^[0-9]+$ ]]; then
            category="ORPHAN_UID"
            color_cat="$COLOR_MAGENTA"
            (( ORPHAN_UID++ )) || true
        else
            category="FOREIGN_USER"
            color_cat="$COLOR_YELLOW"
            (( FOREIGN_USER++ )) || true
        fi

        printf "%-12s %-6s %-10s %-10s ${color_cat}%-16s${COLOR_RESET} %s\n" \
            "$owner" "$uid_num" "$perms" "${size}B" "$category" "$file"

        log "VIOLATION" "Ownership mismatch: $file (actual: $owner:$uid_num, expected: $ADMIN_USER, cat: $category)"

        esc_file="$(echo "$file" | sed 's/"/\\"/g')"
        JSON_ITEMS+=("{\"path\":\"$esc_file\",\"actual_owner\":\"$owner\",\"actual_uid\":$uid_num,\"group\":\"$group\",\"symbolic_mode\":\"$perms\",\"octal_mode\":\"$octal\",\"size\":$size,\"category\":\"$category\",\"remediation\":\"sudo chown $ADMIN_USER $esc_file\"}")

        if [[ "$REMEDIATE" == true ]]; then
            if sudo chown "$ADMIN_USER" "$file" 2>/dev/null; then
                echo -e "       ${COLOR_GREEN}-> REMEDIATED: Reassigned owner to '${ADMIN_USER}'${COLOR_RESET}"
                log "REMEDIATE" "Reassigned $file to $ADMIN_USER"
            else
                echo -e "       ${COLOR_RED}-> REMEDIATION FAILED: Permission denied${COLOR_RESET}"
            fi
        fi
    done < "$RAW_FLAGGED"
else
    echo -e "${COLOR_GREEN}${COLOR_BOLD}[STATUS] COMPLIANT: All files in project are owned by '${ADMIN_USER}'.${COLOR_RESET}"
    log "INFO" "All files in $TARGET_DIR_CANONICAL owned by $ADMIN_USER"
fi

rm -f "$RAW_ALL" "$RAW_FLAGGED"

# ------------------------------------------------------------------------------
# JSON Serialization
# ------------------------------------------------------------------------------
JSON_ITEMS_JOINED="$(IFS=,; echo "${JSON_ITEMS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_05",
  "title": "Ownership Audit",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "target_directory": "$TARGET_DIR_CANONICAL",
  "designated_admin": "$ADMIN_USER",
  "admin_uid": $ADMIN_UID,
  "total_files_scanned": $TOTAL_FILES,
  "compliant_files": $COMPLIANT_COUNT,
  "flagged_files_count": $FLAGGED_COUNT,
  "breakdown": {
    "root_privilege_drift": $ROOT_OWNED,
    "foreign_user_accounts": $FOREIGN_USER,
    "orphan_uids": $ORPHAN_UID
  },
  "status": "$([[ $FLAGGED_COUNT -eq 0 ]] && echo "COMPLIANT" || echo "VIOLATIONS_FOUND")",
  "flagged_files": [
    $JSON_ITEMS_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}OWNERSHIP AUDIT SUMMARY:${COLOR_RESET}"
echo -e "  Overall Status       : $([[ $FLAGGED_COUNT -eq 0 ]] && echo -e "${COLOR_GREEN}COMPLIANT (100% Admin Owned)${COLOR_RESET}" || echo -e "${COLOR_RED}VIOLATIONS DETECTED (${FLAGGED_COUNT} Files Mismatched)${COLOR_RESET}")"
echo -e "  Root Privilege Drift : ${COLOR_RED}${ROOT_OWNED}${COLOR_RESET} files (Accidental root ownership)"
echo -e "  Foreign User Files   : ${COLOR_YELLOW}${FOREIGN_USER}${COLOR_RESET} files (Wrong user / contractor)"
echo -e "  Orphan UIDs          : ${COLOR_MAGENTA}${ORPHAN_UID}${COLOR_RESET} files (Unmapped UIDs)"
echo -e "  Compliance Ratio     : $(awk -v tot="$TOTAL_FILES" -v comp="$COMPLIANT_COUNT" 'BEGIN { if (tot>0) printf "%.1f%%", (comp/tot)*100; else print "100.0%" }')"
echo -e "  Audit Telemetry JSON : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Audit Log History    : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit $([[ $FLAGGED_COUNT -gt 0 ]] && echo 1 || echo 0)
