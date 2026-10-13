#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_02)
# Problem Statement #2: Inactive Employee Detection
# Focus: User Administration & Authentication Audit
#
# ROLE:
#   Linux System Administrator auditing local employee accounts for inactivity.
#
# PROBLEM STATEMENT:
#   The system administrator wants to identify users who have not logged in
#   recently. Write a script to display inactive user accounts.
#
# ARCHITECTURAL OVERVIEW & LOGIC:
#   1. Local User Account Enumeration:
#      - Reads /etc/passwd directly to discover all local accounts.
#      - By Linux FHS and distribution convention (login.defs):
#        * Regular human / employee accounts have UID >= 1000.
#        * UID 65534 (nobody) is excluded as a standard non-login pseudo-user.
#        * Accounts with non-interactive shells (/usr/sbin/nologin, /bin/false,
#          /bin/sync) are filtered out by default to avoid false positives from
#          system service daemons.
#        * An optional flag (--include-system) allows auditing all accounts if
#          explicitly requested for comprehensive system auditing.
#
#   2. Multi-Tier Login History Engine & Tool Fallback:
#      - Primary Method: 'lastlog -u <username>'
#        Reads /var/log/lastlog. Displays exact timestamp or "**Never logged in**".
#      - Secondary Fallback: 'last -F <username> | head -1'
#        Reads /var/log/wtmp if 'lastlog' is not available.
#      - Tertiary Fallback (Modern Linux / WSL2 / Cloud Minimal Images):
#        Ubuntu 24.04/26.04 minimal and WSL2 environments often omit legacy 32-bit
#        utmp tools or have an empty /var/log/lastlog. The script queries:
#        a) Active live sessions via 'who' and 'w'.
#        b) Systemd user session timestamps via 'loginctl show-user <user>'.
#        c) PAM authentication log events via /var/log/auth.log or /var/log/secure.
#      - Error Handling & Zero-Record Edge Cases:
#        If no login record exists across all engines, the account is gracefully
#        treated as "Never logged in" / INACTIVE without script termination.
#
#   3. TECHNICAL DEEP DIVE: 'lastlog' vs. 'last' Differences:
#      -------------------------------------------------------------------------
#      Feature             | lastlog (/var/log/lastlog) | last (/var/log/wtmp)
#      --------------------+----------------------------+-----------------------
#      File Format         | Sparse binary indexed by   | Sequential append-only
#                          | UID (lseek to UID*size)    | circular binary log
#      Contents            | ONLY the most recent login | Full chronological
#                          | event per UID              | history of all logins,
#                          |                            | logouts, and reboots
#      Log Rotation Risk   | Never rotated (fixed size) | Regularly rotated by
#                          | Record preserved forever   | logrotate (wtmp.1, etc.)
#      Retention Issue     | Overwritten on next login  | Older logins purged
#                          |                            | when log file rotates
#      "Never Logged In"   | Explicitly recognized via  | Indistinguishable from
#                          | zero offset / null record  | logins rotated out
#      --------------------+----------------------------+-----------------------
#
#   4. Dynamic Inactivity Threshold:
#      - Configurable via command-line argument (--threshold / -t) or env var.
#      - Default: 30 days (aligned with CIS Benchmark 5.4 & NIST SP 800-53 AC-2).
#      - Days inactive computed by calculating: (current_epoch - login_epoch) / 86400.
#      - Accounts flagged as INACTIVE if days_inactive > threshold OR if "Never".
#
#   5. Safety & Read-Only Guarantee:
#      - Strictly read-only: does NOT modify, lock, disable, or delete any account.
#      - Sandboxed within project folder (only writes to logs/inactive_check.log).
# ==============================================================================

set -euo pipefail

