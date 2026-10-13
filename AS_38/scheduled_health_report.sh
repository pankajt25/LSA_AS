#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #38: Scheduled Linux System Health Report via Cron
# Script: scheduled_health_report.sh
#
# DESCRIPTION:
#   Collects comprehensive live Linux subsystem telemetry:
#     1. System Uptime, Boot Epoch & Active Kernel Identity
#     2. CPU Utilization & System Load Averages (1m, 5m, 15m)
#     3. Memory & Swap Capacity Allocation (RAM used, free, buff/cache)
#     4. Root & Storage Mountpoint Capacity Health (df -hP)
#     5. Top CPU & Memory Intensive Process Profiling (ps)
#     6. Network Interface Status & Addressing (ip -br addr)
#   Generates timestamped health reports into reports/ directory and provides
#   built-in Cron automation with strict '# LSA_SPRINT_TEST' tagging.
#
# USAGE:
#   ./scheduled_health_report.sh [OPTIONS]
#
# OPTIONS:
#   --generate          Generate a live system health report (default action)
#   --schedule [EXPR]   Install cron job in user crontab (default: "*/30 * * * *")
#   --verify-cron       Inspect crontab for scheduled LSA health report job
#   --unschedule        Remove scheduled health report job tagged # LSA_SPRINT_TEST
#   --json              Generate structured telemetry in logs/health_metrics.json
#   --help, -h          Display this help message
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/health_report.log"
JSON_FILE="${LOG_DIR}/health_metrics.json"

mkdir -p "${REPORTS_DIR}" "${LOG_DIR}"

# ANSI Colors
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"

# Default configuration
ACTION="generate"
CRON_EXPR="*/30 * * * *"
EMIT_JSON=true

log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local color=""
    case "${level}" in
        INFO) color="${CLR_CYAN}" ;;
        SUCCESS) color="${CLR_GREEN}" ;;
        WARN) color="${CLR_YELLOW}" ;;
        ERROR) color="${CLR_RED}" ;;
        *) color="${CLR_RESET}" ;;
    esac
    echo -e "${color}[${timestamp}] [${level}] ${message}${CLR_RESET}"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

print_header() {
    echo -e "${CLR_BLUE}${CLR_BOLD}"
    echo "================================================================================"
    echo "     LSA AUTOMATION SPRINT (AS_38) — SYSTEM HEALTH REPORT ENGINE                "
    echo "================================================================================"
    echo -e "${CLR_RESET}"
}

show_help() {
    print_header
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --generate          Generate timestamped health report from live system data (default)
  --schedule [EXPR]   Schedule health report generation in Cron (default: "*/30 * * * *")
  --verify-cron       Check if health report cron job is scheduled
  --unschedule        Remove scheduled health report job tagged with # LSA_SPRINT_TEST
  --json              Generate machine-readable logs/health_metrics.json
  --help, -h          Display this help message

Examples:
  ./scheduled_health_report.sh --generate
  ./scheduled_health_report.sh --schedule "0 * * * *"
  ./scheduled_health_report.sh --verify-cron
  ./scheduled_health_report.sh --unschedule
EOF
    exit 0
}

# Parse Command-Line Options
while [ $# -gt 0 ]; do
    case "$1" in
        --generate)
            ACTION="generate"
            shift
            ;;
        --schedule)
            ACTION="schedule"
            if [ $# -gt 1 ] && [[ "$2" != --* ]]; then
                CRON_EXPR="$2"
                shift 2
            else
                shift
            fi
            ;;
        --verify-cron)
            ACTION="verify-cron"
            shift
            ;;
        --unschedule)
            ACTION="unschedule"
            shift
            ;;
        --json)
            EMIT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${CLR_RED}Unknown option: $1${CLR_RESET}" >&2
            show_help
            ;;
    esac
done

# ==============================================================================
# CRON JOB MANAGEMENT FUNCTIONS
# ==============================================================================
install_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    local cron_cmd="/bin/bash \"${SCRIPT_DIR}/scheduled_health_report.sh\" --generate >> \"${LOG_DIR}/cron_health.log\" 2>&1 ${cron_tag}"
    local new_entry="${CRON_EXPR} ${cron_cmd}"

    log_msg "INFO" "Installing scheduled health report cron task..."
    log_msg "INFO" "Cadence Schedule : '${CRON_EXPR}' (Tag: ${cron_tag})"

    local current_crontab=""
    current_crontab="$(crontab -l 2>/dev/null || true)"

    local filtered_crontab=""
    if [ -n "${current_crontab}" ]; then
        filtered_crontab="$(echo "${current_crontab}" | grep -v "${cron_tag}" || true)"
    fi

    local updated_crontab
    if [ -n "${filtered_crontab}" ]; then
        updated_crontab="${filtered_crontab}
