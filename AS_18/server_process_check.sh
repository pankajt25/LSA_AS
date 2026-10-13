#!/usr/bin/env bash
# ==============================================================================
# Script Name : server_process_check.sh
# Course      : Linux System Administration (E1ITA307) — Automation Sprint
# Problem #18 : Server Process Check — Focus: Process Management
# Description : Verifies whether a specified server process is currently running.
#               Reports operational status, total instance count, PID list, and
#               uptime of the oldest instance. Supports strict/case-sensitive
#               mode and logs all checks to a timestamped audit trail.
# ==============================================================================
#
# ARCHITECTURAL NOTE — WHY 'pgrep' IS PREFERRED OVER 'ps aux | grep <name>':
# ------------------------------------------------------------------------------
# In Linux administration, naive process inspection often relies on pipelines
# such as 'ps aux | grep <process_name>'. This pattern has several critical flaws:
#
# 1. SELF-MATCHING RACE CONDITION:
#    The 'grep' process itself appears in the system process table (/proc) with
#    its command-line arguments matching the search pattern. Administrators
#    often resort to fragile workarounds like 'grep [b]ash' or 'grep -v grep',
#    which clutter code and introduce subtle race conditions.
#
# 2. DIRECT KERNEL /proc INTERFACE:
#    'pgrep' (from procps-ng) directly queries kernel process entries under /proc
#    without spawning intermediate subshells or pipelines. It specifically inspects
#    the process table and deliberately ignores itself during execution.
#
# 3. CLEAN POSIX RETURN CODES:
#    'pgrep' provides standardized, predictable exit statuses:
#      - 0 : One or more matching processes were found.
#      - 1 : No matching processes were found.
#      - 2 : Syntax error in pattern (e.g. invalid regex).
#      - 3 : Fatal error.
#    In contrast, piping ps through grep and awk masks errors and requires
#    managing pipe status ($PIPESTATUS) manually.
#
# 4. BUILT-IN FILTERING OPTIONS:
#    'pgrep' natively supports:
#      - '-f' : Pattern match against the full command line (/proc/<PID>/cmdline).
#      - '-i' : Case-insensitive matching.
#      - '-o' : Select the oldest matching process.
#      - '-n' : Select the newest matching process.
#      - '-u' : Filter by effective user ID or username.
#
# 5. IMMUNITY TO OUTPUT TRUNCATION:
#    Raw 'ps aux' formatting varies across terminal widths, distributions, and
#    busybox vs full GNU procps implementations. 'pgrep' bypasses formatting layers.
# ==============================================================================

# Strict shell execution settings:
# -u : Treat unset variables as an error when substituting.
# -o pipefail : The return value of a pipeline is the status of the last command
#               to exit with a non-zero status.
# Note: We do NOT use 'set -e' globally here because 'pgrep' exits with 1 when no
# process is found; we handle and evaluate this return code explicitly and gracefully.
set -uo pipefail

# ------------------------------------------------------------------------------
# DIRECTORY & LOG PATH CONFIGURATION (SANDBOX CONSTRAINED)
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/process_check.log"
SCRIPT_NAME="$(basename "$0")"

# Default demo process: safe, standard, and present in user sessions.
DEFAULT_PROCESS="bash"

# Operational flag defaults
STRICT_MODE=false
TARGET_PROCESS=""

# Ensure the logs directory exists strictly within the project sandbox
mkdir -p "${LOG_DIR}"

# ------------------------------------------------------------------------------
# TERMINAL COLOR FORMATTING
# ------------------------------------------------------------------------------
# Color codes are active only when attached to an interactive terminal (TTY)
# to keep redirected output or non-interactive execution clean and readable.
if [ -t 1 ]; then
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_GREEN=$'\033[1;32m'
    COLOR_RED=$'\033[1;31m'
    COLOR_YELLOW=$'\033[1;33m'
    COLOR_CYAN=$'\033[1;36m'
    COLOR_BLUE=$'\033[1;34m'
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_GREEN=""
    COLOR_RED=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
    COLOR_BLUE=""
fi

# ------------------------------------------------------------------------------
# LOGGING HELPER
# ------------------------------------------------------------------------------
# Writes structured, timestamped audit entries to $LOG_FILE.
# Format: [YYYY-MM-DD HH:MM:SS] [STATUS] Mode: <MODE> | Target: <NAME> | Details
log_event() {
    local status="$1"
    local mode="$2"
    local target="$3"
    local details="$4"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [%-7s] Mode: %-16s | Process: %-20s | %s\n" \
        "$timestamp" "$status" "$mode" "$target" "$details" >> "${LOG_FILE}"
}

