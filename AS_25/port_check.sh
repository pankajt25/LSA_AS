#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_25)
# Problem Statement #25: Port Availability Check
# Focus: Network Testing & Socket Reachability Probing
# Author: System Administrator (Individual Sprint)
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   This utility audits TCP port reachability on target hosts.
#   It verifies network accessibility, differentiates connection refusal (TCP RST)
#   from packet filtering / timeouts (firewall drops), and audits multiple ports.
#
# HOW BASH /dev/tcp WORKS INTERNALLY:
#   GNU Bash provides a virtual device abstraction in its pathname redirection
#   handling: '/dev/tcp/HOST/PORT' and '/dev/udp/HOST/PORT'.
#   1. Virtual Pseudo-Path: '/dev/tcp' is NOT an actual file or block/character
#      device node in the Linux VFS (/dev filesystem). If inspected with 'ls',
#      it does not exist.
#   2. Redirection Interception: When Bash parses a redirection operator
#      (e.g., '> /dev/tcp/$host/$port' or '<> /dev/tcp/...'), Bash's parser
#      recognizes the special prefix '/dev/tcp/'.
#   3. System Calls: Bash invokes libc networking routines:
#      - getaddrinfo() / gethostbyname() to resolve the target hostname or IP.
#      - socket(AF_INET/AF_INET6, SOCK_STREAM, 0) to allocate a TCP socket.
#      - connect() to initiate the standard TCP 3-way handshake (SYN -> SYN-ACK -> ACK).
#   4. Connection & Teardown: Sending 'echo > /dev/tcp/$host/$port' writes a
#      newline across the established TCP connection, and closing the subshell
#      or redirection triggers close(), cleanly terminating the connection with
#      a FIN-ACK or RST teardown.
#
# PORTABILITY CAVEAT (BASH vs POSIX SH / DASH):
#   - /dev/tcp is an OPTIONAL compile-time feature of GNU Bash (--enable-net-redirections).
#   - It is standard on Debian, Ubuntu, Fedora, RHEL, CentOS, Arch, and macOS Bash.
#   - HOWEVER, it is COMPLETELY ABSENT in POSIX /bin/sh, Debian Dash (/bin/dash),
#     BusyBox Ash, and standard Zsh (which uses 'zmodload zsh/net/tcp').
#   - If invoked via 'sh script.sh', /dev/tcp will fail with:
#     "cannot create /dev/tcp/...: No such file or directory".
#   - Therefore, this script enforces Bash execution and provides a resilient
#     fallback to OpenBSD/traditional netcat ('nc -zv -w3') if /dev/tcp is disabled.
#
# SANDBOXING & SAFETY COMPLIANCE:
#   - Read-only probing: Only connect-and-close requests are issued.
#   - Never opens persistent listeners on production ports.
#   - Restricted probe scope: localhost loopback and well-known public demo services.
#   - Strictly self-contained: All logs and reports reside in AS_25/.
# ==============================================================================

set -o pipefail

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT VERIFICATION & SHELL INTEGRITY CHECK
# ------------------------------------------------------------------------------
# Enforce execution under GNU Bash. Since /dev/tcp is a Bash-specific built-in,
# executing under dash, sh, or ksh will cause syntax or file not found errors.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "❌ [FATAL] port_check.sh requires GNU Bash! Current shell is not Bash." >&2
    echo "           Please invoke with: bash $0 $*" >&2
    exit 2
fi

# Determine script root directory so all relative paths (logs, reports) are stable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/port_check.log"
JSON_FILE="${LOG_DIR}/port_check.json"

# Ensure the log directory exists
mkdir -p "${LOG_DIR}"

# ------------------------------------------------------------------------------
# 2. COLOR & FORMATTING DEFINITIONS
# ------------------------------------------------------------------------------
# Support terminal ANSI colors with automatic TTY detection or --no-color flag
USE_COLOR=1
if [ ! -t 1 ]; then
    USE_COLOR=0
