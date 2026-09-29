#!/usr/bin/env bash
# ==============================================================================
# Course: Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #22: Multiple Server Check
# Focus: Network Automation, Multi-Host Probing & Inventory Status Reporting
# Script: multi_server_check.sh
#
# ROLE & PURPOSE:
#   A production-grade, self-contained Bash network automation utility designed
#   to read a list of target servers/IPs from an inventory configuration file
#   (servers.txt), probe network reachability using bounded ICMP echo requests,
#   and report real UP/DOWN health metrics in a formatted terminal table and
#   timestamped audit log.
#
# KEY REQUIREMENTS IMPLEMENTED:
#   1. Reads server inventory from servers.txt (supporting comments, inline labels).
#   2. Adaptive OS ping syntax:
#      - Linux: ping -c <count> -W <timeout>
#      - macOS (Darwin): ping -c <count> -t <timeout>
#      - Windows Native (Git Bash/MSYS/Cygwin): ping -n <count> -w <timeout_ms>
#   3. Formatted terminal report table:
#      - Hostname / IP address
#      - Health status ([ UP ] / [ DOWN ]) with ANSI terminal color highlights
#      - Packet loss percentage
#      - Average RTT latency (with Min/Max metrics)
#      - Configured role / description label
#   4. Global executive summary:
#      - Total servers checked, count UP, count DOWN, overall availability percentage.
#   5. High-concurrency parallel probing:
#      - Backgrounds individual server probes using subshells (&) and synchronizes
#        with bash 'wait'.
#      - Preserves inventory display order using numbered temporary slot files.
#      - Includes optional sequential mode (--sequential / -s) for constrained devices.
#      - Detailed commentary explaining parallel vs sequential architectural tradeoffs.
#   6. Persistent chronological audit logging:
#      - Appends structured records with ISO-style timestamps to logs/multi_server_check.log.
#   7. Robust error trapping & defensive edge-case handling:
#      - Missing or empty config file detected with clear diagnostics and exit code 1.
#      - Malformed lines, unsafe characters, and blank lines handled defensively.
#      - DNS unresolvable hosts flagged gracefully as DOWN without crashing the loop.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Script Location & Directory Sandboxing
# Ensures script operates relative to AS_22 regardless of invocation directory
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/servers.txt"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/multi_server_check.log"

# Default Probe Parameters
DEFAULT_PING_COUNT=2       # 2 packets transmitted per server for fast, reliable evaluation
DEFAULT_TIMEOUT=2          # 2 seconds per probe to prevent hanging on unresponsive hosts
RUN_PARALLEL=true          # Concurrent execution by default (set false via --sequential)
QUIET_MODE=false           # Suppress banner if set

# ------------------------------------------------------------------------------
# ANSI Color Palette for Terminal Highlighting
# Automatically disabled if standard output is not a terminal (e.g. redirected/piped)
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_GREEN="\033[32m"
    C_RED="\033[31m"
    C_YELLOW="\033[33m"
    C_CYAN="\033[36m"
    C_BLUE="\033[34m"
    C_GRAY="\033[90m"
else
    C_RESET=""
    C_BOLD=""
    C_GREEN=""
    C_RED=""
    C_YELLOW=""
    C_CYAN=""
    C_BLUE=""
    C_GRAY=""
fi

