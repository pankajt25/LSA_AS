#!/usr/bin/env bash
# ==============================================================================
# Script Name : service_availability_check.sh
# Course      : Linux System Administration (E1ITA307) — Automation Sprint
# Problem #16 : Service Availability Check — Focus: Service Monitoring
# Description : Checks service availability (active status) and boot persistence
#               (enabled status), with systemd inspection and SysV init fallback.
#               Outputs user-friendly status banners, logs runs to a persistent
#               audit file, and returns standardized exit codes.
# ==============================================================================

# Enable strict shell safety options:
# -u : Exit immediately if an uninitialized variable is referenced (prevents typos)
# -o pipefail : Causes a pipeline to return the exit status of the last command in the
#               pipe that returned a non-zero status (prevents masked pipeline errors)
set -uo pipefail

# ------------------------------------------------------------------------------
# DIRECTORY & FILE PATH CONFIGURATION (SANDBOX CONSTRAINED)
# ------------------------------------------------------------------------------
# Resolve the directory where this script resides to ensure all relative paths
# (logs, reports) stay strictly confined within the project sandbox directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/service_check.log"
REPORT_FILE="${SCRIPT_DIR}/report.html"

# Default service to check if no argument is passed on CLI.
# 'cron' is chosen because it is standard, pre-installed, enabled, and active
# across Debian/Ubuntu/RHEL/WSL distributions without requiring root changes.
DEFAULT_SERVICE="cron"

# ------------------------------------------------------------------------------
# TERMINAL COLOR FORMATTING
# ------------------------------------------------------------------------------
# Colors enhance human readability in terminal dashboards.
# If stdout is redirected or not a TTY, disable color codes to prevent log pollution.
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
# USAGE INSTRUCTIONS
# ------------------------------------------------------------------------------
# Function: print_usage
# Explains script syntax, flags, defaults, and return codes for end users.
print_usage() {
    cat << EOF
${COLOR_BOLD}Usage:${COLOR_RESET} $(basename "$0") [SERVICE_NAME] [OPTIONS]

${COLOR_BOLD}Description:${COLOR_RESET}
  Monitors the operational availability and boot persistence of a specified Linux
  system service. Automatically detects init architecture (systemd with fallback
  to SysV init), logs checks to an audit file, and returns standardized exit codes.

${COLOR_BOLD}Arguments:${COLOR_RESET}
  SERVICE_NAME          Name of the service to inspect (e.g., cron, ssh, rsync).
                        Defaults to "${DEFAULT_SERVICE}" if omitted.

${COLOR_BOLD}Options:${COLOR_RESET}
  -h, --help            Show this help manual and exit.
  -r, --report          Generate/update HTML dashboard (report.html) after the check.
  -j, --json            Output check results in JSON format to stdout.

${COLOR_BOLD}Exit Codes:${COLOR_RESET}
  0  Service is ACTIVE and running
  1  Service is INACTIVE, STOPPED, or FAILED
  2  Service was NOT FOUND on this system
  3  Invalid invocation or critical environment failure

${COLOR_BOLD}Examples:${COLOR_RESET}
  $ $(basename "$0")                      # Inspects default service (${DEFAULT_SERVICE})
  $ $(basename "$0") cron                 # Inspects active cron service
  $ $(basename "$0") rsync                # Inspects inactive/disabled rsync service
  $ $(basename "$0") not-a-real-service   # Inspects missing service (demonstrates error handling)
  $ $(basename "$0") cron --report        # Inspects cron and refreshes report.html
EOF
}

# ------------------------------------------------------------------------------
# INIT SYSTEM DETECTION
# ------------------------------------------------------------------------------
# Function: detect_init_system
# Why this is needed:
# Linux environments vary substantially across bare metal, VMs, WSL (Windows
# Subsystem for Linux), and containerized environments (Docker/Podman).
# Systemd requires PID 1 to be systemd and '/run/systemd/system' to exist.
# WSL 1 and minimal containers often run classic SysV init or direct init wrappers.
# Detecting the init system at runtime avoids fatal errors when 'systemctl' is
# either missing or unable to communicate with the D-Bus system bus.
detect_init_system() {
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        # Check if systemd is actively responding to control commands
        if systemctl is-system-running >/dev/null 2>&1 || [ "$?" -ne 127 ]; then
            echo "systemd"
            return 0
        fi
    fi

    # Fallback to SysV init if systemd is absent or inactive
    if command -v service >/dev/null 2>&1 || [ -d /etc/init.d ]; then
        echo "sysvinit"
        return 0
    fi

    echo "unknown"
    return 1
}

