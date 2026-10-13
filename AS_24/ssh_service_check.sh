#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_24)
# Problem Statement #24: SSH Service Check
# Focus: SSH Administration & Service Monitoring
# Script: ssh_service_check.sh
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   1. Detects the correct SSH service name dynamically across distributions:
#      tries 'ssh' (Debian/Ubuntu/Mint) first, then 'sshd' (RHEL/CentOS/Fedora/Arch).
#   2. Inspects live runtime active status using systemd ('systemctl is-active <svc>'),
#      with automatic fallback to SysV init ('service <svc> status') when systemd
#      is unavailable (e.g., minimal containers, legacy hosts, or WSL1).
#   3. Inspects boot persistence status using 'systemctl is-enabled <svc>' (or SysV
#      runlevel inspection if systemd is unavailable).
#   4. Conducts an independent network socket cross-check via 'ss -tlnp | grep :22'
#      (or 'netstat -tlnp' / 'lsof' fallback) to confirm whether SSH is actively
#      bound and listening on its designated network port.
#   5. Evaluates and synthesizes a comprehensive combined status message covering
#      optimal, degraded/partial, inactive, and uninstalled service states.
#   6. Records all audit telemetry and check results chronologically with timestamps
#      into 'logs/ssh_check.log' and structured JSON 'logs/ssh_check.json'.
#   7. Provides comprehensive defensive error handling without crashing if neither
#      service exists or if systemd is unavailable.
#
# SANDBOXING CONSTRAINT:
#   Strictly read-only with respect to system services. Never starts, stops,
#   enables, or restarts ssh/sshd. All outputs confined to AS_24 directory.
# ==============================================================================

# Enable strict shell safety options:
# -u : Exit if an uninitialized variable is referenced (prevents typos)
# -o pipefail : Pipeline return status reflects last non-zero exit code
set -uo pipefail

# ------------------------------------------------------------------------------
# 1. DIRECTORY & ENVIRONMENT CONFIGURATION (SANDBOX CONFINED)
# ------------------------------------------------------------------------------
# Resolve the directory where this script resides to ensure all log files and
# artifacts remain strictly confined within the project directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/ssh_check.log"
JSON_FILE="${LOG_DIR}/ssh_check.json"

# Ensure the logs directory exists
mkdir -p "${LOG_DIR}"

# Default parameters
TARGET_PORT=22
CUSTOM_SERVICE=""
OUTPUT_JSON=0
QUIET_MODE=0
USE_COLOR=1

# Disable colors automatically if stdout is not an interactive terminal
if [ ! -t 1 ]; then
    USE_COLOR=0
fi

# ------------------------------------------------------------------------------
# 2. COLOR PALETTE DEFINITION
# ------------------------------------------------------------------------------
setup_colors() {
    if [ "${USE_COLOR}" -eq 1 ]; then
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_DIM=$'\033[2m'
        C_GREEN=$'\033[1;32m'
        C_RED=$'\033[1;31m'
        C_YELLOW=$'\033[1;33m'
        C_BLUE=$'\033[1;34m'
        C_MAGENTA=$'\033[1;35m'
        C_CYAN=$'\033[1;36m'
        C_WHITE=$'\033[1;37m'
    else
        C_RESET=""
        C_BOLD=""
        C_DIM=""
        C_GREEN=""
        C_RED=""
        C_YELLOW=""
        C_BLUE=""
        C_MAGENTA=""
        C_CYAN=""
        C_WHITE=""
    fi
}
setup_colors

# ------------------------------------------------------------------------------
# 3. CLI ARGUMENT PARSING & HELP DISPLAY
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
${C_BOLD}SSH Service Check — Automation Sprint #24 (E1ITA307)${C_RESET}
Usage: $(basename "$0") [OPTIONS]

${C_BOLD}DESCRIPTION:${C_RESET}
  Audits the SSH daemon on the local Linux host by dynamically detecting
  service naming ('ssh' vs 'sshd'), inspecting systemd/SysV active and boot
  persistence states, and independently verifying TCP socket listening on port 22.

${C_BOLD}OPTIONS:${C_RESET}
  -h, --help                 Display this manual and exit
  -j, --json                 Output pure structured JSON telemetry to stdout
  -p, --port <PORT>          Target TCP port to inspect for SSH (default: 22)
  -s, --service <NAME>       Override service candidate detection with a specified service
  -q, --quiet                Suppress human-readable console banners (useful for scripts)
      --no-color             Disable ANSI color highlights

${C_BOLD}EXAMPLES:${C_RESET}
  bash $(basename "$0")              # Standard live SSH service audit
  bash $(basename "$0") --json       # Structured JSON telemetry
  bash $(basename "$0") -p 2222      # Cross-check listening socket on port 2222
  bash $(basename "$0") -s cron      # Diagnostic check against an active system service

EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -j|--json)
            OUTPUT_JSON=1
            QUIET_MODE=1
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=1
            shift
            ;;
        --no-color)
            USE_COLOR=0
            setup_colors
            shift
            ;;
        -p|--port)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                TARGET_PORT="$2"
                shift 2
            else
                echo "${C_RED}[ERROR] Invalid port specified for $1.${C_RESET}" >&2
                exit 1
            fi
            ;;
        -s|--service)
            if [[ -n "${2:-}" ]]; then
                CUSTOM_SERVICE="$2"
                shift 2
            else
                echo "${C_RED}[ERROR] Service name argument required for $1.${C_RESET}" >&2
                exit 1
            fi
            ;;
        *)
            echo "${C_RED}[ERROR] Unknown argument: $1${C_RESET}" >&2
            echo "Use --help for usage instructions." >&2
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. LOGGING UTILITY FUNCTIONS
# ------------------------------------------------------------------------------
# Write timestamped entries both to console (if not quiet) and to persistent log
log_audit() {
    local level="$1"
    local step="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Append to persistent log file inside AS_24/logs/
    printf "[%s] [%-7s] [%-12s] %s\n" "${timestamp}" "${level}" "${step}" "${message}" >> "${LOG_FILE}"

    # Print to console unless suppressed
    if [ "${QUIET_MODE}" -eq 0 ]; then
        local color_lvl="${C_WHITE}"
        case "${level}" in
            INFO)    color_lvl="${C_CYAN}" ;;
            SUCCESS) color_lvl="${C_GREEN}" ;;
            WARN)    color_lvl="${C_YELLOW}" ;;
            ERROR)   color_lvl="${C_RED}" ;;
            STEP)    color_lvl="${C_MAGENTA}" ;;
        esac
        printf "${C_DIM}[%s]${C_RESET} ${color_lvl}[%-7s]${C_RESET} ${C_BOLD}[%-10s]${C_RESET} %s\n" \
            "$(date '+%H:%M:%S')" "${level}" "${step}" "${message}"
    fi
}

# ------------------------------------------------------------------------------
# 5. ENVIRONMENT & PLATFORM DISCOVERY
# ------------------------------------------------------------------------------
HOST_NAME="$(hostname 2>/dev/null || uname -n 2>/dev/null || echo "localhost")"
KERNEL_VERSION="$(uname -r 2>/dev/null || echo "Unknown-Kernel")"
KERNEL_ARCH="$(uname -m 2>/dev/null || echo "Unknown-Arch")"
UNAME_SYSTEM="$(uname -s 2>/dev/null || echo "Linux")"
TIMESTAMP_FULL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
TIMESTAMP_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")"

# Identify Linux distribution name and release
OS_DISTRO="Linux"
if [ -f /etc/os-release ]; then
    # Parse PRETTY_NAME without executing arbitrary code
    OS_DISTRO="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' 2>/dev/null || echo "Linux")"
elif [ "${UNAME_SYSTEM}" = "Darwin" ]; then
    OS_DISTRO="macOS $(sw_vers -productVersion 2>/dev/null || echo "Darwin")"
fi

# Detect WSL (Windows Subsystem for Linux)
IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=1
fi

# ------------------------------------------------------------------------------
# 6. INIT ARCHITECTURE DETECTION (systemd vs SysV init vs macOS launchd)
# ------------------------------------------------------------------------------
# Why this is necessary:
# Ubuntu/Debian and RHEL/CentOS systems utilize systemd as standard init.
# However, containerized environments, older Linux releases, and certain WSL
# distributions run SysV init or OpenRC without systemd PID 1.
# Detecting the init architecture prevents systemctl command failures from
# terminating execution or generating unhandled errors.
INIT_SYSTEM="unknown"
INIT_DETAILS=""

detect_init_architecture() {
    if [ "${UNAME_SYSTEM}" = "Darwin" ]; then
        INIT_SYSTEM="launchd"
        INIT_DETAILS="macOS launchd subsystem (remote login managed via systemsetup)"
        return 0
    fi

    # Check for systemd availability
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        # Confirm systemctl can communicate with the init bus
        local sys_run
        sys_run="$(systemctl is-system-running 2>&1 || true)"
        if [[ ! "${sys_run}" =~ "System has not been booted" && ! "${sys_run}" =~ "Failed to connect to bus" ]]; then
            INIT_SYSTEM="systemd"
            INIT_DETAILS="systemd init manager (PID 1 active, status: ${sys_run})"
            return 0
        fi
    fi

    # Fallback check for SysV init / service command
    if command -v service >/dev/null 2>&1 || [ -d /etc/init.d ]; then
        INIT_SYSTEM="sysvinit"
        INIT_DETAILS="SysV init architecture (using /usr/sbin/service and /etc/init.d/)"
        return 0
    fi

    INIT_SYSTEM="fallback"
    INIT_DETAILS="No standard init manager detected; relying on direct socket inspection"
}

# ------------------------------------------------------------------------------
# 7. REQUIREMENT 1: SERVICE NAME DETECTION ('ssh' vs 'sshd')
# ------------------------------------------------------------------------------
# Why this is necessary:
# Distribution conventions differ across the Linux ecosystem:
# - Debian, Ubuntu, Linux Mint, and Raspberry Pi OS name the OpenSSH unit 'ssh.service'
# - Red Hat Enterprise Linux, CentOS, Fedora, Rocky, Alma, Arch, and Alpine name it 'sshd.service'
# Hardcoding one service name causes immediate failure on distributions using the other.
# We test 'ssh' first, then 'sshd', and safely declare 'none' if neither exists.
DETECTED_SERVICE="none"
SERVICE_DETECTION_METHOD="none"
SERVICE_DETECTION_LOG=""

check_unit_systemd() {
    local svc="$1"
    # Method A: systemctl cat checks if a loaded or unit file exists
    if systemctl cat "${svc}.service" >/dev/null 2>&1; then
        return 0
    fi
    # Method B: systemctl list-unit-files
    if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -Eq "^${svc}\.service"; then
        return 0
    fi
    # Method C: systemctl show LoadState property
    local load_state
    load_state="$(systemctl show -p LoadState --value "${svc}" 2>/dev/null || echo "")"
    if [ "${load_state}" = "loaded" ]; then
        return 0
    fi
    # Method D: Direct file path check in standard systemd directories
    for path in "/lib/systemd/system/${svc}.service" \
                "/usr/lib/systemd/system/${svc}.service" \
                "/etc/systemd/system/${svc}.service"; do
        if [ -f "${path}" ]; then
            return 0
        fi
    done
    return 1
}