# ------------------------------------------------------------------------------
# Function: display_usage
# Prints comprehensive command-line manual, flags, and operational examples.
# ------------------------------------------------------------------------------
display_usage() {
    cat <<EOF
${C_BOLD}Usage:${C_RESET} $0 [OPTIONS]

${C_BOLD}Multiple Server Health Check — Network Automation & Inventory Probing${C_RESET}

${C_BOLD}OPTIONS:${C_RESET}
  -f, --file <path>       Specify custom server inventory config (default: servers.txt)
  -c, --count <num>       Number of ICMP echo packets per target (default: ${DEFAULT_PING_COUNT})
  -w, -W, --timeout <sec> Probe timeout in seconds (default: ${DEFAULT_TIMEOUT}s)
  -p, --parallel          Execute server probes concurrently in parallel (default)
  -s, --sequential        Execute server probes sequentially in serial order
  -l, --log <path>        Custom audit log destination (default: ${LOG_FILE})
  -q, --quiet             Quiet mode (suppress informative headers)
  -h, --help              Display this command manual and exit

${C_BOLD}ARCHITECTURAL MODES (PARALLEL vs. SEQUENTIAL):${C_RESET}
  * Parallel (--parallel):
    Spawns background subshells (&) synchronized via 'wait'. Total runtime drops
    from O(N * timeout) to O(timeout), running in ~2-3 seconds regardless of list
    size. Temporary result files ensure ordered table rendering.
  * Sequential (--sequential):
    Executes checks one host at a time in serial order. Simpler execution model
    with zero temporary files or subshell synchronization, ideal for low-end
    routers or constrained environments where ICMP socket saturation is a concern.

${C_BOLD}EXAMPLES:${C_RESET}
  $0                      # Run parallel check on default servers.txt
  $0 -s                   # Run in sequential mode
  $0 -c 3 -w 1            # Send 3 pings with 1s timeout per target
  $0 -f custom_hosts.txt  # Probe custom server inventory list
  $0 --help               # Show this manual
EOF
}

# ------------------------------------------------------------------------------
# Function: detect_default_gateway
# Discovers the host system's live default gateway IP across Linux, macOS,
# and Windows environments (used if 'GATEWAY' is specified in servers.txt).
# ------------------------------------------------------------------------------
detect_default_gateway() {
    local gw=""
    local os_type
    os_type="$(uname -s 2>/dev/null || echo "Unknown")"

    case "${os_type}" in
        Darwin*)
            # macOS BSD route lookup
            if command -v route >/dev/null 2>&1; then
                gw="$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}' || true)"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows Git Bash / Cygwin route parsing
            if command -v netstat >/dev/null 2>&1; then
                gw="$(netstat -rn 2>/dev/null | awk '$1 == "0.0.0.0" {print $3; exit}' || true)"
            fi
            if [ -z "${gw}" ] && command -v powershell.exe >/dev/null 2>&1; then
                gw="$(powershell.exe -NoProfile -Command "(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1" 2>/dev/null | tr -d '\r\n' || true)"
            fi
            ;;
        Linux*|*)
            # Linux primary iproute2 discovery
            if command -v ip >/dev/null 2>&1; then
                gw="$(ip route 2>/dev/null | grep -E '^default ' | awk '{print $3}' | head -n 1 || true)"
            fi
            # Linux legacy route fallback
            if [ -z "${gw}" ] && command -v route >/dev/null 2>&1; then
                gw="$(route -n 2>/dev/null | awk '/^0.0.0.0/ {print $2; exit}' || true)"
            fi
            ;;
    esac

    echo "${gw}"
}

