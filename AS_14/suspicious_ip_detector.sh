#!/usr/bin/env bash
# ==============================================================================
# Script Name: suspicious_ip_detector.sh
# Course:      Linux System Administration (E1ITA307) - Automation Sprint
# Problem:     #14 - Suspicious IP Detection (Security Monitoring)
# Author:      Linux System Administrator
# ==============================================================================
#
# HOW TO RUN / USAGE GUIDE:
# -------------------------
# Syntax:
#   ./suspicious_ip_detector.sh [LOG_FILE] [THRESHOLD]
#   ./suspicious_ip_detector.sh -h | --help
#
# Arguments:
#   LOG_FILE   (Optional) Path to the SSH authentication log file to analyze.
#              Defaults to auto-detecting real system logs:
#                1. /var/log/auth.log
#                2. /var/log/secure
#                3. journalctl -u ssh / journalctl _COMM=sshd
#              Fallback: synthetic test log (test_auth.log) clearly labeled.
#   THRESHOLD  (Optional) Integer threshold of failed attempts required to
#              flag an IP as suspicious.
#              Defaults to: 5
#
# Examples:
#   1. Run with auto-detected real system log and default threshold (5):
#      ./suspicious_ip_detector.sh
#
#   2. Run with auto-detected real log and custom threshold (e.g. 3 attempts):
#      ./suspicious_ip_detector.sh 3
#
#   3. Run with custom log file override and custom threshold:
#      ./suspicious_ip_detector.sh ./test_auth.log 3
#
#   4. Display help information:
#      ./suspicious_ip_detector.sh --help
#
# Outputs:
#   - Terminal: Formatted summary table of suspicious IPs with timestamps.
#   - Report File: Timestamped log saved to ./reports/
# ==============================================================================

# Exit immediately if a pipeline command returns a non-zero status,
# treat unset variables as an error, and ensure pipe failures propagate.
set -euo pipefail

# ------------------------------------------------------------------------------
# CONSTANTS AND DEFAULT CONFIGURATION
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SYNTHETIC_LOG="${SCRIPT_DIR}/test_auth.log"
readonly DEFAULT_THRESHOLD=5
readonly REPORT_DIR="${SCRIPT_DIR}/reports"

# Generate ISO-style timestamp for report file naming
REPORT_TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
readonly REPORT_FILE="${REPORT_DIR}/suspicious_ip_report_${REPORT_TIMESTAMP}.log"

