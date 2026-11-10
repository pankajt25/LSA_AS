#!/usr/bin/env bash
# ==============================================================================
# Script: resource_monitor.sh
# Purpose: Real-time CPU & Memory utilization monitoring against configurable thresholds.
# Author: System Administrator (LSA Sprint AS_44)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/resource_monitor_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

# Threshold Defaults (Percentage)
CPU_WARN=70
CPU_CRIT=85
MEM_WARN=75
MEM_CRIT=90
SWAP_WARN=50
SWAP_CRIT=75
SAMPLE_INTERVAL=1.0

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
  --cpu-warn <PCT>    CPU Warning threshold percentage (default: 70)
  --cpu-crit <PCT>    CPU Critical threshold percentage (default: 85)
  --mem-warn <PCT>    Memory Warning threshold percentage (default: 75)
  --mem-crit <PCT>    Memory Critical threshold percentage (default: 90)
  --swap-warn <PCT>   Swap Warning threshold percentage (default: 50)
  --swap-crit <PCT>   Swap Critical threshold percentage (default: 75)
  --interval <SEC>    CPU sample interval in seconds (default: 1.0)
  -h, --help          Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu-warn) CPU_WARN="$2"; shift 2 ;;
        --cpu-crit) CPU_CRIT="$2"; shift 2 ;;
        --mem-warn) MEM_WARN="$2"; shift 2 ;;
        --mem-crit) MEM_CRIT="$2"; shift 2 ;;
        --swap-warn) SWAP_WARN="$2"; shift 2 ;;
        --swap-crit) SWAP_CRIT="$2"; shift 2 ;;
        --interval) SAMPLE_INTERVAL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log "ERROR" "Unknown option: $1"; usage ;;
    esac
done

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_44 - Real-Time Resource Threshold Monitor"
log "INFO" "CPU Thresholds:       Warn >= ${CPU_WARN}%, Crit >= ${CPU_CRIT}%"
log "INFO" "Memory Thresholds:    Warn >= ${MEM_WARN}%, Crit >= ${MEM_CRIT}%"
log "INFO" "Swap Thresholds:      Warn >= ${SWAP_WARN}%, Crit >= ${SWAP_CRIT}%"
log "INFO" "Sample Interval:      ${SAMPLE_INTERVAL}s"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# --- 1. CPU Utilization Measurement via /proc/stat ---
read -r _ user1 nice1 sys1 idle1 iow1 irq1 sirq1 steal1 _ < /proc/stat
total1=$((user1 + nice1 + sys1 + idle1 + iow1 + irq1 + sirq1 + steal1))
idle_all1=$((idle1 + iow1))

sleep "${SAMPLE_INTERVAL}"

read -r _ user2 nice2 sys2 idle2 iow2 irq2 sirq2 steal2 _ < /proc/stat
total2=$((user2 + nice2 + sys2 + idle2 + iow2 + irq2 + sirq2 + steal2))
idle_all2=$((idle2 + iow2))

total_delta=$((total2 - total1))
idle_delta=$((idle_all2 - idle_all1))

if [ "${total_delta}" -gt 0 ]; then
    CPU_USAGE_PCT=$(awk -v t="${total_delta}" -v i="${idle_delta}" 'BEGIN { printf "%.2f", 100 * (1 - (i / t)) }')
else
    CPU_USAGE_PCT="0.00"
fi

# Load averages
read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg
CPU_CORES=$(nproc)

# --- 2. Memory & Swap Utilization via /proc/meminfo ---
MEM_TOTAL_KB=$(grep -m1 "MemTotal:" /proc/meminfo | awk '{print $2}')
MEM_AVAIL_KB=$(grep -m1 "MemAvailable:" /proc/meminfo | awk '{print $2}')
SWAP_TOTAL_KB=$(grep -m1 "SwapTotal:" /proc/meminfo | awk '{print $2}')
SWAP_FREE_KB=$(grep -m1 "SwapFree:" /proc/meminfo | awk '{print $2}')

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_USAGE_PCT=$(awk -v u="${MEM_USED_KB}" -v t="${MEM_TOTAL_KB}" 'BEGIN { printf "%.2f", (u / t) * 100 }')