# ------------------------------------------------------------------------------
# Function: ping_single_host
# Executes an OS-adapted bounded ping against a single target host, parses
# raw output via grep/awk, and returns a pipe-delimited telemetry record.
#
# Arguments:
#   $1: Slot index (for deterministic ordering)
#   $2: Target IP or Hostname
#   $3: Target Role / Description Label
#   $4: Ping Packet Count
#   $5: Timeout in seconds
#
# Output format (pipe-delimited record):
#   INDEX|TARGET|LABEL|STATUS|LOSS_PCT|AVG_RTT|MIN_RTT|MAX_RTT|SENT|RECEIVED|ERR_NOTE
# ------------------------------------------------------------------------------
ping_single_host() {
    local index="$1"
    local target="$2"
    local label="$3"
    local count="$4"
    local timeout="$5"

    local raw_output=""
    local ping_exit_code=0
    local os_type
    os_type="$(uname -s 2>/dev/null || echo "Unknown")"

    # Step 1: Execute bounded ping adapting flags to host operating system
    # - Linux uses -c <count> -W <timeout_seconds>
    # - macOS uses -c <count> -t <timeout_seconds>
    # - Windows native ping uses -n <count> -w <timeout_milliseconds>
    if [[ "${os_type}" =~ MINGW|MSYS|CYGWIN ]] && ! ping -c 1 127.0.0.1 >/dev/null 2>&1; then
        local win_timeout_ms=$((timeout * 1000))
        raw_output="$(ping -n "${count}" -w "${win_timeout_ms}" "${target}" 2>&1)" || ping_exit_code=$?
    elif [[ "${os_type}" == "Darwin" ]]; then
        raw_output="$(ping -c "${count}" -t "${timeout}" "${target}" 2>&1)" || ping_exit_code=$?
    else
        # Linux standard iputils ping
        raw_output="$(ping -c "${count}" -W "${timeout}" "${target}" 2>&1)" || ping_exit_code=$?
    fi

    # Step 2: Detect DNS resolution failures or non-existent domains
    if echo "${raw_output}" | grep -qiE "unknown host|Name or service not known|could not find host|ping: cannot resolve|No address associated"; then
        echo "${index}|${target}|${label}|DOWN|100%|N/A|N/A|N/A|0|0|DNS Resolution Failure"
        return
    fi

    # Step 3: Extract packets transmitted and received
    local sent="0"
    local received="0"
    sent="$(echo "${raw_output}" | grep -oE '[0-9]+ packets transmitted' | awk '{print $1}' || echo "0")"
    received="$(echo "${raw_output}" | grep -oE '[0-9]+ (packets )?received' | awk '{print $1}' || echo "0")"

    # Windows native ping output format compatibility ("Sent = 2, Received = 2")
    if [ -z "${sent}" ] || [ "${sent}" = "0" ]; then
        sent="$(echo "${raw_output}" | grep -iE 'Sent = [0-9]+' | grep -oE 'Sent = [0-9]+' | awk '{print $3}' || echo "${count}")"
    fi
    if [ -z "${received}" ]; then
        received="$(echo "${raw_output}" | grep -iE 'Received = [0-9]+' | grep -oE 'Received = [0-9]+' | awk '{print $3}' || echo "0")"
    fi

    # Step 4: Extract packet loss percentage
    local loss_pct=""
    loss_pct="$(echo "${raw_output}" | grep -oE '[0-9]+(\.[0-9]+)?% packet loss' | awk '{print $1}' || echo "")"
    if [ -z "${loss_pct}" ]; then
        loss_pct="$(echo "${raw_output}" | grep -oE '\([0-9]+% loss\)' | tr -d '()' || echo "")"
    fi
    if [ -z "${loss_pct}" ]; then
        if [ "${received}" -eq 0 ] 2>/dev/null; then
            loss_pct="100%"
        elif [ "${received}" -eq "${sent}" ] 2>/dev/null; then
            loss_pct="0%"
        else
            loss_pct="Unknown"
        fi
    fi

    # Step 5: Extract Round-Trip Time (RTT) statistics: Min, Avg, Max
    local min_rtt="N/A"
    local avg_rtt="N/A"
    local max_rtt="N/A"

    if echo "${raw_output}" | grep -qE "rtt|round-trip"; then
        # Example Linux format: rtt min/avg/max/mdev = 27.034/27.779/28.524/0.745 ms
        local stats_line
        stats_line="$(echo "${raw_output}" | grep -E "rtt|round-trip" | head -n 1)"
        local rtt_values
        rtt_values="$(echo "${stats_line}" | awk -F'=' '{print $2}')"
        min_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')"
        avg_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')"
        max_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')"

        [ -n "${min_rtt}" ] && min_rtt="$(printf "%.2f" "${min_rtt}" 2>/dev/null || echo "${min_rtt}")ms" || min_rtt="N/A"
        [ -n "${avg_rtt}" ] && avg_rtt="$(printf "%.2f" "${avg_rtt}" 2>/dev/null || echo "${avg_rtt}")ms" || avg_rtt="N/A"
        [ -n "${max_rtt}" ] && max_rtt="$(printf "%.2f" "${max_rtt}" 2>/dev/null || echo "${max_rtt}")ms" || max_rtt="N/A"
    elif echo "${raw_output}" | grep -qi "Average ="; then
        # Windows ping summary: Minimum = 2ms, Maximum = 5ms, Average = 3ms
        avg_rtt="$(echo "${raw_output}" | grep -i "Average =" | sed 's/.*Average = //' | awk '{print $1}' || echo "N/A")"
        min_rtt="$(echo "${raw_output}" | grep -i "Minimum =" | sed 's/.*Minimum = //' | awk -F',' '{print $1}' || echo "N/A")"
        max_rtt="$(echo "${raw_output}" | grep -i "Maximum =" | sed 's/.*Maximum = //' | awk -F',' '{print $1}' || echo "N/A")"
    fi

    # Step 6: Determine UP / DOWN status
    local status="DOWN"
    local err_note="None"

    if [ -n "${received}" ] && [ "${received}" -gt 0 ] 2>/dev/null && [ "${loss_pct}" != "100%" ]; then
        status="UP"
        err_note="Healthy"
    else
        status="DOWN"
        if [ "${sent}" -gt 0 ] && [ "${received}" -eq 0 ]; then
            err_note="100% Packet Loss / No Response"
        else
            err_note="Unreachable"
        fi
    fi

    # Emit pipe-delimited record
    echo "${index}|${target}|${label}|${status}|${loss_pct}|${avg_rtt}|${min_rtt}|${max_rtt}|${sent}|${received}|${err_note}"
}