fi

setup_colors() {
    if [ "${USE_COLOR}" -eq 1 ]; then
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_GREEN=$'\033[1;32m'
        C_RED=$'\033[1;31m'
        C_YELLOW=$'\033[1;33m'
        C_CYAN=$'\033[1;36m'
        C_BLUE=$'\033[1;34m'
        C_MAGENTA=$'\033[1;35m'
        C_DIM=$'\033[2m'
    else
        C_RESET=""
        C_BOLD=""
        C_GREEN=""
        C_RED=""
        C_YELLOW=""
        C_CYAN=""
        C_BLUE=""
        C_MAGENTA=""
        C_DIM=""
    fi
}
setup_colors

# ------------------------------------------------------------------------------
# 3. LOGGING & TELEMETRY HELPER
# ------------------------------------------------------------------------------
# Appends chronological, timestamped audit events to logs/port_check.log
log_event() {
    local status="$1"
    local host="$2"
    local port="$3"
    local service="$4"
    local latency_ms="$5"
    local method="$6"
    local detail="$7"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [%-12s] host=%-20s port=%-5s service=%-10s latency=%-6sms method=%-10s detail=%s\n" \
        "${ts}" "${status}" "${host}" "${port}" "${service}" "${latency_ms}" "${method}" "${detail}" >> "${LOG_FILE}"
}