# ------------------------------------------------------------------------------
# LOGGING UTILITY
# ------------------------------------------------------------------------------
# Function: append_log_entry
# Why this is needed:
# Requirement 5 requires logging check results with timestamps to a file inside
# the sandbox (logs/service_check.log) so repeated runs build an audit history.
# We ensure the log directory exists, and append a structured, machine-parsable
# format while preserving human readability.
append_log_entry() {
    local timestamp="$1"
    local service="$2"
    local init_sys="$3"
    local active_st="$4"
    local enabled_st="$5"
    local exit_cd="$6"
    local description="$7"

    # Ensure log directory exists within sandbox
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}"
    fi

    # Format: [TIMESTAMP] [INIT] SERVICE=<name> ACTIVE=<state> ENABLED=<state> EXIT=<code|0|1|2> MSG="<desc>"
    printf "[%s] [%s] SERVICE=%s ACTIVE=%s ENABLED=%s EXIT=%s MSG=\"%s\"\n" \
        "${timestamp}" \
        "${init_sys}" \
        "${service}" \
        "${active_st}" \
        "${enabled_st}" \
        "${exit_cd}" \
        "${description}" >> "${LOG_FILE}"
}

# ------------------------------------------------------------------------------
# SYSTEMD SERVICE INSPECTION ENGINE
# ------------------------------------------------------------------------------
# Function: inspect_systemd_service
# Explaining the logic:
# 1. First, check if the unit exists at all:
#    'systemctl show -p LoadState --value <service>' returns 'not-found' if
#    the unit file is missing or invalid.
# 2. If unit exists, check runtime active state:
#    'systemctl is-active <service>' returns:
#       'active'   (exit 0) -> Running
#       'inactive' (exit 3) -> Stopped / idle
#       'failed'   (exit 3/4) -> Crashed / error
# 3. Separately check boot enablement persistence:
#    'systemctl is-enabled <service>' returns:
#       'enabled'  -> starts automatically at boot
#       'disabled' -> will not start automatically
#       'masked'   -> forbidden from starting
#       'static'   -> unit cannot be enabled alone, started by dependency or socket
#       'indirect' / 'generated' -> managed indirectly
inspect_systemd_service() {
    local svc="$1"

    # Query systemd unit properties directly
    local load_state
    load_state=$(systemctl show -p LoadState --value "${svc}" 2>/dev/null || true)

    # If LoadState is not-found or empty, also double check with systemctl cat
    if [ "${load_state}" = "not-found" ] || [ -z "${load_state}" ]; then
        if ! systemctl cat "${svc}" >/dev/null 2>&1; then
            ACTIVE_STATUS="not-found"
            ENABLED_STATUS="n/a"
            UNIT_DESCRIPTION="Unit does not exist in systemd registry"
            MAIN_PID="n/a"
            EXIT_CODE=2
            STATUS_MSG="⚠️ Service '${svc}' not found on this system"
            CARD_COLOR="red"
            return 0
        fi
    fi

    # Read unit description and Main PID for rich diagnostic reporting
    UNIT_DESCRIPTION=$(systemctl show -p Description --value "${svc}" 2>/dev/null || echo "No description")
    MAIN_PID=$(systemctl show -p MainPID --value "${svc}" 2>/dev/null || echo "0")

    # Read raw active state using systemctl is-active
    local raw_active
    raw_active=$(systemctl is-active "${svc}" 2>&1 || true)

    # Read raw enabled state using systemctl is-enabled
    local raw_enabled
    raw_enabled=$(systemctl is-enabled "${svc}" 2>&1 || true)

    ENABLED_STATUS="${raw_enabled}"

    case "${raw_active}" in
        "active")
            ACTIVE_STATUS="active"
            EXIT_CODE=0
            STATUS_MSG="✅ Service '${svc}' is ACTIVE and running"
            CARD_COLOR="green"
            ;;
        "inactive")
            ACTIVE_STATUS="inactive"
            EXIT_CODE=1
            STATUS_MSG="❌ Service '${svc}' is INACTIVE / NOT running"
            # If it is enabled at boot but currently inactive, mark card amber
            if [ "${raw_enabled}" = "enabled" ]; then
                CARD_COLOR="amber"
            else
                CARD_COLOR="red"
            fi
            ;;
        "failed")
            ACTIVE_STATUS="failed"
            EXIT_CODE=1
            STATUS_MSG="❌ Service '${svc}' is FAILED / CRASHED"
            CARD_COLOR="red"
            ;;
        "activating"|"deactivating"|"reloading")
            ACTIVE_STATUS="${raw_active}"
            EXIT_CODE=1
            STATUS_MSG="⏳ Service '${svc}' is in transition (${raw_active})"
            CARD_COLOR="amber"
            ;;
        *)
            # Fallback for unexpected systemctl output
            if [ "${load_state}" = "not-found" ]; then
                ACTIVE_STATUS="not-found"
                ENABLED_STATUS="n/a"
                EXIT_CODE=2
                STATUS_MSG="⚠️ Service '${svc}' not found on this system"
                CARD_COLOR="red"
            else
                ACTIVE_STATUS="${raw_active}"
                EXIT_CODE=1
                STATUS_MSG="❌ Service '${svc}' state: ${raw_active}"
                CARD_COLOR="red"
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# SYSV INIT FALLBACK ENGINE (NON-SYSTEMD ENVIRONMENTS)
# ------------------------------------------------------------------------------
# Function: inspect_sysv_service
# Explaining why this is needed:
# When running on legacy init or Docker/WSL environments without systemd PID 1,
# 'service <service> status' or '/etc/init.d/<service> status' must be used.
# Exit code 0 generally signifies running/active, 3 signifies stopped/inactive,
# and unrecognized service prints an error on stderr with exit code 1 or 4.
inspect_sysv_service() {
    local svc="$1"
    local status_output
    local status_exit

    UNIT_DESCRIPTION="SysV init managed service"
    MAIN_PID="n/a"

    # First check if an init script exists in /etc/init.d/
    if [ ! -f "/etc/init.d/${svc}" ] && ! service --status-all 2>&1 | grep -q "[+-]  *${svc}"; then
        ACTIVE_STATUS="not-found"
        ENABLED_STATUS="n/a"
        EXIT_CODE=2
        STATUS_MSG="⚠️ Service '${svc}' not found on this system (SysV init)"
        CARD_COLOR="red"
        return 0
    fi

    # Query service status via the 'service' wrapper
    status_output=$(service "${svc}" status 2>&1)
    status_exit=$?

    # Check boot persistence in SysV by looking for S* symlinks in default runlevels (2-5)
    if ls /etc/rc[2-5].d/S*"${svc}" >/dev/null 2>&1; then
        ENABLED_STATUS="enabled"
    else
        ENABLED_STATUS="disabled"
    fi

    if [ ${status_exit} -eq 0 ] || echo "${status_output}" | grep -iqE "is running|active \(running\)"; then
        ACTIVE_STATUS="active"
        EXIT_CODE=0
        STATUS_MSG="✅ Service '${svc}' is ACTIVE and running"
        CARD_COLOR="green"
    elif echo "${status_output}" | grep -iqE "unrecognized service|not found"; then
        ACTIVE_STATUS="not-found"
        ENABLED_STATUS="n/a"
        EXIT_CODE=2
        STATUS_MSG="⚠️ Service '${svc}' not found on this system"
        CARD_COLOR="red"
    else
        ACTIVE_STATUS="inactive"
        EXIT_CODE=1
        STATUS_MSG="❌ Service '${svc}' is INACTIVE / NOT running"
        if [ "${ENABLED_STATUS}" = "enabled" ]; then
            CARD_COLOR="amber"
        else
            CARD_COLOR="red"
        fi
    fi
}