# ------------------------------------------------------------------------------
# Parse Command-Line Options
# ------------------------------------------------------------------------------
PING_COUNT="${DEFAULT_PING_COUNT}"
TIMEOUT_SEC="${DEFAULT_TIMEOUT}"

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--file)
            if [ -z "${2:-}" ]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a file path argument.${C_RESET}" >&2
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        -c|--count)
            if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a positive integer count.${C_RESET}" >&2
                exit 1
            fi
            PING_COUNT="$2"
            shift 2
            ;;
        -w|-W|--timeout)
            if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a positive integer timeout in seconds.${C_RESET}" >&2
                exit 1
            fi
            TIMEOUT_SEC="$2"
            shift 2
            ;;
        -p|--parallel)
            RUN_PARALLEL=true
            shift
            ;;
        -s|--sequential)
            RUN_PARALLEL=false
            shift
            ;;
        -l|--log)
            if [ -z "${2:-}" ]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a log file path argument.${C_RESET}" >&2
                exit 1
            fi
            LOG_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            # Support positional argument as config file
            if [ ! -f "$1" ] && [ -f "${SCRIPT_DIR}/$1" ]; then
                CONFIG_FILE="${SCRIPT_DIR}/$1"
            elif [ -f "$1" ]; then
                CONFIG_FILE="$1"
            else
                echo -e "${C_RED}[ERROR] Unrecognized option or missing file: '$1'${C_RESET}" >&2
                echo -e "Run '$0 --help' for syntax instructions." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Validate Configuration Inventory File
# ------------------------------------------------------------------------------
if [ ! -f "${CONFIG_FILE}" ]; then
    echo -e "${C_RED}[ERROR] Server inventory configuration file '${CONFIG_FILE}' not found!${C_RESET}" >&2
    echo -e "Please ensure '${CONFIG_FILE}' exists or specify a valid file with -f <file>." >&2
    exit 1
fi

if [ ! -r "${CONFIG_FILE}" ]; then
    echo -e "${C_RED}[ERROR] Server inventory configuration file '${CONFIG_FILE}' is not readable!${C_RESET}" >&2
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "${LOG_FILE}")"

# ------------------------------------------------------------------------------
# Read and Parse Server Inventory List
# Filters comments, blank lines, trims whitespace, handles inline labels,
# and maps 'GATEWAY' dynamically to the auto-detected default gateway.
# ------------------------------------------------------------------------------
TARGET_LIST=()
LABEL_LIST=()
LINE_NUMBER=0
AUTO_GW=""

