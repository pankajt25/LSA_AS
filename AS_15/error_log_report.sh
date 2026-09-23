#!/usr/bin/env bash
# ==============================================================================
# SCRIPT NAME : error_log_report.sh
# COURSE      : Linux System Administration (E1ITA307) - Automation Sprint
# PROBLEM #15 : Error Log Report — Automated Log Extraction & Summary
# AUTHOR      : System Administrator
#
# ------------------------------------------------------------------------------
# HOW TO RUN:
#   Syntax:
#     ./error_log_report.sh [LOG_FILE_PATH]
#
#   Arguments:
#     LOG_FILE_PATH (Optional) : Path to the target log file to inspect.
#                                Defaults to 'sample_syslog.log' inside the
#                                project sandbox directory if omitted.
#
#   Example Invocations:
#     # 1. Run using default sandboxed sample log:
#     ./error_log_report.sh
#
#     # 2. Run with explicit log path:
#     ./error_log_report.sh ./sample_syslog.log
#
#     # 3. Run with custom application log:
#     ./error_log_report.sh /path/to/custom_application.log
#
#     # 4. Display help manual:
#     ./error_log_report.sh --help
# ==============================================================================

# Enable strict shell safety options:
# - 'e': Exit immediately if any command exits with a non-zero status (handled carefully for grep).
# - 'u': Treat unset variables as an error and exit immediately.
# - 'o pipefail': Return value of a pipeline is the status of the last command to exit with non-zero.
set -euo pipefail

# ------------------------------------------------------------------------------
# CONFIGURATION & VARIABLE INITIALIZATION
# ------------------------------------------------------------------------------

# Resolve the absolute directory where this script resides.
# WHY: Ensures relative paths (like default sample log and reports directory)
# work predictably regardless of the user's current working directory (CWD).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sandboxed default target log file.
# WHY: Prevents unintended modification or dependence on real system logs (/var/log/*).
DEFAULT_LOG_FILE="${SCRIPT_DIR}/sample_syslog.log"

# Directory dedicated to persisting generated reports.
REPORTS_DIR="${SCRIPT_DIR}/reports"

# Monitored error and severity keywords stored in an indexed array.
# WHY: Keeping keywords in an array decouples the configuration from the parsing
# logic. This allows easy extension during oral examination (viva) by simply adding
# keywords (e.g., "panic", "alert", "emerg") without modifying downstream code.
KEYWORDS=("error" "fail" "critical" "fatal" "warn")

# Build pipe-separated regex pattern (e.g., "error|fail|critical|fatal|warn")
# WHY: Extended Regular Expressions (ERE) allow evaluating all keywords in a single
# grep pass, minimizing disk I/O and process spawning overhead.
KEYWORD_REGEX=$(IFS="|"; echo "${KEYWORDS[*]}")

# Parse command-line argument ($1). If not supplied, fallback to DEFAULT_LOG_FILE.
TARGET_LOG="${1:-$DEFAULT_LOG_FILE}"

# ------------------------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------------------------

# Function: show_help
# Purpose : Display command usage syntax, argument options, and examples.
show_help() {
    cat << EOF
Usage: $(basename "$0") [LOG_FILE_PATH]

Analyze a Linux log file to extract and summarize error-relevant events.

ARGUMENTS:
  LOG_FILE_PATH    Path to the log file to analyze (default: sample_syslog.log).

OPTIONS:
  -h, --help       Display this help documentation and exit.

OUTPUT:
  - Formatted analytical summary printed to stdout.
  - Mirrored copy saved to 'reports/error_report_<timestamp>.log'.

EOF
}

