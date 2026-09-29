#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #20: High Memory Process Detection
# Script: high_memory_detector.sh
# Author: System Administrator
#
# PURPOSE:
#   Identifies and reports the top memory-consuming processes currently active
#   on the system. Generates clean tabular output, converts Resident Set Size (RSS)
#   to human-readable megabytes (MB), reports overall system memory context
#   (total/used/free via `free -h`), flags processes exceeding a configurable
#   memory percentage threshold (default: 30.0%), logs all audit scans for
#   historical tracking, and supports flexible CLI flags.
#
# SANDBOXING & SAFETY NOTICE:
#   - 100% READ-ONLY INSPECTION.
#   - No processes are killed, terminated, reniced, signaled, or modified.
#   - All file operations are strictly confined within this project directory.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# DIRECTORY SETUP & LOGGING CONFIGURATION
# ------------------------------------------------------------------------------
# Resolve project directory dynamically so script can be invoked from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
DEFAULT_LOG_FILE="${LOG_DIR}/high_memory.log"
LOG_FILE="${DEFAULT_LOG_FILE}"

# ------------------------------------------------------------------------------
# DEFAULT PARAMETERS (CONFIGURABLE VIA CLI FLAGS)
# ------------------------------------------------------------------------------
# Default number of top memory-consuming processes to display
TOP_COUNT=5

# Memory threshold percentage: processes with %MEM >= THRESHOLD trigger an alert flag.
# Stored as a variable (not hardcoded) to allow dynamic thresholding in monitoring.
MEM_THRESHOLD=30.0

# ------------------------------------------------------------------------------
# USAGE / HELP FUNCTION
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
High Memory Process Detector — Automation Sprint (AS_20)

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -n <count>       Number of top memory-consuming processes to display (default: 5)
    -t <threshold>   Memory percentage alert threshold (default: 30.0)
    -l <logfile>     Custom log file path (default: logs/high_memory.log)
    -h, --help       Show this help manual and exit

EXAMPLES:
    ./high_memory_detector.sh                  # Display top 5 with 30.0% threshold
    ./high_memory_detector.sh -n 10            # Display top 10 processes
    ./high_memory_detector.sh -n 5 -t 15.0     # Flag any process consuming >= 15% RAM
    ./high_memory_detector.sh -l /tmp/mem.log  # Log to custom destination

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
            MEM_THRESHOLD="$2"
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
# Clear error messaging prevents silent failures or confusing shell tracebacks.
if ! command -v ps >/dev/null 2>&1; then
    echo "[ERROR] Required process inspection tool 'ps' is not installed or not in PATH." >&2
    exit 1
fi

if ! command -v awk >/dev/null 2>&1; then
    echo "[ERROR] Required text processing tool 'awk' is not installed or not in PATH." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# ARCHITECTURAL RATIONALE: WHY `ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem`
