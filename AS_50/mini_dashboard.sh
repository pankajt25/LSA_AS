#!/usr/bin/env bash
# ==============================================================================
# Script: mini_dashboard.sh
# Purpose: Mini Linux Administration Dashboard displaying CPU, Memory, Disk,
#          Logged-in Users, Running Services, and System Uptime.
# Author: System Administrator (LSA Sprint AS_50)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/dashboard_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

SAMPLE_INTERVAL=0.5
JSON_ONLY=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -s, --sample-interval <SEC>   CPU sampling interval in seconds (default: 0.5)
  -j, --json-only               Suppress terminal ANSI output, only update log/JSON
  -h, --help                    Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--sample-interval)
            SAMPLE_INTERVAL="$2"
            shift 2
            ;;
        -j|--json-only)
            JSON_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# ANSI color codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"
C_DIM="\033[2m"

# ------------------------------------------------------------------------------
# 1. System Metadata & Uptime
# ------------------------------------------------------------------------------
HOSTNAME_SYS="$(hostname)"
KERNEL_SYS="$(uname -r)"
ARCH_SYS="$(uname -m)"

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    OS_NAME_SYS="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"' || uname -s)"
else
    OS_NAME_SYS="$(uname -s)"
fi

read -r UPTIME_SECS _ < /proc/uptime
UPTIME_INT="${UPTIME_SECS%%.*}"

DAYS=$(( UPTIME_INT / 86400 ))
HOURS=$(( (UPTIME_INT % 86400) / 3600 ))
MINUTES=$(( (UPTIME_INT % 3600) / 60 ))
SECS=$(( UPTIME_INT % 60 ))

UPTIME_FORMATTED=""
if [ "${DAYS}" -gt 0 ]; then
    UPTIME_FORMATTED="${DAYS}d "
fi
UPTIME_FORMATTED="${UPTIME_FORMATTED}${HOURS}h ${MINUTES}m ${SECS}s"

BOOT_EPOCH=$(awk '/btime/ {print $2}' /proc/stat || echo "0")
BOOT_TIMESTAMP="$(date -d "@${BOOT_EPOCH}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")"

# ------------------------------------------------------------------------------
# 2. CPU Utilization & Load
# ------------------------------------------------------------------------------
CPU_CORES=$(nproc 2>/dev/null || echo 1)
read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg

# CPU delta sampling
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep "${SAMPLE_INTERVAL}"
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat

IDLE1=$(( i1 + w1 ))
IDLE2=$(( i2 + w2 ))
TOTAL1=$(( u1 + n1 + s1 + i1 + w1 + q1 + sq1 + st1 ))
TOTAL2=$(( u2 + n2 + s2 + i2 + w2 + q2 + sq2 + st2 ))

DIFF_IDLE=$(( IDLE2 - IDLE1 ))
DIFF_TOTAL=$(( TOTAL2 - TOTAL1 ))

if [ "${DIFF_TOTAL}" -gt 0 ]; then
    CPU_USAGE_PCT=$(awk -v idle="${DIFF_IDLE}" -v total="${DIFF_TOTAL}" 'BEGIN { printf "%.1f", (1.0 - (idle/total)) * 100.0 }')
else
    CPU_USAGE_PCT="0.0"
fi

# Top 5 CPU Processes
TOP_CPU_PROCS=()
while IFS= read -r line; do
    [ -z "${line}" ] && continue
    TOP_CPU_PROCS+=("${line}")
done < <(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu --no-headers | head -n 5)

# ------------------------------------------------------------------------------
# 3. Memory & Swap
# ------------------------------------------------------------------------------
MEM_TOTAL_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo || echo 0)
MEM_AVAIL_KB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo || echo 0)
MEM_FREE_KB=$(awk '/MemFree:/ {print $2}' /proc/meminfo || echo 0)
BUFFERS_KB=$(awk '/Buffers:/ {print $2}' /proc/meminfo || echo 0)
CACHED_KB=$(awk '/^Cached:/ {print $2}' /proc/meminfo || echo 0)