# ------------------------------------------------------------------------------
# REGEX SANITIZATION HELPER
# ------------------------------------------------------------------------------
# Escapes special POSIX Extended Regular Expression (ERE) metacharacters:
#   \ [ ] ( ) { } . * + ? ^ $ |
# This ensures that user-supplied process names with special characters
# (such as '[kworker]', 'c++', 'app(v1)', 'node.js') are interpreted literally
# by pgrep and never cause syntax errors or crash the script.
sanitize_regex() {
    local input="$1"
    # Using sed to insert a backslash before any regex metacharacter
    printf '%s' "$input" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g'
}

# ------------------------------------------------------------------------------
# USAGE & HELP DISPLAY
# ------------------------------------------------------------------------------
print_usage() {
    cat << EOF
${COLOR_BOLD}Usage:${COLOR_RESET} ${SCRIPT_NAME} [OPTIONS] <PROCESS_NAME>

${COLOR_BOLD}Description:${COLOR_RESET}
  Inspects the Linux system process table using 'pgrep -f' to verify if a specified
  server process is running. Reports instance count, process IDs, and uptime of the
  oldest instance. All checks are recorded to the audit log.

${COLOR_BOLD}Arguments:${COLOR_RESET}
  <PROCESS_NAME>        Name or command pattern of the process to inspect.
                        (e.g., bash, sshd, cron, nginx, redis-server)

${COLOR_BOLD}Options:${COLOR_RESET}
  -s, --strict          Enable strict, case-sensitive matching.
                        (Default: case-insensitive partial match via 'pgrep -i -f')
  -d, --default         Use the default safe demo process ('${DEFAULT_PROCESS}').
  -h, --help            Display this help manual and exit.

${COLOR_BOLD}Exit Codes:${COLOR_RESET}
  0  Process is RUNNING (one or more active instances found)
  1  Process is NOT RUNNING (no matching instances found)
  2  Usage error (no process name provided or invalid option)

${COLOR_BOLD}Examples:${COLOR_RESET}
  $ ./${SCRIPT_NAME} bash                  # Case-insensitive check for bash
  $ ./${SCRIPT_NAME} -s bash               # Strict case-sensitive check for bash
  $ ./${SCRIPT_NAME} -s BASH               # Strict check (will not match lowercase bash)
  $ ./${SCRIPT_NAME} not-a-real-proc-xyz   # Nonexistent process check
  $ ./${SCRIPT_NAME} --default             # Check safe default process (${DEFAULT_PROCESS})
EOF
}

# ------------------------------------------------------------------------------
# COMMAND-LINE ARGUMENT PARSING
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--strict)
            STRICT_MODE=true
            shift
            ;;
        -d|--default)
            TARGET_PROCESS="${DEFAULT_PROCESS}"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -*)
            echo "${COLOR_RED}${COLOR_BOLD}[ERROR]${COLOR_RESET} Unknown option: $1" >&2
            echo "" >&2
            print_usage >&2
            log_event "ERROR" "UNKNOWN" "$1" "Unknown command-line option provided"
            exit 2
            ;;
        *)
            if [[ -z "${TARGET_PROCESS}" ]]; then
                TARGET_PROCESS="$1"
            else
                echo "${COLOR_RED}${COLOR_BOLD}[ERROR]${COLOR_RESET} Unexpected extra argument: $1" >&2
                echo "" >&2
                print_usage >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate that a process name was supplied
if [[ -z "${TARGET_PROCESS}" ]]; then
    echo "${COLOR_RED}${COLOR_BOLD}[ERROR]${COLOR_RESET} No process name specified." >&2
    echo "Please provide a process name as an argument, or use --default to test '${DEFAULT_PROCESS}'." >&2
    echo "" >&2
    print_usage >&2
    log_event "ERROR" "UNSPECIFIED" "(none)" "Invocation failed: No process name provided"
    exit 2
fi

# ------------------------------------------------------------------------------
# PROCESS INSPECTION LOGIC
# ------------------------------------------------------------------------------
MODE_DESC="Case-Insensitive"
if [ "${STRICT_MODE}" = true ]; then
    MODE_DESC="Strict / Case-Sensitive"
fi

# Sanitize special characters to prevent regex interpretation crashes in pgrep
ESCAPED_TARGET="$(sanitize_regex "${TARGET_PROCESS}")"

# Configure pgrep flags based on mode:
# -f : Check the full command line argument string
# -i : Ignore case distinctions (only in default mode)
PGREP_FLAGS=(-f)
if [ "${STRICT_MODE}" = false ]; then
    PGREP_FLAGS=(-i -f)
fi

# Execute pgrep safely.
# Capture raw matching PIDs into a variable while preventing subshell abort.
RAW_PIDS="$(pgrep "${PGREP_FLAGS[@]}" "${ESCAPED_TARGET}" 2>/dev/null || true)"

