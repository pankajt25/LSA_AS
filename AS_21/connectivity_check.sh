#!/usr/bin/env bash
# ==============================================================================
# Course: Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #21: Network Connectivity Check
# Focus: Network Monitoring & Gateway Reachability Verification
# Script: connectivity_check.sh
#
# ROLE & PURPOSE:
#   A production-grade, self-contained Bash monitoring utility designed to
#   periodically verify network reachability to the default gateway (or a custom
#   target host) and compare it against a well-known public sanity baseline (e.g. 8.8.8.8).
#
# KEY FEATURES:
#   1. Accepts a target as $1, automatically detecting the real default gateway if omitted:
#      - Linux: ip route | grep default | awk '{print $3}'
#      - macOS fallback: route -n get default | awk '/gateway:/ {print $2}'
#      - Windows fallback: netstat -rn / PowerShell route table
#   2. Probes a secondary public baseline host (8.8.8.8) to distinguish:
#      - Full connectivity (Gateway OK, Baseline OK)
#      - Local-only network (Gateway OK, Baseline Down)
#      - ICMP-filtered Gateway (Gateway drops ICMP, Baseline OK)
#      - Total network outage (Gateway Down, Baseline Down)
#   3. Uses bounded pings (-c 4 on Linux/macOS, -n 4 on Windows) to prevent hanging.
#   4. Robust grep/awk parser extracting loss %, avg RTT, transmitted/received packets.
#   5. Clear status reporting: e.g. "✅ Gateway 192.168.x.x is REACHABLE (0% loss, avg 2.1ms)"
#   6. Timestamped chronological logging to logs/connectivity.log.
#   7. Graceful error handling for missing tools, invalid targets, or missing routes.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Default Configuration
# ------------------------------------------------------------------------------
DEFAULT_BASELINE="8.8.8.8"     # Google Public DNS (reliable public sanity baseline)
ALT_BASELINE="1.1.1.1"         # Cloudflare DNS (used if primary target is 8.8.8.8)
DEFAULT_PING_COUNT=4           # Number of ICMP echo requests per probe
DEFAULT_TIMEOUT=2              # Timeout per probe in seconds (Linux -W 2)
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/connectivity.log"

# Color Codes for Terminal Output (disabled if stdout is not a TTY)
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_GREEN="\033[32m"
    C_RED="\033[31m"
    C_YELLOW="\033[33m"
    C_CYAN="\033[36m"
    C_BLUE="\033[34m"
else
    C_RESET=""
    C_BOLD=""
    C_GREEN=""
    C_RED=""
    C_YELLOW=""
    C_CYAN=""
    C_BLUE=""
fi

# ------------------------------------------------------------------------------
# Function: display_usage
# Explains command-line usage, options, and cross-platform notes.
# ------------------------------------------------------------------------------
display_usage() {
    cat <<EOF
Usage: $0 [TARGET] [OPTIONS]

Network Connectivity Check — Automated Gateway & Baseline Probing Utility

ARGUMENTS:
  TARGET                  IP address or hostname to probe. If omitted, automatically
                          defaults to this machine's real default gateway.

OPTIONS:
  -t, --target <host>     Specify target explicitly (alternative to positional \$1)
  -b, --baseline <host>   Specify sanity baseline host (default: ${DEFAULT_BASELINE})
  -c, --count <num>       Number of ping packets to transmit (default: ${DEFAULT_PING_COUNT})
  -l, --log <file>        Path to audit log file (default: ${LOG_FILE})
  -h, --help              Display this manual and exit

CROSS-PLATFORM GATEWAY DETECTION NOTES:
  Linux:                  ip route | grep default | awk '{print \$3}'
  macOS:                  route -n get default | awk '/gateway:/ {print \$2}'
  Windows (PowerShell):   (Get-NetRoute -DestinationPrefix '0.0.0.0/0').NextHop
  Windows (CMD/Netstat):  netstat -rn | findstr "0.0.0.0"

CROSS-PLATFORM PING SYNTAX:
  Linux / macOS:          ping -c 4 <host>  (optionally -W <seconds> on Linux)
  Windows Native:         ping -n 4 <host>

EXAMPLES:
  $0                      # Automatically detects and tests real default gateway + 8.8.8.8
  $0 1.1.1.1              # Tests custom target 1.1.1.1 + baseline 8.8.8.8
  $0 -c 2 -b 1.0.0.1      # Sends 2 pings, uses 1.0.0.1 as sanity baseline
  $0 --help               # Shows this documentation
EOF
}