# Script directory resolution for sandboxed pathing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ------------------------------------------------------------------------------
# Configuration & Defaults
# ------------------------------------------------------------------------------
DEFAULT_THRESHOLD=30
THRESHOLD_DAYS="${INACTIVITY_THRESHOLD:-${DEFAULT_THRESHOLD}}"
INCLUDE_SYSTEM=false
OUTPUT_JSON=false
NO_COLOR=false
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/inactive_check.log"

# Color Codes for Terminal Reporting (disabled if NO_COLOR=true or not a tty)
if [ -t 1 ]; then
    CLR_RESET='\033[0m'
    CLR_BOLD='\033[1m'
    CLR_RED='\033[0;31m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[0;33m'
    CLR_BLUE='\033[0;34m'
    CLR_CYAN='\033[0;36m'
    CLR_GRAY='\033[0;90m'
    CLR_BG_RED='\033[41;37m'
    CLR_BG_GREEN='\033[42;30m'
else
    CLR_RESET=''
    CLR_BOLD=''
    CLR_RED=''
    CLR_GREEN=''
    CLR_YELLOW=''
    CLR_BLUE=''
    CLR_CYAN=''
    CLR_GRAY=''
    CLR_BG_RED=''
    CLR_BG_GREEN=''
fi

# ------------------------------------------------------------------------------
# Usage & Help Manual
# ------------------------------------------------------------------------------
print_help() {
    cat <<EOF
${CLR_BOLD}NAME${CLR_RESET}
    inactive_employee_detector.sh — Inactive Local Employee Account Auditor

${CLR_BOLD}SYNOPSIS${CLR_RESET}
    ./inactive_employee_detector.sh [OPTIONS] [THRESHOLD_DAYS]

${CLR_BOLD}DESCRIPTION${CLR_RESET}
    Audits local user accounts from /etc/passwd and evaluates authentication
    history against a configurable inactivity threshold. Accounts that have
    never logged in or whose last login exceeds the threshold are flagged
    as INACTIVE for administrative review.

    Operates in strict READ-ONLY mode. No accounts or files are modified.

${CLR_BOLD}OPTIONS${CLR_RESET}
    -t, --threshold DAYS   Set inactivity threshold in days (Default: ${DEFAULT_THRESHOLD}).
    -s, --include-system   Include system accounts (UID < 1000 and service daemons).
                           By default, only human / login-capable accounts are audited.
    -j, --json             Output audit results as machine-readable JSON.
        --no-color         Disable ANSI terminal color output.
    -h, --help             Display this help manual and exit.

${CLR_BOLD}POSITIONAL ARGUMENTS${CLR_RESET}
    THRESHOLD_DAYS         Optional integer specifying inactivity threshold in days.

${CLR_BOLD}EXAMPLES${CLR_RESET}
    ./inactive_employee_detector.sh
    ./inactive_employee_detector.sh 60
    ./inactive_employee_detector.sh --threshold 45
    ./inactive_employee_detector.sh --include-system
    ./inactive_employee_detector.sh --json > report.json

${CLR_BOLD}AUDIT LOG FILE${CLR_RESET}
    Run history and summaries are appended to: ${LOG_FILE}
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -t|--threshold)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo -e "${CLR_RED}[ERROR] Invalid threshold days specified: '${2:-}'${CLR_RESET}" >&2
                exit 1
            fi
            THRESHOLD_DAYS="$2"
            shift 2
            ;;
        --threshold=*)
            val="${1#*=}"
            if [[ ! "$val" =~ ^[0-9]+$ ]]; then
                echo -e "${CLR_RED}[ERROR] Invalid threshold days specified: '${val}'${CLR_RESET}" >&2
                exit 1
            fi
            THRESHOLD_DAYS="$val"
            shift 1
            ;;
        -s|--include-system)
            INCLUDE_SYSTEM=true
            shift 1
            ;;
        -j|--json)
            OUTPUT_JSON=true
            shift 1
            ;;
        --no-color)
            NO_COLOR=true
            CLR_RESET=''
            CLR_BOLD=''
            CLR_RED=''
            CLR_GREEN=''
            CLR_YELLOW=''
            CLR_BLUE=''
            CLR_CYAN=''
            CLR_GRAY=''
            CLR_BG_RED=''
            CLR_BG_GREEN=''
            shift 1
            ;;
        [0-9]*)
            THRESHOLD_DAYS="$1"
            shift 1
            ;;
        *)
            echo -e "${CLR_RED}[ERROR] Unknown argument: '$1'${CLR_RESET}" >&2
            echo "Run with --help for usage instructions." >&2
            exit 1
            ;;
    esac