# Function: validate_log_file
# Purpose : Verify file existence, accessibility, and handle edge cases gracefully.
# WHY: Defensive programming ensures clear, actionable error messages instead of
# cryptic command failures or silent exits.
validate_log_file() {
    local file="$1"

    # Edge Case 1: Target path does not exist on disk
    if [[ ! -e "$file" ]]; then
        echo "[ERROR] Log file does not exist: '${file}'" >&2
        echo "        Please provide a valid log file path or run without arguments to use default sample." >&2
        exit 1
    fi

    # Edge Case 2: Target path exists but is a directory or special device, not a regular file
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] Specified path is not a regular file: '${file}'" >&2
        exit 1
    fi

    # Edge Case 3: File exists but lacks read permissions for the current user
    if [[ ! -r "$file" ]]; then
        echo "[ERROR] Permission denied: Cannot read log file '${file}'" >&2
        exit 1
    fi

    # Edge Case 4: File exists but is empty (0 bytes)
    # WHY: Empty logs should produce an explicit warning rather than failing silently.
    if [[ ! -s "$file" ]]; then
        echo "[WARNING] Log file '${file}' exists but is empty (0 bytes)."
        echo "          No log entries available to analyze."

        # Create timestamped report noting the empty log state
        mkdir -p "${REPORTS_DIR}"
        local empty_report="${REPORTS_DIR}/error_report_$(date +%Y%m%d_%H%M%S).log"
        {
            echo "================================================================================"
            echo "                       SYSTEM LOG ERROR ANALYSIS REPORT"
            echo "================================================================================"
            echo "Generated On       : $(date '+%Y-%m-%d %H:%M:%S %Z')"
            echo "Target Log File    : ${file}"
            echo "Log File Size      : 0 bytes"
            echo "Status             : EMPTY LOG FILE - No entries found to analyze."
            echo "================================================================================"
        } > "${empty_report}"
        echo "[INFO] Empty status record saved to: ${empty_report}"
        exit 0
    fi
}