check_unit_sysv() {
    local svc="$1"
    # Check if SysV init script exists and is executable in /etc/init.d/
    if [ -x "/etc/init.d/${svc}" ]; then
        return 0
    fi
    # Check if service status recognizes the candidate
    if command -v service >/dev/null 2>&1; then
        local s_out
        s_out="$(service "${svc}" status 2>&1 || true)"
        if [[ ! "${s_out}" =~ "unrecognized service" && ! "${s_out}" =~ "could not be found" && ! "${s_out}" =~ "not found" ]]; then
            return 0
        fi
    fi
    return 1
}

detect_service_name() {
    # If user provided a specific service name to test via --service flag
    if [ -n "${CUSTOM_SERVICE}" ]; then
        log_audit "INFO" "DETECT" "Testing user-specified override service candidate: '${CUSTOM_SERVICE}'"
        if [ "${INIT_SYSTEM}" = "systemd" ] && check_unit_systemd "${CUSTOM_SERVICE}"; then
            DETECTED_SERVICE="${CUSTOM_SERVICE}"
            SERVICE_DETECTION_METHOD="user-override (systemd unit confirmed)"
            SERVICE_DETECTION_LOG="Found unit '${CUSTOM_SERVICE}.service' via systemd"
            return 0
        elif check_unit_sysv "${CUSTOM_SERVICE}"; then
            DETECTED_SERVICE="${CUSTOM_SERVICE}"
            SERVICE_DETECTION_METHOD="user-override (SysV init confirmed)"
            SERVICE_DETECTION_LOG="Found script '/etc/init.d/${CUSTOM_SERVICE}'"
            return 0
        else
            DETECTED_SERVICE="${CUSTOM_SERVICE}"
            SERVICE_DETECTION_METHOD="user-override (unverified)"
            SERVICE_DETECTION_LOG="User specified '${CUSTOM_SERVICE}', unit existence unconfirmed"
            return 0
        fi
    fi

    # macOS platform check
    if [ "${UNAME_SYSTEM}" = "Darwin" ]; then
        DETECTED_SERVICE="sshd"
        SERVICE_DETECTION_METHOD="macOS Remote Login subsystem"
        SERVICE_DETECTION_LOG="macOS uses launchd com.openssh.sshd / systemsetup"
        return 0
    fi

    # Candidate 1: Check 'ssh' (Debian / Ubuntu convention)
    log_audit "INFO" "DETECT" "Evaluating Candidate 1: 'ssh' (Debian/Ubuntu standard)..."
    if [ "${INIT_SYSTEM}" = "systemd" ] && check_unit_systemd "ssh"; then
        DETECTED_SERVICE="ssh"
        SERVICE_DETECTION_METHOD="systemd unit file discovery"
        SERVICE_DETECTION_LOG="Candidate 1 'ssh' matched: systemd unit file found"
        log_audit "SUCCESS" "DETECT" "Detected SSH service candidate: 'ssh' (Debian/Ubuntu)"
        return 0
    elif check_unit_sysv "ssh"; then
        DETECTED_SERVICE="ssh"
        SERVICE_DETECTION_METHOD="SysV init script discovery"
        SERVICE_DETECTION_LOG="Candidate 1 'ssh' matched: /etc/init.d/ssh exists"
        log_audit "SUCCESS" "DETECT" "Detected SSH service candidate: 'ssh' (SysV init)"
        return 0
    fi

    # Candidate 2: Check 'sshd' (RHEL / CentOS / Fedora / Arch convention)
    log_audit "INFO" "DETECT" "Candidate 1 ('ssh') not found. Evaluating Candidate 2: 'sshd' (RHEL/CentOS standard)..."
    if [ "${INIT_SYSTEM}" = "systemd" ] && check_unit_systemd "sshd"; then
        DETECTED_SERVICE="sshd"
        SERVICE_DETECTION_METHOD="systemd unit file discovery"
        SERVICE_DETECTION_LOG="Candidate 2 'sshd' matched: systemd unit file found"
        log_audit "SUCCESS" "DETECT" "Detected SSH service candidate: 'sshd' (RHEL/CentOS)"
        return 0
    elif check_unit_sysv "sshd"; then
        DETECTED_SERVICE="sshd"
        SERVICE_DETECTION_METHOD="SysV init script discovery"
        SERVICE_DETECTION_LOG="Candidate 2 'sshd' matched: /etc/init.d/sshd exists"
        log_audit "SUCCESS" "DETECT" "Detected SSH service candidate: 'sshd' (SysV init)"
        return 0
    fi

    # Check for sshd binary on disk even if service files are absent
    if command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ]; then
        local bin_path
        bin_path="$(command -v sshd 2>/dev/null || echo "/usr/sbin/sshd")"
        DETECTED_SERVICE="sshd"
        SERVICE_DETECTION_METHOD="binary discovery (${bin_path})"
        SERVICE_DETECTION_LOG="sshd binary present at ${bin_path}, but init service files absent"
        log_audit "WARN" "DETECT" "OpenSSH daemon binary exists at ${bin_path}, but no active systemd/SysV unit registered"
        return 0
    fi

    # Neither service candidate exists
    DETECTED_SERVICE="none"
    SERVICE_DETECTION_METHOD="not-found"
    SERVICE_DETECTION_LOG="Neither 'ssh' nor 'sshd' service found; OpenSSH server not installed"
    log_audit "WARN" "DETECT" "Neither 'ssh' nor 'sshd' service found on this system"
    return 0
}

