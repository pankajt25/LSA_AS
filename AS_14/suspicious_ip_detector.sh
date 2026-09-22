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
#              Defaults to: ~/sprint-sandbox/test_auth.log
#   THRESHOLD  (Optional) Integer threshold of failed attempts required to
#              flag an IP as suspicious.
#              Defaults to: 5
#
# Examples:
#   1. Run with default sandbox log and default threshold (5):
#      ~/sprint-sandbox/suspicious_ip_detector.sh
#
#   2. Run with custom log file and default threshold:
#      ~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/test_auth.log
#
#   3. Run with custom log file and custom threshold (e.g., 3 failed attempts):
#      ~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/test_auth.log 3
#
#   4. Display help information:
#      ~/sprint-sandbox/suspicious_ip_detector.sh --help
#
# Outputs:
#   - Terminal: Formatted summary table of suspicious IPs with timestamps.
#   - Report File: Timestamped log saved to ~/sprint-sandbox/reports/
# ==============================================================================

# Exit immediately if a pipeline command returns a non-zero status,
# treat unset variables as an error, and ensure pipe failures propagate.
set -euo pipefail

# ------------------------------------------------------------------------------
# CONSTANTS AND DEFAULT CONFIGURATION
# ------------------------------------------------------------------------------
readonly SANDBOX_DIR="${HOME}/sprint-sandbox"
readonly DEFAULT_LOG="${SANDBOX_DIR}/test_auth.log"
readonly DEFAULT_THRESHOLD=5
readonly REPORT_DIR="${SANDBOX_DIR}/reports"

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

Automated SSH Log Security Monitor - Suspicious IP Detection

Arguments:
  LOG_FILE     Path to SSH auth log (default: ${DEFAULT_LOG})
  THRESHOLD    Minimum failed attempts to flag as suspicious (default: ${DEFAULT_THRESHOLD})

Options:
  -h, --help   Show this help message and exit

Examples:
  $(basename "$0")
  $(basename "$0") ${DEFAULT_LOG} 3
  $(basename "$0") /var/log/auth.log 10 (read-only mode)

EOF
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

    # Ensure destination report directory exists inside the sandbox
    mkdir -p "${REPORT_DIR}"

    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}         SSH SECURITY MONITOR - SUSPICIOUS IP DETECTION ENGINE${COLOR_RESET}"
    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e " Target Log File : ${COLOR_BOLD}${target_log}${COLOR_RESET}"
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
        echo -e "${COLOR_GREEN}[STATUS] System is clean. No threats detected.${COLOR_RESET}"
        
        # Log result to report file
        {
            echo "================================================================================"
            echo "           SUSPICIOUS IP DETECTION REPORT - SSH SECURITY MONITOR"
            echo "================================================================================"
            echo "Generated At : $(date '+%Y-%m-%d %H:%M:%S %Z')"
            echo "Log File     : ${target_log}"
            echo "Threshold    : ${threshold}"
            echo "Result       : No failed SSH login attempts found. No threats detected."
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

    # Assign arguments or fallback to sandbox defaults
    local target_log="${1:-${DEFAULT_LOG}}"
    local threshold="${2:-${DEFAULT_THRESHOLD}}"

    # Validate inputs before processing
    validate_inputs "${target_log}" "${threshold}"

    # Execute core detection logic
    analyze_ssh_log "${target_log}" "${threshold}"
}

# Invoke main entry point with all script arguments
main "$@"
