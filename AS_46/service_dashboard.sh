#!/usr/bin/env bash
# ==============================================================================
# Script: service_dashboard.sh
# Purpose: Service status dashboard auditing SSH, Web, and Core System daemons.
# Author: System Administrator (LSA Sprint AS_46)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/service_dashboard_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

# Default service catalog
SERVICES=("ssh" "nginx" "apache2" "cron" "rsyslog" "systemd-resolved" "chrony" "containerd")

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
  -s, --services "s1 s2..."  Space-separated list of services to audit
  -h, --help                 Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--services)
            read -r -a SERVICES <<< "$2"
            shift 2
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
log "INFO" "LSA Sprint AS_46 - Service Status Dashboard Engine"
log "INFO" "Target Services:      ${SERVICES[*]}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# Header
echo "============================================================================================"
printf "%-22s %-14s %-12s %-8s %-10s %-20s\n" "SERVICE" "STATUS" "BOOT ENABLE" "PID" "MEMORY" "UPTIME / SINCE"
echo "============================================================================================"

SERVICE_RESULTS=()
ACTIVE_COUNT=0
INACTIVE_COUNT=0
FAILED_COUNT=0
NOT_FOUND_COUNT=0

for svc in "${SERVICES[@]}"; do
    unit="${svc%.service}.service"
    
    # Check if unit exists
    load_state="$(systemctl show -p LoadState --value "${unit}" 2>/dev/null || echo "not-found")"
    
    if [ "${load_state}" == "not-found" ] || [ -z "${load_state}" ]; then
        status_label="NOT INSTALLED"
        enable_state="not-found"
        pid="-"
        mem_mb="-"
        since="-"
        desc="${svc} service"
        NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
        color="\033[90m" # Gray
    else
        # Inspect active state
        active_raw="$(systemctl is-active "${unit}" 2>/dev/null || true)"
        enable_state="$(systemctl is-enabled "${unit}" 2>/dev/null || echo "disabled")"
        desc="$(systemctl show -p Description --value "${unit}" 2>/dev/null || echo "${svc}")"
        
        if [ "${active_raw}" == "active" ]; then
            status_label="ACTIVE"
            ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
            color="\033[32m" # Green
            pid="$(systemctl show -p MainPID --value "${unit}" 2>/dev/null || echo "-")"
            [ "${pid}" == "0" ] && pid="-"
            
            mem_bytes="$(systemctl show -p MemoryCurrent --value "${unit}" 2>/dev/null || echo "")"
            if [[ "${mem_bytes}" =~ ^[0-9]+$ ]] && [ "${mem_bytes}" -gt 0 ]; then
                mem_mb="$(awk -v b="${mem_bytes}" 'BEGIN { printf "%.1f MB", b / 1048576 }')"
            else
                mem_mb="N/A"
            fi
            
            since_raw="$(systemctl show -p ActiveEnterTimestamp --value "${unit}" 2>/dev/null || echo "-")"
            if [ -n "${since_raw}" ] && [ "${since_raw}" != "-" ]; then
                since="${since_raw%% *}" # Keep date or short time
            else
                since="Active"
            fi
        elif [ "${active_raw}" == "failed" ]; then
            status_label="FAILED"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            color="\033[31m" # Red
            pid="-"
            mem_mb="-"
            since="Failed"
        else
            status_label="INACTIVE"
            INACTIVE_COUNT=$((INACTIVE_COUNT + 1))
            color="\033[33m" # Yellow
            pid="-"
            mem_mb="-"
            since="Stopped"
        fi
    fi
    
    # Terminal output
    printf "${color}%-22s %-14s\033[0m %-12s %-8s %-10s %-20s\n" "${svc}" "${status_label}" "${enable_state}" "${pid}" "${mem_mb}" "${since}"
    log "INFO" "Service: ${svc} | Status: ${status_label} | Enabled: ${enable_state} | PID: ${pid} | Memory: ${mem_mb}"
    
    # Clean description for JSON
    clean_desc=$(echo "${desc}" | tr '"' "'" | xargs)
    SERVICE_RESULTS+=("{\"service\": \"${svc}\", \"unit\": \"${unit}\", \"status\": \"${status_label}\", \"enabled\": \"${enable_state}\", \"pid\": \"${pid}\", \"memory\": \"${mem_mb}\", \"since\": \"${since}\", \"description\": \"${clean_desc}\"}")
done

echo "============================================================================================"
echo " Summary: ${ACTIVE_COUNT} Active, ${INACTIVE_COUNT} Inactive, ${FAILED_COUNT} Failed, ${NOT_FOUND_COUNT} Not Installed"
echo "============================================================================================"

# Export JSON Telemetry
python3 - <<PYEOF
import json, os, datetime

data = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "total_services": len("${SERVICES[*]}".split()),
    "active_count": ${ACTIVE_COUNT},
    "inactive_count": ${INACTIVE_COUNT},
    "failed_count": ${FAILED_COUNT},
    "not_found_count": ${NOT_FOUND_COUNT},
    "log_file": "${LOG_FILE}",
    "services": [
        $(IFS=,; echo "${SERVICE_RESULTS[*]}")
    ]
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(data, f, indent=2)

print(f"Service audit telemetry saved to ${SUMMARY_JSON}")
PYEOF

exit 0