# ------------------------------------------------------------------------------
# 8. REQUIREMENT 2: ACTIVE STATUS INSPECTION & FALLBACK
# ------------------------------------------------------------------------------
# Checks if the service is currently executing.
# Preferred: 'systemctl is-active <service>'
# Fallback: 'service <service> status' if systemd is unavailable
ACTIVE_STATUS="unknown"
ACTIVE_CODE=99
ACTIVE_OUTPUT=""
ACTIVE_EXPLANATION=""

check_active_state() {
    # Case: Service does not exist
    if [ "${DETECTED_SERVICE}" = "none" ]; then
        ACTIVE_STATUS="not-installed"
        ACTIVE_CODE=4
        ACTIVE_OUTPUT="Unit not found"
        ACTIVE_EXPLANATION="Neither 'ssh' nor 'sshd' service is installed or registered"
        log_audit "WARN" "ACTIVE" "Active state: NOT INSTALLED (${ACTIVE_EXPLANATION})"
        return 0
    fi

    # Case: macOS Darwin
    if [ "${UNAME_SYSTEM}" = "Darwin" ]; then
        log_audit "INFO" "ACTIVE" "macOS detected: checking Remote Login via 'systemsetup -getremotelogin'..."
        local mac_out
        mac_out="$(systemsetup -getremotelogin 2>&1 || true)"
        ACTIVE_OUTPUT="${mac_out}"
        if [[ "${mac_out}" =~ "On" ]]; then
            ACTIVE_STATUS="active"
            ACTIVE_CODE=0
            ACTIVE_EXPLANATION="macOS Remote Login (SSH) is enabled and active"
        else
            ACTIVE_STATUS="inactive"
            ACTIVE_CODE=3
            ACTIVE_EXPLANATION="macOS Remote Login (SSH) is disabled/inactive"
        fi
        log_audit "SUCCESS" "ACTIVE" "macOS Remote Login status: ${ACTIVE_STATUS} (${mac_out})"
        return 0
    fi

    # Case: systemd is available and active
    if [ "${INIT_SYSTEM}" = "systemd" ]; then
        log_audit "INFO" "ACTIVE" "Executing systemd check: 'systemctl is-active ${DETECTED_SERVICE}'..."
        set +e
        ACTIVE_OUTPUT="$(systemctl is-active "${DETECTED_SERVICE}" 2>&1)"
        ACTIVE_CODE=$?
        set -e

        case "${ACTIVE_CODE}" in
            0)
                ACTIVE_STATUS="active"
                ACTIVE_EXPLANATION="Service daemon is running actively under systemd"
                log_audit "SUCCESS" "ACTIVE" "Service '${DETECTED_SERVICE}' is ACTIVE (exit code 0)"
                ;;
            3)
                ACTIVE_STATUS="inactive"
                ACTIVE_EXPLANATION="Service unit exists but is currently stopped or inactive"
                log_audit "WARN" "ACTIVE" "Service '${DETECTED_SERVICE}' is INACTIVE/STOPPED (exit code 3)"
                ;;
            4)
                ACTIVE_STATUS="not-found"
                ACTIVE_EXPLANATION="Service unit file could not be found by systemd manager"
                log_audit "WARN" "ACTIVE" "Service '${DETECTED_SERVICE}' NOT FOUND by systemd (exit code 4)"
                ;;
            *)
                # Sub-states: failed, activating, deactivating, etc.
                ACTIVE_STATUS="${ACTIVE_OUTPUT:-failed}"
                ACTIVE_EXPLANATION="Service reported non-zero status '${ACTIVE_OUTPUT}' (exit code: ${ACTIVE_CODE})"
                log_audit "ERROR" "ACTIVE" "Service '${DETECTED_SERVICE}' returned '${ACTIVE_STATUS}' (exit code ${ACTIVE_CODE})"
                ;;
        esac
        return 0
    fi

    # Case: SysV init fallback (systemd unavailable or inoperative)
    log_audit "WARN" "ACTIVE" "systemd unavailable. Engaging SysV fallback: 'service ${DETECTED_SERVICE} status'..."
    set +e
    ACTIVE_OUTPUT="$(service "${DETECTED_SERVICE}" status 2>&1)"
    ACTIVE_CODE=$?
    set -e

    if [ "${ACTIVE_CODE}" -eq 0 ]; then
        ACTIVE_STATUS="active"
        ACTIVE_EXPLANATION="SysV init reported service running (exit code 0)"
        log_audit "SUCCESS" "ACTIVE" "SysV fallback: '${DETECTED_SERVICE}' is ACTIVE"
    else
        ACTIVE_STATUS="inactive"
        ACTIVE_EXPLANATION="SysV init reported service stopped or failed (exit code ${ACTIVE_CODE})"
        log_audit "WARN" "ACTIVE" "SysV fallback: '${DETECTED_SERVICE}' is INACTIVE (code ${ACTIVE_CODE})"
    fi
}

# ------------------------------------------------------------------------------
# 9. REQUIREMENT 3: BOOT PERSISTENCE INSPECTION ('is-enabled')
# ------------------------------------------------------------------------------
# Checks if the service is configured to automatically launch upon system boot.
# Preferred: 'systemctl is-enabled <service>'
# Fallback: SysV runlevel symlinks inspection (/etc/rc*.d/S*<svc>)
ENABLED_STATUS="unknown"
ENABLED_CODE=99
ENABLED_OUTPUT=""
ENABLED_EXPLANATION=""