# Terminal ANSI color codes for enhanced readability (only enabled for TTY)
if [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[1;31m"
    COLOR_GREEN="\033[1;32m"
    COLOR_YELLOW="\033[1;33m"
    COLOR_BLUE="\033[1;34m"
    COLOR_CYAN="\033[1;36m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
    COLOR_BOLD=""
fi

# ------------------------------------------------------------------------------
# FUNCTION: display_usage
# Description: Prints helpful usage information and command line syntax.
# ------------------------------------------------------------------------------
display_usage() {
    cat << EOF
Usage: $(basename "$0") [LOG_FILE] [THRESHOLD]
       $(basename "$0") [THRESHOLD]

Automated SSH Log Security Monitor - Suspicious IP Detection

Arguments:
  LOG_FILE     Path to SSH auth log (auto-detected if omitted:
                 1. /var/log/auth.log
                 2. /var/log/secure
                 3. journalctl -u ssh / journalctl _COMM=sshd
                 Fallback: ${SYNTHETIC_LOG} [synthetic demonstration data])
  THRESHOLD    Minimum failed attempts to flag as suspicious (default: ${DEFAULT_THRESHOLD})

Options:
  -h, --help   Show this help message and exit

Examples:
  $(basename "$0")                          # Auto-detects real auth log and uses threshold ${DEFAULT_THRESHOLD}
  $(basename "$0") 3                        # Auto-detects real auth log with custom threshold 3
  $(basename "$0") /var/log/auth.log 5      # Explicit real log override with threshold 5
  $(basename "$0") ${SYNTHETIC_LOG} 5       # Run against synthetic test log

EOF
}

# ------------------------------------------------------------------------------
# FUNCTION: detect_auth_log_source
# Description: Auto-detects the first accessible real SSH auth log source in order:
#              1. /var/log/auth.log (Debian/Ubuntu)
#              2. /var/log/secure (RHEL/CentOS/Rocky/Fedora)
#              3. journalctl -u ssh / journalctl _COMM=sshd (systemd journal)
#              Fallback: synthetic test_auth.log with clear notification
# ------------------------------------------------------------------------------
detect_auth_log_source() {
    # 1. Standard Debian/Ubuntu auth log
    if [[ -f "/var/log/auth.log" && -r "/var/log/auth.log" ]]; then
        echo "/var/log/auth.log"
        return 0
    fi

    # 2. Standard RHEL/CentOS secure log
    if [[ -f "/var/log/secure" && -r "/var/log/secure" ]]; then
        echo "/var/log/secure"
        return 0
    fi

    # 3. Systemd journald for ssh/sshd service units
    if command -v journalctl >/dev/null 2>&1; then
        local j_ssh
        j_ssh="$(journalctl -u ssh --no-pager -n 1 2>/dev/null || true)"
        if [[ -n "${j_ssh}" && "${j_ssh}" != *"-- No entries --"* ]]; then
            local jtmp
            jtmp="$(mktemp /tmp/journal_ssh_XXXXXX.log)"
            journalctl -u ssh --no-pager > "${jtmp}" 2>/dev/null || true
            echo "${jtmp}"
            return 0
        fi

        local j_sshd
        j_sshd="$(journalctl _COMM=sshd --no-pager -n 1 2>/dev/null || true)"
        if [[ -n "${j_sshd}" && "${j_sshd}" != *"-- No entries --"* ]]; then
            local jtmp
            jtmp="$(mktemp /tmp/journal_sshd_XXXXXX.log)"
            journalctl _COMM=sshd --no-pager > "${jtmp}" 2>/dev/null || true
            echo "${jtmp}"
            return 0
        fi
    fi

    # 4. Fallback to synthetic demonstration log
    if [[ -f "${SYNTHETIC_LOG}" ]]; then
        echo "${SYNTHETIC_LOG}"
        return 0
    fi

    echo ""
    return 1
}

# ------------------------------------------------------------------------------
# FUNCTION: get_source_label
# Description: Determines whether the log file is real system data or fallback
# ------------------------------------------------------------------------------
get_source_label() {
    local target="$1"
    if [[ "${target}" == "${SYNTHETIC_LOG}" || "${target}" == *"test_auth.log"* ]]; then
        echo "synthetic demonstration data — no real auth log was available on this system"
    elif [[ "${target}" == "/tmp/journal_ssh_"* || "${target}" == "/tmp/journal_sshd_"* ]]; then
        echo "real system journald log (journalctl)"
    elif [[ "${target}" == "/var/log/auth.log" || "${target}" == "/var/log/secure" ]]; then
        echo "real system authentication log (${target})"
    else
        echo "custom log source (${target})"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: validate_inputs
# Description: Validates log file existence, readability, size, and threshold.
# Arguments:
#   $1 - Log file path
#   $2 - Threshold value
# ------------------------------------------------------------------------------
validate_inputs() {
    local target_log="$1"
    local threshold_val="$2"

    # Check 0: Was a log file resolved?
    if [[ -z "${target_log}" ]]; then
        echo -e "${COLOR_RED}[ERROR] No log file specified and no accessible authentication log could be detected.${COLOR_RESET}" >&2
        echo "Please provide a valid file path or ensure read permissions on /var/log/auth.log." >&2
        exit 1
    fi

    # Check 1: Does the specified log file exist?
    if [[ ! -e "${target_log}" ]]; then
        echo -e "${COLOR_RED}[ERROR] Target log file does not exist: '${target_log}'${COLOR_RESET}" >&2
        echo "Please provide a valid file path or create test data first." >&2
        exit 1
    fi

    # Check 2: Is the target a regular file?
    if [[ ! -f "${target_log}" ]]; then
        echo -e "${COLOR_RED}[ERROR] Specified path is not a regular file: '${target_log}'${COLOR_RESET}" >&2
        exit 1
    fi

    # Check 3: Is the log file readable by the current user?
    if [[ ! -r "${target_log}" ]]; then
        echo -e "${COLOR_RED}[ERROR] Permission denied: Cannot read log file '${target_log}'${COLOR_RESET}" >&2
        exit 1
    fi

    # Check 4: Is the log file empty? (Requirement 7: clear message, not silent failure)
    if [[ ! -s "${target_log}" ]]; then
        echo -e "${COLOR_YELLOW}[WARNING] Log file '${target_log}' exists but is completely empty.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}[RESULT] No threats detected (0 events in log).${COLOR_RESET}"
        # Write clean notice to report file as well
        mkdir -p "${REPORT_DIR}"
        {
            echo "================================================================================"
            echo "           SUSPICIOUS IP DETECTION REPORT - SSH SECURITY MONITOR"
            echo "================================================================================"
            echo "Generated At : $(date '+%Y-%m-%d %H:%M:%S %Z')"
            echo "Log File     : ${target_log}"
            echo "Threshold    : ${threshold_val}"
            echo "Status       : Target log file is empty. No threats detected."
            echo "================================================================================"
        } > "${REPORT_FILE}"
        echo -e "${COLOR_BLUE}[INFO] Empty log summary logged to: ${REPORT_FILE}${COLOR_RESET}"
        exit 0
    fi

    # Check 5: Is the threshold a valid positive integer?
    if ! [[ "${threshold_val}" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${COLOR_RED}[ERROR] Invalid threshold value: '${threshold_val}'. Threshold must be a positive integer >= 1.${COLOR_RESET}" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: extract_line_timestamp
# Description: Extracts the timestamp from a raw syslog or ISO-8601 log line.
# Arguments:
#   $1 - Full raw log entry line
# Output:
#   Prints the extracted timestamp string (syslog 'Mon DD HH:MM:SS' or ISO date)
# ------------------------------------------------------------------------------
extract_line_timestamp() {
    local line="$1"
    # Traditional syslog format begins with 3-letter month (e.g., 'Sep 23 00:10:01')
    # Modern systemd / RFC 5424 formats begin with ISO timestamp (e.g., '2026-09-23T00:10:01')
    local first_token
    first_token="$(echo "${line}" | awk '{print $1}')"

    if [[ "${first_token}" =~ ^[A-Za-z]{3}$ ]]; then
        # Syslog format: Tokens 1, 2, and 3 represent Month, Day, Time
        echo "${line}" | awk '{print $1, $2, $3}'
    else
        # ISO / RFC timestamp: First token is the complete datetime stamp
        echo "${first_token}"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: analyze_ssh_log
# Description: Core analysis pipeline.
#   1. Filters for SSH failed login attempts.
#   2. Extracts source IP addresses using robust PCRE regex.
#   3. Aggregates count per IP sorted in descending order.
#   4. Evaluates count against configured threshold.
#   5. Gathers first seen and last seen timestamps.
#   6. Produces formatted terminal and report file output.
# Arguments:
#   $1 - Log file path
#   $2 - Alert threshold
# ------------------------------------------------------------------------------
analyze_ssh_log() {
    local target_log="$1"
    local threshold="$2"

    # Ensure destination report directory exists inside the project
    mkdir -p "${REPORT_DIR}"

    local source_label
    source_label="$(get_source_label "${target_log}")"

    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}         SSH SECURITY MONITOR - SUSPICIOUS IP DETECTION ENGINE${COLOR_RESET}"
    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e " Target Log File : ${COLOR_BOLD}${target_log}${COLOR_RESET}"
    echo -e " Log Source Type : ${COLOR_YELLOW}${source_label}${COLOR_RESET}"
    echo -e " Alert Threshold : ${COLOR_BOLD}${threshold}${COLOR_RESET} failed attempts"
    echo -e " Scan Started At : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

    # --------------------------------------------------------------------------
    # PIPELINE EXPLANATION:
    # 1. grep -E 'sshd.*Failed password' "${target_log}":
    #    Target only SSH daemon entries reporting failed authentication.
    #    This includes standard "Failed password for <user>" and
    #    "Failed password for invalid user <user>" lines, while ignoring
    #    successful logins, disconnected sessions, and non-SSH services.
    #
    # 2. grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}':
    #    - '-o' : Prints only matching tokens instead of the entire line.
    #    - '-P' : Enables Perl-Compatible Regular Expressions (PCRE).
    #    - 'from ' : Matches the keyword "from " preceding the remote IP address.
    #    - '\K' : Reset match start (lookbehind equivalent). Drops "from " so
    #             only the actual IP string is returned.
    #    - '([0-9]{1,3}\.){3}[0-9]{1,3}' : Matches valid IPv4 addresses consisting
    #             of 3 octets with dots followed by a 4th octet (e.g. 203.0.113.45).
    #             Using this regex prevents hardcoding column numbers (awk $11),
    #             which break when log lines contain extra words like "invalid user".
    #
    # 3. sort:
    #    Sorts the IP addresses alphabetically so uniq can group consecutive matches.
    #
    # 4. uniq -c:
    #    Counts consecutive occurrences of each distinct IP address.
    #
    # 5. sort -nr:
    #    Sorts the aggregated counts numerically (-n) in reverse/descending order (-r)
    #    so the most aggressive attackers appear at the very top.
    # --------------------------------------------------------------------------

    # Step A: Extract all failed attempts into a temporary buffer/variable
    local failed_lines
    failed_lines="$(grep -E 'sshd.*Failed password' "${target_log}" 2>/dev/null || true)"

    if [[ -z "${failed_lines}" ]]; then
        echo -e "${COLOR_GREEN}[RESULT] No failed SSH login attempts found in '${target_log}'.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}[STATUS] No suspicious IP activity found in the current system logs.${COLOR_RESET}"
        
        # Log result to report file
        {
            echo "================================================================================"
            echo "           SUSPICIOUS IP DETECTION REPORT - SSH SECURITY MONITOR"
            echo "================================================================================"
            echo "Generated At : $(date '+%Y-%m-%d %H:%M:%S %Z')"
            echo "Log File     : ${target_log}"
            echo "Log Source   : ${source_label}"
            echo "Threshold    : ${threshold} failed attempts"
            echo "Result       : No suspicious IP activity found in the current system logs."
            echo "Status       : Clean (0 threats detected)"
            echo "================================================================================"
        } > "${REPORT_FILE}"
        echo -e "${COLOR_BLUE}[INFO] Report written to: ${REPORT_FILE}${COLOR_RESET}"
        return 0
    fi

    # Step B: Count occurrences per IP
    local ip_counts
    ip_counts="$(echo "${failed_lines}" | grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr || true)"

    if [[ -z "${ip_counts}" ]]; then
        echo -e "${COLOR_YELLOW}[WARNING] Failed login lines found, but no IP addresses could be parsed.${COLOR_RESET}"
        return 0
    fi

    # Step C: Filter against threshold and collect detailed records
    local suspicious_count=0
    local total_failed_attempts=0
    local report_buffer=""

    # Header for report file
    {
        echo "================================================================================"
        echo "           SUSPICIOUS IP DETECTION REPORT - SSH SECURITY MONITOR"
        echo "================================================================================"
        echo "Generated At : $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Log File     : ${target_log}"
        echo "Log Source   : ${source_label}"
        echo "Threshold    : ${threshold} failed attempts"
        echo "================================================================================"
        printf "%-18s | %-8s | %-19s | %-19s | %-12s\n" "IP ADDRESS" "ATTEMPTS" "FIRST SEEN" "LAST SEEN" "STATUS"
        echo "-------------------+----------+---------------------+---------------------+-------------"
    } > "${REPORT_FILE}"

    # Print table header to terminal
    printf "${COLOR_BOLD}%-18s | %-8s | %-19s | %-19s | %-12s${COLOR_RESET}\n" \
           "IP ADDRESS" "ATTEMPTS" "FIRST SEEN" "LAST SEEN" "STATUS"
    echo "-------------------+----------+---------------------+---------------------+-------------"

    # Process each IP count record (line format: "<count> <ip>")
    while read -r count ip; do
        [[ -z "${count}" || -z "${ip}" ]] && continue
        total_failed_attempts=$((total_failed_attempts + count))

        # Check if the count meets or exceeds the configurable threshold
        if [[ "${count}" -ge "${threshold}" ]]; then
            suspicious_count=$((suspicious_count + 1))

            # Extract first seen and last seen entries for this specific IP
            local ip_entries
            ip_entries="$(echo "${failed_lines}" | grep -F "${ip}")"

            local first_line last_line first_seen last_seen
            first_line="$(echo "${ip_entries}" | head -n1)"
            last_line="$(echo "${ip_entries}" | tail -n1)"

            first_seen="$(extract_line_timestamp "${first_line}")"
            last_seen="$(extract_line_timestamp "${last_line}")"

            # Print to terminal with highlight
            printf "${COLOR_RED}%-18s${COLOR_RESET} | %-8d | %-19s | %-19s | ${COLOR_RED}%-12s${COLOR_RESET}\n" \
                   "${ip}" "${count}" "${first_seen}" "${last_seen}" "FLAGGED"

            # Append to file report (without color escape codes)
            printf "%-18s | %-8d | %-19s | %-19s | %-12s\n" \
                   "${ip}" "${count}" "${first_seen}" "${last_seen}" "FLAGGED" >> "${REPORT_FILE}"
        fi
    done <<< "${ip_counts}"

    echo "-------------------+----------+---------------------+---------------------+-------------"

    # Step D: Final summary reporting
    if [[ "${suspicious_count}" -eq 0 ]]; then
        echo -e "${COLOR_GREEN}[RESULT] No threats detected.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}All detected IPs had fewer than ${threshold} failed attempts.${COLOR_RESET}"
        echo "--------------------------------------------------------------------------------" >> "${REPORT_FILE}"
        echo "RESULT: No threats detected. All IPs were below the threshold of ${threshold} failed attempts." >> "${REPORT_FILE}"
    else
        echo -e "${COLOR_RED}[ALERT] Detected ${suspicious_count} suspicious IP(s) exceeding threshold (>= ${threshold})${COLOR_RESET}"
        echo "--------------------------------------------------------------------------------" >> "${REPORT_FILE}"
        echo "ALERT: Detected ${suspicious_count} suspicious IP(s) exceeding threshold (>= ${threshold})." >> "${REPORT_FILE}"
    fi

    # Append footer metrics to report file
    {
        echo "Total Failed Login Events Scanned : ${total_failed_attempts}"
        echo "Total Flagged Suspicious IP Count : ${suspicious_count}"
        echo "Scan Completed At                 : $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "================================================================================"
    } >> "${REPORT_FILE}"

    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e " Total Failed Logins Scanned : ${COLOR_BOLD}${total_failed_attempts}${COLOR_RESET}"
    echo -e " Total Flagged IPs           : ${COLOR_BOLD}${suspicious_count}${COLOR_RESET}"
    echo -e " Detailed Log Saved To       : ${COLOR_GREEN}${REPORT_FILE}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION ROUTINE
# ------------------------------------------------------------------------------
main() {
    # Check for help flag
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        display_usage
        exit 0
    fi

    local target_log=""
    local threshold="${DEFAULT_THRESHOLD}"

    if [[ $# -ge 1 ]]; then
        if [[ "$1" =~ ^[1-9][0-9]*$ && $# -eq 1 ]]; then
            # User passed only threshold: auto-detect log source
            threshold="$1"
            target_log="$(detect_auth_log_source)"
        else
            target_log="$1"
            threshold="${2:-${DEFAULT_THRESHOLD}}"
        fi
    else
        target_log="$(detect_auth_log_source)"
    fi

    # Set trap to clean up temporary journal log files if used
    trap '[[ -n "${target_log:-}" && "${target_log}" == /tmp/journal_* ]] && rm -f "${target_log}"' EXIT

    # Validate inputs before processing
    validate_inputs "${target_log}" "${threshold}"

    # Execute core detection logic
    analyze_ssh_log "${target_log}" "${threshold}"
}

# Invoke main entry point with all script arguments
main "$@"
