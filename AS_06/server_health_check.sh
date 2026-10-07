#!/usr/bin/env bash
# ==============================================================================
# Script: server_health_check.sh
# Purpose: Pre-workday server health monitoring report covering CPU, Memory,
#          Disk Usage, System Uptime, and Logged-In Users (AS_06).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/server_health_check.log"
JSON_FILE="${LOG_DIR}/server_health_check.json"

# Warning Thresholds
THRESH_LOAD_PER_CORE=1.5   # Load avg 1m per core
THRESH_MEM_PCT=85.0        # RAM usage %
THRESH_DISK_PCT=85.0       # Root disk usage %

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
OUTPUT_JSON=false
QUIET=false

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
# Help Manual
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate a comprehensive pre-workday server health report from live system telemetry.

Covered Metrics:
  - System Uptime & Load Averages (1m, 5m, 15m)
  - CPU Cores & Real-Time Processor Utilization
  - Physical Memory (RAM) & Swap Space Accounting
  - Storage & Disk Utilization across Mounted Filesystems
  - Active Logged-In User Sessions & Terminal Origins
  - Process Health Diagnostics (Total Processes, Zombie Detection, Top Hogs)

Options:
  --json      Output structured JSON telemetry to stdout and file
  -q, --quiet Display only the final health summary badge
  -h, --help  Display this manual and exit

Examples:
  ./server_health_check.sh            # Standard human-readable console report
  ./server_health_check.sh --json     # Emits JSON telemetry for integration
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
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
# Step 1: System Identification & Uptime
# ------------------------------------------------------------------------------
HOSTNAME_STR="$(hostname 2>/dev/null || uname -n)"
KERNEL_STR="$(uname -r 2>/dev/null || echo 'Unknown')"
ARCH_STR="$(uname -m 2>/dev/null || echo 'Unknown')"
TIMESTAMP_STR="$(date '+%Y-%m-%d %H:%M:%S %Z')"

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_DISPLAY="${PRETTY_NAME:-$(uname -s)}"
else
    OS_DISPLAY="$(uname -s)"
fi

# Uptime string & Boot Time
UPTIME_PRETTY="$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/' || echo 'Active')"
BOOT_TIME="$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || echo 'N/A')"

# ------------------------------------------------------------------------------
# Step 2: CPU Cores & Load Average
# ------------------------------------------------------------------------------
CPU_CORES="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo '1')"

if [[ -f /proc/loadavg ]]; then
    LOAD_1M="$(awk '{print $1}' /proc/loadavg)"
    LOAD_5M="$(awk '{print $2}' /proc/loadavg)"
    LOAD_15M="$(awk '{print $3}' /proc/loadavg)"
else
    LOAD_1M="$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')"
    LOAD_5M="$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $2}' | tr -d ' ')"
    LOAD_15M="$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $3}' | tr -d ' ')"
fi

LOAD_PER_CORE="$(awk -v l="$LOAD_1M" -v c="$CPU_CORES" 'BEGIN { printf "%.2f", l / c }')"

# CPU Usage Percentage calculation from /proc/stat
CPU_UTIL_PCT="0.0"
if [[ -f /proc/stat ]]; then
    # Sample 1
    read -r _ u1 n1 s1 i1 w1 irq1 sirq1 steal1 _ < /proc/stat
    total1=$(( u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + steal1 ))
    idle1=$(( i1 + w1 ))
    sleep 0.3
    # Sample 2
    read -r _ u2 n2 s2 i2 w2 irq2 sirq2 steal2 _ < /proc/stat
    total2=$(( u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + steal2 ))
    idle2=$(( i2 + w2 ))

    diff_total=$(( total2 - total1 ))
    diff_idle=$(( idle2 - idle1 ))
    if [[ $diff_total -gt 0 ]]; then
        CPU_UTIL_PCT="$(awk -v dt="$diff_total" -v di="$diff_idle" 'BEGIN { printf "%.1f", ((dt - di) / dt) * 100 }')"
    fi
fi

# ------------------------------------------------------------------------------
# Step 3: Memory & Swap Accounting
# ------------------------------------------------------------------------------
# Parse free in megabytes
MEM_TOTAL_MB=0
MEM_USED_MB=0
MEM_FREE_MB=0
MEM_AVAIL_MB=0
MEM_USAGE_PCT=0.0

SWAP_TOTAL_MB=0
SWAP_USED_MB=0
SWAP_FREE_MB=0
SWAP_USAGE_PCT=0.0