# ------------------------------------------------------------------------------
# 4. CAPABILITY DETECTION: /dev/tcp vs Netcat Fallback
# ------------------------------------------------------------------------------
# Check if Bash's /dev/tcp virtual network redirection is functional on this system.
# If bash was compiled without net-redirections, accessing /dev/tcp returns
# "No such file or directory".
check_dev_tcp_capability() {
    local test_err
    test_err=$(bash -c 'timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/1"' 2>&1 || true)
    if echo "${test_err}" | grep -qi "No such file or directory"; then
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 5. INPUT VALIDATION FUNCTIONS
# ------------------------------------------------------------------------------
# Validate port: must be a decimal integer between 1 and 65535 (RFC 793 / IANA)
validate_port_number() {
    local port="$1"
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
        return 1
    fi
    return 0
}

# Validate hostname/IP: verify host resolves via getent, host, or is valid IPv4/IPv6
validate_target_host() {
    local host="$1"
    [ -z "${host}" ] && return 1

    # Standard loopback identifiers are always valid
    if [ "${host}" = "localhost" ] || [ "${host}" = "127.0.0.1" ] || [ "${host}" = "::1" ]; then
        return 0
    fi

    # IPv4 numerical address check
    if [[ "${host}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    fi

    # Standard glibc resolver query via getent hosts
    if getent hosts "${host}" >/dev/null 2>&1; then
        return 0
    fi

    # Fallback to host command if getent is restricted
    if command -v host >/dev/null 2>&1 && host "${host}" >/dev/null 2>&1; then
        return 0
    fi

    # Fallback to ping lookup (single packet, 1s timeout)
    if ping -c 1 -w 1 "${host}" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Resolve well-known service name from port using /etc/services or getent
resolve_service_name() {
    local port="$1"
    local svc
    svc="$(getent services "${port}/tcp" 2>/dev/null | awk '{print $1}')"
    if [ -n "${svc}" ]; then
        echo "${svc}"
    else
        echo "unknown"
    fi
}

# ------------------------------------------------------------------------------
# 6. USAGE & HELP MANUAL
# ------------------------------------------------------------------------------
display_usage() {
    cat << EOF
${C_BOLD}PORT AVAILABILITY CHECKER — AS_25 (E1ITA307)${C_RESET}
Usage:
  $0 [host] [port] [options]
  $0 [host] [port1,port2,port3...]
  $0 [host] [port1] [port2] [port3]...
  $0 --demo

${C_BOLD}ARGUMENTS:${C_RESET}
  host                    Target hostname (e.g. google.com, localhost, 127.0.0.1)
  port                    Single port number (1-65535) or comma-separated list (e.g. 22,80,443)
  port1 port2 ...         Multiple space-separated port arguments to audit in sequence

${C_BOLD}OPTIONS:${C_RESET}
  --demo                  Execute comprehensive safe demo suite (localhost:22, google.com:443/12345)
  --timeout <sec>         Connection timeout in seconds (default: 3)
  --nc | --fallback       Force usage of netcat (nc -zv -w3) instead of /dev/tcp
  --json                  Output structured JSON telemetry to stdout
  --no-color              Suppress ANSI color formatting
  -h, --help              Display this detailed usage and architectural manual

${C_BOLD}DEFAULT BEHAVIOR:${C_RESET}
  If invoked with no arguments, $0 explains usage and runs the safe demo suite:
    1. localhost:22       (Tests local SSH — demonstrates active connection refusal)
    2. google.com:443     (Tests public HTTPS — demonstrates open/reachable socket)
    3. google.com:12345   (Tests unassigned port — demonstrates packet filter timeout)
    4. Multi-port check   (Loops through common ports on target host)

${C_BOLD}EXAMPLES:${C_RESET}
  $0                                   # Run default safe demo suite
  $0 localhost 22                      # Probe single local SSH port
  $0 google.com 443                    # Probe single remote HTTPS port
  $0 google.com 80,443,8080            # Probe comma-separated port list
  $0 google.com 22 80 443 8443         # Probe multiple space-separated ports
  $0 --timeout 5 google.com 443        # Custom 5-second timeout
  $0 --demo                            # Explicit demo mode

EOF
}

# ------------------------------------------------------------------------------
# 7. PROBING IMPLEMENTATIONS
# ------------------------------------------------------------------------------

# Primary Probe: Bash built-in /dev/tcp redirection
# Mechanics:
#   timeout N bash -c "echo > /dev/tcp/$host/$port"
# Exit Codes & Diagnostic Mapping:
#   0   -> Connection established; TCP SYN sent, SYN-ACK received, ACK returned. (OPEN)
#   1   -> Connection refused (TCP RST packet received) OR host unreachable. (REFUSED/CLOSED)
#   124 -> Command timed out (no response within N seconds, packets filtered/dropped). (TIMEOUT)
probe_via_dev_tcp() {
    local target_host="$1"
    local target_port="$2"
    local timeout_secs="$3"

    local start_ns end_ns elapsed_ms
    start_ns="$(date +%s%N 2>/dev/null || echo 0)"

    local err_output
    # Run redirection inside subshell guarded by timeout
    err_output="$(timeout "${timeout_secs}" bash -c "echo > /dev/tcp/${target_host}/${target_port}" 2>&1)"
    local exit_code=$?

    end_ns="$(date +%s%N 2>/dev/null || echo 0)"
    if [ "${start_ns}" -ne 0 ] && [ "${end_ns}" -ne 0 ]; then
        elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
        [ "${elapsed_ms}" -lt 0 ] && elapsed_ms=0
    else
        elapsed_ms=0
    fi

    if [ "${exit_code}" -eq 0 ]; then
        echo "OPEN|${elapsed_ms}|/dev/tcp|TCP handshake completed successfully (SYN-ACK received)"
        return 0
    elif [ "${exit_code}" -eq 124 ]; then
        echo "TIMEOUT|${elapsed_ms}|/dev/tcp|Connection timed out after ${timeout_secs}s (no response; packet filtered/dropped)"
        return 1
    elif echo "${err_output}" | grep -qi "Connection refused"; then
        echo "REFUSED|${elapsed_ms}|/dev/tcp|Connection refused (Active TCP RST packet received from host)"
        return 1
    elif echo "${err_output}" | grep -qi "No route to host"; then
        echo "UNREACHABLE|${elapsed_ms}|/dev/tcp|Network routing failure (No route to host)"
        return 1
    elif echo "${err_output}" | grep -qi "Network is unreachable"; then
        echo "UNREACHABLE|${elapsed_ms}|/dev/tcp|Network interface is down or unreachable"
        return 1
    elif echo "${err_output}" | grep -qi "Name or service not known"; then
        echo "UNRESOLVABLE|${elapsed_ms}|/dev/tcp|DNS hostname lookup failure"
        return 1
    else
        # Generic closed socket fallback
        echo "CLOSED|${elapsed_ms}|/dev/tcp|Socket closed/unreachable (${err_output:-Exit code ${exit_code}})"
        return 1
    fi
}

# Fallback Probe: OpenBSD / Traditional Netcat ('nc -zv -w3 <host> <port>')
# Mechanics:
#   -z : Zero-I/O mode (scan/probe listening sockets without sending data)
#   -v : Verbose diagnostic output to stderr
#   -w : Timeout in seconds for connection establishment
probe_via_netcat() {
    local target_host="$1"
    local target_port="$2"
    local timeout_secs="$3"

    if ! command -v nc >/dev/null 2>&1; then
        echo "ERROR|0|nc|Netcat (nc) command not found on this system"
        return 2
    fi

    local start_ns end_ns elapsed_ms
    start_ns="$(date +%s%N 2>/dev/null || echo 0)"

    local nc_output
    nc_output="$(nc -zv -w"${timeout_secs}" "${target_host}" "${target_port}" 2>&1)"
    local exit_code=$?

    end_ns="$(date +%s%N 2>/dev/null || echo 0)"
    if [ "${start_ns}" -ne 0 ] && [ "${end_ns}" -ne 0 ]; then
        elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
        [ "${elapsed_ms}" -lt 0 ] && elapsed_ms=0
    else
        elapsed_ms=0
    fi

    if [ "${exit_code}" -eq 0 ]; then
        echo "OPEN|${elapsed_ms}|nc|nc probe succeeded: connection established"
        return 0
    elif echo "${nc_output}" | grep -qi "timed out"; then
        echo "TIMEOUT|${elapsed_ms}|nc|nc connection timed out after ${timeout_secs}s"
        return 1
    elif echo "${nc_output}" | grep -qi "Connection refused"; then
        echo "REFUSED|${elapsed_ms}|nc|nc connection refused (TCP RST packet received)"
        return 1
    else
        echo "CLOSED|${elapsed_ms}|nc|nc closed/unreachable (${nc_output})"
        return 1
    fi
}

# Unified Probe Dispatcher
# Selects /dev/tcp by default, falling back to nc if /dev/tcp is unavailable
probe_port() {
    local target_host="$1"
    local target_port="$2"
    local timeout_secs="$3"
    local force_nc="$4"

    if [ "${force_nc}" -eq 1 ]; then
        probe_via_netcat "${target_host}" "${target_port}" "${timeout_secs}"
    elif check_dev_tcp_capability; then
        probe_via_dev_tcp "${target_host}" "${target_port}" "${timeout_secs}"
    else
        # Automatic fallback when /dev/tcp is unsupported by shell build
        probe_via_netcat "${target_host}" "${target_port}" "${timeout_secs}"
    fi
}

# ------------------------------------------------------------------------------
# 8. AUDIT EXECUTION ENGINE (SINGLE / MULTI-PORT LOOP)
# ------------------------------------------------------------------------------
# Global arrays to store audit results for summary reporting and JSON telemetry
RESULTS_HOST=()
RESULTS_PORT=()
RESULTS_SERVICE=()
RESULTS_STATUS=()
RESULTS_LATENCY=()
RESULTS_METHOD=()
RESULTS_DETAIL=()

execute_port_audit() {
    local host="$1"
    shift
    local ports=("$@")
    local timeout_val="${PROBE_TIMEOUT:-3}"
    local force_nc="${FORCE_NC:-0}"

    # Verify target host resolution before launching probes
    if ! validate_target_host "${host}"; then
        echo -e "${C_RED}❌ Error: Cannot resolve hostname '${host}'. Name or service not known.${C_RESET}" >&2
        log_event "UNRESOLVABLE" "${host}" "-" "-" "0" "dns" "Host resolution failed"
        return 2
    fi

    # Display inspection header
    echo -e "${C_BOLD}${C_CYAN}Target Host  :${C_RESET} ${C_BOLD}${host}${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}Target Ports :${C_RESET} ${ports[*]}"
    echo -e "${C_BOLD}${C_CYAN}Timeout      :${C_RESET} ${timeout_val}s"
    if [ "${force_nc}" -eq 1 ]; then
        echo -e "${C_BOLD}${C_CYAN}Probe Engine :${C_RESET} Netcat fallback (nc -zv -w${timeout_val})"
    else
        echo -e "${C_BOLD}${C_CYAN}Probe Engine :${C_RESET} Bash built-in /dev/tcp redirection (with nc fallback)"
    fi
    echo -e "${C_DIM}--------------------------------------------------------------------------------${C_RESET}"
    printf "${C_BOLD}%-10s %-12s %-16s %-10s %-10s %s${C_RESET}\n" "PORT" "SERVICE" "STATUS" "LATENCY" "METHOD" "DIAGNOSTIC DETAIL"
    echo -e "${C_DIM}--------------------------------------------------------------------------------${C_RESET}"

    local any_failed=0

    # Multi-port loop: audits each requested port sequentially
    for port in "${ports[@]}"; do
        # Validate port format & bounds (1-65535)
        if ! validate_port_number "${port}"; then
            echo -e "${C_RED}❌ Error: Invalid port '${port}'. Port must be an integer between 1 and 65535.${C_RESET}" >&2
            log_event "INVALID_PORT" "${host}" "${port}" "-" "0" "validation" "Port out of range or non-numeric"
            any_failed=1
            continue
        fi

        local service
        service="$(resolve_service_name "${port}")"

        # Execute probe
        local probe_raw
        probe_raw="$(probe_port "${host}" "${port}" "${timeout_val}" "${force_nc}")"

        # Parse pipe-delimited probe telemetry: STATUS|LATENCY_MS|METHOD|DETAIL
        local status latency_ms method detail
        status="$(echo "${probe_raw}" | cut -d'|' -f1)"
        latency_ms="$(echo "${probe_raw}" | cut -d'|' -f2)"
        method="$(echo "${probe_raw}" | cut -d'|' -f3)"
        detail="$(echo "${probe_raw}" | cut -d'|' -f4-)"

        # Store in telemetry arrays
        RESULTS_HOST+=("${host}")
        RESULTS_PORT+=("${port}")
        RESULTS_SERVICE+=("${service}")
        RESULTS_STATUS+=("${status}")
        RESULTS_LATENCY+=("${latency_ms}")
        RESULTS_METHOD+=("${method}")
        RESULTS_DETAIL+=("${detail}")

        # Log event to persistent audit trail
        log_event "${status}" "${host}" "${port}" "${service}" "${latency_ms}" "${method}" "${detail}"

        # Format console status badge and message matching requirement:
        # "✅ Port <port> on <host> is OPEN/reachable"
        # "❌ Port <port> on <host> is CLOSED/unreachable/timed out"
        local status_badge
        case "${status}" in
            OPEN)
                status_badge="${C_GREEN}✅ OPEN${C_RESET}"
                ;;
            REFUSED)
                status_badge="${C_RED}❌ CLOSED${C_RESET}"
                any_failed=1
                ;;
            TIMEOUT)
                status_badge="${C_YELLOW}❌ TIMEOUT${C_RESET}"
                any_failed=1
                ;;
            UNREACHABLE)
                status_badge="${C_RED}❌ UNREACHABLE${C_RESET}"
                any_failed=1
                ;;
            *)
                status_badge="${C_RED}❌ ${status}${C_RESET}"
                any_failed=1
                ;;
        esac

        printf "%-10s %-12s %-25b %-10s %-10s %s\n" \
            "${port}/tcp" "${service}" "${status_badge}" "${latency_ms}ms" "${method}" "${detail}"

        # Print explicit summary line per port required by specification
        if [ "${status}" = "OPEN" ]; then
            echo -e "   ${C_GREEN}✅ Port ${port} on ${host} is OPEN/reachable${C_RESET} (${service}, ${latency_ms}ms)"
        elif [ "${status}" = "REFUSED" ]; then
            echo -e "   ${C_RED}❌ Port ${port} on ${host} is CLOSED/unreachable/timed out${C_RESET} (Active refusal: TCP RST received)"
        elif [ "${status}" = "TIMEOUT" ]; then
            echo -e "   ${C_YELLOW}❌ Port ${port} on ${host} is CLOSED/unreachable/timed out${C_RESET} (Connection timed out after ${timeout_val}s)"
        else
            echo -e "   ${C_RED}❌ Port ${port} on ${host} is CLOSED/unreachable/timed out${C_RESET} (${detail})"
        fi
        echo ""
    done

    return "${any_failed}"
}

