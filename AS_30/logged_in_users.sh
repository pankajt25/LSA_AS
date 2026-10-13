#!/usr/bin/env bash
# ==============================================================================
# Script: logged_in_users.sh
# Purpose: Real-time inspection of active logged-in user sessions (AS_30).
#          Extracts usernames, terminals (tty/pts), login times, remote IPs, and idle times.
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/user_sessions.log"
JSON_FILE="${LOG_DIR}/user_sessions.json"
SANDBOX_FILE="${SCRIPT_DIR}/sandbox_data/simulated_w.txt"

mkdir -p "$LOG_DIR"

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_MAGENTA="\033[35m"

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
Usage: $(basename "$0") [OPTIONS]

Inspect and report all currently logged-in users, terminal devices, login timestamps,
remote source IPs, and idle metrics.

Options:
  --sandbox       Parse simulated enterprise multi-user dataset (sandbox_data/simulated_w.txt)
  --json          Output structured JSON telemetry to console and logs/user_sessions.json
  -h, --help      Display this help manual and exit

Examples:
  ./logged_in_users.sh                 # Inspects live host sessions
  ./logged_in_users.sh --sandbox       # Inspects multi-user enterprise scenario
  ./logged_in_users.sh --json          # Machine-readable JSON output
EOF
}

USE_SANDBOX=false
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sandbox)
            USE_SANDBOX=true
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
        *)
            echo -e "${COLOR_RED}[ERROR] Unknown option: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Ingestion: Live vs Sandbox
# ------------------------------------------------------------------------------
TMP_DATA="$(mktemp)"

if [[ "$USE_SANDBOX" == true ]]; then
    if [[ ! -r "$SANDBOX_FILE" ]]; then
        echo -e "${COLOR_RED}[ERROR] Sandbox file not readable: '$SANDBOX_FILE'${COLOR_RESET}" >&2
        exit 1
    fi
    SOURCE_MODE="SIMULATED_SANDBOX"
    # Filter header lines if present
    tail -n +3 "$SANDBOX_FILE" > "$TMP_DATA"
else
    SOURCE_MODE="REAL_LIVE_HOST"
    if command -v w >/dev/null 2>&1; then
        w -h > "$TMP_DATA" 2>/dev/null || true
    elif command -v who >/dev/null 2>&1; then
        who -u | awk '{print $1, $2, ($7 ? $7 : "-"), $3" "$4, $5, "-", "-", "-"}' > "$TMP_DATA" 2>/dev/null || true
    else
        echo -e "${COLOR_RED}[ERROR] Neither 'w' nor 'who' utility found on host.${COLOR_RESET}" >&2
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# Parse Session Records
# ------------------------------------------------------------------------------
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"

TOTAL_SESSIONS=0
REMOTE_SESSIONS=0
LOCAL_SESSIONS=0
declare -A UNIQUE_USERS_MAP

PARSED_SESSIONS=()
JSON_SESSIONS=()

while read -r u tty from login idle jcpu pcpu what; do
    [[ -z "$u" ]] && continue
    (( TOTAL_SESSIONS++ )) || true
    UNIQUE_USERS_MAP["$u"]=1

    # Remote vs Local determination
    is_remote=false
    remote_ip="$from"
    if [[ "$from" != "-" && "$from" != ":0" && "$from" != ":1" && -n "$from" ]]; then
        is_remote=true
        (( REMOTE_SESSIONS++ )) || true
        session_type="Remote"
    else
        (( LOCAL_SESSIONS++ )) || true
        session_type="Local/Console"
        remote_ip="Local (No IP)"
    fi

    # Format idle time description
    idle_desc="Active"
    if [[ "$idle" =~ m$ || "$idle" =~ : ]]; then
        idle_desc="Idle ($idle)"
    elif [[ "$idle" =~ s$ || "$idle" == "0.00s" || "$idle" == "." ]]; then
        idle_desc="Active ($idle)"
    else
        idle_desc="$idle"
    fi

    PARSED_SESSIONS+=("$u|$tty|$from|$login|$idle|$idle_desc|$session_type|$what")
    JSON_SESSIONS+=("{\"user\":\"$u\",\"tty\":\"$tty\",\"remote_host\":\"$from\",\"is_remote\":$is_remote,\"session_type\":\"$session_type\",\"login_time\":\"$login\",\"idle\":\"$idle\",\"idle_description\":\"$idle_desc\",\"what\":\"$what\"}")
    log "SESSION" "User: $u, TTY: $tty, Remote: $from ($session_type), Login: $login, Idle: $idle, Command: $what"