MEM_USED_KB=$(( MEM_TOTAL_KB - MEM_AVAIL_KB ))
if [ "${MEM_TOTAL_KB}" -gt 0 ]; then
    MEM_USAGE_PCT=$(awk -v used="${MEM_USED_KB}" -v total="${MEM_TOTAL_KB}" 'BEGIN { printf "%.1f", (used/total) * 100.0 }')
else
    MEM_USAGE_PCT="0.0"
fi

SWAP_TOTAL_KB=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo || echo 0)
SWAP_FREE_KB=$(awk '/SwapFree:/ {print $2}' /proc/meminfo || echo 0)
SWAP_USED_KB=$(( SWAP_TOTAL_KB - SWAP_FREE_KB ))

if [ "${SWAP_TOTAL_KB}" -gt 0 ]; then
    SWAP_USAGE_PCT=$(awk -v used="${SWAP_USED_KB}" -v total="${SWAP_TOTAL_KB}" 'BEGIN { printf "%.1f", (used/total) * 100.0 }')
else
    SWAP_USAGE_PCT="0.0"
fi

MEM_TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
MEM_USED_MB=$(( MEM_USED_KB / 1024 ))
MEM_AVAIL_MB=$(( MEM_AVAIL_KB / 1024 ))
SWAP_TOTAL_MB=$(( SWAP_TOTAL_KB / 1024 ))
SWAP_USED_MB=$(( SWAP_USED_KB / 1024 ))

# Top 5 Memory Processes
TOP_MEM_PROCS=()
while IFS= read -r line; do
    [ -z "${line}" ] && continue
    TOP_MEM_PROCS+=("${line}")
done < <(ps -eo pid,user,%mem,%cpu,comm --sort=-%mem --no-headers | head -n 5)

# ------------------------------------------------------------------------------
# 4. Storage & Filesystem Capacity
# ------------------------------------------------------------------------------
ROOT_LINE=$(df -hP / | tail -n 1)
ROOT_FS=$(awk '{print $1}' <<< "${ROOT_LINE}")
ROOT_SIZE=$(awk '{print $2}' <<< "${ROOT_LINE}")
ROOT_USED=$(awk '{print $3}' <<< "${ROOT_LINE}")
ROOT_AVAIL=$(awk '{print $4}' <<< "${ROOT_LINE}")
ROOT_PCT_STR=$(awk '{print $5}' <<< "${ROOT_LINE}")
ROOT_PCT="${ROOT_PCT_STR%\%}"

ROOT_INODE_LINE=$(df -iP / | tail -n 1)
ROOT_INODE_TOTAL=$(awk '{print $2}' <<< "${ROOT_INODE_LINE}")
ROOT_INODE_USED=$(awk '{print $3}' <<< "${ROOT_INODE_LINE}")
ROOT_INODE_PCT_STR=$(awk '{print $5}' <<< "${ROOT_INODE_LINE}")
ROOT_INODE_PCT="${ROOT_INODE_PCT_STR%\%}"

# All mount points (filter out virtual duplication, capture real mounts)
ALL_MOUNTS=()
while IFS= read -r mline; do
    [ -z "${mline}" ] && continue
    m_fs=$(awk '{print $1}' <<< "${mline}")
    m_size=$(awk '{print $2}' <<< "${mline}")
    m_used=$(awk '{print $3}' <<< "${mline}")
    m_avail=$(awk '{print $4}' <<< "${mline}")
    m_pct=$(awk '{print $5}' <<< "${mline}")
    m_point=$(awk '{print $6}' <<< "${mline}")
    
    # CRITICAL: Escape backslashes for DrvFs mount names (C:\ and D:\)
    m_fs="${m_fs//\\/\\\\}"
    m_point="${m_point//\\/\\\\}"
    
    ALL_MOUNTS+=("{\"filesystem\": \"${m_fs}\", \"size\": \"${m_size}\", \"used\": \"${m_used}\", \"avail\": \"${m_avail}\", \"pct\": \"${m_pct}\", \"mount\": \"${m_point}\"}")