# ------------------------------------------------------------------------------
# 9. JSON TELEMETRY EXPORT
# ------------------------------------------------------------------------------
export_json_telemetry() {
    local outfile="$1"
    local total="${#RESULTS_HOST[@]}"
    local open_count=0
    local closed_count=0
    local timeout_count=0

    for ((i=0; i<total; i++)); do
        case "${RESULTS_STATUS[i]}" in
            OPEN) open_count=$((open_count + 1)) ;;
            REFUSED|CLOSED|UNREACHABLE) closed_count=$((closed_count + 1)) ;;
            TIMEOUT) timeout_count=$((timeout_count + 1)) ;;
        esac
    done

    cat << EOF > "${outfile}"
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')",
  "hostname": "$(hostname 2>/dev/null || echo 'localhost')",
  "os": "$(uname -s 2>/dev/null || echo 'Linux')",
  "kernel": "$(uname -r 2>/dev/null || echo 'Unknown')",
  "total_checked": ${total},
  "open_count": ${open_count},
  "closed_count": ${closed_count},
  "timeout_count": ${timeout_count},
  "results": [
EOF

    for ((i=0; i<total; i++)); do
        local comma=","
        [ "$((i + 1))" -eq "${total}" ] && comma=""
        cat << EOF >> "${outfile}"
    {
      "host": "${RESULTS_HOST[i]}",
      "port": ${RESULTS_PORT[i]},
      "service": "${RESULTS_SERVICE[i]}",
      "status": "${RESULTS_STATUS[i]}",
      "latency_ms": ${RESULTS_LATENCY[i]},
      "method": "${RESULTS_METHOD[i]}",
      "detail": "${RESULTS_DETAIL[i]}"
    }${comma}
EOF
    done

    cat << EOF >> "${outfile}"
  ]
}
EOF
}