done

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

# ------------------------------------------------------------------------------
# System Metadata & Audit Engine Discovery
# ------------------------------------------------------------------------------
AUDIT_TIMESTAMP_UTC="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
AUDIT_TIMESTAMP_LOCAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
AUDIT_TIMESTAMP_ISO="$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
CURRENT_EPOCH="$(date +%s)"
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
OS_NAME_VAL="$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release 2>/dev/null | tr -d '"' || uname -s)"
KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"

# Determine primary and fallback tools available on this host
ENGINE_PRIMARY="none"
ENGINE_SECONDARY="none"
ENGINE_TERTIARY="none"

if command -v lastlog >/dev/null 2>&1; then
    ENGINE_PRIMARY="lastlog (/var/log/lastlog)"
elif command -v lastlog2 >/dev/null 2>&1; then
    ENGINE_PRIMARY="lastlog2"
fi

if command -v last >/dev/null 2>&1; then
    ENGINE_SECONDARY="last (/var/log/wtmp)"
elif command -v wtmpdb >/dev/null 2>&1; then
    ENGINE_SECONDARY="wtmpdb"
fi

if command -v loginctl >/dev/null 2>&1; then
    ENGINE_TERTIARY="loginctl / who / auth.log"
elif command -v who >/dev/null 2>&1; then
    ENGINE_TERTIARY="who / w"
fi

# Pre-cache active live sessions from 'who' for O(1) instantaneous lookup
declare -A WHO_CACHE
while read -r w_user w_tty w_date w_time _; do
    if [[ -n "${w_user:-}" && -n "${w_date:-}" && -n "${w_time:-}" ]]; then
        WHO_CACHE["${w_user}"]="${w_date} ${w_time}"
    fi
done < <(who 2>/dev/null || true)

