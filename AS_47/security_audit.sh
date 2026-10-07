#!/usr/bin/env bash
# ==============================================================================
# Script: security_audit.sh
# Purpose: Comprehensive Linux security auditing covering password-less accounts,
#          world-writable files, failed login attempts, and active user sessions.
# Author: System Administrator (LSA Sprint AS_47)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
DATA_DIR="${SCRIPT_DIR}/sandbox_data"
mkdir -p "${LOG_DIR}" "${DATA_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/security_audit_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

DEMO_USER="lsatest_audit_nopass"
AUDIT_TARGET_DIR="${SCRIPT_DIR}"

log() {
    local level="$1"
    shift
    local msg="[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*"
    echo -e "${msg}"
    echo -e "${msg}" >> "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --target-dir <DIR>    Directory tree to audit for world-writable files (default: project folder)
  --no-demo-user        Skip provisioning test passwordless account
  -h, --help            Display this help message
EOF
    exit 0
}

CREATE_DEMO_USER=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dir)
            AUDIT_TARGET_DIR="$2"
            shift 2
            ;;
        --no-demo-user)
            CREATE_DEMO_USER=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            ;;
    esac
done

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_47 - System Security Audit Engine"
log "INFO" "Audit Target:         ${AUDIT_TARGET_DIR}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# Ensure demo environment has verifiable test artifacts
if [ "${CREATE_DEMO_USER}" = true ]; then
    if ! getent passwd "${DEMO_USER}" >/dev/null 2>&1; then
        log "INFO" "Provisioning test account '${DEMO_USER}' to demonstrate passwordless detection..."
        sudo useradd -M -s /usr/sbin/nologin -c "Security Audit Test Subject" "${DEMO_USER}"
        sudo passwd -d "${DEMO_USER}" 2>/dev/null || sudo usermod -p "" "${DEMO_USER}"
        log "SUCCESS" "Demo user '${DEMO_USER}' created with blank password."
    fi
fi

# Create a sample world-writable file in sandbox_data
SAMPLE_WW_FILE="${DATA_DIR}/insecure_shared_config.conf"
echo "# Insecure configuration file for testing" > "${SAMPLE_WW_FILE}"
chmod 0666 "${SAMPLE_WW_FILE}"
log "INFO" "Seeded world-writable test file: ${SAMPLE_WW_FILE}"

# --- Vector 1: Audit Password-less Accounts ---
log "INFO" "Vector 1: Scanning /etc/shadow for password-less accounts..."
PASSWORDLESS_ACCOUNTS=()
while IFS=: read -r user pass _; do
    # Check for empty password hash or NP status
    if [ -z "${pass}" ]; then
        user_shell=$(getent passwd "${user}" | cut -d: -f7 || echo "unknown")
        user_uid=$(getent passwd "${user}" | cut -d: -f3 || echo "unknown")
        log "WARN" "[HIGH RISK] Password-less account found: '${user}' (UID: ${user_uid}, Shell: ${user_shell})"
        PASSWORDLESS_ACCOUNTS+=("{\"user\": \"${user}\", \"uid\": \"${user_uid}\", \"shell\": \"${user_shell}\", \"severity\": \"CRITICAL\"}")
    fi
done < <(sudo cat /etc/shadow)