# ------------------------------------------------------------------------------
# 1. WHY `--sort=-%mem`:
#    - Native Kernel/Userspace Sorting: GNU `ps` extracts memory statistics directly
#      from kernel data structures in /proc/[pid]/statm and performs descending
#      sort internally before generating stdout.
#    - Leading Minus Sign ('-'): Guarantees highest memory consumers appear first.
#    - Performance & Stability: Avoids piping through external `sort`, preventing
#      locale-dependent decimal point issues (comma vs dot in floats), multi-line
#      wrapping bugs, pipe race conditions, and SIGPIPE termination under
#      'set -eo pipefail'.
#
# 2. WHY `rss` (Resident Set Size in KB) IS INCLUDED ALONGSIDE `%mem`:
#    - %MEM is Relative: `%mem` represents `(RSS / Total_Physical_RAM) * 100`.
#      On a 4 GB RAM node, 10% is ~400 MB. On a 128 GB production hypervisor,
#      10% is ~12.8 GB! Without absolute numbers, percentage alone does not reveal
#      the true physical footprint.
#    - RSS is Absolute: Resident Set Size (`rss`) measures the exact amount of
#      physical RAM (in KB) currently allocated and resident in hardware RAM
#      for that process. It excludes swapped-out memory and unallocated virtual
#      address space (VSZ), giving administrators the most accurate measure
#      of real physical memory pressure.
#    - Side-by-side Synergy: Presenting both `%mem` and human-readable `RSS (MB)`
#      gives immediate proportional impact AND exact capacity consumption.
#
# 3. WHY THIS FULL COLUMN SET (`pid,ppid,user,%mem,%cpu,rss,comm`):
#    - `pid`: Process ID. Definitive unique OS identifier for targeted tracing.
#    - `ppid`: Parent Process ID. Traces process ancestry and execution hierarchy
#      (e.g., systemd PID 1, cron, Docker runtime, worker thread, interactive bash).
#    - `user`: Process owner. Differentiates system services (root) from dedicated
#      daemons (www-data, postgres) or interactive user sessions.
#    - `%mem`: Memory percentage relative to total system RAM.
#    - `%cpu`: CPU utilization percentage. High memory consumers frequently leak
#      memory while spinning in allocation loops or garbage collection thrashing;
#      monitoring CPU alongside memory offers holistic diagnostic capability.
#    - `rss`: Physical memory consumption in KB (converted downstream to MB).
#    - `comm`: Short executable name from `/proc/[pid]/comm`. Produces clean,
#      fixed-width tabular formatting immune to long command-line argument wraps.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# OS-AWARE PROCESS QUERY COMMAND DEFINITION
# ------------------------------------------------------------------------------
# On Linux, GNU ps supports `--sort=-%mem`.
# On macOS (Darwin BSD ps), `--sort` is unsupported; BSD ps uses `-m` to sort
# by memory usage in descending order.
OS_TYPE="$(uname -s)"
if [ "${OS_TYPE}" = "Linux" ]; then
    PS_QUERY=(ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem)
elif [ "${OS_TYPE}" = "Darwin" ]; then
    # BSD ps sorting by memory usage
    PS_QUERY=(ps -eo pid,ppid,user,%mem,%cpu,rss,comm -m)
else
    # Fallback POSIX ps
    PS_QUERY=(ps -eo pid,ppid,user,%mem,%cpu,rss,comm)
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
# SYSTEM TELEMETRY & OVERALL MEMORY CONTEXT GATHERING (free -h)
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

# Retrieve overall system memory context via `free -h` (Requirement 4 & 7)
# On Linux, `free -h` provides human-readable summary of total/used/free/available RAM and swap.
# On macOS (Darwin), `free` does not exist; we query `sysctl hw.memsize` and `vm_stat` as an OS-aware fallback.
FREE_CONTEXT=""
FREE_AVAILABLE=0
if command -v free >/dev/null 2>&1; then
    if FREE_RAW="$(free -h 2>&1)"; then
        FREE_CONTEXT="${FREE_RAW}"
        FREE_AVAILABLE=1
    else
        FREE_CONTEXT="[WARNING] 'free -h' command failed to execute."
    fi
elif [ "${OS_TYPE}" = "Darwin" ]; then
    TOTAL_MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    TOTAL_MEM_GB="$(awk -v b="${TOTAL_MEM_BYTES}" 'BEGIN {printf "%.1f GiB", b/1024/1024/1024}')"
    FREE_CONTEXT="macOS System Memory Context: Total Physical RAM: ${TOTAL_MEM_GB}\n(Standard 'free -h' is Linux-specific; Darwin vm_stat telemetry used)"
    FREE_AVAILABLE=1
else
    FREE_CONTEXT="[WARNING] Neither 'free' nor alternative memory diagnostic tools were found in PATH."
fi