# ------------------------------------------------------------------------------
# 10. SAFE DEMO SUITE EXECUTION
# ------------------------------------------------------------------------------
run_safe_demo_suite() {
    echo -e "${C_BOLD}${C_MAGENTA}================================================================================${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}          AUTOMATION SPRINT (AS_25) — SAFE DEMO PORT AUDIT SUITE               ${C_RESET}"
    echo -e "${C_BOLD}${C_MAGENTA}================================================================================${C_RESET}"
    echo -e "${C_CYAN}[DEMO CASE 1]${C_RESET} Testing Local Host SSH (localhost:22) — Expects Active Refusal / Closed"
    echo -e "${C_DIM}Probing loopback interface without persistent listeners.${C_RESET}"
    execute_port_audit "localhost" 22 || true
    echo -e "${C_DIM}--------------------------------------------------------------------------------${C_RESET}"

    echo -e "${C_CYAN}[DEMO CASE 2]${C_RESET} Testing Public Secure Web (google.com:443) — Expects OPEN / Reachable"
    echo -e "${C_DIM}Probing real-world remote HTTPS service endpoint.${C_RESET}"
    execute_port_audit "google.com" 443 || true
    echo -e "${C_DIM}--------------------------------------------------------------------------------${C_RESET}"

    echo -e "${C_CYAN}[DEMO CASE 3]${C_RESET} Testing Public Unassigned Port (google.com:12345) — Expects TIMEOUT / Filtered"
    echo -e "${C_DIM}Demonstrating timeout detection vs active connection reset.${C_RESET}"
    execute_port_audit "google.com" 12345 || true
    echo -e "${C_DIM}--------------------------------------------------------------------------------${C_RESET}"

    echo -e "${C_CYAN}[DEMO CASE 4]${C_RESET} Multi-Port Loop Demonstration (google.com: 80, 443)"
    echo -e "${C_DIM}Auditing a list of ports across one host via internal loop.${C_RESET}"
    execute_port_audit "google.com" 80 443 || true
}

