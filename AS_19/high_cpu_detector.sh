#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #19: High CPU Process Detection
# Script: high_cpu_detector.sh
# Author: System Administrator
#
# PURPOSE:
#   Identifies and reports the top CPU-consuming processes currently active on
#   the system. Generates clean tabular output, highlights processes exceeding
#   a defined CPU utilization threshold, logs all scan results for audit trails,
#   and provides flexible CLI arguments.
#
# SANDBOXING & SAFETY NOTICE:
#   - 100% READ-ONLY INSPECTION.
#   - No processes are killed, reniced, signaled, or modified.
#   - All disk operations are strictly confined within this project directory.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# DIRECTORY SETUP & LOGGING CONFIGURATION
# ------------------------------------------------------------------------------
# Resolve project directory dynamically so script can be invoked from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
DEFAULT_LOG_FILE="${LOG_DIR}/high_cpu.log"
LOG_FILE="${DEFAULT_LOG_FILE}"

# ------------------------------------------------------------------------------
# DEFAULT PARAMETERS (CONFIGURABLE VIA CLI FLAGS)
# ------------------------------------------------------------------------------
# Default number of top CPU-consuming processes to display
TOP_COUNT=5

# CPU threshold percentage: processes with %CPU >= THRESHOLD trigger an alert flag.
# Stored as a variable (not hardcoded) to allow dynamic thresholding in monitoring.
CPU_THRESHOLD=50.0

# ------------------------------------------------------------------------------
# USAGE / HELP FUNCTION
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
High CPU Process Detector — Automation Sprint (AS_19)

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -n <count>       Number of top CPU-consuming processes to display (default: 5)
    -t <threshold>   CPU percentage alert threshold (default: 50.0)
    -l <logfile>     Custom log file path (default: logs/high_cpu.log)
    -h, --help       Show this help manual and exit

EXAMPLES:
    ./high_cpu_detector.sh                  # Display top 5 with 50.0% threshold
    ./high_cpu_detector.sh -n 10            # Display top 10 processes
    ./high_cpu_detector.sh -n 5 -t 20.0     # Flag any process consuming >= 20% CPU
    ./high_cpu_detector.sh -l /tmp/cpu.log  # Log to custom destination

EXIT STATUS:
    0  Successful execution and process inspection
    1  System environment error (e.g. 'ps' unavailable or query failure)
    2  Invalid command-line arguments or syntax error
EOF
}

# ------------------------------------------------------------------------------
# COMMAND-LINE ARGUMENT PARSING
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "[ERROR] Option -n requires a positive integer argument. Received: '${2:-}'" >&2
                exit 2
            fi
            TOP_COUNT="$2"
            shift 2
            ;;
        -t)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                echo "[ERROR] Option -t requires a numeric percentage threshold. Received: '${2:-}'" >&2
                exit 2
            fi
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        -l)
            if [[ -z "${2:-}" ]]; then
                echo "[ERROR] Option -l requires a file path argument." >&2
                exit 2
            fi
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: '$1'" >&2
            echo "Run '$(basename "$0") --help' for usage instructions." >&2
            exit 2
            ;;
    esac
done

# Ensure log directory exists
mkdir -p "$(dirname "${LOG_FILE}")"

# ------------------------------------------------------------------------------
# DEPENDENCY & ENVIRONMENT CHECKS
# ------------------------------------------------------------------------------
# Ensure standard process examination utilities exist before running.
if ! command -v ps >/dev/null 2>&1; then
    echo "[ERROR] Required process inspection tool 'ps' is not installed or not in PATH." >&2
    exit 1
fi

if ! command -v awk >/dev/null 2>&1; then
    echo "[ERROR] Required text processing tool 'awk' is not installed or not in PATH." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# ARCHITECTURAL RATIONALE: WHY `ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu`
