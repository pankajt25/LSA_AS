#!/usr/bin/env bash
# ==============================================================================
# Script: admin_daily_report.sh
# Purpose: Generate comprehensive administrator daily report covering uptime,
#          CPU, memory, disk usage, active users, and system services.
# Author: System Administrator (LSA Sprint AS_48)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${REPORTS_DIR}" "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
DATE_STAMP="$(date +"%Y%m%d")"
LOG_FILE="${LOG_DIR}/daily_report_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"
DAILY_TXT="${REPORTS_DIR}/daily_report_${DATE_STAMP}.txt"
LATEST_TXT="${REPORTS_DIR}/latest_daily_report.txt"

QUIET=false

log() {
    local level="$1"
    shift
    local msg="[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*"
    echo -e "${msg}" >> "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -o, --output-dir <DIR>  Destination directory for daily report files (default: reports/)
  -q, --quiet             Suppress console output
  -h, --help              Display this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir)
            REPORTS_DIR="$2"
            mkdir -p "${REPORTS_DIR}"
            DAILY_TXT="${REPORTS_DIR}/daily_report_${DATE_STAMP}.txt"
            LATEST_TXT="${REPORTS_DIR}/latest_daily_report.txt"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_48 - Administrator Daily Report Engine"
log "INFO" "Report File:          ${DAILY_TXT}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# --- 1. Uptime & Kernel Architecture ---
read -r UPTIME_RAW _ < /proc/uptime
UPTIME_SECS=$(echo "${UPTIME_RAW}" | cut -d. -f1)
DAYS=$((UPTIME_SECS / 86400))
HOURS=$(( (UPTIME_SECS % 86400) / 3600 ))
MINS=$(( (UPTIME_SECS % 3600) / 60 ))
SECS=$((UPTIME_SECS % 60))
FORMATTED_UPTIME="${DAYS}d ${HOURS}h ${MINS}m ${SECS}s"
PRETTY_UPTIME=$(uptime -p 2>/dev/null || echo "up ${DAYS} days, ${HOURS} hours")
BOOT_TIME=$(uptime -s 2>/dev/null || date -d "@$(( $(date +%s) - UPTIME_SECS ))" +"%Y-%m-%d %H:%M:%S")
KERNEL_RELEASE=$(uname -r)
ARCH=$(uname -m)
HOSTNAME_STR=$(hostname)

# --- 2. CPU Utilization ---
read -r _ u1 n1 s1 i1 io1 ir1 sir1 st1 _ < /proc/stat
tot1=$((u1 + n1 + s1 + i1 + io1 + ir1 + sir1 + st1))
idle1=$((i1 + io1))

sleep 0.5

read -r _ u2 n2 s2 i2 io2 ir2 sir2 st2 _ < /proc/stat
tot2=$((u2 + n2 + s2 + i2 + io2 + ir2 + sir2 + st2))
idle2=$((i2 + io2))

tot_delta=$((tot2 - tot1))
idle_delta=$((idle2 - idle1))

if [ "${tot_delta}" -gt 0 ]; then
    CPU_USAGE=$(awk -v t="${tot_delta}" -v i="${idle_delta}" 'BEGIN { printf "%.2f", 100 * (1 - (i / t)) }')
else
    CPU_USAGE="0.00"
fi

read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg
CPU_CORES=$(nproc)
TOP_CPU_COMM=$(ps -eo comm,%cpu --sort=-%cpu 2>/dev/null | sed -n '2p' | awk '{print $1" ("$2"%)"}' || echo "N/A")

