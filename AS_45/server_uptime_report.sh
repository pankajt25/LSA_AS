#!/usr/bin/env bash
# ==============================================================================
# Script: server_uptime_report.sh
# Purpose: Comprehensive server uptime reporting and continuous operation evaluation.
# Author: System Administrator (LSA Sprint AS_45)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/uptime_report_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

# Threshold Defaults (in Days)
TARGET_THRESHOLD_DAYS=30
WARN_THRESHOLD_DAYS=90
CRIT_THRESHOLD_DAYS=180

log() {
    local level="$1"
    shift
    local msg="[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*"
    echo -e "${msg}"
    echo -e "${msg}" >> "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -t, --threshold-days <DAYS>  Continuous operation target threshold (default: 30)
  --warn-days <DAYS>           Maintenance advisory threshold (default: 90)
  --crit-days <DAYS>           Reboot overdue critical threshold (default: 180)
  -h, --help                   Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold-days)
            TARGET_THRESHOLD_DAYS="$2"
            shift 2
            ;;
        --warn-days)
            WARN_THRESHOLD_DAYS="$2"
            shift 2
            ;;
        --crit-days)
            CRIT_THRESHOLD_DAYS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            ;;
    esac
done

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_45 - Server Uptime & Availability Engine"
log "INFO" "Target Threshold:     ${TARGET_THRESHOLD_DAYS} Days"
log "INFO" "Advisory Threshold:   ${WARN_THRESHOLD_DAYS} Days"
log "INFO" "Overdue Threshold:    ${CRIT_THRESHOLD_DAYS} Days"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# --- 1. Query /proc/uptime & Kernel Timers ---
read -r UPTIME_RAW IDLE_RAW < /proc/uptime
UPTIME_SECONDS=$(echo "${UPTIME_RAW}" | cut -d. -f1)
IDLE_SECONDS=$(echo "${IDLE_RAW}" | cut -d. -f1)
NUM_CORES=$(nproc)

# Breakdown into Days, Hours, Minutes, Seconds
DAYS=$((UPTIME_SECONDS / 86400))
HOURS=$(( (UPTIME_SECONDS % 86400) / 3600 ))
MINUTES=$(( (UPTIME_SECONDS % 3600) / 60 ))
SECS=$((UPTIME_SECONDS % 60))

FORMATTED_UPTIME="${DAYS}d ${HOURS}h ${MINUTES}m ${SECS}s"
PRETTY_UPTIME=$(uptime -p 2>/dev/null || echo "up ${DAYS} days, ${HOURS} hours")

# Boot time discovery
BOOT_TIME_STR=$(uptime -s 2>/dev/null || date -d "@$(( $(date +%s) - UPTIME_SECONDS ))" +"%Y-%m-%d %H:%M:%S")
BTIME_EPOCH=$(grep -m1 "^btime" /proc/stat | awk '{print $2}' || date -d "${BOOT_TIME_STR}" +%s)

# Idle percentage calculation
TOTAL_CPU_TIME=$((UPTIME_SECONDS * NUM_CORES))
if [ "${TOTAL_CPU_TIME}" -gt 0 ]; then
    IDLE_PERCENT=$(awk -v i="${IDLE_SECONDS}" -v t="${TOTAL_CPU_TIME}" 'BEGIN { printf "%.2f", (i / t) * 100 }')
else
    IDLE_PERCENT="0.00"
fi

# Load averages & active user count
read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg
USER_COUNT=$(who 2>/dev/null | wc -l || echo "1")
KERNEL_RELEASE=$(uname -r)
ARCH=$(uname -m)

# --- 2. Evaluate Continuous Operation & Maintenance Status ---
THRESHOLD_MET=false
if [ "${DAYS}" -ge "${TARGET_THRESHOLD_DAYS}" ]; then
    THRESHOLD_MET=true
fi