check_enabled_state() {
    # Case: Service does not exist
    if [ "${DETECTED_SERVICE}" = "none" ]; then
        ENABLED_STATUS="not-installed"
        ENABLED_CODE=4
        ENABLED_OUTPUT="Unit not found"
        ENABLED_EXPLANATION="Cannot inspect boot persistence for non-existent service"
        log_audit "WARN" "ENABLED" "Boot persistence: NOT INSTALLED"
        return 0
    fi

    # Case: macOS Darwin
    if [ "${UNAME_SYSTEM}" = "Darwin" ]; then
        if [ "${ACTIVE_STATUS}" = "active" ]; then
            ENABLED_STATUS="enabled"
            ENABLED_CODE=0
            ENABLED_OUTPUT="Remote Login: On"
            ENABLED_EXPLANATION="macOS Remote Login is persistent across system reboots"
        else
            ENABLED_STATUS="disabled"
            ENABLED_CODE=1
            ENABLED_OUTPUT="Remote Login: Off"
            ENABLED_EXPLANATION="macOS Remote Login is disabled"
        fi
        log_audit "INFO" "ENABLED" "macOS Remote Login persistence: ${ENABLED_STATUS}"
        return 0
    fi

    # Case: systemd is available
    if [ "${INIT_SYSTEM}" = "systemd" ]; then
        log_audit "INFO" "ENABLED" "Executing systemd check: 'systemctl is-enabled ${DETECTED_SERVICE}'..."
        set +e
        ENABLED_OUTPUT="$(systemctl is-enabled "${DETECTED_SERVICE}" 2>&1)"
        ENABLED_CODE=$?
        set -e

        case "${ENABLED_CODE}" in
            0)
                ENABLED_STATUS="enabled"
                ENABLED_EXPLANATION="Service has active symlink in systemd boot targets (multi-user.target)"
                log_audit "SUCCESS" "ENABLED" "Service '${DETECTED_SERVICE}' is ENABLED at boot (code 0)"
                ;;
            1)
                if [[ "${ENABLED_OUTPUT}" =~ "disabled" ]]; then
                    ENABLED_STATUS="disabled"
                    ENABLED_EXPLANATION="Service will NOT automatically start on system boot"
                elif [[ "${ENABLED_OUTPUT}" =~ "masked" ]]; then
                    ENABLED_STATUS="masked"
                    ENABLED_EXPLANATION="Service unit is masked (symlinked to /dev/null)"
                elif [[ "${ENABLED_OUTPUT}" =~ "static" ]]; then
                    ENABLED_STATUS="static"
                    ENABLED_EXPLANATION="Service is static (starts only on demand or by socket/dependency)"
                else
                    ENABLED_STATUS="${ENABLED_OUTPUT:-disabled}"
                    ENABLED_EXPLANATION="Service boot state: ${ENABLED_OUTPUT}"
                fi
                log_audit "WARN" "ENABLED" "Service '${DETECTED_SERVICE}' boot status: ${ENABLED_STATUS} (code 1)"
                ;;
            4)
                ENABLED_STATUS="not-found"
                ENABLED_EXPLANATION="No unit file found in systemd search paths"
                log_audit "WARN" "ENABLED" "Service '${DETECTED_SERVICE}' unit not found (code 4)"
                ;;
            *)
                ENABLED_STATUS="${ENABLED_OUTPUT:-unknown}"
                ENABLED_EXPLANATION="systemctl is-enabled returned code ${ENABLED_CODE} (${ENABLED_OUTPUT})"
                log_audit "WARN" "ENABLED" "Service '${DETECTED_SERVICE}' boot status: ${ENABLED_STATUS} (code ${ENABLED_CODE})"
                ;;
        esac
        return 0
    fi

    # Case: SysV init fallback
    log_audit "INFO" "ENABLED" "systemd unavailable. Inspecting SysV runlevel links in /etc/rc*.d/..."
    local found_rc=0
    for rc_link in /etc/rc[2345].d/S*"${DETECTED_SERVICE}"; do
        if [ -e "${rc_link}" ]; then
            found_rc=1
            break
        fi
    done

    if [ "${found_rc}" -eq 1 ]; then
        ENABLED_STATUS="enabled"
        ENABLED_CODE=0
        ENABLED_OUTPUT="SysV runlevel S-links present"
        ENABLED_EXPLANATION="Start symlinks found in default multi-user runlevels (/etc/rc[2-5].d)"
        log_audit "SUCCESS" "ENABLED" "SysV fallback: service '${DETECTED_SERVICE}' is ENABLED at boot"
    else
        ENABLED_STATUS="disabled"
        ENABLED_CODE=1
        ENABLED_OUTPUT="No SysV runlevel S-links"
        ENABLED_EXPLANATION="No start symlinks found in /etc/rc*.d for '${DETECTED_SERVICE}'"
        log_audit "WARN" "ENABLED" "SysV fallback: service '${DETECTED_SERVICE}' is DISABLED at boot"
    fi
}