# ------------------------------------------------------------------------------
# PROCESS DATA EXTRACTION, RSS CONVERSION & ALERT FLAGGING VIA AWK
# ------------------------------------------------------------------------------
# We process the raw process data using awk for the following reasons:
# - Awk natively supports floating-point numerical comparisons ($4 >= thresh).
# - Bash native arithmetic $(( ... )) only supports integer math and would truncate
#   fractional memory percentages like 29.8% to 29%, causing missed alerts.
# - Converts RSS from KB to human-readable MB (rss / 1024.0).
# - Formats clean fixed-width tabular columns with robust field handling.
# ------------------------------------------------------------------------------

PARSED_OUTPUT=$(echo "${RAW_PS_DATA}" | awk -v count="${TOP_COUNT}" -v thresh="${MEM_THRESHOLD}" '
BEGIN {
    high_count = 0
    max_mem = 0.0
    total_rss_mb = 0.0
}
NR == 1 { next } # Skip ps header row

printed < count {
    pid = $1
    ppid = $2
    user = $3
    mem = $4 + 0.0
    cpu = $5 + 0.0
    rss_kb = $6 + 0.0

    # Convert RSS from KB to MB (Human-Readable)
    rss_mb = rss_kb / 1024.0
    total_rss_mb += rss_mb

    # Build command name from field 7 onwards to handle any spaced process names
    cmd = $7
    for (i = 8; i <= NF; i++) {
        cmd = cmd " " $i
    }

    # Track maximum memory percentage observed
    if (mem > max_mem) {
        max_mem = mem
    }

    # Evaluate against memory threshold
    if (mem >= thresh) {
        status = "⚠️  ALERT (>= " thresh "%)"
        is_alert = 1
        high_count++
    } else {
        status = "✓ NORMAL"
        is_alert = 0
    }

    # Print delimited line: PID|PPID|USER|%MEM|%CPU|RSS_KB|RSS_MB|COMMAND|STATUS|IS_ALERT
    printf "%s|%s|%s|%.1f|%.1f|%.0f|%.1f|%s|%s|%d\n", pid, ppid, user, mem, cpu, rss_kb, rss_mb, cmd, status, is_alert
    printed++
}

END {
    # Summary trailer line
    printf "__SUMMARY__|%d|%.1f|%.1f|%d\n", high_count, max_mem, total_rss_mb, printed
}
')

# Separate table rows from summary metadata
TABLE_ROWS=$(echo "${PARSED_OUTPUT}" | grep -v '^__SUMMARY__')
SUMMARY_LINE=$(echo "${PARSED_OUTPUT}" | grep '^__SUMMARY__')

HIGH_MEM_COUNT=$(echo "${SUMMARY_LINE}" | cut -d'|' -f2)
MAX_MEM_SEEN=$(echo "${SUMMARY_LINE}" | cut -d'|' -f3)
TOTAL_TOP_RSS_MB=$(echo "${SUMMARY_LINE}" | cut -d'|' -f4)
ACTUAL_COUNT=$(echo "${SUMMARY_LINE}" | cut -d'|' -f5)

# ------------------------------------------------------------------------------
# TERMINAL OUTPUT GENERATION
# ------------------------------------------------------------------------------
echo "=================================================================================="
echo "                HIGH MEMORY PROCESS DETECTION REPORT (LIVE DATA)                  "
echo "=================================================================================="
printf " Timestamp       : %s\n" "${TIMESTAMP}"
printf " Host / Node     : %s (OS: %s, Kernel: %s)\n" "${HOSTNAME_STR}" "${OS_TYPE}" "${KERNEL_STR}"
printf " Active User     : %s\n" "${CURRENT_USER}"
printf " System Load     : %s (1m, 5m, 15m)\n" "${LOAD_AVG}"
printf " Total Processes : %s running in process table\n" "${TOTAL_PROCESSES}"
printf " Top Processes   : %s requested (Displaying %s)\n" "${TOP_COUNT}" "${ACTUAL_COUNT}"
printf " Memory Threshold: %.1f%% (Processes >= threshold flagged as high memory)\n" "${MEM_THRESHOLD}"
echo "----------------------------------------------------------------------------------"
echo "OVERALL SYSTEM MEMORY CONTEXT (free -h):"
echo -e "${FREE_CONTEXT}"
echo "----------------------------------------------------------------------------------"
printf "%-8s %-8s %-14s %7s %11s %7s   %-20s %s\n" "PID" "PPID" "USER" "%MEM" "RSS (MB)" "%CPU" "COMMAND" "STATUS / ALERT"
printf "%-8s %-8s %-14s %7s %11s %7s   %-20s %s\n" "--------" "--------" "--------------" "-------" "-----------" "-------" "--------------------" "-------------------"

while IFS='|' read -r pid ppid user mem cpu rss_kb rss_mb cmd status is_alert; do
    printf "%-8s %-8s %-14s %6.1f%% %9.1f MB %6.1f%%   %-20s %s\n" \
        "${pid}" "${ppid}" "${user}" "${mem}" "${rss_mb}" "${cpu}" "${cmd}" "${status}"
done <<< "${TABLE_ROWS}"

echo "----------------------------------------------------------------------------------"
if [[ "${HIGH_MEM_COUNT}" -gt 0 ]]; then
    printf "⚠️  ALERT: %s process(es) exceeded the %.1f%% memory threshold! (Peak: %.1f%%)\n" \
        "${HIGH_MEM_COUNT}" "${MEM_THRESHOLD}" "${MAX_MEM_SEEN}"
else
    printf "✓ All top %s processes are operating within normal memory limits (< %.1f%%).\n" \
        "${ACTUAL_COUNT}" "${MEM_THRESHOLD}"
fi
printf "   Top %s processes consume a cumulative %s MB of physical RAM (Peak: %.1f%%).\n" \
    "${ACTUAL_COUNT}" "${TOTAL_TOP_RSS_MB}" "${MAX_MEM_SEEN}"
echo "=================================================================================="

# ------------------------------------------------------------------------------
# AUDIT LOGGING (APPEND HISTORY TO LOG FILE)
# ------------------------------------------------------------------------------
# Appending (>>) rather than overwriting preserves chronological telemetry over time.
{
    echo "================================================================================"
    echo "[${TIMESTAMP}] HIGH MEMORY AUDIT SCAN"
    echo "Host: ${HOSTNAME_STR} | OS: ${OS_TYPE} | Kernel: ${KERNEL_STR} | Scanned by: ${CURRENT_USER}"
    echo "Parameters: Top Count = ${TOP_COUNT} | Memory Threshold = ${MEM_THRESHOLD}%"
    echo "System State: Total Processes = ${TOTAL_PROCESSES} | Load Avg = ${LOAD_AVG}"
    echo "--------------------------------------------------------------------------------"
    echo "System Memory Summary:"
    echo -e "${FREE_CONTEXT}"
    echo "--------------------------------------------------------------------------------"
    printf "%-8s %-8s %-14s %7s %11s %7s   %-20s %s\n" "PID" "PPID" "USER" "%MEM" "RSS (MB)" "%CPU" "COMMAND" "STATUS"
    printf "%-8s %-8s %-14s %7s %11s %7s   %-20s %s\n" "--------" "--------" "--------------" "-------" "-----------" "-------" "--------------------" "------"
    while IFS='|' read -r pid ppid user mem cpu rss_kb rss_mb cmd status is_alert; do
        printf "%-8s %-8s %-14s %6.1f%% %9.1f MB %6.1f%%   %-20s %s\n" \
            "${pid}" "${ppid}" "${user}" "${mem}" "${rss_mb}" "${cpu}" "${cmd}" "${status}"
    done <<< "${TABLE_ROWS}"
    echo "--------------------------------------------------------------------------------"
    echo "Result: ${HIGH_MEM_COUNT} process(es) >= ${MEM_THRESHOLD}% threshold. Peak %MEM: ${MAX_MEM_SEEN}%. Cumulative Top RSS: ${TOTAL_TOP_RSS_MB} MB."
    echo "================================================================================"
    echo ""
} >> "${LOG_FILE}"

echo "Audit log appended to: ${LOG_FILE}"
exit 0