# Filter raw PIDs defensively:
# 1. Exclude the current script's PID ($$)
# 2. Exclude the direct parent shell PID ($PPID) which executed this script
# 3. Exclude any processes whose command line contains this script itself (e.g. subshells)
# 4. Verify the process is still alive and responsive to 'ps'
FILTERED_PIDS=()
for pid in ${RAW_PIDS}; do
    # Skip current script and immediate parent
    if [[ "${pid}" -eq $$ || "${pid}" -eq ${PPID} ]]; then
        continue
    fi

    # Query command line of the PID; if process has already terminated, skip it
    if ! proc_cmd="$(ps -o args= -p "${pid}" 2>/dev/null)"; then
        continue
    fi

    # Exclude instances of this check script itself
    if [[ "${proc_cmd}" == *"${SCRIPT_NAME}"* ]]; then
        continue
    fi

    FILTERED_PIDS+=("${pid}")
done

INSTANCE_COUNT="${#FILTERED_PIDS[@]}"

# ------------------------------------------------------------------------------
# RESULT EVALUATION & OUTPUT
# ------------------------------------------------------------------------------
echo "${COLOR_BLUE}${COLOR_BOLD}================================================================${COLOR_RESET}"
echo "${COLOR_CYAN}${COLOR_BOLD}              LINUX SERVER PROCESS STATUS CHECK                 ${COLOR_RESET}"
echo "${COLOR_BLUE}${COLOR_BOLD}================================================================${COLOR_RESET}"
printf " %-20s : %s%s%s\n" "Target Process" "${COLOR_BOLD}" "${TARGET_PROCESS}" "${COLOR_RESET}"
printf " %-20s : %s\n" "Matching Mode" "${MODE_DESC}"
printf " %-20s : %s\n" "Audit Log File" "${LOG_FILE}"
echo "${COLOR_BLUE}----------------------------------------------------------------${COLOR_RESET}"

if [[ "${INSTANCE_COUNT}" -gt 0 ]]; then
    # Format PID list for display (space-delimited and comma-delimited for ps)
    PID_DISPLAY="${FILTERED_PIDS[*]}"
    PID_CSV="$(IFS=,; echo "${FILTERED_PIDS[*]}")"

    # Identify the oldest running instance among the matched PIDs.
    # We query PID, elapsed time in seconds (etimes=), and formatted elapsed time (etime=).
    # Sorting numerically descending on column 2 (etimes) places the oldest at the top.
    OLDEST_LINE="$(ps -o pid=,etimes=,etime= -p "${PID_CSV}" 2>/dev/null | sort -k2,2rn | head -n1 || true)"
    read -r OLDEST_PID OLDEST_ETIMES OLDEST_ETIME <<< "${OLDEST_LINE}"

    # As required by problem statement: verify elapsed time via 'ps -o etime= -p <pid>'
    FORMATTED_UPTIME="$(ps -o etime= -p "${OLDEST_PID}" 2>/dev/null | tr -d ' ' || echo "N/A")"

    # Display human-readable success status card
    printf " %-20s : %s%s [RUNNING]%s\n" "Operational Status" "${COLOR_GREEN}${COLOR_BOLD}" "ACTIVE" "${COLOR_RESET}"
    printf " %-20s : %s%d instance(s)%s\n" "Instance Count" "${COLOR_BOLD}" "${INSTANCE_COUNT}" "${COLOR_RESET}"
    printf " %-20s : %s\n" "Active PID(s)" "${PID_DISPLAY}"
    printf " %-20s : PID %s\n" "Oldest Instance" "${OLDEST_PID}"
    printf " %-20s : %s%s%s (ps -o etime= -p %s)\n" "Oldest Uptime" "${COLOR_CYAN}${COLOR_BOLD}" "${FORMATTED_UPTIME}" "${COLOR_RESET}" "${OLDEST_PID}"
    echo "${COLOR_BLUE}================================================================${COLOR_RESET}"
    echo "${COLOR_GREEN}✓ Process '${TARGET_PROCESS}' is RUNNING with ${INSTANCE_COUNT} active instance(s).${COLOR_RESET}"

    # Record successful check to audit log
    log_event "RUNNING" "${MODE_DESC}" "${TARGET_PROCESS}" \
        "Instances: ${INSTANCE_COUNT} | PIDs: [${PID_DISPLAY}] | Oldest PID: ${OLDEST_PID} | Uptime: ${FORMATTED_UPTIME}"

    exit 0
else
    # Process is NOT running
    printf " %-20s : %s%s [NOT RUNNING]%s\n" "Operational Status" "${COLOR_RED}${COLOR_BOLD}" "INACTIVE" "${COLOR_RESET}"
    printf " %-20s : 0 instances found\n" "Instance Count"
    echo "${COLOR_BLUE}================================================================${COLOR_RESET}"
    echo "${COLOR_RED}✗ Process '${TARGET_PROCESS}' is NOT running on this server.${COLOR_RESET}"

    # Record inactive check to audit log
    log_event "STOPPED" "${MODE_DESC}" "${TARGET_PROCESS}" \
        "Instances: 0 | PIDs: none | Process is NOT running"

    exit 1
fi