if command -v free >/dev/null 2>&1; then
    # Mem: total used free shared buff/cache available
    MEM_LINE="$(free -m | grep -i '^Mem:')"
    MEM_TOTAL_MB="$(echo "$MEM_LINE" | awk '{print $2}')"
    MEM_USED_MB="$(echo "$MEM_LINE" | awk '{print $3}')"
    MEM_FREE_MB="$(echo "$MEM_LINE" | awk '{print $4}')"
    MEM_AVAIL_MB="$(echo "$MEM_LINE" | awk '{print $7}')"

    if [[ "$MEM_TOTAL_MB" -gt 0 ]]; then
        MEM_USAGE_PCT="$(awk -v u="$MEM_USED_MB" -v t="$MEM_TOTAL_MB" 'BEGIN { printf "%.1f", (u / t) * 100 }')"
    fi

    # Swap
    SWAP_LINE="$(free -m | grep -i '^Swap:' || true)"
    if [[ -n "$SWAP_LINE" ]]; then
        SWAP_TOTAL_MB="$(echo "$SWAP_LINE" | awk '{print $2}')"
        SWAP_USED_MB="$(echo "$SWAP_LINE" | awk '{print $3}')"
        SWAP_FREE_MB="$(echo "$SWAP_LINE" | awk '{print $4}')"
        if [[ "$SWAP_TOTAL_MB" -gt 0 ]]; then
            SWAP_USAGE_PCT="$(awk -v u="$SWAP_USED_MB" -v t="$SWAP_TOTAL_MB" 'BEGIN { printf "%.1f", (u / t) * 100 }')"
        fi
    fi
fi

# Human-readable Memory Strings
MEM_TOTAL_HR="$(free -h | grep -i '^Mem:' | awk '{print $2}')"
MEM_USED_HR="$(free -h | grep -i '^Mem:' | awk '{print $3}')"
MEM_AVAIL_HR="$(free -h | grep -i '^Mem:' | awk '{print $7}')"

# ------------------------------------------------------------------------------
# Step 4: Storage & Filesystem Utilization
# ------------------------------------------------------------------------------
# Query root filesystem utilization
ROOT_DISK_TOTAL="$(df -h / | awk 'NR==2 {print $2}')"
ROOT_DISK_USED="$(df -h / | awk 'NR==2 {print $3}')"
ROOT_DISK_AVAIL="$(df -h / | awk 'NR==2 {print $4}')"
ROOT_DISK_USE_PCT="$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')"

# Raw mounted physical filesystems
FS_TABLE_RAW="$(df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h)"

# ------------------------------------------------------------------------------
# Step 5: Logged-in Users & Session Tracking
# ------------------------------------------------------------------------------
ACTIVE_USERS_COUNT=0
USER_SESSIONS_LIST=()
WHO_OUTPUT="$(who 2>/dev/null || true)"

if [[ -n "$WHO_OUTPUT" ]]; then
    ACTIVE_USERS_COUNT="$(echo "$WHO_OUTPUT" | wc -l | tr -d ' ')"
fi

# ------------------------------------------------------------------------------
# Step 6: Process Diagnostics & Top Consumers
# ------------------------------------------------------------------------------
TOTAL_PROCESSES="$(ps -ef 2>/dev/null | awk 'NR>1 {c++} END {print c+0}')"
ZOMBIE_COUNT="$(ps -eo stat 2>/dev/null | grep -c '^Z' || true)"

TOP_CPU_PROCS="$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 4 || true)"
TOP_MEM_PROCS="$(ps -eo pid,user,%mem,%cpu,comm --sort=-%mem 2>/dev/null | head -n 4 || true)"

# ------------------------------------------------------------------------------
# Health Status Assessment
# ------------------------------------------------------------------------------
HEALTH_STATUS="OPTIMAL"
HEALTH_COLOR="$COLOR_GREEN"
HEALTH_WARNINGS=()

if (( $(awk -v p="$LOAD_PER_CORE" -v th="$THRESH_LOAD_PER_CORE" 'BEGIN {print (p >= th)}') )); then
    HEALTH_STATUS="DEGRADED"
    HEALTH_COLOR="$COLOR_YELLOW"
    HEALTH_WARNINGS+=("High load average: ${LOAD_PER_CORE}/core")
fi

if (( $(awk -v m="$MEM_USAGE_PCT" -v th="$THRESH_MEM_PCT" 'BEGIN {print (m >= th)}') )); then
    HEALTH_STATUS="DEGRADED"
    HEALTH_COLOR="$COLOR_YELLOW"
    HEALTH_WARNINGS+=("High RAM utilization: ${MEM_USAGE_PCT}%")
fi

if (( ROOT_DISK_USE_PCT >= 85 )); then
    HEALTH_STATUS="CRITICAL"
    HEALTH_COLOR="$COLOR_RED"
    HEALTH_WARNINGS+=("High root disk utilization: ${ROOT_DISK_USE_PCT}%")
