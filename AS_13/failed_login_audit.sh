#!/usr/bin/env bash
# ==============================================================================
# Script: failed_login_audit.sh
# Purpose: Identify the number of failed SSH login attempts from system logs,
#          aggregating failures by source IP, target user, and method (AS_13).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/failed_login_audit.log"
JSON_FILE="${LOG_DIR}/failed_logins.json"
SANDBOX_LOG="${SCRIPT_DIR}/sandbox_data/auth.log"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

TARGET_LOG=""
OUTPUT_JSON=false
LOG_SOURCE_TYPE=""

mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [LOG_FILE]

Audit and report failed SSH login attempts from system authentication logs.

Arguments:
  LOG_FILE                Explicit path to auth log file to analyze.
                          Defaults to auto-detecting live system logs:
                            1. /var/log/auth.log
                            2. /var/log/secure
                            3. journalctl system stream
                            Fallback: ./sandbox_data/auth.log (synthetic demonstration)

Options:
  --sandbox               Explicitly target local sandbox_data/auth.log
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Examples:
  ./failed_login_audit.sh                  # Audits live system log
  ./failed_login_audit.sh --sandbox        # Audits simulated attack sandbox log
  ./failed_login_audit.sh /var/log/auth.log
  ./failed_login_audit.sh --json           # Emits machine-readable telemetry
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sandbox)
            TARGET_LOG="$SANDBOX_LOG"
            LOG_SOURCE_TYPE="SYNTHETIC_SANDBOX"
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