MEM_TOTAL_MB=$(awk -v k="${MEM_TOTAL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
MEM_USED_MB=$(awk -v k="${MEM_USED_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
MEM_AVAIL_MB=$(awk -v k="${MEM_AVAIL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')

if [ "${SWAP_TOTAL_KB}" -gt 0 ]; then
    SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
    SWAP_USAGE_PCT=$(awk -v u="${SWAP_USED_KB}" -v t="${SWAP_TOTAL_KB}" 'BEGIN { printf "%.2f", (u / t) * 100 }')
    SWAP_TOTAL_MB=$(awk -v k="${SWAP_TOTAL_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
    SWAP_USED_MB=$(awk -v k="${SWAP_USED_KB}" 'BEGIN { printf "%.1f", k / 1024 }')
else
    SWAP_USED_KB=0
    SWAP_USAGE_PCT="0.00"
    SWAP_TOTAL_MB="0.0"
    SWAP_USED_MB="0.0"
fi

# --- 3. Evaluate Thresholds ---
eval_status() {
    local val="$1"
    local warn="$2"
    local crit="$3"
    awk -v v="${val}" -v w="${warn}" -v c="${crit}" 'BEGIN {
        if (v >= c) print "CRITICAL";
        else if (v >= w) print "WARNING";
        else print "OK";
    }'
}

CPU_STATUS=$(eval_status "${CPU_USAGE_PCT}" "${CPU_WARN}" "${CPU_CRIT}")
MEM_STATUS=$(eval_status "${MEM_USAGE_PCT}" "${MEM_WARN}" "${MEM_CRIT}")
SWAP_STATUS=$(eval_status "${SWAP_USAGE_PCT}" "${SWAP_WARN}" "${SWAP_CRIT}")

OVERALL_STATUS="OK"
if [ "${CPU_STATUS}" == "CRITICAL" ] || [ "${MEM_STATUS}" == "CRITICAL" ] || [ "${SWAP_STATUS}" == "CRITICAL" ]; then
    OVERALL_STATUS="CRITICAL"
elif [ "${CPU_STATUS}" == "WARNING" ] || [ "${MEM_STATUS}" == "WARNING" ] || [ "${SWAP_STATUS}" == "WARNING" ]; then
    OVERALL_STATUS="WARNING"
fi

log "INFO" "CPU Usage:            ${CPU_USAGE_PCT}% [${CPU_STATUS}] (Cores: ${CPU_CORES}, Load: ${LOAD1}, ${LOAD5}, ${LOAD15})"
log "INFO" "Memory Usage:         ${MEM_USAGE_PCT}% [${MEM_STATUS}] (${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB)"
log "INFO" "Swap Usage:           ${SWAP_USAGE_PCT}% [${SWAP_STATUS}] (${SWAP_USED_MB}MB / ${SWAP_TOTAL_MB}MB)"
log "INFO" "Overall System State: [${OVERALL_STATUS}]"

if [ "${OVERALL_STATUS}" != "OK" ]; then
    log "WARN" "RESOURCE ALERT: System resource utilization exceeded configured thresholds!"
fi

# --- 4. Harvest Top CPU & Memory Processes ---
log "INFO" "Harvesting top running processes..."

TOP_CPU_JSON=$(python3 - <<'PYEOF'
import subprocess, json

cmd = ["ps", "-eo", "pid,user,%cpu,%mem,comm,args", "--sort=-%cpu"]
res = subprocess.run(cmd, capture_output=True, text=True)
lines = res.stdout.strip().split("\n")
top_cpu = []
for line in lines[1:6]:
    parts = line.split(None, 5)
    if len(parts) >= 6:
        top_cpu.append({
            "pid": parts[0],
            "user": parts[1],
            "cpu_pct": parts[2],
            "mem_pct": parts[3],
            "comm": parts[4],
            "args": parts[5][:60]
        })
print(json.dumps(top_cpu))
PYEOF
)

TOP_MEM_JSON=$(python3 - <<'PYEOF'
import subprocess, json

cmd = ["ps", "-eo", "pid,user,%mem,%cpu,rss,comm,args", "--sort=-%mem"]
res = subprocess.run(cmd, capture_output=True, text=True)
lines = res.stdout.strip().split("\n")
top_mem = []
for line in lines[1:6]:
    parts = line.split(None, 6)
    if len(parts) >= 7:
        top_mem.append({
            "pid": parts[0],
            "user": parts[1],
            "mem_pct": parts[2],
            "cpu_pct": parts[3],
            "rss_mb": round(int(parts[4]) / 1024, 1),
            "comm": parts[5],
            "args": parts[6][:60]
        })
print(json.dumps(top_mem))
PYEOF
)

# Export Full JSON Telemetry
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "overall_status": "${OVERALL_STATUS}",
    "cpu": {
        "usage_pct": float("${CPU_USAGE_PCT}"),
        "status": "${CPU_STATUS}",
        "cores": int("${CPU_CORES}"),
        "load_1m": float("${LOAD1}"),
        "load_5m": float("${LOAD5}"),
        "load_15m": float("${LOAD15}"),
        "warn_threshold": float("${CPU_WARN}"),
        "crit_threshold": float("${CPU_CRIT}")
    },
    "memory": {
        "usage_pct": float("${MEM_USAGE_PCT}"),
        "status": "${MEM_STATUS}",
        "total_mb": float("${MEM_TOTAL_MB}"),
        "used_mb": float("${MEM_USED_MB}"),
        "available_mb": float("${MEM_AVAIL_MB}"),
        "warn_threshold": float("${MEM_WARN}"),
        "crit_threshold": float("${MEM_CRIT}")
    },
    "swap": {
        "usage_pct": float("${SWAP_USAGE_PCT}"),
        "status": "${SWAP_STATUS}",
        "total_mb": float("${SWAP_TOTAL_MB}"),
        "used_mb": float("${SWAP_USED_MB}"),
        "warn_threshold": float("${SWAP_WARN}"),
        "crit_threshold": float("${SWAP_CRIT}")
    },
    "top_cpu_processes": ${TOP_CPU_JSON},
    "top_mem_processes": ${TOP_MEM_JSON},
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Summary telemetry exported to ${SUMMARY_JSON}")
PYEOF

log "INFO" "Resource threshold monitoring cycle completed."
exit 0