fi

if [[ "$ZOMBIE_COUNT" -gt 0 ]]; then
    HEALTH_WARNINGS+=("Detected ${ZOMBIE_COUNT} zombie process(es)")
fi

# ------------------------------------------------------------------------------
# JSON Serialization
# ------------------------------------------------------------------------------
# Format user sessions for JSON
USER_SESSIONS_JSON=()
if [[ -n "$WHO_OUTPUT" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        u_name="$(echo "$line" | awk '{print $1}')"
        u_tty="$(echo "$line" | awk '{print $2}')"
        u_time="$(echo "$line" | awk '{print $3, $4}')"
        u_ip="$(echo "$line" | awk '{print $5}' | tr -d '()' || echo 'local')"
        USER_SESSIONS_JSON+=("{\"user\":\"$u_name\",\"terminal\":\"$u_tty\",\"login_time\":\"$u_time\",\"host\":\"$u_ip\"}")
    done <<< "$WHO_OUTPUT"
fi
USER_SESSIONS_JOINED="$(IFS=,; echo "${USER_SESSIONS_JSON[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_06",
  "title": "Server Health Check",
  "timestamp": "$TIMESTAMP_STR",
  "timestamp_epoch": $(date +%s),
  "host": {
    "hostname": "$HOSTNAME_STR",
    "os": "$OS_DISPLAY",
    "kernel": "$KERNEL_STR",
    "arch": "$ARCH_STR",
    "boot_time": "$BOOT_TIME",
    "uptime": "$UPTIME_PRETTY"
  },
  "cpu": {
    "cores": $CPU_CORES,
    "utilization_pct": $CPU_UTIL_PCT,
    "load_1m": $LOAD_1M,
    "load_5m": $LOAD_5M,
    "load_15m": $LOAD_15M,
    "load_per_core": $LOAD_PER_CORE
  },
  "memory": {
    "total_mb": $MEM_TOTAL_MB,
    "used_mb": $MEM_USED_MB,
    "free_mb": $MEM_FREE_MB,
    "available_mb": $MEM_AVAIL_MB,
    "usage_pct": $MEM_USAGE_PCT,
    "total_readable": "$MEM_TOTAL_HR",
    "used_readable": "$MEM_USED_HR",
    "avail_readable": "$MEM_AVAIL_HR"
  },
  "swap": {
    "total_mb": $SWAP_TOTAL_MB,
    "used_mb": $SWAP_USED_MB,
    "usage_pct": $SWAP_USAGE_PCT
  },
  "disk": {
    "root_total": "$ROOT_DISK_TOTAL",
    "root_used": "$ROOT_DISK_USED",
    "root_avail": "$ROOT_DISK_AVAIL",
    "root_use_pct": $ROOT_DISK_USE_PCT
  },
  "users": {
    "logged_in_count": $ACTIVE_USERS_COUNT,
    "sessions": [
      $USER_SESSIONS_JOINED
    ]
  },
  "processes": {
    "total_count": $TOTAL_PROCESSES,
    "zombie_count": $ZOMBIE_COUNT
  },
  "health": {
    "status": "$HEALTH_STATUS",
    "warnings_count": ${#HEALTH_WARNINGS[@]}
  }
}
EOF

log "HEALTH" "Health scan completed. Status: $HEALTH_STATUS, CPU: ${CPU_UTIL_PCT}%, Mem: ${MEM_USAGE_PCT}%, Disk: ${ROOT_DISK_USE_PCT}%"

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
    exit 0
fi

if [[ "$QUIET" == true ]]; then
    echo -e "Health Status: ${HEALTH_COLOR}${HEALTH_STATUS}${COLOR_RESET}"
    exit 0
fi

# ------------------------------------------------------------------------------
# Terminal Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}          PRE-WORKDAY SERVER HEALTH CHECK & OPERATIONAL AUDIT (AS_06)            ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Hostname       : ${COLOR_BOLD}${HOSTNAME_STR}${COLOR_RESET} (${OS_DISPLAY})"
echo -e " Kernel / Arch  : ${KERNEL_STR} (${ARCH_STR})"
echo -e " System Uptime  : ${COLOR_GREEN}${UPTIME_PRETTY}${COLOR_RESET} (Boot: ${BOOT_TIME})"
echo -e " Timestamp      : ${TIMESTAMP_STR}"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# Section 1: CPU & Load
echo -e "${COLOR_BOLD}[1] CPU & SYSTEM LOAD AUDIT${COLOR_RESET}"
echo -e "  - Logical Cores  : ${CPU_CORES} core(s)"
echo -e "  - CPU Utilization: ${COLOR_BOLD}${CPU_UTIL_PCT}%${COLOR_RESET}"
echo -e "  - Load Averages  : 1m: ${COLOR_BOLD}${LOAD_1M}${COLOR_RESET} | 5m: ${COLOR_BOLD}${LOAD_5M}${COLOR_RESET} | 15m: ${COLOR_BOLD}${LOAD_15M}${COLOR_RESET}"
echo -e "  - Load per Core  : ${COLOR_BOLD}${LOAD_PER_CORE}${COLOR_RESET} (Threshold: < ${THRESH_LOAD_PER_CORE})"

# Section 2: Memory & Swap
echo -e ""
echo -e "${COLOR_BOLD}[2] MEMORY (RAM) & SWAP ACCOUNTING${COLOR_RESET}"
echo -e "  - Total RAM      : ${MEM_TOTAL_HR} (${MEM_TOTAL_MB} MB)"
echo -e "  - Used RAM       : ${MEM_USED_HR} (${MEM_USED_MB} MB) -> ${COLOR_BOLD}${MEM_USAGE_PCT}%${COLOR_RESET}"
echo -e "  - Available RAM  : ${COLOR_GREEN}${MEM_AVAIL_HR} (${MEM_AVAIL_MB} MB)${COLOR_RESET}"
if [[ "$SWAP_TOTAL_MB" -gt 0 ]]; then
    echo -e "  - Swap Space     : ${SWAP_USED_MB} MB used / ${SWAP_TOTAL_MB} MB total (${SWAP_USAGE_PCT}%)"
else
    echo -e "  - Swap Space     : None configured / Inactive"
fi

# Section 3: Disk Space
echo -e ""
echo -e "${COLOR_BOLD}[3] STORAGE & DISK UTILIZATION (ROOT /)${COLOR_RESET}"
echo -e "  - Total Space    : ${ROOT_DISK_TOTAL}"
echo -e "  - Used Space     : ${ROOT_DISK_USED} (${COLOR_BOLD}${ROOT_DISK_USE_PCT}%${COLOR_RESET})"
echo -e "  - Available      : ${COLOR_GREEN}${ROOT_DISK_AVAIL}${COLOR_RESET}"
echo -e "  - Filesystem Table:"
echo "$FS_TABLE_RAW" | head -n 6 | sed 's/^/      /'

# Section 4: Logged-In Users
echo -e ""
echo -e "${COLOR_BOLD}[4] ACTIVE LOGGED-IN USERS & TERMINAL SESSIONS${COLOR_RESET}"
echo -e "  - Total Active Sessions: ${COLOR_BOLD}${ACTIVE_USERS_COUNT}${COLOR_RESET}"
if [[ $ACTIVE_USERS_COUNT -gt 0 ]]; then
    printf "      %-12s %-10s %-18s %s\n" "USER" "TTY" "LOGIN TIME" "FROM"
    echo "      --------------------------------------------------------"
    echo "$WHO_OUTPUT" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "      %-12s %-10s %-18s %s\n" \
            "$(echo "$line" | awk '{print $1}')" \
            "$(echo "$line" | awk '{print $2}')" \
            "$(echo "$line" | awk '{print $3, $4}')" \
            "$(echo "$line" | awk '{print $5}' || echo 'local')"
    done
else
    echo "      (No active interactive user sessions detected)"
fi

# Section 5: Process Diagnostics
echo -e ""
echo -e "${COLOR_BOLD}[5] PROCESS DIAGNOSTICS${COLOR_RESET}"
echo -e "  - Active Tasks   : ${TOTAL_PROCESSES} total processes"
echo -e "  - Zombie Tasks   : $([[ "$ZOMBIE_COUNT" -gt 0 ]] && echo -e "${COLOR_RED}${ZOMBIE_COUNT} ZOMBIES DETECTED${COLOR_RESET}" || echo -e "${COLOR_GREEN}0 (Clean)${COLOR_RESET}")"

# Section 6: Overall Verdict
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}SYSTEM OPERATIONAL STATUS: ${HEALTH_COLOR}${HEALTH_STATUS}${COLOR_RESET}"
if [[ ${#HEALTH_WARNINGS[@]} -gt 0 ]]; then
    for w in "${HEALTH_WARNINGS[@]}"; do
        echo -e "  ${COLOR_YELLOW}⚠️  WARNING: $w${COLOR_RESET}"
    done
else
    echo -e "  ${COLOR_GREEN}✅ All core subsystems (CPU, RAM, Disk, Uptime, Users) are operating normally.${COLOR_RESET}"
fi
echo -e " Telemetry File : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e " Audit Log File : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
