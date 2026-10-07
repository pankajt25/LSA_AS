#!/usr/bin/env bash
# ==============================================================================
# Script: permission_audit.sh
# Purpose: Identify and audit all world-writable files in a specified directory (AS_04).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET_DIR="${SCRIPT_DIR}/sandbox_data"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/permission_audit.log"
JSON_FILE="${LOG_DIR}/permission_audit.json"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_MAGENTA="\033[35m"

# Flags
TARGET_DIR=""
VERBOSE=false
OUTPUT_JSON=false
REMEDIATE=false

# ------------------------------------------------------------------------------
# Logging Helpers
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
# Help Manual
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Audit a directory to identify all world-writable files (permission -o+w / -0002).

Arguments:
  DIRECTORY             Target directory path to inspect (default: ${DEFAULT_TARGET_DIR})

Options:
  --system              Audit live system temporary directories (/var/tmp and /tmp)
  -r, --remediate       Simulate or execute permission hardening (chmod o-w)
  -v, --verbose         Display all inspected files including compliant files
  --json                Emit structured JSON telemetry to stdout and file
  -h, --help            Show this usage manual and exit

Examples:
  ./permission_audit.sh                              # Audits default sandbox_data
  ./permission_audit.sh /var/log                     # Audits /var/log
  ./permission_audit.sh --system                     # Audits live system temp locations
  ./permission_audit.sh --json                       # Outputs audit findings in JSON format
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL_ARGS=()
SYSTEM_SCAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)
            SYSTEM_SCAN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -r|--remediate)
            REMEDIATE=true
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
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ "$SYSTEM_SCAN" == true ]]; then
    TARGET_DIR="/var/tmp"
elif [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
    TARGET_DIR="${POSITIONAL_ARGS[0]}"
else
    TARGET_DIR="$DEFAULT_TARGET_DIR"
fi

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Target directory '${TARGET_DIR}' does not exist or is not a directory.${COLOR_RESET}" >&2
    log "ERROR" "Target directory '${TARGET_DIR}' not found."
    exit 1
fi

TARGET_DIR_CANONICAL="$(cd "$TARGET_DIR" && pwd)"

# ------------------------------------------------------------------------------
# Header Banner
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}           SECURITY AUDIT ENGINE: WORLD-WRITABLE FILE SCANNER (AS_04)            ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Directory : ${COLOR_BOLD}${TARGET_DIR_CANONICAL}${COLOR_RESET}"
echo -e " Audit Policy     : ${COLOR_BOLD}Zero-Tolerance World-Writable Files (perm -0002 / -o+w)${COLOR_RESET}"
echo -e " Timestamp        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e " Hostname         : $(hostname)"
echo -e " User             : $(whoami)"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Audit Scan Execution
# ------------------------------------------------------------------------------
log "INFO" "Starting permission audit on directory: ${TARGET_DIR_CANONICAL}"

TOTAL_FILES=0
COMPLIANT_COUNT=0
VULN_COUNT=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0

# Temporary files to store audit findings
AUDIT_RAW="$(mktemp)"
ALL_FILES_RAW="$(mktemp)"

# Collect all regular files
find "$TARGET_DIR_CANONICAL" -type f 2>/dev/null > "$ALL_FILES_RAW" || true
TOTAL_FILES="$(wc -l < "$ALL_FILES_RAW" | tr -d ' ')"

# Collect world-writable regular files (-perm -0002 matches files where 'others' has write bit)
find "$TARGET_DIR_CANONICAL" -type f -perm -0002 2>/dev/null > "$AUDIT_RAW" || true
VULN_COUNT="$(wc -l < "$AUDIT_RAW" | tr -d ' ')"
COMPLIANT_COUNT=$(( TOTAL_FILES - VULN_COUNT ))

echo -e "[INFO] Total regular files scanned: ${COLOR_BOLD}${TOTAL_FILES}${COLOR_RESET}"
echo -e "[INFO] Compliant files             : ${COLOR_GREEN}${COLOR_BOLD}${COMPLIANT_COUNT}${COLOR_RESET}"
echo -e "[INFO] World-writable files flagged: $([[ $VULN_COUNT -gt 0 ]] && echo -e "${COLOR_RED}${COLOR_BOLD}${VULN_COUNT}${COLOR_RESET}" || echo -e "${COLOR_GREEN}0 (CLEAN)${COLOR_RESET}")"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Process & Report Findings
# ------------------------------------------------------------------------------
JSON_ITEMS=()