# ------------------------------------------------------------------------------
# Function: detect_default_gateway
# Identifies the active default gateway across different operating systems.
# Returns gateway IP or empty string on failure.
# ------------------------------------------------------------------------------
detect_default_gateway() {
    local gw=""
    local os_type
    os_type="$(uname -s 2>/dev/null || echo "Unknown")"

    case "${os_type}" in
        Darwin*)
            # macOS route table parsing
            if command -v route >/dev/null 2>&1; then
                gw="$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}' || true)"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows Git Bash / Cygwin route table
            if command -v netstat >/dev/null 2>&1; then
                gw="$(netstat -rn 2>/dev/null | awk '$1 == "0.0.0.0" {print $3; exit}' || true)"
            fi
            if [ -z "${gw}" ] && command -v powershell.exe >/dev/null 2>&1; then
                gw="$(powershell.exe -NoProfile -Command "(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1" 2>/dev/null | tr -d '\r\n' || true)"
            fi
            ;;
        Linux*|*)
            # Primary Linux detection using iproute2
            if command -v ip >/dev/null 2>&1; then
                gw="$(ip route 2>/dev/null | grep -E '^default ' | awk '{print $3}' | head -n 1 || true)"
            fi
            # Fallback to route command if iproute2 is absent
            if [ -z "${gw}" ] && command -v route >/dev/null 2>&1; then
                gw="$(route -n 2>/dev/null | awk '/^0.0.0.0/ {print $2; exit}' || true)"
            fi
            # Fallback to netstat if ip and route are absent
            if [ -z "${gw}" ] && command -v netstat >/dev/null 2>&1; then
                gw="$(netstat -rn 2>/dev/null | awk '$1 == "0.0.0.0" {print $2; exit}' || true)"
            fi
            ;;
    esac

    echo "${gw}"
}