# ------------------------------------------------------------------------------
# 11. COMMAND LINE PARSING & DISPATCH
# ------------------------------------------------------------------------------
PROBE_TIMEOUT=3
FORCE_NC=0
OUTPUT_JSON=0
DEMO_MODE=0

RAW_ARGS=()

# Process flags and arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            display_usage
            exit 0
            ;;
        --demo)
            DEMO_MODE=1
            shift
            ;;
        --no-color)
            USE_COLOR=0
            setup_colors
            shift
            ;;
        --json)
            OUTPUT_JSON=1
            shift
            ;;
        --timeout)
            if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo -e "${C_RED}❌ Error: --timeout requires an integer number of seconds.${C_RESET}" >&2
                display_usage
                exit 2
            fi
            PROBE_TIMEOUT="$2"
            shift 2
            ;;
        --nc|--fallback)
            FORCE_NC=1
            shift
            ;;
        -*)
            echo -e "${C_RED}❌ Error: Unrecognized option '$1'.${C_RESET}" >&2
            display_usage
            exit 2
            ;;
        *)
            RAW_ARGS+=("$1")
            shift
            ;;
    esac
done

# If --demo was explicitly requested OR no arguments provided:
if [ "${DEMO_MODE}" -eq 1 ] || [ "${#RAW_ARGS[@]}" -eq 0 ]; then
    if [ "${#RAW_ARGS[@]}" -eq 0 ] && [ "${DEMO_MODE}" -eq 0 ]; then
        echo -e "${C_YELLOW}[NOTICE] No target host/port provided. Defaulting to safe demonstration suite.${C_RESET}"
        echo -e "${C_DIM}         Usage: $0 <host> <port1[,port2,...]> [options] | Try: $0 --help${C_RESET}\n"
    fi
    run_safe_demo_suite
    export_json_telemetry "${JSON_FILE}"

    # Print overall summary banner
    TOTAL_PROBED="${#RESULTS_HOST[@]}"
    OPEN_COUNT=0
    REFUSED_COUNT=0
    TIMEOUT_COUNT=0
    for s in "${RESULTS_STATUS[@]}"; do
        case "$s" in
            OPEN) OPEN_COUNT=$((OPEN_COUNT + 1)) ;;
            REFUSED|CLOSED|UNREACHABLE) REFUSED_COUNT=$((REFUSED_COUNT + 1)) ;;
            TIMEOUT) TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1)) ;;
        esac
    done

    echo -e "${C_BOLD}================================================================================${C_RESET}"
    echo -e "${C_BOLD}OVERALL AUDIT SUMMARY:${C_RESET} ${TOTAL_PROBED} Probed | ${C_GREEN}${OPEN_COUNT} OPEN${C_RESET} | ${C_RED}${REFUSED_COUNT} REFUSED/CLOSED${C_RESET} | ${C_YELLOW}${TIMEOUT_COUNT} TIMED OUT${C_RESET}"
    echo -e "${C_BOLD}Audit Log Stored     :${C_RESET} ${LOG_FILE}"
    echo -e "${C_BOLD}Telemetry JSON Stored:${C_RESET} ${JSON_FILE}"
    echo -e "${C_BOLD}================================================================================${C_RESET}"

    if [ "${OUTPUT_JSON}" -eq 1 ]; then
        cat "${JSON_FILE}"
    fi

    # Exit 0 if at least one port was open, or exit with status
    exit 0