if [[ $VULN_COUNT -gt 0 ]]; then
    printf "${COLOR_BOLD}%-10s %-5s %-12s %-12s %-8s %-10s %s${COLOR_RESET}\n" \
        "PERMS" "OCTAL" "OWNER" "GROUP" "SIZE" "SEVERITY" "FILE PATH"
    echo "--------------------------------------------------------------------------------"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        # Extract file metadata
        octal="$(stat -c "%a" "$file" 2>/dev/null || echo "???")"
        symbolic="$(stat -c "%A" "$file" 2>/dev/null || echo "???")"
        owner="$(stat -c "%U" "$file" 2>/dev/null || echo "???")"
        group="$(stat -c "%G" "$file" 2>/dev/null || echo "???")"
        size="$(stat -c "%s" "$file" 2>/dev/null || echo "0")"
        mod_time="$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 || echo "???")"

        # Determine severity level
        # CRITICAL: executable files (scripts/binaries) or files in sensitive dirs
        # HIGH: config files, data stores, credentials
        # MEDIUM: other world-writable files
        severity="HIGH"
        color_sev="$COLOR_YELLOW"

        if [[ -x "$file" ]] || [[ "$file" =~ \.(sh|py|pl|bin|so|exe)$ ]]; then
            severity="CRITICAL"
            color_sev="$COLOR_RED"
            (( CRITICAL_COUNT++ )) || true
        elif [[ "$file" =~ \.(conf|cfg|ini|key|pem|json|yaml|sql|csv|env)$ ]]; then
            severity="HIGH"
            color_sev="$COLOR_YELLOW"
            (( HIGH_COUNT++ )) || true
        else
            severity="MEDIUM"
            color_sev="$COLOR_MAGENTA"
            (( MEDIUM_COUNT++ )) || true
        fi

        printf "%-10s %-5s %-12s %-12s %-8s ${color_sev}%-10s${COLOR_RESET} %s\n" \
            "$symbolic" "$octal" "$owner" "$group" "${size}B" "$severity" "$file"

        log "VULN" "World-writable found: $file (mode: $octal, $symbolic, severity: $severity)"

        # Escape path for JSON
        esc_file="$(echo "$file" | sed 's/"/\\"/g')"
        JSON_ITEMS+=("{\"path\":\"$esc_file\",\"octal\":\"$octal\",\"symbolic\":\"$symbolic\",\"owner\":\"$owner\",\"group\":\"$group\",\"size\":$size,\"modified\":\"$mod_time\",\"severity\":\"$severity\",\"remediation\":\"chmod o-w $esc_file\"}")

        # Optional remediation
        if [[ "$REMEDIATE" == true ]]; then
            chmod o-w "$file" 2>/dev/null && \
                echo -e "       ${COLOR_GREEN}-> REMEDIATED: Stripped world-write bit (chmod o-w)${COLOR_RESET}" || \
                echo -e "       ${COLOR_RED}-> REMEDIATION FAILED: Permission denied${COLOR_RESET}"
        fi
    done < "$AUDIT_RAW"
else
    echo -e "${COLOR_GREEN}${COLOR_BOLD}[STATUS] SECURE: No world-writable files discovered in target directory.${COLOR_RESET}"
    echo -e "Target directory complies with standard Linux least-privilege security policy."
    log "INFO" "No world-writable files detected in $TARGET_DIR_CANONICAL"
fi

rm -f "$AUDIT_RAW" "$ALL_FILES_RAW"

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_ITEMS_JOINED="$(IFS=,; echo "${JSON_ITEMS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_04",
  "title": "Permission Audit",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "target_directory": "$TARGET_DIR_CANONICAL",
  "total_files_scanned": $TOTAL_FILES,
  "compliant_files": $COMPLIANT_COUNT,
  "world_writable_count": $VULN_COUNT,
  "severity_breakdown": {
    "critical": $CRITICAL_COUNT,
    "high": $HIGH_COUNT,
    "medium": $MEDIUM_COUNT
  },
  "status": "$([[ $VULN_COUNT -eq 0 ]] && echo "SECURE" || echo "VULNERABILITIES_FOUND")",
  "vulnerabilities": [
    $JSON_ITEMS_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Audit Summary
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}SECURITY AUDIT SUMMARY:${COLOR_RESET}"
echo -e "  Overall Status       : $([[ $VULN_COUNT -eq 0 ]] && echo -e "${COLOR_GREEN}CLEAN / COMPLIANT${COLOR_RESET}" || echo -e "${COLOR_RED}VULNERABLE (${VULN_COUNT} Threats)${COLOR_RESET}")"
echo -e "  Critical Exposures   : ${COLOR_RED}${CRITICAL_COUNT}${COLOR_RESET} (World-writable executables / scripts)"
echo -e "  High Risk Exposures  : ${COLOR_YELLOW}${HIGH_COUNT}${COLOR_RESET} (World-writable configs / data stores)"
echo -e "  Medium Exposures     : ${COLOR_MAGENTA}${MEDIUM_COUNT}${COLOR_RESET}"
echo -e "  Compliance Score     : $(awk -v total="$TOTAL_FILES" -v comp="$COMPLIANT_COUNT" 'BEGIN { if (total>0) printf "%.1f%%", (comp/total)*100; else print "100.0%" }')"
echo -e "  Audit Report JSON    : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Persistent Log File  : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit $([[ $VULN_COUNT -gt 0 ]] && echo 1 || echo 0)