# ------------------------------------------------------------------------------
# Function: probe_target
# Sends a bounded ping to a given host, extracts performance metrics with
# grep/awk, and formats human-readable status and structured output.
#
# Arguments:
#   $1: Target IP or Hostname
#   $2: Target Role Description ("Gateway" or "Baseline Host" or "Target")
#   $3: Packet Count (e.g. 4)
#   $4: Timeout in seconds
#
# Output format (pipe-delimited string sent to stdout):
#   STATUS|LOSS_PCT|AVG_RTT|TRANSMITTED|RECEIVED|MIN_RTT|MAX_RTT|STATUS_MSG|RAW_SUMMARY
# ------------------------------------------------------------------------------
probe_target() {
    local target="$1"
    local role="$2"
    local count="$3"
    local timeout="$4"

    local raw_output=""
    local ping_exit_code=0
    local os_type
    os_type="$(uname -s 2>/dev/null || echo "Unknown")"

    # Step 1: Execute bounded ping based on platform capabilities
    # We deliberately capture exit code without tripping set -e
    if [[ "${os_type}" =~ MINGW|MSYS|CYGWIN ]] && ! ping -c 1 127.0.0.1 >/dev/null 2>&1; then
        # Native Windows ping uses -n <count> and -w <timeout_ms>
        local win_timeout_ms=$((timeout * 1000))
        raw_output="$(ping -n "${count}" -w "${win_timeout_ms}" "${target}" 2>&1)" || ping_exit_code=$?
    elif [[ "${os_type}" == "Darwin" ]]; then
        # macOS BSD ping uses -c <count> and -t <timeout_seconds>
        raw_output="$(ping -c "${count}" -t "${timeout}" "${target}" 2>&1)" || ping_exit_code=$?
    else
        # Linux standard iputils ping: -c <count> and -W <timeout_seconds>
        # -W guarantees we do not hang on unresponsive targets
        raw_output="$(ping -c "${count}" -W "${timeout}" "${target}" 2>&1)" || ping_exit_code=$?
    fi

    # Step 2: Check for name resolution / DNS failures or invalid destination
    if echo "${raw_output}" | grep -qiE "unknown host|Name or service not known|could not find host|ping: cannot resolve|No address associated"; then
        local err_msg="❌ ${role} ${target} is UNREACHABLE (DNS resolution failure or invalid target)"
        echo "ERROR|100%|N/A|0|0|N/A|N/A|${err_msg}|${raw_output}"
        return
    fi

    # Step 3: Extract packets transmitted and received
    local transmitted
    local received
    transmitted="$(echo "${raw_output}" | grep -oE '[0-9]+ packets transmitted' | awk '{print $1}' || echo "0")"
    received="$(echo "${raw_output}" | grep -oE '[0-9]+ (packets )?received' | awk '{print $1}' || echo "0")"

    # Fallback for Windows ping output format ("Packets: Sent = 4, Received = 4, Lost = 0")
    if [ -z "${transmitted}" ] || [ "${transmitted}" = "0" ]; then
        transmitted="$(echo "${raw_output}" | grep -iE 'Sent = [0-9]+' | grep -oE 'Sent = [0-9]+' | awk '{print $3}' || echo "${count}")"
    fi
    if [ -z "${received}" ]; then
        received="$(echo "${raw_output}" | grep -iE 'Received = [0-9]+' | grep -oE 'Received = [0-9]+' | awk '{print $3}' || echo "0")"
    fi

    # Step 4: Extract Packet Loss Percentage
    local loss_pct
    loss_pct="$(echo "${raw_output}" | grep -oE '[0-9]+(\.[0-9]+)?% packet loss' | awk '{print $1}' || echo "")"
    if [ -z "${loss_pct}" ]; then
        loss_pct="$(echo "${raw_output}" | grep -oE '\([0-9]+% loss\)' | tr -d '()' || echo "")"
    fi
    if [ -z "${loss_pct}" ]; then
        if [ "${received}" -eq 0 ] 2>/dev/null; then
            loss_pct="100%"
        elif [ "${received}" -eq "${transmitted}" ] 2>/dev/null; then
            loss_pct="0%"
        else
            loss_pct="Unknown"
        fi
    fi

    # Step 5: Extract Round-Trip Times (Min, Avg, Max)
    local min_rtt="N/A"
    local avg_rtt="N/A"
    local max_rtt="N/A"

    if echo "${raw_output}" | grep -qE "rtt|round-trip"; then
        # Format: rtt min/avg/max/mdev = 29.097/34.319/44.426/6.047 ms
        local stats_line
        stats_line="$(echo "${raw_output}" | grep -E "rtt|round-trip" | head -n 1)"
        local rtt_values
        rtt_values="$(echo "${stats_line}" | awk -F'=' '{print $2}')"
        min_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')"
        avg_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')"
        max_rtt="$(echo "${rtt_values}" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')"

        [ -n "${min_rtt}" ] && min_rtt="${min_rtt}ms" || min_rtt="N/A"
        [ -n "${avg_rtt}" ] && avg_rtt="${avg_rtt}ms" || avg_rtt="N/A"
        [ -n "${max_rtt}" ] && max_rtt="${max_rtt}ms" || max_rtt="N/A"
    elif echo "${raw_output}" | grep -qi "Average ="; then
        # Windows ping summary format: Minimum = 2ms, Maximum = 5ms, Average = 3ms
        avg_rtt="$(echo "${raw_output}" | grep -i "Average =" | sed 's/.*Average = //' | awk '{print $1}' || echo "N/A")"
        min_rtt="$(echo "${raw_output}" | grep -i "Minimum =" | sed 's/.*Minimum = //' | awk -F',' '{print $1}' || echo "N/A")"
        max_rtt="$(echo "${raw_output}" | grep -i "Maximum =" | sed 's/.*Maximum = //' | awk -F',' '{print $1}' || echo "N/A")"
    fi

    # Step 6: Formulate reachability state and human-readable message
    local status="UNREACHABLE"
    local status_msg=""

    if [ -n "${received}" ] && [ "${received}" -gt 0 ] 2>/dev/null && [ "${loss_pct}" != "100%" ]; then
        status="REACHABLE"
        status_msg="✅ ${role} ${target} is REACHABLE (${loss_pct} loss, avg ${avg_rtt})"
    else
        status="UNREACHABLE"
        status_msg="❌ ${role} ${target} is UNREACHABLE (${loss_pct} loss)"
    fi

    # Single-line summary extracted from ping statistics
    local raw_summary
    raw_summary="$(echo "${raw_output}" | grep -E 'transmitted|packets' | tail -n 1 | sed 's/^[ \t]*//' || echo "Ping completed")"

    # Return pipe-separated metrics
    echo "${status}|${loss_pct}|${avg_rtt}|${transmitted}|${received}|${min_rtt}|${max_rtt}|${status_msg}|${raw_summary}"
}