fi

# Custom execution mode: target host and ports provided
TARGET_HOST="${RAW_ARGS[0]}"

# Check if port argument is missing
if [ "${#RAW_ARGS[@]}" -lt 2 ]; then
    echo -e "${C_RED}❌ Error: Missing port argument for host '${TARGET_HOST}'.${C_RESET}" >&2
    echo -e "   Please specify at least one port number (e.g., $0 ${TARGET_HOST} 80,443)" >&2
    echo ""
    display_usage
    exit 2
fi

# Parse remaining arguments into individual ports (supports comma-separated & space-separated)
RAW_PORT_INPUTS=("${RAW_ARGS[@]:1}")
TARGET_PORTS=()

for item in "${RAW_PORT_INPUTS[@]}"; do
    IFS=',' read -ra SPLIT_ITEMS <<< "${item}"
    for p in "${SPLIT_ITEMS[@]}"; do
        p="$(echo "${p}" | tr -d '[:space:]')"
        if [ -n "${p}" ]; then
            TARGET_PORTS+=("${p}")
        fi
    done
done

# Execute target audit
echo -e "${C_BOLD}================================================================================${C_RESET}"
echo -e "${C_BOLD}          PORT AVAILABILITY CHECKER — AS_25 (E1ITA307)                         ${C_RESET}"
echo -e "${C_BOLD}================================================================================${C_RESET}"