# ------------------------------------------------------------------------------
# 1. WHY `--sort=-%cpu`:
#    - Native Sorting: GNU ps performs sorting internally directly from /proc
#      structures in kernel/userspace before generating text output.
#    - Descending Order: The leading minus sign ('-') guarantees the highest
#      CPU consumers appear immediately at the top of the table.
#    - Performance & Safety: Avoids piping huge process tables across external
#      'sort' utilities, eliminating pipeline race conditions, broken multi-line
#      records, locale issues (comma vs dot in floats), and SIGPIPE errors under
#      'set -eo pipefail'.
#
# 2. WHY THIS EXACT COLUMN SET (`pid,ppid,user,%cpu,%mem,comm`):
#    - `pid`: Process ID. The definitive unique operating system identifier
#      needed for further troubleshooting, tracing, or targeted isolation.
#    - `ppid`: Parent Process ID. Indispensable for establishing process ancestry;
#      identifies whether the process was spawned by systemd (PID 1), cron,
#      a container runtime, a web application worker, or an interactive shell.
#    - `user`: Effective User Name. Critical for security audits; immediately
#      reveals whether the CPU hog is running as root (system privilege),
#      a dedicated service daemon (e.g. www-data, postgres), or an unprivileged user.
#    - `%cpu`: CPU utilization ratio. The primary metric required for Problem #19;
#      expresses CPU time used divided by the time the process has been running.
#    - `%mem`: Memory utilization ratio. CPU spikes frequently correlate with
#      memory bottlenecks (e.g. garbage collection loops, memory thrashing, or
#      swap thrashing); monitoring %MEM alongside %CPU provides critical holistic context.
#    - `comm`: Executable/Command name (from /proc/[pid]/comm). Produces a clean,
#      concise name without lengthy argument strings, keeping terminal and HTML
#      tabular alignment stable and immune to column-wrapping distortion.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# OS-AWARE PROCESS QUERY COMMAND DEFINITION
# ------------------------------------------------------------------------------
# On Linux, GNU ps supports `--sort=-%cpu`.
# On macOS (Darwin BSD ps), `--sort` is unsupported; BSD ps uses `-r` to sort by
# current CPU usage in descending order.
OS_TYPE="$(uname -s)"
if [ "${OS_TYPE}" = "Linux" ]; then
    PS_QUERY=(ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu)
elif [ "${OS_TYPE}" = "Darwin" ]; then
    # BSD ps sorting by CPU usage
    PS_QUERY=(ps -eo pid,ppid,user,%cpu,%mem,comm -r)
else
    # Fallback POSIX ps
    PS_QUERY=(ps -eo pid,ppid,user,%cpu,%mem,comm)
fi

# Execute process query safely and capture output
if ! RAW_PS_DATA="$("${PS_QUERY[@]}" 2>/dev/null)"; then
    echo "[ERROR] Failed to query process table using '${PS_QUERY[*]}'." >&2
    exit 1
fi

if [[ -z "${RAW_PS_DATA}" ]]; then
    echo "[ERROR] Process query returned empty output." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# SYSTEM TELEMETRY & CONTEXT GATHERING
# ------------------------------------------------------------------------------
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
HOSTNAME_STR="$(hostname 2>/dev/null || uname -n)"
KERNEL_STR="$(uname -r 2>/dev/null || echo 'Unknown')"
CURRENT_USER="$(whoami 2>/dev/null || echo 'Unknown')"

# Count total active processes on the system (excluding ps header)
TOTAL_PROCESSES="$(echo "${RAW_PS_DATA}" | awk 'NR>1 {count++} END {print count+0}')"

# System load average (1m, 5m, 15m)
if [ -f /proc/loadavg ]; then
    LOAD_AVG="$(cut -d' ' -f1-3 /proc/loadavg)"
else
    LOAD_AVG="$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//' || echo 'N/A')"
fi

# ------------------------------------------------------------------------------
# PROCESS DATA EXTRACTION, TABULATION & ALERT FLAGGING VIA AWK
# ------------------------------------------------------------------------------
# We process the raw process data using awk for the following reasons:
# - Awk natively supports floating-point numerical comparisons ($4 >= threshold).
# - Bash native arithmetic $(( ... )) only supports integer math and would truncate
#   fractional CPU percentages like 49.8% to 49%, causing inaccurate alerting.
# - Formats clean fixed-width tabular columns with robust field-handling.
# ------------------------------------------------------------------------------