# ------------------------------------------------------------------------------
# Parse Command-Line Arguments
# ------------------------------------------------------------------------------
CLI_TARGET=""
CLI_BASELINE="${DEFAULT_BASELINE}"
CLI_COUNT="${DEFAULT_PING_COUNT}"
CLI_LOG="${LOG_FILE}"

# Support positional $1 if provided and not an option flag
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
    CLI_TARGET="$1"
    shift
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target)
            if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a target IP or hostname.${C_RESET}" >&2
                exit 2
            fi
            CLI_TARGET="$2"
            shift 2
            ;;
        -b|--baseline)
            if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a baseline host address.${C_RESET}" >&2
                exit 2
            fi
            CLI_BASELINE="$2"
            shift 2
            ;;
        -c|--count)
            if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a positive integer packet count.${C_RESET}" >&2
                exit 2
            fi
            CLI_COUNT="$2"
            shift 2
            ;;
        -l|--log)
            if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
                echo -e "${C_RED}[ERROR] Option $1 requires a log file path.${C_RESET}" >&2
                exit 2
            fi
            CLI_LOG="$2"
            shift 2
            ;;
        -h|--help)
            display_usage
            exit 0
            ;;
        *)
            echo -e "${C_RED}[ERROR] Unrecognized option: $1${C_RESET}" >&2
            display_usage >&2
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Step 1: Pre-flight Verification (Environment & Tooling)
# ------------------------------------------------------------------------------
if ! command -v ping >/dev/null 2>&1; then
    echo -e "${C_RED}[ERROR] The 'ping' command is not available on this system.${C_RESET}" >&2
    echo "Please install iputils-ping (Debian/Ubuntu) or iputils (RHEL/Fedora)." >&2
    exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "${CLI_LOG}")"

# ------------------------------------------------------------------------------
# Step 2: Target Determination & Gateway Auto-Detection
# ------------------------------------------------------------------------------
TARGET_ROLE="Target Host"
DETECTED_GATEWAY=""

if [ -z "${CLI_TARGET}" ]; then
    DETECTED_GATEWAY="$(detect_default_gateway)"
    if [ -n "${DETECTED_GATEWAY}" ]; then
        CLI_TARGET="${DETECTED_GATEWAY}"
        TARGET_ROLE="Gateway"
    else
        echo -e "${C_YELLOW}[WARNING] Unable to automatically detect the default gateway.${C_RESET}" >&2
        echo -e "${C_YELLOW}[WARNING] Falling back to default probe target 127.0.0.1 (Localhost).${C_RESET}" >&2
        CLI_TARGET="127.0.0.1"
        TARGET_ROLE="Localhost (Fallback)"
    fi
else
    # Check if the user-supplied target matches the default gateway
    DETECTED_GATEWAY="$(detect_default_gateway)"
    if [ -n "${DETECTED_GATEWAY}" ] && [ "${CLI_TARGET}" = "${DETECTED_GATEWAY}" ]; then
        TARGET_ROLE="Gateway"
    fi
fi

# If target is identical to baseline host, switch baseline to alternate
if [ "${CLI_TARGET}" = "${CLI_BASELINE}" ]; then
    CLI_BASELINE="${ALT_BASELINE}"
fi