done < <(df -hP | grep -vE '^Filesystem' | grep -vE '(/run/credentials|/usr/lib/modules|/mnt/wslg/doc|/mnt/wslg/versions)')

# ------------------------------------------------------------------------------
# 5. Logged-in Users
# ------------------------------------------------------------------------------
LOGGED_USERS=()
while IFS= read -r uline; do
    [ -z "${uline}" ] && continue
    u_name=$(awk '{print $1}' <<< "${uline}")
    u_line=$(awk '{print $2}' <<< "${uline}")
    u_date=$(awk '{print $3 " " $4}' <<< "${uline}")
    u_host=$(awk '{$1=$2=$3=$4=""; print $0}' <<< "${uline}" | sed 's/^[ \t]*//' | tr -d '()')
    [ -z "${u_host}" ] && u_host="local"
    LOGGED_USERS+=("{\"user\": \"${u_name}\", \"terminal\": \"${u_line}\", \"time\": \"${u_date}\", \"host\": \"${u_host}\"}")
done < <(who || true)

ACTIVE_SESSION_COUNT="${#LOGGED_USERS[@]}"
UNIQUE_USER_COUNT=$(who | awk '{print $1}' | sort -u | wc -l || echo 0)

# If no sessions reported (e.g., automated cron or subshell), capture current caller
if [ "${ACTIVE_SESSION_COUNT}" -eq 0 ]; then
    CURRENT_CALLER="${USER:-$(id -un)}"
    LOGGED_USERS+=("{\"user\": \"${CURRENT_CALLER}\", \"terminal\": \"console\", \"time\": \"$(date +"%Y-%m-%d %H:%M")\", \"host\": \"active-session\"}")
    ACTIVE_SESSION_COUNT=1
    UNIQUE_USER_COUNT=1
fi

# ------------------------------------------------------------------------------
# 6. Running Services & Daemon Health
# ------------------------------------------------------------------------------
TOTAL_SERVICES_RUNNING=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || echo 0)
TOTAL_SERVICES_FAILED=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | wc -l || echo 0)

CHECK_SERVICES=("cron" "dbus" "rsyslog" "systemd-journald" "systemd-logind" "systemd-resolved" "containerd" "ssh" "sshd")
SERVICE_RECORDS=()

for svc in "${CHECK_SERVICES[@]}"; do
    unit="${svc}.service"
    
    # Check if unit exists
    unit_status=$(systemctl is-active "${unit}" 2>/dev/null || echo "inactive")
    if [ "${unit_status}" == "active" ]; then
        state="ACTIVE"
        enabled_state=$(systemctl is-enabled "${unit}" 2>/dev/null || echo "unknown")
        pid=$(systemctl show -p MainPID --value "${unit}" 2>/dev/null || echo "0")
        mem_bytes=$(systemctl show -p MemoryCurrent --value "${unit}" 2>/dev/null || echo "0")
        if [[ "${mem_bytes}" =~ ^[0-9]+$ ]] && [ "${mem_bytes}" -gt 0 ]; then
            mem_formatted="$(awk -v b="${mem_bytes}" 'BEGIN { printf "%.1f MB", b / 1048576 }')"
        else
            mem_formatted="N/A"
        fi
        SERVICE_RECORDS+=("{\"unit\": \"${unit}\", \"status\": \"ACTIVE\", \"enabled\": \"${enabled_state}\", \"pid\": \"${pid}\", \"memory\": \"${mem_formatted}\"}")
    else
        # Check if enabled or installed
        if systemctl list-unit-files "${unit}" &>/dev/null; then
            enabled_state=$(systemctl is-enabled "${unit}" 2>/dev/null || echo "inactive")
            SERVICE_RECORDS+=("{\"unit\": \"${unit}\", \"status\": \"INACTIVE\", \"enabled\": \"${enabled_state}\", \"pid\": \"0\", \"memory\": \"-\"}")
        fi
    fi