PARSED_OUTPUT=$(echo "${RAW_PS_DATA}" | awk -v count="${TOP_COUNT}" -v thresh="${CPU_THRESHOLD}" '
BEGIN {
    high_count = 0
    max_cpu = 0.0
}
NR == 1 { next } # Skip ps header row

printed < count {
    pid = $1
    ppid = $2
    user = $3
    cpu = $4 + 0.0
    mem = $5 + 0.0

    # Build command name from field 6 onwards to handle any spaced process names
    cmd = $6
    for (i = 7; i <= NF; i++) {
        cmd = cmd " " $i
    }

    # Track maximum CPU observed
    if (cpu > max_cpu) {
        max_cpu = cpu
    }

    # Evaluate against CPU threshold
    if (cpu >= thresh) {
        status = "⚠️  ALERT (>= " thresh "%)"
        is_alert = 1
        high_count++
    } else {
        status = "NORMAL"
        is_alert = 0
    }

    # Print delimited line: PID|PPID|USER|%CPU|%MEM|COMMAND|STATUS|IS_ALERT
    printf "%s|%s|%s|%.1f|%.1f|%s|%s|%d\n", pid, ppid, user, cpu, mem, cmd, status, is_alert
    printed++
}

END {
    # Summary trailer line
    printf "__SUMMARY__|%d|%.1f|%d\n", high_count, max_cpu, printed
}
')

# Separate table rows from summary metadata
TABLE_ROWS=$(echo "${PARSED_OUTPUT}" | grep -v '^__SUMMARY__')
SUMMARY_LINE=$(echo "${PARSED_OUTPUT}" | grep '^__SUMMARY__')

HIGH_CPU_COUNT=$(echo "${SUMMARY_LINE}" | cut -d'|' -f2)
MAX_CPU_SEEN=$(echo "${SUMMARY_LINE}" | cut -d'|' -f3)
ACTUAL_COUNT=$(echo "${SUMMARY_LINE}" | cut -d'|' -f4)

# ------------------------------------------------------------------------------
# TERMINAL OUTPUT GENERATION
# ------------------------------------------------------------------------------
echo "=================================================================================="
echo "                 HIGH CPU PROCESS DETECTION REPORT (LIVE DATA)                    "
echo "=================================================================================="
printf " Timestamp       : %s\n" "${TIMESTAMP}"
printf " Host / Node     : %s (OS: %s, Kernel: %s)\n" "${HOSTNAME_STR}" "${OS_TYPE}" "${KERNEL_STR}"
printf " Active User     : %s\n" "${CURRENT_USER}"
printf " System Load     : %s (1m, 5m, 15m)\n" "${LOAD_AVG}"
printf " Total Processes : %s running in process table\n" "${TOTAL_PROCESSES}"
printf " Top Processes   : %s requested (Displaying %s)\n" "${TOP_COUNT}" "${ACTUAL_COUNT}"
printf " CPU Threshold   : %.1f%% (Processes >= threshold flagged as high CPU)\n" "${CPU_THRESHOLD}"
echo "----------------------------------------------------------------------------------"
printf "%-8s %-8s %-14s %8s %8s   %-20s %s\n" "PID" "PPID" "USER" "%CPU" "%MEM" "COMMAND" "STATUS / ALERT"
printf "%-8s %-8s %-14s %8s %8s   %-20s %s\n" "--------" "--------" "--------------" "--------" "--------" "--------------------" "-------------------"

while IFS='|' read -r pid ppid user cpu mem cmd status is_alert; do
    if [[ "${is_alert}" -eq 1 ]]; then
        # Highlight high CPU processes
        printf "%-8s %-8s %-14s %8.1f %8.1f   %-20s %s\n" "${pid}" "${ppid}" "${user}" "${cpu}" "${mem}" "${cmd}" "${status}"
    else
        printf "%-8s %-8s %-14s %8.1f %8.1f   %-20s %s\n" "${pid}" "${ppid}" "${user}" "${cpu}" "${mem}" "${cmd}" "${status}"
    fi
done <<< "${TABLE_ROWS}"

echo "----------------------------------------------------------------------------------"
if [[ "${HIGH_CPU_COUNT}" -gt 0 ]]; then
    printf "⚠️  ALERT: %s process(es) exceeded the %.1f%% CPU threshold! (Peak: %.1f%%)\n" \
        "${HIGH_CPU_COUNT}" "${CPU_THRESHOLD}" "${MAX_CPU_SEEN}"
else
    printf "✓ All top %s processes are operating within normal CPU limits (< %.1f%%).\n" \
        "${ACTUAL_COUNT}" "${CPU_THRESHOLD}"
fi
echo "=================================================================================="

# ------------------------------------------------------------------------------
# AUDIT LOGGING (APPEND HISTORY TO LOG FILE)
# ------------------------------------------------------------------------------
# Appending (>>) rather than overwriting preserves chronological telemetry over time.
{
    echo "================================================================================"
    echo "[${TIMESTAMP}] HIGH CPU AUDIT SCAN"
    echo "Host: ${HOSTNAME_STR} | OS: ${OS_TYPE} | Kernel: ${KERNEL_STR} | Scanned by: ${CURRENT_USER}"
    echo "Parameters: Top Count = ${TOP_COUNT} | CPU Threshold = ${CPU_THRESHOLD}%"
    echo "System State: Total Processes = ${TOTAL_PROCESSES} | Load Avg = ${LOAD_AVG}"
    echo "--------------------------------------------------------------------------------"
    printf "%-8s %-8s %-14s %8s %8s   %-20s %s\n" "PID" "PPID" "USER" "%CPU" "%MEM" "COMMAND" "STATUS"
    printf "%-8s %-8s %-14s %8s %8s   %-20s %s\n" "--------" "--------" "--------------" "--------" "--------" "--------------------" "------"
    while IFS='|' read -r pid ppid user cpu mem cmd status is_alert; do
        printf "%-8s %-8s %-14s %8.1f %8.1f   %-20s %s\n" "${pid}" "${ppid}" "${user}" "${cpu}" "${mem}" "${cmd}" "${status}"
    done <<< "${TABLE_ROWS}"
    echo "--------------------------------------------------------------------------------"
    echo "Result: ${HIGH_CPU_COUNT} process(es) >= ${CPU_THRESHOLD}% threshold. Peak CPU: ${MAX_CPU_SEEN}%."
    echo "================================================================================"
    echo ""
} >> "${LOG_FILE}"

echo "Audit log appended to: ${LOG_FILE}"
exit 0
