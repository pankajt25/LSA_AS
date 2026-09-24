#!/usr/bin/env bash
# ==============================================================================
# Script Name: auto_service_recovery.sh
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# Problem Statement #17: Automatic Service Recovery
# Description: Checks a specified systemd service and restarts it automatically
#              if it is not running, logging all transitions and verification states.
# ==============================================================================

# Enable strict error handling:
# -u : Treat unset variables as an error when substituting
# -o pipefail : Return value of a pipeline is the status of the last command to exit
#               with a non-zero status
set -u
set -o pipefail

# ------------------------------------------------------------------------------
# Configuration & Argument Handling
# ------------------------------------------------------------------------------
# Why default to 'dummy-test':
# In a timed sprint and shared administration environment, default commands must
# adhere strictly to safety boundaries. Defaulting to 'dummy-test' prevents
# accidental disruptions to critical host/WSL services (e.g., ssh, cron, networking)
# if an operator runs the script without specifying an argument.
TARGET_SERVICE="${1:-dummy-test}"

# Why determine script directory dynamically:
# Using BASH_SOURCE ensures that file paths (such as the log directory) resolve
# relative to the project workspace regardless of the current working directory
# from which the administrator invokes this script.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/recovery.log"

# ANSI color codes for clear visual feedback in interactive terminal sessions
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_YELLOW="\033[1;33m"
COLOR_CYAN="\033[1;36m"
COLOR_BOLD="\033[1m"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Ensure log directory exists so recovery logs can be written reliably.
ensure_log_environment() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}" || {
            echo -e "${COLOR_RED}[CRITICAL ERROR] Failed to create log directory: ${LOG_DIR}${COLOR_RESET}" >&2
            exit 2
        }
    fi
}

# Standardized logging function:
# Why structured format:
# A structured log entry allows consistent parsing for automated monitoring,
# SIEM ingest, and HTML dashboard report generation.
# Fields: [Timestamp] Service | Prior State | Action | Result State
log_event() {
    local service="$1"
    local prior_state="$2"
    local action="$3"
    local result_state="$4"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[${timestamp}] Service: ${service} | Prior State: ${prior_state} | Action: ${action} | Result State: ${result_state}" >> "${LOG_FILE}"
}

# Determine appropriate privilege escalation prefix:
# Why check for sudo:
# Querying service status is unprivileged, but restarting a system service
# requires elevated permissions. Automatically prepending 'sudo' when run as
# a non-root user avoids permission denied errors while maintaining seamless execution.
get_privilege_prefix() {
    if [[ "${EUID}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            echo "sudo"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# ------------------------------------------------------------------------------
# Main Execution Logic
# ------------------------------------------------------------------------------

main() {
    ensure_log_environment
    local priv_prefix
    priv_prefix="$(get_privilege_prefix)"

    echo -e "${COLOR_CYAN}${COLOR_BOLD}=== Automatic Service Recovery Monitor ===${COLOR_RESET}"
    echo -e "Target Service : ${COLOR_BOLD}${TARGET_SERVICE}${COLOR_RESET}"
    echo -e "Log Destination: ${COLOR_BOLD}${LOG_FILE}${COLOR_RESET}"
    echo "--------------------------------------------------------"

    # Step 1: Probe current service status using systemctl is-active
    # Why is-active:
    # 'systemctl is-active' is the canonical machine-readable way to verify whether
    # a unit is active (running). It returns stdout such as 'active', 'inactive',
    # or 'failed', with exit code 0 if active and non-zero otherwise.
    local prior_state
    prior_state="$(systemctl is-active "${TARGET_SERVICE}" 2>/dev/null || true)"
    if [[ -z "${prior_state}" ]]; then
        prior_state="unknown"
    fi

    # Step 2: Evaluate health status
    if [[ "${prior_state}" == "active" ]]; then
        echo -e "${COLOR_GREEN}[OK] Service '${TARGET_SERVICE}' is healthy, no action needed.${COLOR_RESET}"
        log_event "${TARGET_SERVICE}" "${prior_state}" "Checked (healthy, no action needed)" "${prior_state}"
        exit 0
    fi

    # Step 3: Handle unhealthy or inactive service
    echo -e "${COLOR_YELLOW}[WARN] Service '${TARGET_SERVICE}' is currently '${prior_state}'. Initiating recovery...${COLOR_RESET}"

    # Step 4: Attempt restart
    # Why capture stderr & exit status:
    # If the service does not exist, unit file is broken, or permissions fail,
    # we must trap the exact error immediately rather than entering an infinite
    # recovery loop or hanging.
    local restart_output
    local restart_exit_code=0
    restart_output="$(${priv_prefix} systemctl restart "${TARGET_SERVICE}" 2>&1)" || restart_exit_code=$?

    if [[ ${restart_exit_code} -ne 0 ]]; then
        local err_summary
        err_summary=$(echo "${restart_output}" | tr '\n' ' ' | sed 's/  */ /g')
        echo -e "${COLOR_RED}[ERROR] Restart attempt failed (Exit Code ${restart_exit_code}): ${err_summary}${COLOR_RESET}"
        log_event "${TARGET_SERVICE}" "${prior_state}" "Restart attempt failed (${err_summary})" "${prior_state}"
        exit 1
    fi

    # Step 5: Wait for service initialization
    # Why sleep 2:
    # Many services require a brief initialization window to transition from
    # 'activating' to stable 'active' state, or to fail if immediate crashes occur.
    # Probing immediately without delay can cause false positives or race conditions.
    echo -e "${COLOR_CYAN}[INFO] Restart signal sent. Waiting 2 seconds for service stabilization...${COLOR_RESET}"
    sleep 2

    # Step 6: Post-recovery verification
    # Why re-verify:
    # A successful 'systemctl restart' exit code only guarantees the command was
    # accepted; verifying post-restart state ensures the service actually reached
    # and maintained an active state.
    local result_state
    result_state="$(systemctl is-active "${TARGET_SERVICE}" 2>/dev/null || true)"
    if [[ -z "${result_state}" ]]; then
        result_state="unknown"
    fi

    if [[ "${result_state}" == "active" ]]; then
        echo -e "${COLOR_GREEN}[SUCCESS] Service '${TARGET_SERVICE}' successfully recovered and is now active.${COLOR_RESET}"
        log_event "${TARGET_SERVICE}" "${prior_state}" "Restarted service" "${result_state}"
        exit 0
    else
        echo -e "${COLOR_RED}[FAILED] Recovery attempted, but service '${TARGET_SERVICE}' is in state: '${result_state}'.${COLOR_RESET}"
        log_event "${TARGET_SERVICE}" "${prior_state}" "Restart attempted but service remained inactive" "${result_state}"
        exit 1
    fi
}

main "$@"