# ------------------------------------------------------------------------------
# Core Account Query & Last Login Resolution Function
# ------------------------------------------------------------------------------
# Function: resolve_user_login
# Arguments: $1 = username, $2 = uid
# Sets:
#   LOGIN_RAW_DATE    Human-readable date string or "Never"
#   LOGIN_EPOCH       Integer epoch timestamp or ""
#   DAYS_INACTIVE     Integer days or "Never"
#   ACCOUNT_STATUS    "ACTIVE" or "INACTIVE"
#   RESOLVED_VIA      Tool/source that provided the record
# ------------------------------------------------------------------------------
resolve_user_login() {
    local target_user="$1"
    local target_uid="$2"

    LOGIN_RAW_DATE="Never"
    LOGIN_EPOCH=""
    DAYS_INACTIVE="Never"
    ACCOUNT_STATUS="INACTIVE"
    RESOLVED_VIA="None (No record)"

    local found_epoch=""
    local found_date_str=""
    local source_engine=""

    # --------------------------------------------------------------------------
    # Engine 1: 'lastlog' (Preferred, reads /var/log/lastlog)
    # --------------------------------------------------------------------------
    if command -v lastlog >/dev/null 2>&1; then
        local ll_raw
        ll_raw="$(lastlog -u "${target_user}" 2>/dev/null | tail -n +2 | grep -E "^[[:space:]]*${target_user}[[:space:]]" || true)"
        if [[ -n "${ll_raw}" ]]; then
            if [[ "${ll_raw}" =~ (\*\*Never logged in\*\*|Never logged in|\*\*Never\*\*) ]]; then
                found_date_str="Never"
                source_engine="lastlog"
            else
                # Extract date from tail of lastlog output (last 4-5 tokens e.g. "Mon Oct 5 09:20:32 +0530 2026")
                local parsed_date_candidate
                parsed_date_candidate="$(echo "${ll_raw}" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}' | sed 's/[[:space:]]*$//')"
                if [[ -n "${parsed_date_candidate}" ]]; then
                    local cand_epoch
                    if cand_epoch="$(date -d "${parsed_date_candidate}" +%s 2>/dev/null)"; then
                        found_epoch="${cand_epoch}"
                        found_date_str="$(date -d "@${found_epoch}" '+%Y-%m-%d %H:%M:%S')"
                        source_engine="lastlog"
                    fi
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Engine 2: 'last -F' Fallback (reads /var/log/wtmp)
    # --------------------------------------------------------------------------
    if [[ -z "${found_epoch}" && "${found_date_str}" != "Never" ]] && command -v last >/dev/null 2>&1; then
        local last_raw
        last_raw="$(last -F "${target_user}" 2>/dev/null | grep -E "^${target_user}[[:space:]]" | head -n 1 || true)"
        if [[ -n "${last_raw}" ]]; then
            # Format: user tty host Mon Oct 5 09:20:32 2026 ...
            local last_date_candidate
            last_date_candidate="$(echo "${last_raw}" | awk '{print $4, $5, $6, $7, $8}')"
            if [[ -n "${last_date_candidate}" ]]; then
                local cand_epoch
                if cand_epoch="$(date -d "${last_date_candidate}" +%s 2>/dev/null)"; then
                    found_epoch="${cand_epoch}"
                    found_date_str="$(date -d "@${found_epoch}" '+%Y-%m-%d %H:%M:%S')"
                    source_engine="last (wtmp)"
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Engine 3: Live Session & Systemd Fallback ('who', 'loginctl', auth.log)
    # --------------------------------------------------------------------------
    # a) Check active sessions in 'who'
    if [[ -z "${found_epoch}" && "${found_date_str}" != "Never" ]]; then
        if [[ -n "${WHO_CACHE[${target_user}]:-}" ]]; then
            local who_ts="${WHO_CACHE[${target_user}]}"
            local cand_epoch
            if cand_epoch="$(date -d "${who_ts}" +%s 2>/dev/null)"; then
                found_epoch="${cand_epoch}"
                found_date_str="$(date -d "@${found_epoch}" '+%Y-%m-%d %H:%M:%S')"
                source_engine="who (active session)"
            fi
        fi
    fi

    # b) Check systemd logind user session timestamp
    if [[ -z "${found_epoch}" && "${found_date_str}" != "Never" ]] && command -v loginctl >/dev/null 2>&1; then
        local logind_ts
        logind_ts="$(loginctl show-user "${target_user}" 2>/dev/null | grep -oP '(?<=^Timestamp=).+' || true)"
        if [[ -n "${logind_ts}" ]]; then
            local cand_epoch
            if cand_epoch="$(date -d "${logind_ts}" +%s 2>/dev/null)"; then
                found_epoch="${cand_epoch}"
                found_date_str="$(date -d "@${found_epoch}" '+%Y-%m-%d %H:%M:%S')"
                source_engine="loginctl"
            fi
        fi
    fi

    # c) Check system authentication log (/var/log/auth.log or /var/log/secure)
    if [[ -z "${found_epoch}" && "${found_date_str}" != "Never" ]]; then
        local auth_log_file=""
        if [[ -f /var/log/auth.log && -r /var/log/auth.log ]]; then
            auth_log_file="/var/log/auth.log"
        elif [[ -f /var/log/secure && -r /var/log/secure ]]; then
            auth_log_file="/var/log/secure"
        fi

        if [[ -n "${auth_log_file}" ]]; then
            local auth_line
            auth_line="$(grep -E "session opened for user ${target_user}\b" "${auth_log_file}" 2>/dev/null | tail -n 1 || true)"
            if [[ -n "${auth_line}" ]]; then
                local auth_iso
                auth_iso="$(echo "${auth_line}" | awk '{print $1}')"
                local cand_epoch
                if cand_epoch="$(date -d "${auth_iso}" +%s 2>/dev/null)"; then
                    found_epoch="${cand_epoch}"
                    found_date_str="$(date -d "@${found_epoch}" '+%Y-%m-%d %H:%M:%S')"
                    source_engine="auth.log"
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Evaluation of Inactivity Status
    # --------------------------------------------------------------------------
    if [[ -n "${found_epoch}" ]]; then
        LOGIN_RAW_DATE="${found_date_str}"
        LOGIN_EPOCH="${found_epoch}"
        RESOLVED_VIA="${source_engine}"

        local diff_sec=$(( CURRENT_EPOCH - LOGIN_EPOCH ))
        if (( diff_sec < 0 )); then
            diff_sec=0
        fi
        local days=$(( diff_sec / 86400 ))
        DAYS_INACTIVE="${days}"

        if (( days > THRESHOLD_DAYS )); then
            ACCOUNT_STATUS="INACTIVE"
        else
            ACCOUNT_STATUS="ACTIVE"
        fi
    else
        # No login record found anywhere — treat as Never logged in
        LOGIN_RAW_DATE="Never"
        LOGIN_EPOCH=""
        DAYS_INACTIVE="Never"
        ACCOUNT_STATUS="INACTIVE"
        RESOLVED_VIA="${source_engine:-No login records found}"
    fi
}