# ------------------------------------------------------------------------------
# FORMATTED HUMAN-READABLE BANNER DISPLAY
# ------------------------------------------------------------------------------
# Function: display_cli_report
# Renders a formatted terminal summary displaying active status, boot persistence,
# init engine, and PID diagnostics.
display_cli_report() {
    local svc="$1"
    local init_sys="$2"
    local check_time="$3"

    echo ""
    echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}SYSTEM SERVICE AVAILABILITY CHECK${COLOR_RESET} — ${COLOR_DIM}${check_time}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"
    printf "  Target Service   : %b%s%b\n" "${COLOR_BOLD}" "${svc}" "${COLOR_RESET}"
    printf "  Init Subsystem   : %s\n" "${init_sys}"
    [ -n "${UNIT_DESCRIPTION}" ] && printf "  Unit Description : %s\n" "${UNIT_DESCRIPTION}"
    [ "${MAIN_PID}" != "0" ] && [ "${MAIN_PID}" != "n/a" ] && printf "  Main Process PID : %s\n" "${MAIN_PID}"
    echo -e "----------------------------------------------------------------------"
    
    # Active Status Display
    case "${ACTIVE_STATUS}" in
        "active")
            echo -e "  Active Status    : ${COLOR_GREEN}${STATUS_MSG}${COLOR_RESET}"
            ;;
        "not-found")
            echo -e "  Active Status    : ${COLOR_YELLOW}${STATUS_MSG}${COLOR_RESET}"
            ;;
        *)
            echo -e "  Active Status    : ${COLOR_RED}${STATUS_MSG}${COLOR_RESET}"
            ;;
    esac

    # Boot Persistence Display (Requirement 4)
    case "${ENABLED_STATUS}" in
        "enabled")
            echo -e "  Boot Persistence : ${COLOR_GREEN}⚙️  ENABLED${COLOR_RESET} (Starts automatically on system boot)"
            ;;
        "disabled")
            echo -e "  Boot Persistence : ${COLOR_YELLOW}⚙️  DISABLED${COLOR_RESET} (Manual start required; will not start at boot)"
            ;;
        "masked")
            echo -e "  Boot Persistence : ${COLOR_RED}⚙️  MASKED${COLOR_RESET} (Unit is masked and forbidden from starting)"
            ;;
        "static")
            echo -e "  Boot Persistence : ${COLOR_CYAN}⚙️  STATIC${COLOR_RESET} (Unit cannot be enabled alone; started on demand)"
            ;;
        "n/a")
            echo -e "  Boot Persistence : ${COLOR_DIM}⚙️  N/A${COLOR_RESET} (Unit file does not exist)"
            ;;
        *)
            echo -e "  Boot Persistence : ${COLOR_DIM}⚙️  ${ENABLED_STATUS}${COLOR_RESET}"
            ;;
    esac

    echo -e "----------------------------------------------------------------------"
    echo -e "  Logged To        : ${COLOR_DIM}${LOG_FILE}${COLOR_RESET}"
    echo -e "  Script Exit Code : ${EXIT_CODE}"
    echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# JSON OUTPUT GENERATOR
