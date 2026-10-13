#!/usr/bin/env bash
# ==============================================================================
# Script: offboard_employee.sh
# Purpose: Securely offboard an employee account: terminate processes, lock
#          password, disable login shell, expire account, and archive home dir.
# Author: System Administrator (LSA Sprint AS_43)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
ARCHIVE_DIR="${SCRIPT_DIR}/archives"
mkdir -p "${LOG_DIR}" "${ARCHIVE_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/offboarding_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

TARGET_USER="lsatest_offboard_demo"

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
  -u, --user <USERNAME>    Username to offboard (must start with lsatest_, default: lsatest_offboard_demo)
  -a, --archive-dir <DIR>  Destination directory for archive (default: archives/)
  -h, --help               Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        -a|--archive-dir)
            ARCHIVE_DIR="$2"
            shift 2
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

# Safety validation
if [[ ! "${TARGET_USER}" =~ ^lsatest_ ]]; then
    log "ERROR" "Safety rule violation: TARGET_USER must be prefixed with 'lsatest_'. Received: '${TARGET_USER}'"
    exit 1
fi

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_43 - Employee Offboarding Engine"
log "INFO" "Target Employee:      ${TARGET_USER}"
log "INFO" "Archive Directory:    ${ARCHIVE_DIR}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# Ensure target user exists for demonstration
if ! getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
    log "INFO" "Demo user '${TARGET_USER}' does not exist. Creating with sample files..."
    sudo useradd -m -s /bin/bash -c "Offboarding Demo Employee" "${TARGET_USER}"
    # Set dummy password so account isn't locked by default
    echo "${TARGET_USER}:DemoPass123\!" | sudo chpasswd
    
    # Populate realistic user home documents
    user_home="/home/${TARGET_USER}"
    sudo -u "${TARGET_USER}" mkdir -p "${user_home}/documents" "${user_home}/projects" "${user_home}/mail"
    echo "Quarterly handover summary" | sudo -u "${TARGET_USER}" tee "${user_home}/documents/handover_notes.txt" >/dev/null
    echo "print('Employee microservice v2')" | sudo -u "${TARGET_USER}" tee "${user_home}/projects/service.py" >/dev/null
    echo "Client contacts list" | sudo -u "${TARGET_USER}" tee "${user_home}/mail/contacts.csv" >/dev/null
    log "SUCCESS" "Provisioned demo user '${TARGET_USER}' with home directory '${user_home}'."
fi

# Capture Pre-Offboarding State
USER_ENTRY="$(getent passwd "${TARGET_USER}")"
PRE_SHELL="$(echo "${USER_ENTRY}" | cut -d: -f7)"
USER_HOME="$(echo "${USER_ENTRY}" | cut -d: -f6)"
PRE_SHADOW_STATUS="$(sudo passwd -S "${TARGET_USER}" 2>/dev/null | awk '{print $2}' || echo "P")"

log "INFO" "Pre-Offboarding State:"
log "INFO" "  Home Directory:    ${USER_HOME}"
log "INFO" "  Active Shell:      ${PRE_SHELL}"
log "INFO" "  Password Status:   ${PRE_SHADOW_STATUS} (P=Password active, L=Locked, NP=No password)"

# Step 1: Kill all running processes owned by user
log "INFO" "Step 1: Terminating any active processes for '${TARGET_USER}'..."
sudo pkill -u "${TARGET_USER}" 2>/dev/null || true
ACTIVE_PIDS=$(pgrep -u "${TARGET_USER}" 2>/dev/null | wc -l || true)
log "SUCCESS" "Active processes terminated. Remaining processes: ${ACTIVE_PIDS}."

# Step 2: Lock the user account password
log "INFO" "Step 2: Locking user password..."
sudo usermod -L "${TARGET_USER}"
POST_SHADOW_STATUS="$(sudo passwd -S "${TARGET_USER}" 2>/dev/null | awk '{print $2}' || echo "L")"
log "SUCCESS" "Password locked. Status: ${POST_SHADOW_STATUS}."