# ------------------------------------------------------------------------------
# 10. REQUIREMENT 4: PORT LISTENING CROSS-CHECK ('ss -tlnp' / 'netstat')
# ------------------------------------------------------------------------------
# Why this is necessary:
# A service may report 'active' in systemd (due to a stale PID or hanging fork),
# yet fail to bind to its designated network port due to socket errors, firewall
# restrictions, or IP address conflicts.
# Conversely, in containerized or custom environments, an SSH daemon may listen
# on port 22 directly without a systemd service wrapper.
# Conducting an independent socket cross-check catches these edge cases.
PORT_STATUS="unknown"
PORT_COMMAND_USED=""
PORT_RAW_MATCH=""
PORT_PROCESS_INFO="None"
PORT_EXPLANATION=""

check_listening_socket() {
    log_audit "INFO" "SOCKET" "Performing independent network socket cross-check for port ${TARGET_PORT}..."

    local socket_match=""

    # Attempt 1: Modern iproute2 'ss -tlnp' (includes process PID if permitted)
    if command -v ss >/dev/null 2>&1; then
        PORT_COMMAND_USED="ss -tlnp (fallback: ss -tln)"
        # Match pattern: :<port> followed by word boundary or space
        socket_match="$(ss -tlnp 2>/dev/null | grep -E ":(${TARGET_PORT})\b" || true)"
        
        # If ss with -p was restricted or returned empty, try ss -tln
        if [ -z "${socket_match}" ]; then
            socket_match="$(ss -tln 2>/dev/null | grep -E ":(${TARGET_PORT})\b" || true)"
        fi
    # Attempt 2: Legacy net-tools 'netstat -tlnp' fallback
    elif command -v netstat >/dev/null 2>&1; then
        PORT_COMMAND_USED="netstat -tlnp (fallback: netstat -tln)"
        socket_match="$(netstat -tlnp 2>/dev/null | grep -E ":(${TARGET_PORT})\b" || true)"
        if [ -z "${socket_match}" ]; then
            socket_match="$(netstat -tln 2>/dev/null | grep -E ":(${TARGET_PORT})\b" || true)"
        fi
    # Attempt 3: lsof fallback
    elif command -v lsof >/dev/null 2>&1; then
        PORT_COMMAND_USED="lsof -iTCP:${TARGET_PORT}"
        socket_match="$(lsof -iTCP:"${TARGET_PORT}" -sTCP:LISTEN -P -n 2>/dev/null | grep -v '^COMMAND' || true)"
    else
        PORT_COMMAND_USED="socket inspection unavailable"
        socket_match=""
    fi

    # Evaluate socket findings
    if [ -n "${socket_match}" ]; then
        PORT_STATUS="listening"
        PORT_RAW_MATCH="$(echo "${socket_match}" | head -n 1 | tr -s ' ')"
        PORT_EXPLANATION="A TCP socket is actively bound and accepting connections on port ${TARGET_PORT}"

        # Extract process or daemon name if available in socket output
        if [[ "${PORT_RAW_MATCH}" =~ users:\(\(\"([^\"]+)\" ]]; then
            PORT_PROCESS_INFO="${BASH_REMATCH[1]}"
        elif [[ "${PORT_RAW_MATCH}" =~ ([0-9]+)/([a-zA-Z0-9_\.-]+) ]]; then
            PORT_PROCESS_INFO="${BASH_REMATCH[2]} (PID ${BASH_REMATCH[1]})"
        else
            PORT_PROCESS_INFO="Detected (PID hidden/unprivileged)"
        fi

        log_audit "SUCCESS" "SOCKET" "Port ${TARGET_PORT} is LISTENING. Match: ${PORT_RAW_MATCH}"
    else
        PORT_STATUS="not-listening"
        PORT_RAW_MATCH="None"
        PORT_PROCESS_INFO="None"
        PORT_EXPLANATION="No active TCP listening sockets bound to port ${TARGET_PORT}"
        log_audit "WARN" "SOCKET" "Port ${TARGET_PORT} is NOT LISTENING (no bound TCP sockets detected)"
    fi
}

# ------------------------------------------------------------------------------
# 11. REQUIREMENT 5 & 7: COMBINED STATUS SYNTHESIS & ERROR HANDLING
# ------------------------------------------------------------------------------
# Synthesizes the active state, boot persistence state, and port listening state
# into a clear human-readable status banner and standardized health classification.
OVERALL_HEALTH="CRITICAL"
STATUS_ICON="❌"
COMBINED_MESSAGE=""
REMEDIATION_HINT=""

synthesize_status() {
    # Scenario A: Neither 'ssh' nor 'sshd' service is installed
    if [ "${DETECTED_SERVICE}" = "none" ]; then
        if [ "${PORT_STATUS}" = "listening" ]; then
            OVERALL_HEALTH="WARNING"
            STATUS_ICON="⚠️"
            COMBINED_MESSAGE="⚠️ SSH service ('ssh'/'sshd') is NOT INSTALLED via systemd/SysV, but port ${TARGET_PORT} IS LISTENING (standalone daemon or container detected)"
            REMEDIATION_HINT="Port ${TARGET_PORT} is held by a non-standard or containerized process: ${PORT_PROCESS_INFO}."
        else
            OVERALL_HEALTH="CRITICAL"
            STATUS_ICON="❌"
            COMBINED_MESSAGE="❌ SSH is NOT INSTALLED (neither 'ssh' nor 'sshd' service found on this system, and port ${TARGET_PORT} is not listening)"
            if [ -f /etc/debian_version ] || [[ "${OS_DISTRO}" =~ Ubuntu|Debian ]]; then
                REMEDIATION_HINT="To install OpenSSH server on Debian/Ubuntu: sudo apt-get update && sudo apt-get install openssh-server"
            elif [ -f /etc/redhat-release ] || [[ "${OS_DISTRO}" =~ RHEL|CentOS|Fedora|Rocky ]]; then
                REMEDIATION_HINT="To install OpenSSH server on RHEL/CentOS/Fedora: sudo dnf install openssh-server"
            else
                REMEDIATION_HINT="Install OpenSSH server using your distribution's package manager."
            fi
        fi
        return 0
    fi

    # Scenario B: Service is installed and ACTIVE
    if [ "${ACTIVE_STATUS}" = "active" ]; then
        if [ "${PORT_STATUS}" = "listening" ]; then
            if [ "${ENABLED_STATUS}" = "enabled" ]; then
                # Optimal State: Active + Enabled + Listening
                OVERALL_HEALTH="OPTIMAL"
                STATUS_ICON="✅"
                COMBINED_MESSAGE="✅ SSH ('${DETECTED_SERVICE}') is ACTIVE, ENABLED at boot, and LISTENING on port ${TARGET_PORT}"
                REMEDIATION_HINT="SSH service configuration is optimal and accepting remote connections."
            else
                # Partial State: Active + Listening, but Not Enabled at boot
                OVERALL_HEALTH="WARNING"
                STATUS_ICON="⚠️"
                COMBINED_MESSAGE="⚠️ SSH ('${DETECTED_SERVICE}') is ACTIVE and LISTENING on port ${TARGET_PORT}, but ${ENABLED_STATUS^^} at boot"
                REMEDIATION_HINT="To enable SSH automatically on boot: sudo systemctl enable ${DETECTED_SERVICE}"
            fi
        else
            # Degraded State: Active, but NOT Listening on target port
            OVERALL_HEALTH="WARNING"
            STATUS_ICON="⚠️"
            COMBINED_MESSAGE="⚠️ SSH ('${DETECTED_SERVICE}') is ACTIVE and ${ENABLED_STATUS^^} at boot, but NOT LISTENING on port ${TARGET_PORT}"
            REMEDIATION_HINT="SSH service is running but may be bound to a non-standard port or socket activation has failed. Check /etc/ssh/sshd_config."
        fi
        return 0
    fi

    # Scenario C: Service is installed but INACTIVE / STOPPED
    if [ "${ENABLED_STATUS}" = "enabled" ]; then
        # Partial State: Inactive, but Enabled at boot
        OVERALL_HEALTH="CRITICAL"
        STATUS_ICON="❌"
        COMBINED_MESSAGE="❌ SSH ('${DETECTED_SERVICE}') is INACTIVE (${ACTIVE_STATUS}), though ENABLED at boot, and NOT LISTENING on port ${TARGET_PORT}"
        REMEDIATION_HINT="To start SSH service: sudo systemctl start ${DETECTED_SERVICE} (or check 'journalctl -xeu ${DETECTED_SERVICE}')"
    else
        # Inactive + Disabled
        OVERALL_HEALTH="CRITICAL"
        STATUS_ICON="❌"
        COMBINED_MESSAGE="❌ SSH ('${DETECTED_SERVICE}') is INACTIVE (${ACTIVE_STATUS}), ${ENABLED_STATUS^^} at boot, and NOT LISTENING on port ${TARGET_PORT}"
        REMEDIATION_HINT="To activate and enable SSH: sudo systemctl enable --now ${DETECTED_SERVICE}"
    fi
}

# ------------------------------------------------------------------------------
# 12. TERMINAL DASHBOARD BANNER DISPLAY
# ------------------------------------------------------------------------------
display_terminal_report() {
    local health_color="${C_RED}"
    case "${OVERALL_HEALTH}" in
        OPTIMAL) health_color="${C_GREEN}" ;;
        WARNING) health_color="${C_YELLOW}" ;;
        CRITICAL) health_color="${C_RED}" ;;
    esac

    echo ""
    echo "${C_BOLD}================================================================================${C_RESET}"
    echo "       ${C_CYAN}SSH SERVICE AUDIT REPORT — AUTOMATION SPRINT #24 (E1ITA307)${C_RESET}       "
    echo "${C_BOLD}================================================================================${C_RESET}"
    printf " ${C_DIM}Timestamp :${C_RESET} %s\n" "${TIMESTAMP_FULL}"
    printf " ${C_DIM}Hostname  :${C_RESET} %s | ${C_DIM}OS:${C_RESET} %s | ${C_DIM}Kernel:${C_RESET} %s\n" \
        "${HOST_NAME}" "${OS_DISTRO}" "${KERNEL_VERSION}"
    printf " ${C_DIM}Init System:${C_RESET} %s\n" "${INIT_DETAILS}"
    echo "--------------------------------------------------------------------------------"
    echo " ${C_BOLD}SERVICE INSPECTION MATRIX:${C_RESET}"
    echo "--------------------------------------------------------------------------------"
    printf "  %-24s : %s\n" "Detected Service Name" "${C_BOLD}${DETECTED_SERVICE}${C_RESET} (${SERVICE_DETECTION_METHOD})"
    
    # Active State Badge
    local active_badge="${C_RED}${ACTIVE_STATUS^^}${C_RESET}"
    [ "${ACTIVE_STATUS}" = "active" ] && active_badge="${C_GREEN}ACTIVE (running)${C_RESET}"
    printf "  %-24s : %s (%s)\n" "Active Status" "${active_badge}" "${ACTIVE_EXPLANATION}"

    # Enabled State Badge
    local enabled_badge="${C_YELLOW}${ENABLED_STATUS^^}${C_RESET}"
    [ "${ENABLED_STATUS}" = "enabled" ] && enabled_badge="${C_GREEN}ENABLED (boot auto-start)${C_RESET}"
    [ "${ENABLED_STATUS}" = "disabled" ] && enabled_badge="${C_RED}DISABLED (manual start)${C_RESET}"
    printf "  %-24s : %s (%s)\n" "Boot Persistence" "${enabled_badge}" "${ENABLED_EXPLANATION}"

    # Port Listening Badge
    local port_badge="${C_RED}NOT LISTENING${C_RESET}"
    [ "${PORT_STATUS}" = "listening" ] && port_badge="${C_GREEN}LISTENING on port ${TARGET_PORT}${C_RESET}"
    printf "  %-24s : %s (%s)\n" "TCP Port ${TARGET_PORT} Socket" "${port_badge}" "${PORT_EXPLANATION}"

    if [ "${PORT_STATUS}" = "listening" ]; then
        printf "  %-24s : %s\n" "Socket Bound Address" "${PORT_RAW_MATCH}"
        printf "  %-24s : %s\n" "Bound Process" "${PORT_PROCESS_INFO}"
    fi

    echo "--------------------------------------------------------------------------------"
    echo " ${C_BOLD}OVERALL STATUS EVALUATION:${C_RESET}"
    echo "--------------------------------------------------------------------------------"
    printf "  ${health_color}%s${C_RESET}\n" "${COMBINED_MESSAGE}"
    if [ -n "${REMEDIATION_HINT}" ]; then
        echo ""
        printf "  ${C_DIM}Remediation / Admin Note:${C_RESET}\n"
        printf "  %s\n" "${REMEDIATION_HINT}"
    fi
    echo "${C_BOLD}================================================================================${C_RESET}"
    echo " ${C_DIM}Audit Log File  :${C_RESET} ${LOG_FILE}"
    echo " ${C_DIM}JSON Telemetry  :${C_RESET} ${JSON_FILE}"
    echo "${C_BOLD}================================================================================${C_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# 13. STRUCTURED JSON TELEMETRY EMISSION
# ------------------------------------------------------------------------------
write_json_telemetry() {
    # Generate structured JSON for run.sh HTML dashboard generation
    cat << JSON_EOF > "${JSON_FILE}"
{
  "timestamp": "${TIMESTAMP_FULL}",
  "timestamp_iso": "${TIMESTAMP_ISO}",
  "hostname": "${HOST_NAME}",
  "os_distro": "${OS_DISTRO}",
  "kernel": "${KERNEL_VERSION}",
  "arch": "${KERNEL_ARCH}",
  "is_wsl": ${IS_WSL},
  "init_system": {
    "type": "${INIT_SYSTEM}",
    "details": "${INIT_DETAILS}"
  },
  "service": {
    "detected_name": "${DETECTED_SERVICE}",
    "detection_method": "${SERVICE_DETECTION_METHOD}",
    "detection_log": "${SERVICE_DETECTION_LOG}"
  },
  "active_check": {
    "status": "${ACTIVE_STATUS}",
    "exit_code": ${ACTIVE_CODE},
    "raw_output": "${ACTIVE_OUTPUT}",
    "explanation": "${ACTIVE_EXPLANATION}"
  },
  "enabled_check": {
    "status": "${ENABLED_STATUS}",
    "exit_code": ${ENABLED_CODE},
    "raw_output": "${ENABLED_OUTPUT}",
    "explanation": "${ENABLED_EXPLANATION}"
  },
  "port_check": {
    "port": ${TARGET_PORT},
    "status": "${PORT_STATUS}",
    "command_used": "${PORT_COMMAND_USED}",
    "raw_match": "${PORT_RAW_MATCH}",
    "process": "${PORT_PROCESS_INFO}",
    "explanation": "${PORT_EXPLANATION}"
  },
  "evaluation": {
    "overall_health": "${OVERALL_HEALTH}",
    "status_icon": "${STATUS_ICON}",
    "combined_message": "${COMBINED_MESSAGE}",
    "remediation_hint": "${REMEDIATION_HINT}"
  }
}
JSON_EOF

    if [ "${OUTPUT_JSON}" -eq 1 ]; then
        cat "${JSON_FILE}"
    fi
}

# ------------------------------------------------------------------------------
# 14. MAIN EXECUTION PIPELINE
# ------------------------------------------------------------------------------
main() {
    # Step 1: Detect init architecture
    detect_init_architecture

    # Step 2: Dynamically detect SSH service name ('ssh' vs 'sshd')
    detect_service_name

    # Step 3: Inspect active running state
    check_active_state

    # Step 4: Inspect boot persistence state
    check_enabled_state

    # Step 5: Perform independent socket cross-check on port 22
    check_listening_socket

    # Step 6: Synthesize combined status and health evaluation
    synthesize_status

    # Step 7: Record final evaluation in persistent audit log
    log_audit "INFO" "EVAL" "Combined Result: ${COMBINED_MESSAGE}"

    # Step 8: Write JSON telemetry file
    write_json_telemetry

    # Step 9: Render terminal report if not running in JSON/quiet mode
    if [ "${QUIET_MODE}" -eq 0 ]; then
        display_terminal_report
    fi

    # Exit code strategy:
    # 0 if optimal (active + enabled + listening)
    # 1 if service inactive or uninstalled
    # 2 if partially active or degraded
    if [ "${OVERALL_HEALTH}" = "OPTIMAL" ]; then
        return 0
    elif [ "${OVERALL_HEALTH}" = "WARNING" ]; then
        return 2
    else
        return 1
    fi
}

# Invoke main entrypoint
main "$@"