# ------------------------------------------------------------------------------
# Function: display_json_output
# Provides clean JSON output for automated scripting or telemetry pipelines.
display_json_output() {
    local svc="$1"
    local init_sys="$2"
    local check_time="$3"

    cat << EOF
{
  "service": "${svc}",
  "timestamp": "${check_time}",
  "init_system": "${init_sys}",
  "active_status": "${ACTIVE_STATUS}",
  "enabled_status": "${ENABLED_STATUS}",
  "status_message": "${STATUS_MSG}",
  "main_pid": "${MAIN_PID}",
  "description": "${UNIT_DESCRIPTION}",
  "exit_code": ${EXIT_CODE}
}
EOF
}

# ------------------------------------------------------------------------------
# HTML REPORT GENERATOR
# ------------------------------------------------------------------------------
# Function: generate_html_report
# Requirement: Generate report.html inside the sandbox — a single self-contained
# HTML file (inline CSS only, no external dependencies) presenting results as
# a clean dark-themed dashboard:
# - Header with problem title
# - A summary "status card" per service checked, color-coded:
#     * green = active
#     * red = inactive / not found
#     * amber = enabled-but-inactive
# - Large service name and status text
# - Collapsible or scrollable log section below showing raw log file contents
# - Basic responsive layout, dark background with clear accent color
generate_html_report() {
    local gen_time
    gen_time=$(date "+%Y-%m-%d %H:%M:%S %Z")

    # Read up to the last 20 log entries to build status cards dynamically
    # and escape raw logs safely
    local raw_logs=""
    if [ -f "${LOG_FILE}" ]; then
        raw_logs=$(cat "${LOG_FILE}")
    else
        raw_logs="No log entries recorded yet."
    fi

    # Escape HTML special chars in raw logs for safe display inside <pre>
    local escaped_logs
    escaped_logs=$(echo "${raw_logs}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    # Parse distinct checked services from the log to generate dynamic cards
    # We will build cards for each unique service tested in the log file
    local cards_html=""
    
    # Read unique services in order of appearance
    local unique_services=()
    if [ -f "${LOG_FILE}" ]; then
        while IFS= read -r s; do
            [ -n "${s}" ] && unique_services+=("${s}")
        done < <(grep -o 'SERVICE=[^ ]*' "${LOG_FILE}" | cut -d'=' -f2 | awk '!seen[$0]++')
    fi

    # If no services were found in the log yet, show the current service
    if [ ${#unique_services[@]} -eq 0 ]; then
        unique_services+=("${SERVICE_NAME}")
    fi

    for svc in "${unique_services[@]}"; do
        # Extract the most recent log line for this service
        local latest_line
        latest_line=$(grep "SERVICE=${svc} " "${LOG_FILE}" 2>/dev/null | tail -n 1 || true)
        
        local l_time l_init l_active l_enabled l_exit l_msg
        if [ -n "${latest_line}" ]; then
            l_time=$(echo "${latest_line}" | awk -F'[][]' '{print $2}')
            l_init=$(echo "${latest_line}" | awk -F'[][]' '{print $4}')
            l_active=$(echo "${latest_line}" | grep -o 'ACTIVE=[^ ]*' | cut -d'=' -f2)
            l_enabled=$(echo "${latest_line}" | grep -o 'ENABLED=[^ ]*' | cut -d'=' -f2)
            l_exit=$(echo "${latest_line}" | grep -o 'EXIT=[^ ]*' | cut -d'=' -f2)
            l_msg=$(echo "${latest_line}" | sed -n 's/.*MSG="\(.*\)".*/\1/p')
        else
            l_time="${gen_time}"
            l_init="${INIT_SYSTEM}"
            l_active="${ACTIVE_STATUS}"
            l_enabled="${ENABLED_STATUS}"
            l_exit="${EXIT_CODE}"
            l_msg="${STATUS_MSG}"
        fi

        # Determine Card Color Scheme:
        # Green: Active
        # Amber: Enabled at boot but currently Inactive
        # Red: Inactive (not enabled) or Not Found or Failed
        local card_theme="red"
        local badge_bg="#dc2626"
        local badge_border="#ef4444"
        local badge_text="INACTIVE"
        local icon="❌"

        if [ "${l_active}" = "active" ]; then
            card_theme="green"
            badge_bg="#059669"
            badge_border="#10b981"
            badge_text="ACTIVE &amp; RUNNING"
            icon="✅"
        elif [ "${l_active}" = "not-found" ]; then
            card_theme="red"
            badge_bg="#991b1b"
            badge_border="#f87171"
            badge_text="NOT FOUND"
            icon="⚠️"
        elif [ "${l_enabled}" = "enabled" ] && [ "${l_active}" != "active" ]; then
            card_theme="amber"
            badge_bg="#d97706"
            badge_border="#f59e0b"
            badge_text="ENABLED (INACTIVE)"
            icon="⚠️"
        else
            card_theme="red"
            badge_bg="#dc2626"
            badge_border="#ef4444"
            badge_text="INACTIVE"
            icon="❌"
        fi

        # Color codes for card border and accents
        local border_color="#334155"
        local header_bg="#1e293b"
        local status_text_color="#f87171"
        if [ "${card_theme}" = "green" ]; then
            border_color="#10b981"
            header_bg="rgba(16, 185, 129, 0.12)"
            status_text_color="#34d399"
        elif [ "${card_theme}" = "amber" ]; then
            border_color="#f59e0b"
            header_bg="rgba(245, 158, 11, 0.12)"
            status_text_color="#fbbf24"
        else
            border_color="#ef4444"
            header_bg="rgba(239, 68, 68, 0.12)"
            status_text_color="#f87171"
        fi

        cards_html+=$'\n'
        cards_html+=$(cat << CARD_EOF
      <div class="card" style="border-top: 4px solid ${border_color};">
        <div class="card-header" style="background: ${header_bg};">
          <div class="service-identity">
            <span class="icon">${icon}</span>
            <div class="service-name-wrap">
              <span class="service-name">${svc}</span>
              <span class="init-badge">${l_init}</span>
            </div>
          </div>
          <span class="status-badge" style="background: ${badge_bg}; border: 1px solid ${badge_border};">${badge_text}</span>
        </div>
        <div class="card-body">
          <div class="status-highlight">
            <div class="status-label">Operational State</div>
            <div class="status-value" style="color: ${status_text_color};">${l_msg}</div>
          </div>
          <div class="meta-grid">
            <div class="meta-item">
              <div class="meta-key">Boot Persistence</div>
              <div class="meta-val">${l_enabled}</div>
            </div>
            <div class="meta-item">
              <div class="meta-key">Exit Code</div>
              <div class="meta-val"><code>${l_exit}</code></div>
            </div>
            <div class="meta-item full-width">
              <div class="meta-key">Last Checked</div>
              <div class="meta-val">${l_time}</div>
            </div>
          </div>
        </div>
      </div>
CARD_EOF
)
    done

    # Generate the complete standalone HTML dashboard via heredoc
    cat << EOF > "${REPORT_FILE}"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Service Availability Check — Automation Sprint Dashboard</title>
  <style>
    :root {
      --bg-base: #0a0e17;
      --bg-surface: #111827;
      --bg-card: #1f2937;
      --bg-code: #030712;
      --accent-blue: #38bdf8;
      --accent-indigo: #6366f1;
      --text-main: #f3f4f6;
      --text-muted: #9ca3af;
      --text-dim: #6b7280;
      --border-color: #374151;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      background-color: var(--bg-base);
      color: var(--text-main);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.5;
      padding: 2rem 1.5rem;
    }

    .container {
      max-width: 1100px;
      margin: 0 auto;
    }

    /* Header styling */
    .dashboard-header {
      background: linear-gradient(135deg, #1e1e38 0%, #111827 100%);
      border: 1px solid var(--border-color);
      border-left: 6px solid var(--accent-blue);
      padding: 2rem;
      border-radius: 12px;
      margin-bottom: 2rem;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
    }

    .header-tag {
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--accent-blue);
      margin-bottom: 0.5rem;
      background: rgba(56, 189, 248, 0.1);
      padding: 0.25rem 0.6rem;
      border-radius: 4px;
      border: 1px solid rgba(56, 189, 248, 0.2);
    }

    .dashboard-header h1 {
      font-size: 1.85rem;
      font-weight: 800;
      color: #ffffff;
      margin-bottom: 0.4rem;
      letter-spacing: -0.02em;
    }

    .dashboard-header p.subtitle {
      color: var(--text-muted);
      font-size: 0.95rem;
    }

    .header-stats {
      display: flex;
      flex-wrap: wrap;
      gap: 1.5rem;
      margin-top: 1.25rem;
      padding-top: 1.25rem;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      font-size: 0.85rem;
      color: var(--text-muted);
    }

    .header-stats span strong {
      color: var(--text-main);
    }

    /* Cards Grid */
    .section-title {
      font-size: 1.25rem;
      font-weight: 700;
      color: #ffffff;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .cards-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2.5rem;
    }

    .card {
      background: var(--bg-card);
      border-radius: 10px;
      overflow: hidden;
      border: 1px solid var(--border-color);
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
      transition: transform 0.2s ease, box-shadow 0.2s ease;
      display: flex;
      flex-direction: column;
    }

    .card:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.45);
    }

    .card-header {
      padding: 1.25rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }

    .service-identity {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }

    .service-identity .icon {
      font-size: 1.6rem;
    }

    .service-name-wrap {
      display: flex;
      flex-direction: column;
    }

    .service-name {
      font-size: 1.35rem;
      font-weight: 750;
      color: #ffffff;
      letter-spacing: -0.01em;
    }

    .init-badge {
      font-size: 0.7rem;
      color: var(--accent-blue);
      text-transform: uppercase;
      font-weight: 600;
    }

    .status-badge {
      font-size: 0.75rem;
      font-weight: 700;
      color: #ffffff;
      padding: 0.3rem 0.7rem;
      border-radius: 9999px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .card-body {
      padding: 1.25rem;
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }

    .status-highlight {
      margin-bottom: 1.25rem;
    }

    .status-label {
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-dim);
      margin-bottom: 0.25rem;
    }

    .status-value {
      font-size: 1.05rem;
      font-weight: 700;
      line-height: 1.3;
    }

    .meta-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.75rem;
      padding-top: 1rem;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
      font-size: 0.82rem;
    }

    .meta-item.full-width {
      grid-column: span 2;
    }

    .meta-key {
      color: var(--text-dim);
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }

    .meta-val {
      color: var(--text-main);
      font-weight: 600;
      margin-top: 0.15rem;
    }

    .meta-val code {
      background: var(--bg-surface);
      padding: 0.15rem 0.4rem;
      border-radius: 4px;
      color: var(--accent-blue);
      font-size: 0.8rem;
    }

    /* Log section */
    .log-section {
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 1.5rem;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
    }

    details.log-accordion summary {
      cursor: pointer;
      user-select: none;
      outline: none;
      list-style: none;
    }

    details.log-accordion summary::-webkit-details-marker {
      display: none;
    }

    .log-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 0.75rem;
    }

    .log-title {
      font-size: 1.15rem;
      font-weight: 700;
      color: #ffffff;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .log-toggle-hint {
      font-size: 0.75rem;
      color: var(--accent-blue);
      background: rgba(56, 189, 248, 0.1);
      padding: 0.2rem 0.5rem;
      border-radius: 4px;
      margin-left: 0.5rem;
    }

    .log-subtitle {
      font-size: 0.8rem;
      color: var(--text-muted);
    }

    .log-viewer {
      background: var(--bg-code);
      border: 1px solid #1f2937;
      border-radius: 6px;
      padding: 1rem;
      max-height: 320px;
      overflow-y: auto;
      font-family: "Consolas", "Monaco", "Courier New", monospace;
      font-size: 0.82rem;
      color: #38bdf8;
      white-space: pre-wrap;
      word-break: break-all;
      line-height: 1.6;
      margin-top: 0.75rem;
    }

    /* Scrollbar styling */
    .log-viewer::-webkit-scrollbar {
      width: 8px;
    }
    .log-viewer::-webkit-scrollbar-track {
      background: var(--bg-code);
    }
    .log-viewer::-webkit-scrollbar-thumb {
      background: #374151;
      border-radius: 4px;
    }
    .log-viewer::-webkit-scrollbar-thumb:hover {
      background: #4b5563;
    }

    /* Footer */
    .dashboard-footer {
      text-align: center;
      margin-top: 2.5rem;
      color: var(--text-dim);
      font-size: 0.8rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Header -->
    <header class="dashboard-header">
      <div class="header-tag">Course: Linux System Administration (E1ITA307)</div>
      <h1>Problem #16: Service Availability Check</h1>
      <p class="subtitle">Real-time status monitoring, boot persistence verification, and structured audit logs.</p>
      <div class="header-stats">
        <span>Init Architecture: <strong>${INIT_SYSTEM}</strong></span>
        <span>Environment: <strong>$(uname -s) $(uname -r)</strong></span>
        <span>Generated At: <strong>${gen_time}</strong></span>
        <span>Host: <strong>$(hostname)</strong></span>
      </div>
    </header>

    <!-- Status Cards -->
    <section>
      <h2 class="section-title">📊 Service Status Cards</h2>
      <div class="cards-grid">
${cards_html}
      </div>
    </section>

    <!-- Raw Audit Log View (Collapsible and Scrollable) -->
    <section class="log-section">
      <details class="log-accordion" open>
        <summary class="log-header">
          <div class="log-title">
            <span>📜 Audit Log History</span>
            <span class="log-toggle-hint">Click to toggle</span>
          </div>
          <div class="log-subtitle">Stored at: <code>logs/service_check.log</code></div>
        </summary>
        <div class="log-viewer"><pre>${escaped_logs}</pre></div>
      </details>
    </section>

    <!-- Footer -->
    <footer class="dashboard-footer">
      Automation Sprint — Problem Statement #16 Service Availability Check &bull; Linux System Administration (E1ITA307)
    </footer>
  </div>
</body>
</html>
EOF
    echo -e "${COLOR_GREEN}✓ HTML dashboard generated:${COLOR_RESET} ${REPORT_FILE}"
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION FLOW
# ------------------------------------------------------------------------------
main() {
    local service_arg=""
    local flag_report=false
    local flag_json=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                print_usage
                exit 0
                ;;
            -r|--report)
                flag_report=true
                shift
                ;;
            -j|--json)
                flag_json=true
                shift
                ;;
            -*)
                echo -e "${COLOR_RED}Error:${COLOR_RESET} Unknown option '$1'" >&2
                echo "Run '$0 --help' for usage instructions." >&2
                exit 3
                ;;
            *)
                if [ -z "${service_arg}" ]; then
                    service_arg="$1"
                else
                    echo -e "${COLOR_RED}Error:${COLOR_RESET} Unexpected additional argument '$1'" >&2
                    echo "Run '$0 --help' for usage instructions." >&2
                    exit 3
                fi
                shift
                ;;
        esac
    done

    # Default to safe standard service if no argument provided
    SERVICE_NAME="${service_arg:-${DEFAULT_SERVICE}}"

    # Sanitize service name (strip trailing .service if user specified it for consistency)
    SERVICE_NAME="${SERVICE_NAME%.service}"

    # Capture check timestamp
    CHECK_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")

    # Detect the init subsystem
    INIT_SYSTEM=$(detect_init_system)

    # Initialize diagnostic variables
    ACTIVE_STATUS="unknown"
    ENABLED_STATUS="unknown"
    STATUS_MSG="Status undetermined"
    UNIT_DESCRIPTION=""
    MAIN_PID="0"
    EXIT_CODE=3
    CARD_COLOR="red"

    # Execute service check according to detected init system
    if [ "${INIT_SYSTEM}" = "systemd" ]; then
        inspect_systemd_service "${SERVICE_NAME}"
    elif [ "${INIT_SYSTEM}" = "sysvinit" ]; then
        inspect_sysv_service "${SERVICE_NAME}"
    else
        ACTIVE_STATUS="error"
        ENABLED_STATUS="n/a"
        EXIT_CODE=3
        STATUS_MSG="❌ Unsupported init system (neither systemd nor sysvinit detected)"
        CARD_COLOR="red"
    fi

    # Append structured audit entry to log file inside sandbox
    append_log_entry \
        "${CHECK_TIMESTAMP}" \
        "${SERVICE_NAME}" \
        "${INIT_SYSTEM}" \
        "${ACTIVE_STATUS}" \
        "${ENABLED_STATUS}" \
        "${EXIT_CODE}" \
        "${STATUS_MSG}"

    # Output results
    if [ "${flag_json}" = true ]; then
        display_json_output "${SERVICE_NAME}" "${INIT_SYSTEM}" "${CHECK_TIMESTAMP}"
    else
        display_cli_report "${SERVICE_NAME}" "${INIT_SYSTEM}" "${CHECK_TIMESTAMP}"
    fi

    # Refresh HTML report if requested
    if [ "${flag_report}" = true ]; then
        generate_html_report
    fi

    # Exit with the determined status code (0 = Active, 1 = Inactive, 2 = Not Found, 3 = Error)
    exit "${EXIT_CODE}"
}

# Run entrypoint
main "$@"