PASSWORDLESS_COUNT=${#PASSWORDLESS_ACCOUNTS[@]}
log "INFO" "Found ${PASSWORDLESS_COUNT} password-less account(s)."

# --- Vector 2: Audit World-Writable Files ---
log "INFO" "Vector 2: Auditing directory '${AUDIT_TARGET_DIR}' for world-writable files..."
WORLD_WRITABLE_FILES=()
while IFS= read -r f; do
    [ -z "${f}" ] && continue
    # Skip .git internal files to keep audit focused
    if [[ "${f}" == *"/.git/"* ]]; then
        continue
    fi
    f_stat=$(stat -c "%A|%a|%U|%G|%s" "${f}" 2>/dev/null || echo "")
    if [ -n "${f_stat}" ]; then
        IFS="|" read -r perm_str perm_oct owner grp f_size <<< "${f_stat}"
        rel_f="${f#"${SCRIPT_DIR}/"}"
        log "WARN" "[MEDIUM RISK] World-writable file: ${rel_f} (${perm_str} / ${perm_oct}, Owner: ${owner}:${grp})"
        WORLD_WRITABLE_FILES+=("{\"path\": \"${rel_f}\", \"permissions\": \"${perm_str}\", \"octal\": \"${perm_oct}\", \"owner\": \"${owner}\", \"group\": \"${grp}\", \"size\": \"${f_size}\"}")
    fi
done < <(find "${AUDIT_TARGET_DIR}" -type f -perm -0002 2>/dev/null || true)

WW_COUNT=${#WORLD_WRITABLE_FILES[@]}
log "INFO" "Found ${WW_COUNT} world-writable file(s)."

# --- Vector 3: Audit Failed Logins ---
log "INFO" "Vector 3: Analyzing authentication logs for failed login attempts..."
FAILED_LOGINS=()
AUTH_LOG="/var/log/auth.log"
if [ ! -f "${AUTH_LOG}" ]; then
    AUTH_LOG="/var/log/secure"
fi

if [ -f "${AUTH_LOG}" ]; then
    # Extract recent failed logins (last 50 matches)
    while IFS= read -r log_line; do
        [ -z "${log_line}" ] && continue
        # Extract IP, User, Timestamp where possible
        f_user=$(echo "${log_line}" | grep -oP 'for (invalid user )?\K[a-zA-Z0-9_\-]+' || echo "unknown")
        f_ip=$(echo "${log_line}" | grep -oP 'from \K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' || echo "local/internal")
        f_time=$(echo "${log_line}" | awk '{print $1" "$2" "$3}')
        FAILED_LOGINS+=("{\"timestamp\": \"${f_time}\", \"user\": \"${f_user}\", \"source_ip\": \"${f_ip}\", \"raw\": \"$(echo "${log_line}" | tr '"' "'" | xargs)\"}")
    done < <(sudo grep -iE "(Failed password|authentication failure|Failed publickey)" "${AUTH_LOG}" 2>/dev/null | tail -n 15 || true)
fi

FAILED_COUNT=${#FAILED_LOGINS[@]}
log "INFO" "Found ${FAILED_COUNT} recent failed login attempt(s)."

# --- Vector 4: Audit Active Users ---
log "INFO" "Vector 4: Profiling active interactive login sessions..."
ACTIVE_USERS=()
while IFS= read -r line; do
    [ -z "${line}" ] && continue
    a_user=$(echo "${line}" | awk '{print $1}')
    a_tty=$(echo "${line}" | awk '{print $2}')
    a_login=$(echo "${line}" | awk '{print $3" "$4}')
    a_host=$(echo "${line}" | awk '{print $5}' | tr -d '()')
    [ -z "${a_host}" ] && a_host="local"
    
    log "INFO" "Active Session: User=${a_user}, TTY=${a_tty}, Login=${a_login}, Remote=${a_host}"
    ACTIVE_USERS+=("{\"user\": \"${a_user}\", \"tty\": \"${a_tty}\", \"login_time\": \"${a_login}\", \"remote_host\": \"${a_host}\"}")
done < <(who 2>/dev/null || true)

ACTIVE_COUNT=${#ACTIVE_USERS[@]}
log "INFO" "Identified ${ACTIVE_COUNT} active interactive session(s)."

# --- Compute Overall Security Posture ---
# Score starts at 100, drops 25 per passwordless account, 5 per world-writable file
COMPLIANCE_SCORE=100
COMPLIANCE_SCORE=$((COMPLIANCE_SCORE - (PASSWORDLESS_COUNT * 30)))
COMPLIANCE_SCORE=$((COMPLIANCE_SCORE - (WW_COUNT * 5)))
[ "${COMPLIANCE_SCORE}" -lt 0 ] && COMPLIANCE_SCORE=0

if [ "${PASSWORDLESS_COUNT}" -gt 0 ]; then
    OVERALL_SEVERITY="CRITICAL VULNERABILITY DETECTED"
    SEVERITY_CLASS="CRITICAL"
elif [ "${WW_COUNT}" -gt 0 ]; then
    OVERALL_SEVERITY="WARNING: PERMISSION DRIFT"
    SEVERITY_CLASS="WARNING"
else
    OVERALL_SEVERITY="NOMINAL / COMPLIANT"
    SEVERITY_CLASS="SUCCESS"
fi

log "INFO" "Security Audit Complete. Compliance Score: ${COMPLIANCE_SCORE}% | Severity: [${OVERALL_SEVERITY}]"

# --- Export JSON Telemetry ---
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "compliance_score": ${COMPLIANCE_SCORE},
    "severity_label": "${OVERALL_SEVERITY}",
    "severity_class": "${SEVERITY_CLASS}",
    "summary": {
        "passwordless_accounts": ${PASSWORDLESS_COUNT},
        "world_writable_files": ${WW_COUNT},
        "failed_logins": ${FAILED_COUNT},
        "active_users": ${ACTIVE_COUNT}
    },
    "passwordless_details": [
        $(IFS=,; echo "${PASSWORDLESS_ACCOUNTS[*]}")
    ],
    "world_writable_details": [
        $(IFS=,; echo "${WORLD_WRITABLE_FILES[*]}")
    ],
    "failed_login_details": [
        $(IFS=,; echo "${FAILED_LOGINS[*]}")
    ],
    "active_user_details": [
        $(IFS=,; echo "${ACTIVE_USERS[*]}")
    ],
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Security audit telemetry written to ${SUMMARY_JSON}")
PYEOF

exit 0