${new_entry}"
    else
        updated_crontab="${new_entry}"
    fi

    echo "${updated_crontab}" | crontab -
    log_msg "SUCCESS" "Health report cron schedule installed successfully in user crontab."
    log_msg "INFO" "Verifying active crontab entry:"
    crontab -l | grep "${cron_tag}" | while read -r line; do
        echo -e "   ${CLR_GREEN}↳ ${line}${CLR_RESET}"
    done
}

verify_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    log_msg "INFO" "Inspecting user crontab for scheduled LSA health report jobs..."
    local active_jobs
    active_jobs="$(crontab -l 2>/dev/null | grep "${cron_tag}" || true)"

    if [ -n "${active_jobs}" ]; then
        log_msg "SUCCESS" "Active scheduled health report job(s) found:"
        echo "${active_jobs}" | while read -r line; do
            echo -e "   ${CLR_GREEN}✔ ${line}${CLR_RESET}"
        done
        return 0
    else
        log_msg "WARN" "No crontab entry matching '${cron_tag}' is currently installed."
        return 1
    fi
}

remove_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    log_msg "INFO" "Attempting to remove crontab entries matching '${cron_tag}'..."

    local current_crontab=""
    current_crontab="$(crontab -l 2>/dev/null || true)"

    if [ -z "${current_crontab}" ]; then
        log_msg "INFO" "Crontab is already empty. Nothing to remove."
        return 0
    fi

    if ! echo "${current_crontab}" | grep -q "${cron_tag}"; then
        log_msg "INFO" "No entries matching '${cron_tag}' found. System crontab clean."
        return 0
    fi

    local remaining_crontab
    remaining_crontab="$(echo "${current_crontab}" | grep -v "${cron_tag}" || true)"

    if [ -n "$(echo "${remaining_crontab}" | tr -d '[:space:]')" ]; then
        echo "${remaining_crontab}" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi

    log_msg "SUCCESS" "Successfully removed LSA test health report cron job(s)."
}

# ==============================================================================
# SYSTEM HEALTH TELEMETRY COLLECTION
# ==============================================================================
generate_health_report() {
    print_header
    local start_time
    start_time="$(date +%s)"
    local timestamp_iso
    timestamp_iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    local file_stamp
    file_stamp="$(date '+%Y%m%d_%H%M%S')"
    local report_txt="${REPORTS_DIR}/health_report_${file_stamp}.txt"
    local latest_txt="${REPORTS_DIR}/latest_health_report.txt"

    log_msg "INFO" "Gathering live system health telemetry..."

    # 1. System Identity & Uptime
    local host_name
    host_name="$(hostname 2>/dev/null || uname -n)"
    local kernel_ver
    kernel_ver="$(uname -r 2>/dev/null || echo 'Unknown')"
    local uptime_str
    uptime_str="$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6,$7}' || echo 'N/A')"

    # 2. Load Average (1m, 5m, 15m)
    local load_1m="0.00" load_5m="0.00" load_15m="0.00"
    if [ -f /proc/loadavg ]; then
        read -r load_1m load_5m load_15m _ < /proc/loadavg
    fi

    # 3. CPU Core Count
    local cpu_cores
    cpu_cores="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo 1)"

    # 4. Memory & Swap Metrics
    local mem_total_mb=0 mem_used_mb=0 mem_free_mb=0 mem_buff_mb=0 mem_avail_mb=0
    local swap_total_mb=0 swap_used_mb=0 swap_free_mb=0
    if command -v free >/dev/null 2>&1; then
        local mem_line
        mem_line="$(free -m | awk '/Mem:/ {print $2,$3,$4,$6,$7}')"
        read -r mem_total_mb mem_used_mb mem_free_mb mem_buff_mb mem_avail_mb <<< "${mem_line}"
        local swap_line
        swap_line="$(free -m | awk '/Swap:/ {print $2,$3,$4}')"
        read -r swap_total_mb swap_used_mb swap_free_mb <<< "${swap_line}"
    fi
    local mem_used_pct=0
    if [ "${mem_total_mb}" -gt 0 ]; then
        mem_used_pct="$(awk "BEGIN {printf \"%.1f\", (${mem_used_mb} / ${mem_total_mb}) * 100}")"
    fi

    # 5. Storage Capacity
    local disk_total disk_used disk_avail disk_pct
    disk_total="$(df -hP / | awk 'NR==2 {print $2}')"
    disk_used="$(df -hP / | awk 'NR==2 {print $3}')"
    disk_avail="$(df -hP / | awk 'NR==2 {print $4}')"
    disk_pct="$(df -hP / | awk 'NR==2 {print $5}')"

    # 6. Network Interfaces
    local net_interfaces
    net_interfaces="$( { ip -br addr show 2>/dev/null || ifconfig -s 2>/dev/null || true; } | head -n 8)"

    # 7. Top 5 CPU Processes
    local top_cpu_procs
    top_cpu_procs="$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 6 || true)"

    # 8. Top 5 RAM Processes
    local top_mem_procs
    top_mem_procs="$(ps -eo pid,user,%mem,rss,comm --sort=-%mem 2>/dev/null | head -n 6 || true)"

    # Emit Text Report
    cat <<TEOF > "${report_txt}"
================================================================================
LINUX SYSTEM HEALTH AUDIT REPORT
Generated At: ${timestamp_iso}
Host: ${host_name} | Kernel: ${kernel_ver} | Uptime: ${uptime_str}
================================================================================

1. SYSTEM IDENTITY & LOAD
--------------------------------------------------------------------------------
Hostname         : ${host_name}
Kernel Version   : ${kernel_ver}
CPU Logical Cores: ${cpu_cores}
Uptime           : ${uptime_str}
Load Average     : 1 min: ${load_1m} | 5 min: ${load_5m} | 15 min: ${load_15m}

2. MEMORY & SWAP UTILIZATION
--------------------------------------------------------------------------------
Physical RAM     : Total: ${mem_total_mb}MB | Used: ${mem_used_mb}MB (${mem_used_pct}%) | Free: ${mem_free_mb}MB
Buffers/Cached   : ${mem_buff_mb}MB | Available: ${mem_avail_mb}MB
Swap Space       : Total: ${swap_total_mb}MB | Used: ${swap_used_mb}MB | Free: ${swap_free_mb}MB

3. FILESYSTEM STORAGE FOOTPRINT (Root /)
--------------------------------------------------------------------------------
Total Capacity   : ${disk_total}
Used Space       : ${disk_used} (${disk_pct})
Available Space  : ${disk_avail}

4. NETWORK INTERFACES
--------------------------------------------------------------------------------
${net_interfaces}

5. TOP 5 CPU INTENSIVE PROCESSES
--------------------------------------------------------------------------------
${top_cpu_procs}

6. TOP 5 MEMORY INTENSIVE PROCESSES
--------------------------------------------------------------------------------
${top_mem_procs}

================================================================================
END OF REPORT — LSA SPRINT AUTOMATION (AS_38)
================================================================================
TEOF

    cp "${report_txt}" "${latest_txt}"
    log_msg "SUCCESS" "Timestamped health report generated: ${report_txt}"
    log_msg "SUCCESS" "Updated latest report pointer: ${latest_txt}"

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))

    # Emit JSON Telemetry
    if [ "${EMIT_JSON}" = true ]; then
        # Parse top CPU process lines to JSON array safely
        python3 - <<PYEOF