# Step 3: Disable interactive login shell
log "INFO" "Step 3: Disabling interactive login shell..."
NOLOGIN_SHELL="/usr/sbin/nologin"
if [ ! -x "${NOLOGIN_SHELL}" ]; then
    if [ -x "/sbin/nologin" ]; then
        NOLOGIN_SHELL="/sbin/nologin"
    else
        NOLOGIN_SHELL="/bin/false"
    fi
fi
sudo usermod -s "${NOLOGIN_SHELL}" "${TARGET_USER}"
POST_SHELL="$(getent passwd "${TARGET_USER}" | cut -d: -f7)"
log "SUCCESS" "Shell updated to: ${POST_SHELL}."

# Step 4: Expire the user account
log "INFO" "Step 4: Expiring account validity date..."
# Expire immediately
sudo usermod -e 1 "${TARGET_USER}"
EXPIRE_DATE="$(sudo chage -l "${TARGET_USER}" | grep -i "Account expires" | cut -d: -f2- | xargs)"
log "SUCCESS" "Account expiry status: ${EXPIRE_DATE}."

# Step 5: Archive Home Directory
log "INFO" "Step 5: Archiving home directory '${USER_HOME}'..."
ARCHIVE_NAME="${TARGET_USER}_archive_${TIMESTAMP}.tar.gz"
ARCHIVE_FILE="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

if [ -d "${USER_HOME}" ]; then
    HOME_PARENT="$(dirname "${USER_HOME}")"
    HOME_BASE="$(basename "${USER_HOME}")"
    
    sudo tar -czf "${ARCHIVE_FILE}" -C "${HOME_PARENT}" "${HOME_BASE}"
    # Set ownership of the archive to running administrator
    sudo chown "$(id -un):$(id -gn)" "${ARCHIVE_FILE}"
    
    ARCHIVE_SIZE=$(stat -c%s "${ARCHIVE_FILE}")
    SHA256_HASH=$(sha256sum "${ARCHIVE_FILE}" | awk '{print $1}')
    echo "${SHA256_HASH}  ${ARCHIVE_NAME}" > "${ARCHIVE_FILE}.sha256"
    
    log "SUCCESS" "Home directory successfully archived: ${ARCHIVE_FILE} (${ARCHIVE_SIZE} bytes)."
    log "SUCCESS" "SHA-256 Digest: ${SHA256_HASH}."
    
    # Non-destructive decompression test
    log "INFO" "Verifying archive bundle integrity..."
    ARCHIVE_FILE_COUNT=$(tar -tzf "${ARCHIVE_FILE}" | wc -l)
    log "SUCCESS" "Archive integrity confirmed. Contained entries: ${ARCHIVE_FILE_COUNT}."
else
    log "WARN" "Home directory '${USER_HOME}' does not exist on disk."
    ARCHIVE_FILE="None"
    ARCHIVE_SIZE=0
    SHA256_HASH="None"
    ARCHIVE_FILE_COUNT=0
fi

# Step 6: Generate JSON Telemetry
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "target_user": "${TARGET_USER}",
    "pre_shell": "${PRE_SHELL}",
    "post_shell": "${POST_SHELL}",
    "pre_shadow_status": "${PRE_SHADOW_STATUS}",
    "post_shadow_status": "${POST_SHADOW_STATUS}",
    "account_expiry": "${EXPIRE_DATE}",
    "home_directory": "${USER_HOME}",
    "archive_file": "${ARCHIVE_FILE}",
    "archive_size_bytes": ${ARCHIVE_SIZE},
    "sha256": "${SHA256_HASH}",
    "archived_entries_count": ${ARCHIVE_FILE_COUNT},
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Summary telemetry recorded to ${SUMMARY_JSON}")
PYEOF

log "INFO" "Employee offboarding completed successfully."
exit 0