# Determine SLA Status
if [ "${DAYS}" -ge "${CRIT_THRESHOLD_DAYS}" ]; then
    OPERATIONAL_STATUS="REBOOT OVERDUE"
    STATUS_CLASS="CRITICAL"
    ADVISORY_NOTE="Server has operated continuously for over ${CRIT_THRESHOLD_DAYS} days. Reboot strongly recommended to apply cumulative kernel security updates and defragment physical memory pools."
elif [ "${DAYS}" -ge "${WARN_THRESHOLD_DAYS}" ]; then
    OPERATIONAL_STATUS="MAINTENANCE ADVISORY"
    STATUS_CLASS="WARNING"
    ADVISORY_NOTE="Server exceeds ${WARN_THRESHOLD_DAYS} days continuous runtime. Schedule a planned maintenance reboot window during off-peak hours."
elif [ "${DAYS}" -ge "${TARGET_THRESHOLD_DAYS}" ]; then
    OPERATIONAL_STATUS="SLA COMPLIANT (HA TARGET MET)"
    STATUS_CLASS="SUCCESS"
    ADVISORY_NOTE="Server has satisfied the continuous operation threshold of ${TARGET_THRESHOLD_DAYS} days with continuous stability."
elif [ "${DAYS}" -ge 1 ]; then
    OPERATIONAL_STATUS="NOMINAL OPERATION"
    STATUS_CLASS="SUCCESS"
    ADVISORY_NOTE="Server running stably in steady-state. Days towards ${TARGET_THRESHOLD_DAYS}-day SLA target: ${DAYS}/${TARGET_THRESHOLD_DAYS}."
else
    OPERATIONAL_STATUS="FRESH BOOT / STABLE"
    STATUS_CLASS="INFO"
    ADVISORY_NOTE="Server was booted within the past 24 hours. Services are actively warming up."
fi

log "INFO" "Uptime (Raw):         ${UPTIME_RAW}s"
log "INFO" "Formatted Uptime:     ${FORMATTED_UPTIME} (${PRETTY_UPTIME})"
log "INFO" "System Boot Time:     ${BOOT_TIME_STR} (Epoch: ${BTIME_EPOCH})"
log "INFO" "Target Threshold:     ${TARGET_THRESHOLD_DAYS} Days (Met: ${THRESHOLD_MET})"
log "INFO" "CPU Idle Ratio:       ${IDLE_PERCENT}% across ${NUM_CORES} core(s)"
log "INFO" "Operational Status:   [${OPERATIONAL_STATUS}] (${STATUS_CLASS})"
log "INFO" "Advisory Note:        ${ADVISORY_NOTE}"

# --- 3. Export Telemetry to JSON ---
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "boot_time": "${BOOT_TIME_STR}",
    "boot_epoch": int("${BTIME_EPOCH}"),
    "uptime_seconds": int("${UPTIME_SECONDS}"),
    "days": int("${DAYS}"),
    "hours": int("${HOURS}"),
    "minutes": int("${MINUTES}"),
    "seconds": int("${SECS}"),
    "formatted_uptime": "${FORMATTED_UPTIME}",
    "pretty_uptime": "${PRETTY_UPTIME}",
    "target_threshold_days": int("${TARGET_THRESHOLD_DAYS}"),
    "threshold_met": True if "${THRESHOLD_MET}" == "true" else False,
    "operational_status": "${OPERATIONAL_STATUS}",
    "status_class": "${STATUS_CLASS}",
    "advisory_note": "${ADVISORY_NOTE}",
    "cpu_idle_percent": float("${IDLE_PERCENT}"),
    "cores": int("${NUM_CORES}"),
    "load_1m": float("${LOAD1}"),
    "load_5m": float("${LOAD5}"),
    "load_15m": float("${LOAD15}"),
    "user_count": int("${USER_COUNT}"),
    "kernel_release": "${KERNEL_RELEASE}",
    "architecture": "${ARCH}",
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Uptime telemetry exported to ${SUMMARY_JSON}")
PYEOF

log "INFO" "Server uptime evaluation completed successfully."
exit 0