done < "$TMP_DATA"

rm -f "$TMP_DATA"

UNIQUE_USERS_COUNT=${#UNIQUE_USERS_MAP[@]}

# ------------------------------------------------------------------------------
# Terminal Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         ACTIVE LOGGED-IN USERS MONITORING ENGINE (AS_30)                       ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Data Source        : $(if [[ "$SOURCE_MODE" =~ REAL ]]; then echo -e "${COLOR_GREEN}${SOURCE_MODE}${COLOR_RESET}"; else echo -e "${COLOR_YELLOW}${SOURCE_MODE}${COLOR_RESET}"; fi)"
echo -e " Hostname           : ${COLOR_BOLD}${HOSTNAME_VAL}${COLOR_RESET}"
echo -e " System Uptime      : $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')"
echo -e " Timestamp          : ${TIMESTAMP_VAL}"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e " Active Sessions    : ${COLOR_BOLD}${TOTAL_SESSIONS}${COLOR_RESET} (${COLOR_GREEN}${LOCAL_SESSIONS} Local${COLOR_RESET}, ${COLOR_YELLOW}${REMOTE_SESSIONS} Remote${COLOR_RESET})"
echo -e " Unique Users       : ${COLOR_BOLD}${UNIQUE_USERS_COUNT}${COLOR_RESET}"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
printf "%-12s %-10s %-18s %-16s %-12s %-12s %s\n" "USER" "TTY" "REMOTE HOST/IP" "TYPE" "LOGIN TIME" "IDLE" "ACTIVE COMMAND"
echo "------------------------------------------------------------------------------------------------"

for s in "${PARSED_SESSIONS[@]}"; do
    IFS='|' read -r u tty from login idle idle_desc stype what <<< "$s"
    user_disp="${COLOR_BOLD}${u}${COLOR_RESET}"
    if [[ "$u" == "root" ]]; then
        user_disp="${COLOR_RED}${COLOR_BOLD}${u}${COLOR_RESET}"
    fi

    type_disp="${COLOR_GREEN}${stype}${COLOR_RESET}"
    if [[ "$stype" == "Remote" ]]; then
        type_disp="${COLOR_YELLOW}${stype}${COLOR_RESET}"
    fi

    printf "%-21b %-10s %-18s %-25b %-12s %-12s %s\n" "$user_disp" "$tty" "$from" "$type_disp" "$login" "$idle" "$what"
done

if (( TOTAL_SESSIONS == 0 )); then
    echo -e "${COLOR_YELLOW}No active logged-in user sessions detected on current console.${COLOR_RESET}"
fi
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_JOINED="$(IFS=,; echo "${JSON_SESSIONS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_30",
  "title": "Logged-in User Report",
  "timestamp": "${TIMESTAMP_VAL}",
  "timestamp_epoch": $(date +%s),
  "hostname": "${HOSTNAME_VAL}",
  "source_mode": "${SOURCE_MODE}",
  "total_sessions": ${TOTAL_SESSIONS},
  "unique_users_count": ${UNIQUE_USERS_COUNT},
  "remote_sessions": ${REMOTE_SESSIONS},
  "local_sessions": ${LOCAL_SESSIONS},
  "sessions": [
    $JSON_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

exit 0