done

# ------------------------------------------------------------------------------
# Progress Bar Helper for Terminal Output
# ------------------------------------------------------------------------------
render_bar() {
    local pct_int="${1%%.*}"
    local width=20
    local filled=$(( (pct_int * width) / 100 ))
    local empty=$(( width - filled ))
    [ "${filled}" -gt "${width}" ] && filled="${width}"
    [ "${empty}" -lt 0 ] && empty=0
    
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    bar+="]"
    echo -n "${bar}"
}

# ------------------------------------------------------------------------------
# Terminal Dashboard Display
# ------------------------------------------------------------------------------
{
    echo -e "${C_CYAN}========================================================================================${C_RESET}"
    echo -e "${C_BOLD}   LINUX SYSTEM ADMINISTRATION — MINI ADMINISTRATION DASHBOARD (AS_50)${C_RESET}"
    echo -e "${C_CYAN}========================================================================================${C_RESET}"
    echo -e " Hostname:    ${C_BOLD}${HOSTNAME_SYS}${C_RESET} | OS: ${OS_NAME_SYS} | Kernel: ${KERNEL_SYS}"
    echo -e " Uptime:      ${C_GREEN}${UPTIME_FORMATTED}${C_RESET} (Boot: ${BOOT_TIMESTAMP}) | Cores: ${CPU_CORES}"
    echo -e "${C_CYAN}----------------------------------------------------------------------------------------${C_RESET}"
    
    # Resource Utilization Cards
    echo -e "${C_BOLD}VITAL RESOURCE UTILIZATION:${C_RESET}"
    echo -e "  CPU Usage:    $(render_bar "${CPU_USAGE_PCT}") ${C_BOLD}${CPU_USAGE_PCT}%${C_RESET}  (Load 1m/5m/15m: ${LOAD1}, ${LOAD5}, ${LOAD15})"
    echo -e "  Memory Usage: $(render_bar "${MEM_USAGE_PCT}") ${C_BOLD}${MEM_USAGE_PCT}%${C_RESET}  (${MEM_USED_MB} MB / ${MEM_TOTAL_MB} MB, Avail: ${MEM_AVAIL_MB} MB)"
    echo -e "  Swap Usage:   $(render_bar "${SWAP_USAGE_PCT}") ${C_BOLD}${SWAP_USAGE_PCT}%${C_RESET}  (${SWAP_USED_MB} MB / ${SWAP_TOTAL_MB} MB)"
    echo -e "  Root Storage: $(render_bar "${ROOT_PCT}") ${C_BOLD}${ROOT_PCT}%${C_RESET}  (${ROOT_USED} / ${ROOT_SIZE}, Avail: ${ROOT_AVAIL}, Inodes: ${ROOT_INODE_PCT}%)"
    echo -e ""
    
    # Active Users & Daemons Overview
    echo -e "${C_BOLD}SYSTEM SESSIONS & CORE DAEMONS:${C_RESET}"
    echo -e "  Active Users: ${C_BOLD}${ACTIVE_SESSION_COUNT}${C_RESET} session(s) (${UNIQUE_USER_COUNT} unique)"
    echo -e "  Systemd Units: ${C_GREEN}${TOTAL_SERVICES_RUNNING} running${C_RESET} | ${C_RED}${TOTAL_SERVICES_FAILED} failed${C_RESET}"
    echo -e ""
    
    # Tabular Monitored Services
    echo -e "${C_BOLD}KEY MONITORED SERVICES:${C_RESET}"
    printf "  %-24s %-10s %-10s %-8s %-12s\n" "SERVICE UNIT" "STATUS" "ENABLED" "MAIN PID" "MEMORY"
    printf "  %-24s %-10s %-10s %-8s %-12s\n" "------------------------" "----------" "----------" "--------" "------------"
    for s_json in "${SERVICE_RECORDS[@]}"; do
        u_name=$(python3 -c "import json; d=json.loads('${s_json}'); print(d['unit'])")
        u_stat=$(python3 -c "import json; d=json.loads('${s_json}'); print(d['status'])")
        u_enab=$(python3 -c "import json; d=json.loads('${s_json}'); print(d['enabled'])")
        u_pid=$(python3 -c "import json; d=json.loads('${s_json}'); print(d['pid'])")
        u_mem=$(python3 -c "import json; d=json.loads('${s_json}'); print(d['memory'])")
        
        if [ "${u_stat}" == "ACTIVE" ]; then
            stat_color="${C_GREEN}${u_stat}${C_RESET}"
        else
            stat_color="${C_RED}${u_stat}${C_RESET}"
        fi
        printf "  %-24s %-20b %-10s %-8s %-12s\n" "${u_name}" "${stat_color}" "${u_enab}" "${u_pid}" "${u_mem}"
    done
    echo -e ""
    
    # Tabular Active Users
    echo -e "${C_BOLD}LOGGED-IN SESSIONS:${C_RESET}"
    printf "  %-12s %-12s %-18s %-20s\n" "USER" "TERMINAL" "LOGIN TIME" "HOST / ORIGIN"
    printf "  %-12s %-12s %-18s %-20s\n" "------------" "------------" "------------------" "--------------------"
    for u_json in "${LOGGED_USERS[@]}"; do
        usr=$(python3 -c "import json; d=json.loads('${u_json}'); print(d['user'])")
        tty=$(python3 -c "import json; d=json.loads('${u_json}'); print(d['terminal'])")
        ltime=$(python3 -c "import json; d=json.loads('${u_json}'); print(d['time'])")
        host=$(python3 -c "import json; d=json.loads('${u_json}'); print(d['host'])")
        printf "  %-12s %-12s %-18s %-20s\n" "${usr}" "${tty}" "${ltime}" "${host}"
    done
    echo -e ""
    
    # Top CPU Processes
    echo -e "${C_BOLD}TOP CPU PROCESSES:${C_RESET}"
    printf "  %-8s %-12s %-8s %-8s %-20s\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
    for proc in "${TOP_CPU_PROCS[@]}"; do
        p_pid=$(awk '{print $1}' <<< "${proc}")
        p_usr=$(awk '{print $2}' <<< "${proc}")
        p_cpu=$(awk '{print $3}' <<< "${proc}")
        p_mem=$(awk '{print $4}' <<< "${proc}")
        p_cmd=$(awk '{print $5}' <<< "${proc}")
        printf "  %-8s %-12s %-8s %-8s %-20s\n" "${p_pid}" "${p_usr}" "${p_cpu}" "${p_mem}" "${p_cmd}"
    done
    echo -e "${C_CYAN}========================================================================================${C_RESET}"
} | tee "${LOG_FILE}"