# ------------------------------------------------------------------------------
# Step 3: Execute Probes on Target and Sanity Baseline
# ------------------------------------------------------------------------------
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
HOST_NAME="$(hostname 2>/dev/null || uname -n)"
OS_NAME="$(uname -s 2>/dev/null || echo "Linux")"
KERNEL_VER="$(uname -r 2>/dev/null || echo "Unknown")"
USER_NAME="$(whoami 2>/dev/null || echo "User")"

echo -e "${C_BOLD}================================================================================${C_RESET}"
echo -e "${C_BOLD}     NETWORK CONNECTIVITY CHECK — AUTOMATION SPRINT (AS_21)                    ${C_RESET}"
echo -e "${C_BOLD}================================================================================${C_RESET}"
echo -e "Timestamp : ${TIMESTAMP} | Host: ${HOST_NAME} | OS: ${OS_NAME} (${KERNEL_VER})"
echo -e "User      : ${USER_NAME}"
echo -e "Target    : ${CLI_TARGET} (${TARGET_ROLE})"
echo -e "Baseline  : ${CLI_BASELINE} (Sanity Host / Public Internet Reference)"
echo -e "Pings     : ${CLI_COUNT} packets per target (Timeout: ${DEFAULT_TIMEOUT}s)"
echo -e "--------------------------------------------------------------------------------"
echo -e "${C_CYAN}[1/2] Probing ${TARGET_ROLE}: ${CLI_TARGET}...${C_RESET}"

TARGET_RESULT="$(probe_target "${CLI_TARGET}" "${TARGET_ROLE}" "${CLI_COUNT}" "${DEFAULT_TIMEOUT}")"
IFS='|' read -r T_STATUS T_LOSS T_AVG_RTT T_TX T_RX T_MIN_RTT T_MAX_RTT T_MSG T_RAW <<< "${TARGET_RESULT}"

echo -e "${C_CYAN}[2/2] Probing Sanity Baseline Host: ${CLI_BASELINE}...${C_RESET}"

BASELINE_RESULT="$(probe_target "${CLI_BASELINE}" "Baseline Host" "${CLI_COUNT}" "${DEFAULT_TIMEOUT}")"
IFS='|' read -r B_STATUS B_LOSS B_AVG_RTT B_TX B_RX B_MIN_RTT B_MAX_RTT B_MSG B_RAW <<< "${BASELINE_RESULT}"

echo -e "--------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# Step 4: Display Status Messages (Requirement #5)
# ------------------------------------------------------------------------------
echo -e "${C_BOLD}PROBE RESULTS:${C_RESET}"

if [ "${T_STATUS}" = "REACHABLE" ]; then
    echo -e "  ${C_GREEN}${T_MSG}${C_RESET}"
else
    echo -e "  ${C_RED}${T_MSG}${C_RESET}"
fi

if [ "${B_STATUS}" = "REACHABLE" ]; then
    echo -e "  ${C_GREEN}${B_MSG}${C_RESET}"
else
    echo -e "  ${C_RED}${B_MSG}${C_RESET}"
fi

echo -e "--------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# Step 5: Triangulation & Diagnostic Analysis
# ------------------------------------------------------------------------------
DIAGNOSIS_CODE=""
DIAGNOSIS_TITLE=""
DIAGNOSIS_DETAIL=""

if [ "${T_STATUS}" = "REACHABLE" ] && [ "${B_STATUS}" = "REACHABLE" ]; then
    DIAGNOSIS_CODE="FULL_CONNECTIVITY"
    DIAGNOSIS_TITLE="✅ All Systems Operational: Full Local & Internet Connectivity"
    DIAGNOSIS_DETAIL="Both the ${TARGET_ROLE} (${CLI_TARGET}) and the public baseline (${CLI_BASELINE}) are responsive. Packets flow freely through both local and WAN network paths."
elif [ "${T_STATUS}" = "REACHABLE" ] && [ "${B_STATUS}" != "REACHABLE" ]; then
    DIAGNOSIS_CODE="LOCAL_ONLY"
    DIAGNOSIS_TITLE="⚠️ Local Network Only: Gateway Reachable, Public Internet Down"
    DIAGNOSIS_DETAIL="The ${TARGET_ROLE} (${CLI_TARGET}) is reachable, but the external reference (${CLI_BASELINE}) failed to respond. This suggests a local ISP outage, external uplink failure, or upstream DNS/firewall block."