# Function: generate_report
# Purpose : Perform log parsing, compute statistics, and render the complete report.
# WHY: Encapsulating the report generator in a function allows piping its entire
# formatted output directly to 'tee', guaranteeing terminal display and disk backup
# remain 100% synchronized without duplicate code.
generate_report() {
    local file="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    # 1. Total lines in the target log file using 'wc -l'
    # WHY: Provides baseline scale to calculate the error proportion.
    local total_log_lines
    total_log_lines=$(wc -l < "${file}")

    # 2. Extract error lines case-insensitively using grep -E
    # WHY: 'grep -i' handles variations like 'ERROR', 'Error', 'error'.
    # We append '|| true' because grep returns exit code 1 when 0 matches are found,
    # which would otherwise abort the script under 'set -e'.
    local matched_lines
    matched_lines=$(grep -i -E "${KEYWORD_REGEX}" "${file}" || true)

    # Count total distinct matching lines
    local total_error_lines=0
    if [[ -n "${matched_lines}" ]]; then
        total_error_lines=$(echo "${matched_lines}" | wc -l)
    fi

    # Header section
    echo "================================================================================"
    echo "                       SYSTEM LOG ERROR ANALYSIS REPORT"
    echo "================================================================================"
    echo "Generated On       : ${timestamp}"
    echo "Target Log File    : ${file}"
    echo "Log File Size      : $(wc -c < "${file}") bytes"
    echo "Total Log Entries  : ${total_log_lines}"
    echo "Monitored Keywords : ${KEYWORDS[*]}"
    echo "================================================================================"
    echo ""

    # Section 1: Executive Summary
    echo "[+] SECTION 1: EXECUTIVE SUMMARY"
    echo "--------------------------------------------------------------------------------"
    if [[ ${total_error_lines} -eq 0 ]]; then
        echo "Status                  : [OK] No error-relevant keywords detected."
        echo "Total Lines Analyzed    : ${total_log_lines}"
        echo "Matching Error Entries  : 0 (0.00% of log)"
        echo ""
        echo "Explicit Notice: All checked keywords (${KEYWORDS[*]}) were absent from the log."
        echo "================================================================================"
        echo "                          END OF ERROR LOG REPORT"
        echo "================================================================================"
        return 0
    fi

    # Compute percentage of error lines relative to total log entries using 'awk'
    # WHY: Awk offers floating-point arithmetic natively without requiring bc.
    local error_percentage
    error_percentage=$(awk -v err="${total_error_lines}" -v tot="${total_log_lines}" \
        'BEGIN { if (tot > 0) printf "%.2f%%", (err / tot) * 100; else print "0.00%" }')

    echo "Status                  : [ALERT] Errors/Warnings detected!"
    echo "Total Lines Analyzed    : ${total_log_lines}"
    echo "Matching Error Entries  : ${total_error_lines} (${error_percentage} of total entries)"
    echo ""

    # Section 2: Severity & Keyword Breakdown
    # WHY: System administrators need to quickly prioritize critical/fatal issues
    # over mild warnings. We count lines matching each keyword and render a visual bar.
    echo "[+] SECTION 2: SEVERITY & KEYWORD BREAKDOWN"
    echo "--------------------------------------------------------------------------------"
    printf "%-14s %-14s %-12s %-24s\n" "KEYWORD" "MATCHING LINES" "SHARE (%)" "DISTRIBUTION"
    echo "--------------------------------------------------------------------------------"

    for kw in "${KEYWORDS[@]}"; do
        # Count lines matching current keyword (case-insensitive)
        local count
        count=$(grep -i -c "${kw}" "${file}" 2>/dev/null || true)

        # Use awk to format tabular output, calculate percentage share of total errors,
        # and render an ASCII distribution bar.
        awk -v kw="${kw}" -v c="${count}" -v total="${total_error_lines}" 'BEGIN {
            pct = (total > 0) ? (c / total) * 100 : 0;
            # Build 20-character visual progress bar: 1 bar = 5%
            bar_len = int(pct / 5);
            if (bar_len > 20) bar_len = 20;
            bars = "";
            for (i = 0; i < bar_len; i++) bars = bars "#";
            for (i = bar_len; i < 20; i++) bars = bars "-";
            printf "%-14s %-14d %-12s [%s]\n", toupper(kw), c, sprintf("%.1f%%", pct), bars;
        }'
    done
    echo "--------------------------------------------------------------------------------"
    echo "Note: The sum of individual keyword counts may exceed total error lines because"
    echo "      a single log entry can contain multiple keywords (e.g. 'ERROR: failed...')."
    echo ""

    # Section 3: Recurring Error Patterns / Frequency Ranking
    # WHY: Groups and counts identical or repeated error messages using
    # a classic Unix pipeline: sort -> uniq -c -> sort -rn.
    # This helps administrators spot runaway loops, repeated authentication failures,
    # or spammy error signatures immediately.
    echo "[+] SECTION 3: FREQUENCY OF RECURRING ERROR PATTERNS"
    echo "--------------------------------------------------------------------------------"
    printf "%-12s | %s\n" "COUNT" "ERROR ENTRY PATTERN"
    echo "--------------------------------------------------------------------------------"
    echo "${matched_lines}" | sort | uniq -c | sort -rn | head -n 5 | while read -r count pattern; do
        printf "%-12s | %s\n" "${count}" "${pattern}"
    done
    echo ""

    # Section 4: 10 Most Recent Matching Lines (Tail-Style Review)
    # WHY: Provides chronological context of the latest errors without flooding the screen.
    # Line numbers are preserved using 'grep -n' so administrators can jump directly
    # to the exact line inside the source file using their editor or pager.
    echo "[+] SECTION 4: 10 MOST RECENT MATCHING LINES (CHRONOLOGICAL)"
    echo "--------------------------------------------------------------------------------"
    printf "%-10s | %s\n" "ORIG LINE" "LOG ENTRY CONTENT"
    echo "--------------------------------------------------------------------------------"
    grep -i -n -E "${KEYWORD_REGEX}" "${file}" | tail -n 10 | while IFS=: read -r lineno logline; do
        printf "Line %-5s | %s\n" "${lineno}" "${logline}"
    done
    echo "================================================================================"
    echo "                          END OF ERROR LOG REPORT"
    echo "================================================================================"
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION FLOW
# ------------------------------------------------------------------------------
main() {
    # Check if user requested help flags
    if [[ "${TARGET_LOG}" == "-h" || "${TARGET_LOG}" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Validate target log file
    validate_log_file "${TARGET_LOG}"

    # Ensure reports directory exists inside project sandbox
    mkdir -p "${REPORTS_DIR}"

    # Generate timestamped report filename (e.g. reports/error_report_20260923_114500.log)
    local report_timestamp
    report_timestamp="$(date +%Y%m%d_%H%M%S)"
    local report_file="${REPORTS_DIR}/error_report_${report_timestamp}.log"

    # Execute report generation, mirroring output to console AND saving to report file
    # WHY: 'tee' provides immediate visibility on stdout while atomically persisting
    # an immutable audit trail file inside the sandbox.
    generate_report "${TARGET_LOG}" | tee "${report_file}"

    echo ""
    echo "[INFO] Persistent report successfully written to: ${report_file}"
}

# Invoke main entrypoint with all passed arguments
main "$@"