# ------------------------------------------------------------------------------
# Discover Valid Login Shells
# ------------------------------------------------------------------------------
declare -A VALID_SHELLS
if [[ -f /etc/shells ]]; then
    while read -r sh_path; do
        [[ -z "$sh_path" || "$sh_path" =~ ^# ]] && continue
        VALID_SHELLS["$sh_path"]=1
    done < /etc/shells
fi

# Fallback basic valid shells if /etc/shells is unreadable
if [[ ${#VALID_SHELLS[@]} -eq 0 ]]; then
    VALID_SHELLS["/bin/bash"]=1
    VALID_SHELLS["/bin/sh"]=1
    VALID_SHELLS["/bin/dash"]=1
    VALID_SHELLS["/bin/zsh"]=1
    VALID_SHELLS["/usr/bin/bash"]=1
    VALID_SHELLS["/usr/bin/sh"]=1
fi

# ------------------------------------------------------------------------------
# User Account Enumeration Loop
# ------------------------------------------------------------------------------
# Arrays to store audit records
AUDIT_USERNAMES=()
AUDIT_UIDS=()
AUDIT_SHELLS=()
AUDIT_HOMES=()
AUDIT_LAST_DATES=()
AUDIT_DAYS=()
AUDIT_STATUSES=()
AUDIT_ENGINES=()

TOTAL_ACCOUNTS=0
COUNT_ACTIVE=0
COUNT_INACTIVE=0

while IFS=: read -r u_name _ u_uid u_gid u_gecos u_home u_shell; do
    # 1. Skip non-human / pseudo accounts unless explicitly requested
    if ! ${INCLUDE_SYSTEM}; then
        # Standard convention: human accounts have UID >= 1000
        if (( u_uid < 1000 )); then
            continue
        fi
        # Exclude 'nobody' pseudo user (UID 65534)
        if (( u_uid == 65534 )) || [[ "${u_name}" == "nobody" ]]; then
            continue
        fi
        # Exclude obvious non-login service accounts
        case "${u_shell}" in
            */nologin|*/false|*/sync|/dev/null)
                continue
                ;;
        esac
        # Verify shell is listed in /etc/shells
        if [[ -z "${VALID_SHELLS[${u_shell}]:-}" ]]; then
            continue
        fi
    fi

    # Query last login history for this user
    resolve_user_login "${u_name}" "${u_uid}"

    # Store records
    AUDIT_USERNAMES+=("${u_name}")
    AUDIT_UIDS+=("${u_uid}")
    AUDIT_SHELLS+=("${u_shell}")
    AUDIT_HOMES+=("${u_home}")
    AUDIT_LAST_DATES+=("${LOGIN_RAW_DATE}")
    AUDIT_DAYS+=("${DAYS_INACTIVE}")
    AUDIT_STATUSES+=("${ACCOUNT_STATUS}")
    AUDIT_ENGINES+=("${RESOLVED_VIA}")

    TOTAL_ACCOUNTS=$(( TOTAL_ACCOUNTS + 1 ))
    if [[ "${ACCOUNT_STATUS}" == "ACTIVE" ]]; then
        COUNT_ACTIVE=$(( COUNT_ACTIVE + 1 ))
    else
        COUNT_INACTIVE=$(( COUNT_INACTIVE + 1 ))
    fi

done < /etc/passwd

# Calculate inactivity percentage
INACTIVITY_RATE="0.0"
if (( TOTAL_ACCOUNTS > 0 )); then
    INACTIVITY_RATE="$(awk -v inact="${COUNT_INACTIVE}" -v tot="${TOTAL_ACCOUNTS}" 'BEGIN {printf "%.1f", (inact/tot)*100}')"
fi

# ------------------------------------------------------------------------------
# Output Generation: JSON Mode
# ------------------------------------------------------------------------------
if ${OUTPUT_JSON}; then
    cat <<EOF
{
  "audit_metadata": {
    "hostname": "${HOSTNAME_VAL}",
    "os_name": "${OS_NAME_VAL}",
    "kernel": "${KERNEL_VAL}",
    "audit_timestamp_utc": "${AUDIT_TIMESTAMP_UTC}",
    "audit_timestamp_local": "${AUDIT_TIMESTAMP_LOCAL}",
    "audit_timestamp_iso": "${AUDIT_TIMESTAMP_ISO}",
    "threshold_days": ${THRESHOLD_DAYS},
    "include_system_accounts": ${INCLUDE_SYSTEM},
    "engines_detected": {
      "primary": "${ENGINE_PRIMARY}",
      "secondary": "${ENGINE_SECONDARY}",
      "tertiary": "${ENGINE_TERTIARY}"
    }
  },
  "summary": {
    "total_accounts_audited": ${TOTAL_ACCOUNTS},
    "active_accounts": ${COUNT_ACTIVE},
    "inactive_accounts": ${COUNT_INACTIVE},
    "inactivity_rate_percent": ${INACTIVITY_RATE}
  },
  "accounts": [
EOF

    for (( i=0; i<TOTAL_ACCOUNTS; i++ )); do
        u_nm="${AUDIT_USERNAMES[$i]}"
        u_id="${AUDIT_UIDS[$i]}"
        u_sh="${AUDIT_SHELLS[$i]}"
        u_hm="${AUDIT_HOMES[$i]}"
        u_dt="${AUDIT_LAST_DATES[$i]}"
        u_dy="${AUDIT_DAYS[$i]}"
        u_st="${AUDIT_STATUSES[$i]}"
        u_eg="${AUDIT_ENGINES[$i]}"

        # JSON quotation / formatting for days
        days_json_val="null"
        if [[ "${u_dy}" =~ ^[0-9]+$ ]]; then
            days_json_val="${u_dy}"
        fi

        comma=","
        if (( i == TOTAL_ACCOUNTS - 1 )); then
            comma=""
        fi

        cat <<EOF
    {
      "username": "${u_nm}",
      "uid": ${u_id},
      "shell": "${u_sh}",
      "home": "${u_hm}",
      "last_login_date": "${u_dt}",
      "days_inactive": ${days_json_val},
      "status": "${u_st}",
      "resolved_via": "${u_eg}"
    }${comma}
EOF
    done

    cat <<EOF
  ]
}
EOF

    # Still write clean log record
    {
        echo "================================================================================"
        echo "[AUDIT TIMESTAMP] ${AUDIT_TIMESTAMP_LOCAL} (Threshold: ${THRESHOLD_DAYS} days)"
        echo "[SYSTEM INFO]     Host: ${HOSTNAME_VAL} | OS: ${OS_NAME_VAL} | Kernel: ${KERNEL_VAL}"
        echo "[AUDIT SUMMARY]   Total: ${TOTAL_ACCOUNTS} | Active: ${COUNT_ACTIVE} | Inactive: ${COUNT_INACTIVE} (${INACTIVITY_RATE}%)"
        echo "--------------------------------------------------------------------------------"
        for (( i=0; i<TOTAL_ACCOUNTS; i++ )); do
            printf "User: %-15s UID: %-5s Shell: %-15s LastLogin: %-20s Days: %-6s Status: %s\n" \
                "${AUDIT_USERNAMES[$i]}" "${AUDIT_UIDS[$i]}" "${AUDIT_SHELLS[$i]}" \
                "${AUDIT_LAST_DATES[$i]}" "${AUDIT_DAYS[$i]}" "${AUDIT_STATUSES[$i]}"
        done
        echo "================================================================================"
        echo ""
    } >> "${LOG_FILE}"

    exit 0
fi

# ------------------------------------------------------------------------------
# Output Generation: Human-Readable CLI Table Mode
# ------------------------------------------------------------------------------
echo -e "${CLR_CYAN}${CLR_BOLD}====================================================================================================${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}                        INACTIVE EMPLOYEE DETECTION AUDIT REPORT (AS_02)                            ${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}====================================================================================================${CLR_RESET}"
echo -e "  ${CLR_BOLD}Host System:${CLR_RESET}   ${HOSTNAME_VAL} (${OS_NAME_VAL})"
echo -e "  ${CLR_BOLD}Kernel:${CLR_RESET}        ${KERNEL_VAL}"
echo -e "  ${CLR_BOLD}Audit Time:${CLR_RESET}    ${AUDIT_TIMESTAMP_LOCAL}"
echo -e "  ${CLR_BOLD}Threshold:${CLR_RESET}     ${CLR_YELLOW}${THRESHOLD_DAYS} Days${CLR_RESET} (Inactivity criteria: last login > ${THRESHOLD_DAYS}d OR Never)"
echo -e "  ${CLR_BOLD}Engine Info:${CLR_RESET}   Primary: ${ENGINE_PRIMARY} | Secondary: ${ENGINE_SECONDARY} | Tertiary: ${ENGINE_TERTIARY}"
echo -e "${CLR_GRAY}----------------------------------------------------------------------------------------------------${CLR_RESET}"
printf "  ${CLR_BOLD}%-16s %-6s %-16s %-22s %-15s %-12s${CLR_RESET}\n" \
    "USERNAME" "UID" "LOGIN SHELL" "LAST LOGIN DATE" "DAYS INACTIVE" "STATUS"
echo -e "${CLR_GRAY}----------------------------------------------------------------------------------------------------${CLR_RESET}"

for (( i=0; i<TOTAL_ACCOUNTS; i++ )); do
    u_nm="${AUDIT_USERNAMES[$i]}"
    u_id="${AUDIT_UIDS[$i]}"
    u_sh="${AUDIT_SHELLS[$i]}"
    u_dt="${AUDIT_LAST_DATES[$i]}"
    u_dy="${AUDIT_DAYS[$i]}"
    u_st="${AUDIT_STATUSES[$i]}"

    if [[ "${u_st}" == "ACTIVE" ]]; then
        status_disp="${CLR_GREEN}${CLR_BOLD}ACTIVE${CLR_RESET}"
        days_disp="${CLR_GREEN}${u_dy} d${CLR_RESET}"
        date_disp="${CLR_GREEN}${u_dt}${CLR_RESET}"
    else
        status_disp="${CLR_RED}${CLR_BOLD}INACTIVE${CLR_RESET}"
        if [[ "${u_dy}" == "Never" ]]; then
            days_disp="${CLR_RED}Never${CLR_RESET}"
            date_disp="${CLR_RED}Never logged in${CLR_RESET}"
        else
            days_disp="${CLR_YELLOW}${u_dy} d${CLR_RESET}"
            date_disp="${CLR_YELLOW}${u_dt}${CLR_RESET}"
        fi
    fi

    printf "  %-16s %-6s %-16s %-32b %-24b %-20b\n" \
        "${u_nm}" "${u_id}" "${u_sh}" "${date_disp}" "${days_disp}" "${status_disp}"
done

echo -e "${CLR_GRAY}----------------------------------------------------------------------------------------------------${CLR_RESET}"
echo -e "  ${CLR_BOLD}AUDIT SUMMARY:${CLR_RESET} Total Audited: ${CLR_BOLD}${TOTAL_ACCOUNTS}${CLR_RESET} | " \
        "Active: ${CLR_GREEN}${CLR_BOLD}${COUNT_ACTIVE}${CLR_RESET} | " \
        "Inactive: ${CLR_RED}${CLR_BOLD}${COUNT_INACTIVE}${CLR_RESET} " \
        "(${CLR_YELLOW}${CLR_BOLD}${INACTIVITY_RATE}% Inactive${CLR_RESET})"
echo -e "${CLR_CYAN}${CLR_BOLD}====================================================================================================${CLR_RESET}"

# ------------------------------------------------------------------------------
# Audit Trail Logging (Written to logs/inactive_check.log)
# ------------------------------------------------------------------------------
{
    echo "================================================================================"
    echo "[AUDIT TIMESTAMP] ${AUDIT_TIMESTAMP_LOCAL} (Threshold: ${THRESHOLD_DAYS} days)"
    echo "[SYSTEM INFO]     Host: ${HOSTNAME_VAL} | OS: ${OS_NAME_VAL} | Kernel: ${KERNEL_VAL}"
    echo "[ENGINE DETECTED] Primary: ${ENGINE_PRIMARY} | Secondary: ${ENGINE_SECONDARY} | Tertiary: ${ENGINE_TERTIARY}"
    echo "[AUDIT SUMMARY]   Total: ${TOTAL_ACCOUNTS} | Active: ${COUNT_ACTIVE} | Inactive: ${COUNT_INACTIVE} (${INACTIVITY_RATE}%)"
    echo "--------------------------------------------------------------------------------"
    printf "%-16s %-6s %-16s %-22s %-15s %-12s\n" \
        "USERNAME" "UID" "LOGIN SHELL" "LAST LOGIN DATE" "DAYS INACTIVE" "STATUS"
    echo "--------------------------------------------------------------------------------"
    for (( i=0; i<TOTAL_ACCOUNTS; i++ )); do
        printf "%-16s %-6s %-16s %-22s %-15s %-12s\n" \
            "${AUDIT_USERNAMES[$i]}" "${AUDIT_UIDS[$i]}" "${AUDIT_SHELLS[$i]}" \
            "${AUDIT_LAST_DATES[$i]}" "${AUDIT_DAYS[$i]}" "${AUDIT_STATUSES[$i]}"
    done
    echo "================================================================================"
    echo ""
} >> "${LOG_FILE}"

echo -e "${CLR_GRAY}[INFO] Audit record successfully appended to: ${LOG_FILE}${CLR_RESET}"

exit 0