# --- 3. Memory & Swap Metrics ---
MEM_TOTAL_KB=$(grep -m1 "MemTotal:" /proc/meminfo | awk '{print $2}')
MEM_AVAIL_KB=$(grep -m1 "MemAvailable:" /proc/meminfo | awk '{print $2}')
SWAP_TOTAL_KB=$(grep -m1 "SwapTotal:" /proc/meminfo | awk '{print $2}')
SWAP_FREE_KB=$(grep -m1 "SwapFree:" /proc/meminfo | awk '{print $2}')

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_USAGE_PCT=$(awk -v u="${MEM_USED_KB}" -v t="${MEM_TOTAL_KB}" 'BEGIN { printf "%.1f", (u / t) * 100 }')
MEM_TOTAL_MB=$(awk -v k="${MEM_TOTAL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
MEM_USED_MB=$(awk -v k="${MEM_USED_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
MEM_AVAIL_MB=$(awk -v k="${MEM_AVAIL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')

if [ "${SWAP_TOTAL_KB}" -gt 0 ]; then
    SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
    SWAP_USAGE_PCT=$(awk -v u="${SWAP_USED_KB}" -v t="${SWAP_TOTAL_KB}" 'BEGIN { printf "%.1f", (u / t) * 100 }')
    SWAP_TOTAL_MB=$(awk -v k="${SWAP_TOTAL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
    SWAP_USED_MB=$(awk -v k="${SWAP_USED_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
else
    SWAP_USED_KB=0
    SWAP_USAGE_PCT="0.0"
    SWAP_TOTAL_MB="0.0"
    SWAP_USED_MB="0.0"
fi

# --- 4. Disk Usage Metrics ---
ROOT_DF=$(df -hP / | tail -n 1)
ROOT_FS=$(echo "${ROOT_DF}" | awk '{print $1}')
ROOT_TOTAL=$(echo "${ROOT_DF}" | awk '{print $2}')
ROOT_USED=$(echo "${ROOT_DF}" | awk '{print $3}')
ROOT_AVAIL=$(echo "${ROOT_DF}" | awk '{print $4}')
ROOT_PCT=$(echo "${ROOT_DF}" | awk '{print $5}' | tr -d '%')

# Multi-mount overview
DISK_MOUNTS=()
while IFS= read -r df_line; do
    [ -z "${df_line}" ] && continue
    m_fs=$(echo "${df_line}" | awk '{print $1}')
    m_size=$(echo "${df_line}" | awk '{print $2}')
    m_used=$(echo "${df_line}" | awk '{print $3}')
    m_avail=$(echo "${df_line}" | awk '{print $4}')
    m_pct=$(echo "${df_line}" | awk '{print $5}')
    m_point=$(echo "${df_line}" | awk '{print $6}')
    # Escape backslashes for JSON safety
    m_fs="${m_fs//\\/\\\\}"
    m_point="${m_point//\\/\\\\}"
    DISK_MOUNTS+=("{\"filesystem\": \"${m_fs}\", \"size\": \"${m_size}\", \"used\": \"${m_used}\", \"avail\": \"${m_avail}\", \"pct\": \"${m_pct}\", \"mount\": \"${m_point}\"}")
done < <(df -hP -x tmpfs -x devtmpfs 2>/dev/null | tail -n +2 || true)

# --- 5. User Sessions ---
USER_SESSIONS=()
while IFS= read -r who_line; do
    [ -z "${who_line}" ] && continue
    u_name=$(echo "${who_line}" | awk '{print $1}')
    u_tty=$(echo "${who_line}" | awk '{print $2}')
    u_time=$(echo "${who_line}" | awk '{print $3" "$4}')
    USER_SESSIONS+=("{\"user\": \"${u_name}\", \"tty\": \"${u_tty}\", \"login_time\": \"${u_time}\"}")
done < <(who 2>/dev/null || true)
ACTIVE_USER_COUNT=${#USER_SESSIONS[@]}

# --- 6. Core Services Audit ---
SERVICE_LIST=("cron" "rsyslog" "systemd-resolved" "chrony" "containerd" "dbus" "ssh" "nginx")
SERVICE_AUDIT=()
for svc in "${SERVICE_LIST[@]}"; do
    unit="${svc%.service}.service"
    load_st=$(systemctl show -p LoadState --value "${unit}" 2>/dev/null || echo "not-found")
    if [ "${load_st}" == "not-found" ] || [ -z "${load_st}" ]; then
        st="NOT INSTALLED"
    else
        act=$(systemctl is-active "${unit}" 2>/dev/null || echo "inactive")
        if [ "${act}" == "active" ]; then
            st="RUNNING"
        elif [ "${act}" == "failed" ]; then
            st="FAILED"
        else
            st="STOPPED"
        fi
    fi
    SERVICE_AUDIT+=("{\"service\": \"${svc}\", \"status\": \"${st}\"}")
done

# --- 7. Generate Plaintext Daily Report ---
cat <<REPORT_EOF > "${DAILY_TXT}"
================================================================================
                    ADMINISTRATOR DAILY SYSTEM REPORT
================================================================================
Generated: $(date +"%Y-%m-%d %H:%M:%S %Z")
Hostname:  ${HOSTNAME_STR}
Kernel:    ${KERNEL_RELEASE} (${ARCH})
--------------------------------------------------------------------------------

[1. SYSTEM UPTIME & BOOT]
  Current Uptime:     ${FORMATTED_UPTIME} (${PRETTY_UPTIME})
  System Boot Time:   ${BOOT_TIME}

[2. CPU UTILIZATION & LOAD]
  Instantaneous CPU:  ${CPU_USAGE}%
  Load Averages:      1m: ${LOAD1} | 5m: ${LOAD5} | 15m: ${LOAD15}
  Processor Cores:    ${CPU_CORES}
  Top CPU Consumer:   ${TOP_CPU_COMM}

[3. MEMORY & SWAP ALLOCATION]
  Physical RAM:       ${MEM_USED_MB} MB used / ${MEM_TOTAL_MB} MB total (${MEM_USAGE_PCT}%)
  Available RAM:      ${MEM_AVAIL_MB} MB
  Swap Space:         ${SWAP_USED_MB} MB used / ${SWAP_TOTAL_MB} MB total (${SWAP_USAGE_PCT}%)

[4. DISK STORAGE (ROOT FILESYSTEM)]
  Filesystem:         ${ROOT_FS} mounted on /
  Capacity:           ${ROOT_TOTAL} Total | ${ROOT_USED} Used | ${ROOT_AVAIL} Avail (${ROOT_PCT}%)

[5. ACTIVE USER SESSIONS]
  Total Sessions:     ${ACTIVE_USER_COUNT}
$(who 2>/dev/null | awk '{printf "  - User: %-10s TTY: %-8s Login: %s %s\n", $1, $2, $3, $4}' || echo "  (None)")

[6. CORE SYSTEM SERVICES]
$(for item in "${SERVICE_AUDIT[@]}"; do
    s_name=$(echo "${item}" | grep -oP '"service": "\K[^"]+')
    s_stat=$(echo "${item}" | grep -oP '"status": "\K[^"]+')
    printf "  - %-20s [%s]\n" "${s_name}" "${s_stat}"
done)

================================================================================
                    END OF DAILY SYSTEM REPORT
================================================================================
REPORT_EOF

cp "${DAILY_TXT}" "${LATEST_TXT}"
log "SUCCESS" "Daily report saved to ${DAILY_TXT} and symlinked to ${LATEST_TXT}."

if [ "${QUIET}" = false ]; then
    cat "${DAILY_TXT}"
fi

# --- 8. Export JSON Telemetry ---
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "hostname": "${HOSTNAME_STR}",
    "kernel": "${KERNEL_RELEASE}",
    "architecture": "${ARCH}",
    "uptime": {
        "formatted": "${FORMATTED_UPTIME}",
        "pretty": "${PRETTY_UPTIME}",
        "boot_time": "${BOOT_TIME}",
        "seconds": ${UPTIME_SECS}
    },
    "cpu": {
        "usage_pct": float("${CPU_USAGE}"),
        "load_1m": float("${LOAD1}"),
        "load_5m": float("${LOAD5}"),
        "load_15m": float("${LOAD15}"),
        "cores": int("${CPU_CORES}"),
        "top_consumer": "${TOP_CPU_COMM}"
    },
    "memory": {
        "total_mb": float("${MEM_TOTAL_MB}"),
        "used_mb": float("${MEM_USED_MB}"),
        "avail_mb": float("${MEM_AVAIL_MB}"),
        "usage_pct": float("${MEM_USAGE_PCT}"),
        "swap_used_mb": float("${SWAP_USED_MB}"),
        "swap_total_mb": float("${SWAP_TOTAL_MB}"),
        "swap_pct": float("${SWAP_USAGE_PCT}")
    },
    "disk": {
        "root_fs": "${ROOT_FS}",
        "total": "${ROOT_TOTAL}",
        "used": "${ROOT_USED}",
        "avail": "${ROOT_AVAIL}",
        "usage_pct": int("${ROOT_PCT}"),
        "mounts": [
            $(IFS=,; echo "${DISK_MOUNTS[*]}")
        ]
    },
    "users": {
        "count": ${ACTIVE_USER_COUNT},
        "sessions": [
            $(IFS=,; echo "${USER_SESSIONS[*]}")
        ]
    },
    "services": [
        $(IFS=,; echo "${SERVICE_AUDIT[*]}")
    ],
    "report_txt": "${DAILY_TXT}",
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Daily report telemetry exported to ${SUMMARY_JSON}")
PYEOF

exit 0