elif [ "${T_STATUS}" = "ERROR" ] && [ "${B_STATUS}" = "REACHABLE" ]; then
    DIAGNOSIS_CODE="DNS_ERROR"
    DIAGNOSIS_TITLE="🔍 Hostname Resolution Failure: DNS Lookup Failed"
    DIAGNOSIS_DETAIL="The public baseline (${CLI_BASELINE}) responded normally, confirming network access. However, ${TARGET_ROLE} (${CLI_TARGET}) could not be resolved by DNS nameservers. Check DNS configuration in /etc/resolv.conf or verify domain name spelling."
elif [ "${T_STATUS}" != "REACHABLE" ] && [ "${B_STATUS}" = "REACHABLE" ]; then
    DIAGNOSIS_CODE="ICMP_FILTERED"
    DIAGNOSIS_TITLE="🌐 Internet Accessible: Gateway Unreachable / ICMP Echo Filtered"
    DIAGNOSIS_DETAIL="The public baseline (${CLI_BASELINE}) responded normally, confirming WAN routing is active. However, ${TARGET_ROLE} (${CLI_TARGET}) dropped ICMP packets. In virtualized environments (such as WSL2 virtual switch) or enterprise firewalls, host routers routinely block ICMP echo requests while continuing to route forwarded traffic."
else
    DIAGNOSIS_CODE="TOTAL_OUTAGE"
    DIAGNOSIS_TITLE="❌ Complete Network Outage: Neither Target nor Baseline Reachable"
    DIAGNOSIS_DETAIL="Both ${TARGET_ROLE} (${CLI_TARGET}) and public baseline (${CLI_BASELINE}) are completely unreachable. Check physical cable/Wi-Fi connection, network interface state (ip link), or local DHCP/IP configuration."
fi

echo -e "${C_BOLD}DIAGNOSTIC ASSESSMENT:${C_RESET}"
echo -e "  ${DIAGNOSIS_TITLE}"
echo -e "  ${DIAGNOSIS_DETAIL}"
echo -e "================================================================================"

# ------------------------------------------------------------------------------
# Step 6: Audit Logging to logs/connectivity.log (Requirement #6)
# ------------------------------------------------------------------------------
{
    echo "================================================================================"
    echo "[${TIMESTAMP}] NETWORK CONNECTIVITY AUDIT CHECK"
    echo "Host: ${HOST_NAME} | OS: ${OS_NAME} | Kernel: ${KERNEL_VER} | User: ${USER_NAME}"
    echo "Scan Configuration: Count=${CLI_COUNT} packets | Timeout=${DEFAULT_TIMEOUT}s"
    echo "--------------------------------------------------------------------------------"
    echo "PROBE 1: ${TARGET_ROLE} (${CLI_TARGET})"
    echo "  Status        : ${T_STATUS}"
    echo "  Packets       : Transmitted = ${T_TX}, Received = ${T_RX}, Packet Loss = ${T_LOSS}"
    echo "  Round-Trip    : Min = ${T_MIN_RTT}, Avg = ${T_AVG_RTT}, Max = ${T_MAX_RTT}"
    echo "  Summary Line  : ${T_MSG}"
    echo "--------------------------------------------------------------------------------"
    echo "PROBE 2: Sanity Baseline (${CLI_BASELINE})"
    echo "  Status        : ${B_STATUS}"
    echo "  Packets       : Transmitted = ${B_TX}, Received = ${B_RX}, Packet Loss = ${B_LOSS}"
    echo "  Round-Trip    : Min = ${B_MIN_RTT}, Avg = ${B_AVG_RTT}, Max = ${B_MAX_RTT}"
    echo "  Summary Line  : ${B_MSG}"
    echo "--------------------------------------------------------------------------------"
    echo "DIAGNOSIS: [${DIAGNOSIS_CODE}]"
    echo "  ${DIAGNOSIS_TITLE}"
    echo "  ${DIAGNOSIS_DETAIL}"
    echo "================================================================================"
    echo ""
} >> "${CLI_LOG}"

echo -e "Audit log appended to: ${C_BLUE}${CLI_LOG}${C_RESET}"
exit 0