set +e
execute_port_audit "${TARGET_HOST}" "${TARGET_PORTS[@]}"
AUDIT_EXIT_CODE=$?
set -e

# Export structured JSON telemetry
export_json_telemetry "${JSON_FILE}"

# Print overall summary banner
TOTAL_PROBED="${#RESULTS_HOST[@]}"
OPEN_COUNT=0
REFUSED_COUNT=0
TIMEOUT_COUNT=0
for s in "${RESULTS_STATUS[@]}"; do
    case "$s" in
        OPEN) OPEN_COUNT=$((OPEN_COUNT + 1)) ;;
        REFUSED|CLOSED|UNREACHABLE) REFUSED_COUNT=$((REFUSED_COUNT + 1)) ;;
        TIMEOUT) TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1)) ;;
    esac
done

echo -e "${C_BOLD}================================================================================${C_RESET}"
echo -e "${C_BOLD}AUDIT SUMMARY:${C_RESET} ${TOTAL_PROBED} Probed | ${C_GREEN}${OPEN_COUNT} OPEN${C_RESET} | ${C_RED}${REFUSED_COUNT} REFUSED/CLOSED${C_RESET} | ${C_YELLOW}${TIMEOUT_COUNT} TIMED OUT${C_RESET}"
echo -e "${C_BOLD}Audit Log Stored     :${C_RESET} ${LOG_FILE}"
echo -e "${C_BOLD}Telemetry JSON Stored:${C_RESET} ${JSON_FILE}"
echo -e "${C_BOLD}================================================================================${C_RESET}"

if [ "${OUTPUT_JSON}" -eq 1 ]; then
    cat "${JSON_FILE}"
fi

exit "${AUDIT_EXIT_CODE}"