import json
import os

data = {
    "timestamp": "${timestamp_iso}",
    "execution_seconds": ${duration},
    "report_file": "${report_txt}",
    "system": {
        "hostname": "${host_name}",
        "kernel": "${kernel_ver}",
        "uptime": "${uptime_str}",
        "cpu_cores": ${cpu_cores},
        "load_1m": "${load_1m}",
        "load_5m": "${load_5m}",
        "load_15m": "${load_15m}"
    },
    "memory": {
        "total_mb": ${mem_total_mb},
        "used_mb": ${mem_used_mb},
        "free_mb": ${mem_free_mb},
        "buff_cache_mb": ${mem_buff_mb},
        "avail_mb": ${mem_avail_mb},
        "used_pct": "${mem_used_pct}",
        "swap_total_mb": ${swap_total_mb},
        "swap_used_mb": ${swap_used_mb}
    },
    "storage": {
        "mount": "/",
        "total": "${disk_total}",
        "used": "${disk_used}",
        "avail": "${disk_avail}",
        "used_pct": "${disk_pct}"
    }
}

with open("${JSON_FILE}", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
PYEOF
        log_msg "SUCCESS" "Telemetry written to ${JSON_FILE}"
    fi

    # Display console summary
    echo ""
    echo -e "${CLR_GREEN}✔ System Health Summary:${CLR_RESET}"
    echo -e "  Load Averages: ${CLR_CYAN}${load_1m}, ${load_5m}, ${load_15m}${CLR_RESET} (${cpu_cores} Cores)"
    echo -e "  Memory Usage : ${CLR_CYAN}${mem_used_mb}MB / ${mem_total_mb}MB (${mem_used_pct}%)${CLR_RESET}"
    echo -e "  Root Storage : ${CLR_CYAN}${disk_used} / ${disk_total} (${disk_pct})${CLR_RESET}"
    echo -e "  Report Saved : ${CLR_GREEN}${report_txt}${CLR_RESET}"
}

# Dispatch
case "${ACTION}" in
    generate)
        generate_health_report
        ;;
    schedule)
        install_cron_job
        ;;
    verify-cron)
        verify_cron_job
        ;;
    unschedule)
        remove_cron_job
        ;;
esac