# If JSON only requested, suppress terminal printing
if [ "${JSON_ONLY}" = true ]; then
    cat "${LOG_FILE}" >/dev/null
fi

# ------------------------------------------------------------------------------
# Export JSON Telemetry
# ------------------------------------------------------------------------------
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "system": {
        "hostname": "${HOSTNAME_SYS}",
        "os_name": "${OS_NAME_SYS}",
        "kernel": "${KERNEL_SYS}",
        "architecture": "${ARCH_SYS}",
        "uptime": {
            "seconds": int("${UPTIME_INT}"),
            "formatted": "${UPTIME_FORMATTED}",
            "boot_epoch": int("${BOOT_EPOCH}"),
            "boot_time": "${BOOT_TIMESTAMP}"
        }
    },
    "cpu": {
        "usage_pct": float("${CPU_USAGE_PCT}"),
        "cores": int("${CPU_CORES}"),
        "load_avg": {
            "1m": float("${LOAD1}"),
            "5m": float("${LOAD5}"),
            "15m": float("${LOAD15}")
        },
        "top_processes": [
            $([ ${#TOP_CPU_PROCS[@]} -gt 0 ] && {
                first=1
                for proc in "${TOP_CPU_PROCS[@]}"; do
                    [ $first -eq 0 ] && echo ","
                    first=0
                    p_pid=$(awk '{print $1}' <<< "${proc}")
                    p_usr=$(awk '{print $2}' <<< "${proc}")
                    p_cpu=$(awk '{print $3}' <<< "${proc}")
                    p_mem=$(awk '{print $4}' <<< "${proc}")
                    p_cmd=$(awk '{$1=$2=$3=$4=""; print $0}' <<< "${proc}" | sed 's/^[ \t]*//')
                    echo -n "{\"pid\": \"${p_pid}\", \"user\": \"${p_usr}\", \"cpu\": \"${p_cpu}\", \"mem\": \"${p_mem}\", \"command\": \"${p_cmd}\"}"
                done
            })
        ]
    },
    "memory": {
        "total_mb": int("${MEM_TOTAL_MB}"),
        "used_mb": int("${MEM_USED_MB}"),
        "avail_mb": int("${MEM_AVAIL_MB}"),
        "usage_pct": float("${MEM_USAGE_PCT}"),
        "swap_total_mb": int("${SWAP_TOTAL_MB}"),
        "swap_used_mb": int("${SWAP_USED_MB}"),
        "swap_usage_pct": float("${SWAP_USAGE_PCT}"),
        "top_processes": [
            $([ ${#TOP_MEM_PROCS[@]} -gt 0 ] && {
                first=1
                for proc in "${TOP_MEM_PROCS[@]}"; do
                    [ $first -eq 0 ] && echo ","
                    first=0
                    p_pid=$(awk '{print $1}' <<< "${proc}")
                    p_usr=$(awk '{print $2}' <<< "${proc}")
                    p_mem=$(awk '{print $3}' <<< "${proc}")
                    p_cpu=$(awk '{print $4}' <<< "${proc}")
                    p_cmd=$(awk '{$1=$2=$3=$4=""; print $0}' <<< "${proc}" | sed 's/^[ \t]*//')
                    echo -n "{\"pid\": \"${p_pid}\", \"user\": \"${p_usr}\", \"mem\": \"${p_mem}\", \"cpu\": \"${p_cpu}\", \"command\": \"${p_cmd}\"}"
                done
            })
        ]
    },
    "disk": {
        "root": {
            "filesystem": "${ROOT_FS}",
            "size": "${ROOT_SIZE}",
            "used": "${ROOT_USED}",
            "avail": "${ROOT_AVAIL}",
            "usage_pct": float("${ROOT_PCT}"),
            "inode_pct": float("${ROOT_INODE_PCT}")
        },
        "mounts": [
            $(IFS=,; echo "${ALL_MOUNTS[*]}")
        ]
    },
    "users": {
        "session_count": int("${ACTIVE_SESSION_COUNT}"),
        "unique_count": int("${UNIQUE_USER_COUNT}"),
        "sessions": [
            $(IFS=,; echo "${LOGGED_USERS[*]}")
        ]
    },
    "services": {
        "total_running": int("${TOTAL_SERVICES_RUNNING}"),
        "total_failed": int("${TOTAL_SERVICES_FAILED}"),
        "monitored": [
            $(IFS=,; echo "${SERVICE_RECORDS[*]}")
        ]
    },
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Mini dashboard telemetry exported to ${SUMMARY_JSON}")
PYEOF

exit 0