while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
    LINE_NUMBER=$((LINE_NUMBER + 1))

    # Strip carriage returns (CRLF from Windows files)
    clean_line="$(echo "${raw_line}" | tr -d '\r')"

    # Trim leading and trailing whitespace
    clean_line="$(echo "${clean_line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Skip empty lines or pure comment lines
    if [ -z "${clean_line}" ] || [[ "${clean_line}" =~ ^# ]]; then
        continue
    fi

    # Parse target and optional inline comment/label
    # Format: <host_or_ip> [# optional description]
    target_part=""
    label_part=""

    if [[ "${clean_line}" == *"#"* ]]; then
        target_part="$(echo "${clean_line}" | awk -F'#' '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        label_part="$(echo "${clean_line}" | awk -F'#' '{$1=""; print $0}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    else
        # Split on whitespace if multiple words present without '#'
        target_part="$(echo "${clean_line}" | awk '{print $1}')"
        label_part="$(echo "${clean_line}" | awk '{$1=""; print $0}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    fi

    # Defensive check: ensure target token contains valid hostname/IP characters
    # Allowed: alphanumeric, dots, hyphens, colons (IPv6). Reject shell metacharacters (; & | $ `).
    if ! [[ "${target_part}" =~ ^[a-zA-Z0-9.:_-]+$ ]] || [ ${#target_part} -gt 253 ]; then
        echo -e "${C_YELLOW}[WARN] Skipping malformed inventory entry at line ${LINE_NUMBER}: '${clean_line}'${C_RESET}" >&2
        continue
    fi

    # Special Keyword: Map 'GATEWAY' to live detected default gateway
    if [[ "${target_part^^}" == "GATEWAY" || "${target_part^^}" == "DEFAULT_GATEWAY" ]]; then
        if [ -z "${AUTO_GW}" ]; then
            AUTO_GW="$(detect_default_gateway)"
        fi
        if [ -n "${AUTO_GW}" ]; then
            target_part="${AUTO_GW}"
            [ -z "${label_part}" ] && label_part="Auto-Detected Default Gateway"
        else
            echo -e "${C_YELLOW}[WARN] Could not auto-detect default gateway for 'GATEWAY' entry at line ${LINE_NUMBER}. Skipping.${C_RESET}" >&2
            continue
        fi
    fi

    [ -z "${label_part}" ] && label_part="Monitored Server"

    TARGET_LIST+=("${target_part}")
    LABEL_LIST+=("${label_part}")
done < "${CONFIG_FILE}"

TOTAL_SERVERS=${#TARGET_LIST[@]}

if [ "${TOTAL_SERVERS}" -eq 0 ]; then
    echo -e "${C_RED}[ERROR] Configuration file '${CONFIG_FILE}' contains no valid server entries!${C_RESET}" >&2
    echo -e "Please populate '${CONFIG_FILE}' with hostnames or IP addresses (one per line)." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Terminal Execution Banner
# ------------------------------------------------------------------------------
EXEC_START_TIME="$(date +%s)"
SCAN_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST_IDENTITY="$(hostname 2>/dev/null || uname -n)"
OS_SUMMARY="$(uname -s) $(uname -r)"

if [ "${QUIET_MODE}" = false ]; then
    echo -e "${C_BOLD}================================================================================${C_RESET}"
    echo -e "${C_BOLD}           MULTIPLE SERVER HEALTH CHECK — NETWORK AUTOMATION MONITOR            ${C_RESET}"
    echo -e "${C_BOLD}================================================================================${C_RESET}"
    echo -e "  ${C_CYAN}Timestamp:${C_RESET}     ${SCAN_TIMESTAMP}"
    echo -e "  ${C_CYAN}Host System:${C_RESET}   ${HOST_IDENTITY} (${OS_SUMMARY})"
    echo -e "  ${C_CYAN}Config File:${C_RESET}   ${CONFIG_FILE} (${TOTAL_SERVERS} targets loaded)"
    echo -e "  ${C_CYAN}Parameters:${C_RESET}    ${PING_COUNT} packets/host | ${TIMEOUT_SEC}s timeout | Mode: $([ "${RUN_PARALLEL}" = true ] && echo "Parallel Concurrent (&)" || echo "Sequential Serial")"
    echo -e "${C_BOLD}--------------------------------------------------------------------------------${C_RESET}"
fi

# ------------------------------------------------------------------------------
# Probe Execution: Parallel vs Sequential
#
# ARCHITECTURAL TRADEOFF ANALYSIS:
# 1. Sequential Mode:
#    - Simplicity: Code runs in a direct for-loop without IPC or subshell synchronization.
#    - Resource Safety: Probes run strictly one after another; zero socket contention,
#      zero CPU spikes, zero risk of ICMP flooding or buffer overruns on weak routers.
#    - Performance Penalty: Total runtime is O(N * timeout). If 10 servers are down with
#      a 2-second timeout, sequential execution takes 20+ seconds to finish.
#
# 2. Parallel Mode:
#    - Concurrency: Backgrounds each host probe (&) and synchronizes with 'wait'.
#    - Scalability: Total runtime is bounded by max single-host timeout ~ O(timeout).
#      Probing 10 or 100 servers takes ~2 seconds total wall-clock time.
#    - Coordination: Uses numbered temporary slot files to capture subshell outputs
#      and assemble the final report table deterministically in original list order.
# ------------------------------------------------------------------------------
RAW_RECORDS=()

if [ "${RUN_PARALLEL}" = true ]; then
    TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'msc_tmp')"
    # Trap ensures temporary directory cleanup even on SIGINT or unexpected termination
    trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

    # Launch probes concurrently in parallel background subshells
    for i in "${!TARGET_LIST[@]}"; do
        (
            slot="$i"
            tgt="${TARGET_LIST[$i]}"
            lbl="${LABEL_LIST[$i]}"
            ping_single_host "${slot}" "${tgt}" "${lbl}" "${PING_COUNT}" "${TIMEOUT_SEC}" > "${TMP_DIR}/slot_${slot}.dat"
        ) &
    done

    # Await completion of all concurrent background subshells
    wait

    # Reassemble telemetry records in deterministic inventory order
    for i in "${!TARGET_LIST[@]}"; do
        if [ -f "${TMP_DIR}/slot_${i}.dat" ]; then
            rec="$(cat "${TMP_DIR}/slot_${i}.dat")"
            RAW_RECORDS+=("${rec}")
        else
            RAW_RECORDS+=("${i}|${TARGET_LIST[$i]}|${LABEL_LIST[$i]}|DOWN|100%|N/A|N/A|N/A|0|0|Subshell Execution Error")
        fi
    done

    # Clean up temporary directory
    rm -rf "${TMP_DIR}"
    trap - EXIT INT TERM
else
    # Sequential execution: direct iterative evaluation
    for i in "${!TARGET_LIST[@]}"; do
        tgt="${TARGET_LIST[$i]}"
        lbl="${LABEL_LIST[$i]}"
        rec="$(ping_single_host "${i}" "${tgt}" "${lbl}" "${PING_COUNT}" "${TIMEOUT_SEC}")"
        RAW_RECORDS+=("${rec}")
    done
fi

EXEC_END_TIME="$(date +%s)"
TOTAL_RUNTIME=$((EXEC_END_TIME - EXEC_START_TIME))

# ------------------------------------------------------------------------------
# Render Structured Results Table
# ------------------------------------------------------------------------------
COUNT_UP=0
COUNT_DOWN=0

# Table Header
echo ""
printf "+---------------------------------------------------------------------------------------------------------+\n"
printf "| %-20s | %-8s | %-8s | %-10s | %-9s | %-32s |\n" "TARGET / HOST" "STATUS" "LOSS %" "AVG RTT" "PACKETS" "ROLE / DESCRIPTION"
printf "+---------------------------------------------------------------------------------------------------------+\n"

# Table Body Rows
for rec in "${RAW_RECORDS[@]}"; do
    IFS='|' read -r r_idx r_target r_label r_status r_loss r_avg r_min r_max r_sent r_recv r_note <<< "${rec}"

    pkts="${r_recv}/${r_sent}"

    if [ "${r_status}" = "UP" ]; then
        COUNT_UP=$((COUNT_UP + 1))
        status_badge="${C_GREEN}${C_BOLD}[  UP  ]${C_RESET}"
    else
        COUNT_DOWN=$((COUNT_DOWN + 1))
        status_badge="${C_RED}${C_BOLD}[ DOWN ]${C_RESET}"
    fi

    # Truncate strings to prevent column overflow
    t_disp="${r_target:0:20}"
    l_disp="${r_label:0:32}"

    printf "| %-20s | %b | %-8s | %-10s | %-9s | %-32s |\n" \
        "${t_disp}" "${status_badge}" "${r_loss}" "${r_avg}" "${pkts}" "${l_disp}"
done

printf "+---------------------------------------------------------------------------------------------------------+\n"

# ------------------------------------------------------------------------------
# Global Executive Summary
# ------------------------------------------------------------------------------
AVAIL_PCT="0.0"
if [ "${TOTAL_SERVERS}" -gt 0 ]; then
    AVAIL_PCT="$(awk -v up="${COUNT_UP}" -v total="${TOTAL_SERVERS}" 'BEGIN { printf "%.1f", (up / total) * 100 }')"
fi

echo ""
echo -e "${C_BOLD}================================================================================${C_RESET}"
echo -e "${C_BOLD}                             EXECUTION SUMMARY                                  ${C_RESET}"
echo -e "${C_BOLD}================================================================================${C_RESET}"
printf "  %-24s: %d\n" "Total Servers Checked" "${TOTAL_SERVERS}"
printf "  %-24s: %b%d%b\n" "Servers Reachable (UP)" "${C_GREEN}${C_BOLD}" "${COUNT_UP}" "${C_RESET}"
printf "  %-24s: %b%d%b\n" "Servers Down (UNREACHABLE)" "${C_RED}${C_BOLD}" "${COUNT_DOWN}" "${C_RESET}"
printf "  %-24s: %s%%\n" "Overall Availability" "${AVAIL_PCT}"
printf "  %-24s: %d seconds\n" "Total Probe Wall-Time" "${TOTAL_RUNTIME}"
printf "  %-24s: %s\n" "Audit Log Target" "${LOG_FILE}"
echo -e "${C_BOLD}================================================================================${C_RESET}"

# ------------------------------------------------------------------------------
# Append Structured Audit Run to Log File
# Preserves chronological history for system auditing and compliance.
# ------------------------------------------------------------------------------
{
    echo "================================================================================"
    echo "TIMESTAMP: [${SCAN_TIMESTAMP}]"
    echo "HOST: ${HOST_IDENTITY} | OS: ${OS_SUMMARY}"
    echo "CONFIG: ${CONFIG_FILE} | TOTAL: ${TOTAL_SERVERS} | UP: ${COUNT_UP} | DOWN: ${COUNT_DOWN} | AVAILABILITY: ${AVAIL_PCT}%"
    echo "EXECUTION_MODE: $([ "${RUN_PARALLEL}" = true ] && echo "Parallel Concurrent" || echo "Sequential Serial") | RUNTIME: ${TOTAL_RUNTIME}s"
    echo "--------------------------------------------------------------------------------"
    printf "%-22s %-8s %-8s %-10s %-9s %-12s %-24s\n" "TARGET" "STATUS" "LOSS" "AVG_RTT" "PACKETS" "NOTES" "ROLE"
    printf "%-22s %-8s %-8s %-10s %-9s %-12s %-24s\n" "------" "------" "----" "-------" "-------" "-----" "----"
    for rec in "${RAW_RECORDS[@]}"; do
        IFS='|' read -r r_idx r_target r_label r_status r_loss r_avg r_min r_max r_sent r_recv r_note <<< "${rec}"
        pkts="${r_recv}/${r_sent}"
        printf "%-22s %-8s %-8s %-10s %-9s %-12s %-24s\n" \
            "${r_target}" "${r_status}" "${r_loss}" "${r_avg}" "${pkts}" "${r_note}" "${r_label}"
    done
    echo "================================================================================"
    echo ""
} >> "${LOG_FILE}"

# Save machine-readable state for seamless HTML dashboard regeneration
{
    echo "# METADATA|TOTAL=${TOTAL_SERVERS}|UP=${COUNT_UP}|DOWN=${COUNT_DOWN}|AVAIL=${AVAIL_PCT}|TIME=${TOTAL_RUNTIME}|MODE=$([ "${RUN_PARALLEL}" = true ] && echo "Parallel Concurrent" || echo "Sequential Serial")|TIMESTAMP=${SCAN_TIMESTAMP}"
    for rec in "${RAW_RECORDS[@]}"; do
        echo "${rec}"
    done
} > "${LOG_DIR}/.last_run.dat"

# Exit code: 0 if at least one server checked and scan completed cleanly
exit 0