if [[ -z "$TARGET_LOG" && ${#POSITIONAL[@]} -ge 1 ]]; then
    TARGET_LOG="${POSITIONAL[0]}"
    LOG_SOURCE_TYPE="CUSTOM_OVERRIDE"
fi

# Auto-detection of real system log if no target given
TMP_JOURNAL_FILE=""
if [[ -z "$TARGET_LOG" ]]; then
    if [[ -r /var/log/auth.log ]]; then
        TARGET_LOG="/var/log/auth.log"
        LOG_SOURCE_TYPE="REAL_SYSTEM_AUTH_LOG"
    elif [[ -r /var/log/secure ]]; then
        TARGET_LOG="/var/log/secure"
        LOG_SOURCE_TYPE="REAL_SYSTEM_SECURE_LOG"
    elif command -v journalctl >/dev/null 2>&1 && journalctl _COMM=sshd -n 1 --no-pager >/dev/null 2>&1; then
        TMP_JOURNAL_FILE="$(mktemp)"
        journalctl _COMM=sshd --no-pager > "$TMP_JOURNAL_FILE" 2>/dev/null || true
        TARGET_LOG="$TMP_JOURNAL_FILE"
        LOG_SOURCE_TYPE="REAL_SYSTEM_JOURNALD"
    elif [[ -f "$SANDBOX_LOG" ]]; then
        TARGET_LOG="$SANDBOX_LOG"
        LOG_SOURCE_TYPE="SYNTHETIC_SANDBOX"
    else
        echo -e "${COLOR_RED}[ERROR] No readable authentication log source found.${COLOR_RESET}" >&2
        log "ERROR" "No readable authentication log source found."
        exit 1
    fi
fi

if [[ ! -r "$TARGET_LOG" ]]; then
    echo -e "${COLOR_RED}[ERROR] Cannot read log file: '${TARGET_LOG}'${COLOR_RESET}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Banner Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         SECURITY MONITORING: FAILED SSH LOGIN AUDIT (AS_13)                    ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Log Source  : ${COLOR_BOLD}${TARGET_LOG}${COLOR_RESET}"
echo -e " Source Mode        : $(if [[ "$LOG_SOURCE_TYPE" =~ REAL ]]; then echo -e "${COLOR_GREEN}${LOG_SOURCE_TYPE}${COLOR_RESET}"; else echo -e "${COLOR_YELLOW}${LOG_SOURCE_TYPE}${COLOR_RESET}"; fi)"
echo -e " Hostname           : $(hostname)"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

log "INFO" "Auditing failed logins from '${TARGET_LOG}' (${LOG_SOURCE_TYPE})"

# ------------------------------------------------------------------------------
# Log Parsing & Metric Extraction
# ------------------------------------------------------------------------------
RAW_FAILED="$(mktemp)"

# Extract lines relating to failed SSH authentication
# Patterns: 'Failed password', 'Failed publickey', 'authentication failure'
grep -iE "Failed (password|publickey)|authentication failure" "$TARGET_LOG" > "$RAW_FAILED" 2>/dev/null || true

TOTAL_FAILED="$(wc -l < "$RAW_FAILED" | tr -d ' ')"

IP_COUNTS="$(mktemp)"
USER_COUNTS="$(mktemp)"
INVALID_USER_COUNT=0
VALID_USER_COUNT=0

# Extract source IPs: 'from <IP>'
grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAW_FAILED" | sort | uniq -c | sort -nr > "$IP_COUNTS" || true
UNIQUE_IPS="$(wc -l < "$IP_COUNTS" | tr -d ' ')"

# Extract users: 'for invalid user <USER>' or 'for <USER>'
awk '{
    for (i=1; i<=NF; i++) {
        if ($i == "user") {
            print $(i+1);
            next;
        } else if ($i == "for" && $(i+1) != "invalid") {
            print $(i+1);
            next;
        }
    }
}' "$RAW_FAILED" | sort | uniq -c | sort -nr > "$USER_COUNTS" || true
UNIQUE_USERS="$(wc -l < "$USER_COUNTS" | tr -d ' ')"

# Count invalid user attempts
INVALID_USER_COUNT="$(grep -ci "invalid user" "$RAW_FAILED" 2>/dev/null || true)"
INVALID_USER_COUNT="${INVALID_USER_COUNT:-0}"
VALID_USER_COUNT=$(( TOTAL_FAILED - INVALID_USER_COUNT ))
if (( VALID_USER_COUNT < 0 )); then VALID_USER_COUNT=0; fi

# Failure types
PWD_FAILS="$(grep -ci "Failed password" "$RAW_FAILED" 2>/dev/null || true)"
PWD_FAILS="${PWD_FAILS:-0}"
PUBKEY_FAILS="$(grep -ci "Failed publickey" "$RAW_FAILED" 2>/dev/null || true)"
PUBKEY_FAILS="${PUBKEY_FAILS:-0}"
OTHER_FAILS=$(( TOTAL_FAILED - PWD_FAILS - PUBKEY_FAILS ))
if (( OTHER_FAILS < 0 )); then OTHER_FAILS=0; fi

echo -e " Total Failed Attempts : ${COLOR_BOLD}${TOTAL_FAILED}${COLOR_RESET}"
echo -e " Unique Offending IPs  : ${COLOR_YELLOW}${COLOR_BOLD}${UNIQUE_IPS}${COLOR_RESET}"
echo -e " Targeted User Accounts: ${COLOR_CYAN}${COLOR_BOLD}${UNIQUE_USERS}${COLOR_RESET}"
echo -e " Invalid User Attempts : ${COLOR_RED}${INVALID_USER_COUNT}${COLOR_RESET} | Valid User Attempts: ${COLOR_GREEN}${VALID_USER_COUNT}${COLOR_RESET}"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# Build JSON arrays
JSON_IPS=()
JSON_USERS=()

if (( TOTAL_FAILED > 0 )); then
    echo -e "${COLOR_BOLD}TOP OFFENDING IP ADDRESSES:${COLOR_RESET}"
    printf "%-6s %-18s %-12s %s\n" "RANK" "IP ADDRESS" "ATTEMPTS" "PERCENTAGE"
    echo "--------------------------------------------------"
    RANK=0
    while read -r count ip; do
        [[ -z "$ip" ]] && continue
        (( RANK++ )) || true
        pct="$(awk -v c="$count" -v t="$TOTAL_FAILED" 'BEGIN { printf "%.1f%%", (c/t)*100.0 }')"
        if (( RANK <= 10 )); then
            printf "#%-5s %-18s ${COLOR_RED}%-12s${COLOR_RESET} %s\n" "$RANK" "$ip" "$count" "$pct"
        fi
        log "OFFENDER_IP" "Rank #$RANK: $ip - $count attempts ($pct)"
        JSON_IPS+=("{\"rank\":$RANK,\"ip\":\"$ip\",\"attempts\":$count,\"percentage\":\"$pct\"}")
    done < "$IP_COUNTS"
    echo ""

    echo -e "${COLOR_BOLD}TOP TARGETED USER ACCOUNTS:${COLOR_RESET}"
    printf "%-6s %-18s %-12s %s\n" "RANK" "USERNAME" "ATTEMPTS" "PERCENTAGE"
    echo "--------------------------------------------------"
    RANK_U=0
    while read -r count user; do
        [[ -z "$user" ]] && continue
        (( RANK_U++ )) || true
        pct="$(awk -v c="$count" -v t="$TOTAL_FAILED" 'BEGIN { printf "%.1f%%", (c/t)*100.0 }')"
        if (( RANK_U <= 10 )); then
            printf "#%-5s %-18s ${COLOR_YELLOW}%-12s${COLOR_RESET} %s\n" "$RANK_U" "$user" "$count" "$pct"
        fi
        log "TARGET_USER" "Rank #$RANK_U: $user - $count attempts ($pct)"
        JSON_USERS+=("{\"rank\":$RANK_U,\"user\":\"$user\",\"attempts\":$count,\"percentage\":\"$pct\"}")
    done < "$USER_COUNTS"
else
    echo -e "${COLOR_GREEN}${COLOR_BOLD}✅ Clean Authentication State: 0 failed SSH login attempts recorded.${COLOR_RESET}"
    echo -e "No active brute-force or credential-stuffing activity detected in current logs."
    log "INFO" "Zero failed logins found in target log source."
fi

rm -f "$RAW_FAILED" "$IP_COUNTS" "$USER_COUNTS"
if [[ -n "$TMP_JOURNAL_FILE" && -f "$TMP_JOURNAL_FILE" ]]; then
    rm -f "$TMP_JOURNAL_FILE"
fi

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_IPS_JOINED="$(IFS=,; echo "${JSON_IPS[*]}")"
JSON_USERS_JOINED="$(IFS=,; echo "${JSON_USERS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_13",
  "title": "Failed Login Audit",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "log_file": "$TARGET_LOG",
  "log_source_type": "$LOG_SOURCE_TYPE",
  "total_failed_logins": $TOTAL_FAILED,
  "unique_offending_ips": $UNIQUE_IPS,
  "targeted_user_count": $UNIQUE_USERS,
  "invalid_user_attempts": $INVALID_USER_COUNT,
  "valid_user_attempts": $VALID_USER_COUNT,
  "failure_types": {
    "password": $PWD_FAILS,
    "publickey": $PUBKEY_FAILS,
    "other": $OTHER_FAILS
  },
  "status": "$([[ $TOTAL_FAILED -gt 0 ]] && echo "THREATS_DETECTED" || echo "CLEAN")",
  "top_offending_ips": [
    $JSON_IPS_JOINED
  ],
  "top_targeted_users": [
    $JSON_USERS_JOINED
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
echo -e "${COLOR_BOLD}AUDIT SUMMARY:${COLOR_RESET}"
echo -e "  Total Failed Attempts : ${COLOR_BOLD}${TOTAL_FAILED}${COLOR_RESET}"
echo -e "  Threat Status         : $(if (( TOTAL_FAILED > 0 )); then echo -e "${COLOR_RED}ATTACK_ACTIVITY_DETECTED${COLOR_RESET}"; else echo -e "${COLOR_GREEN}HEALTHY_CLEAN${COLOR_RESET}"; fi)"
echo -e "  Telemetry JSON File   : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Persistent Audit Log  : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
