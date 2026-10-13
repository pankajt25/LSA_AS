#!/usr/bin/env bash
# ==============================================================================
# Script: sync_project.sh
# Purpose: Synchronize source project directory with a backup directory via rsync.
# Author: System Administrator (LSA Sprint AS_49)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
DATA_DIR="${SCRIPT_DIR}/sandbox_data"
mkdir -p "${LOG_DIR}" "${DATA_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/sync_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

# Defaults
SOURCE_DIR="${DATA_DIR}/source"
DEST_DIR="${DATA_DIR}/dest"
DRY_RUN=false
DELETE_PRUNE=true

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
  -s, --source <DIR>    Source directory (default: sandbox_data/source)
  -d, --dest <DIR>      Destination backup directory (default: sandbox_data/dest)
  -n, --dry-run         Perform trial run with no changes made
  --no-delete           Do not delete files in destination that were removed from source
  -h, --help            Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-delete)
            DELETE_PRUNE=false
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

# Sandboxing Safety Check (CRITICAL RULE)
if [[ "${SOURCE_DIR}" == "/" ]] || [[ "${DEST_DIR}" == "/" ]] || \
   [[ "${SOURCE_DIR}" == "/home"* && ! "${SOURCE_DIR}" == *"/Automation_sprint/"* ]] || \
   [[ "${DEST_DIR}" == "/home"* && ! "${DEST_DIR}" == *"/Automation_sprint/"* ]]; then
    log "ERROR" "Safety rule violation: Synchronization target must be isolated inside project sandbox!"
    exit 1
fi

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_49 - Automated File Synchronization Engine"
log "INFO" "Source Directory:     ${SOURCE_DIR}"
log "INFO" "Destination Backup:   ${DEST_DIR}"
log "INFO" "Dry Run Mode:         ${DRY_RUN}"
log "INFO" "Delete Extraneous:    ${DELETE_PRUNE}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

mkdir -p "${SOURCE_DIR}" "${DEST_DIR}"

# Populate source directory if empty or seed modifications
SOURCE_FILE_COUNT=$(find "${SOURCE_DIR}" -type f 2>/dev/null | wc -l || true)
if [ "${SOURCE_FILE_COUNT}" -eq 0 ]; then
    log "INFO" "Seeding initial enterprise project files in source directory..."
    mkdir -p "${SOURCE_DIR}/src" "${SOURCE_DIR}/docs" "${SOURCE_DIR}/config" "${SOURCE_DIR}/assets"
    
    echo "print('Application Core v1.0')" > "${SOURCE_DIR}/src/main.py"
    echo "def add(a, b): return a + b" > "${SOURCE_DIR}/src/utils.py"
    echo "# Microservice Architecture Specification" > "${SOURCE_DIR}/docs/architecture.md"
    echo '{"service": "auth-gateway", "port": 8080, "workers": 4}' > "${SOURCE_DIR}/config/settings.json"
    echo "Simulated binary asset data" > "${SOURCE_DIR}/assets/branding.svg"
    log "SUCCESS" "Seeded 5 baseline project files across 4 subdirectories."
else
    # Update a file to demonstrate incremental delta transfer
    echo "# Updated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${SOURCE_DIR}/docs/architecture.md"
    echo "def timestamp(): return '$(date +%s)'" >> "${SOURCE_DIR}/src/utils.py"
    log "INFO" "Added incremental updates to source files to demonstrate delta sync."
fi

# Build rsync command
RSYNC_CMD=("rsync" "-avh" "--stats")

if [ "${DELETE_PRUNE}" = true ]; then
    RSYNC_CMD+=("--delete")
fi

if [ "${DRY_RUN}" = true ]; then
    RSYNC_CMD+=("--dry-run")
fi

RSYNC_CMD+=("${SOURCE_DIR}/" "${DEST_DIR}/")

log "INFO" "Executing rsync: ${RSYNC_CMD[*]}"
RSYNC_STATS_FILE="$(mktemp)"
"${RSYNC_CMD[@]}" > "${RSYNC_STATS_FILE}" 2>&1 || {
    log "ERROR" "rsync execution failed!"
    cat "${RSYNC_STATS_FILE}" >> "${LOG_FILE}"
    rm -f "${RSYNC_STATS_FILE}"
    exit 1
}

cat "${RSYNC_STATS_FILE}" >> "${LOG_FILE}"

# Parse rsync stats
TOTAL_FILES=$(grep -oP 'Number of files: \K[0-9,]+' "${RSYNC_STATS_FILE}" | tr -d ',' || echo "0")
FILES_TRANSFERRED=$(grep -oP 'Number of (regular )?files transferred: \K[0-9,]+' "${RSYNC_STATS_FILE}" | tr -d ',' || echo "0")
TOTAL_FILE_SIZE=$(grep -oP 'Total file size: \K[0-9,.]+\s*[a-zA-Z]*' "${RSYNC_STATS_FILE}" || echo "0 bytes")
TOTAL_TRANSFERRED_SIZE=$(grep -oP 'Total transferred file size: \K[0-9,.]+\s*[a-zA-Z]*' "${RSYNC_STATS_FILE}" || echo "0 bytes")
LITERAL_DATA=$(grep -oP 'Literal data: \K[0-9,.]+\s*[a-zA-Z]*' "${RSYNC_STATS_FILE}" || echo "0 bytes")
SPEEDUP=$(grep -oP 'speedup is \K[0-9.]+' "${RSYNC_STATS_FILE}" || echo "1.00")

log "SUCCESS" "Rsync transfer completed successfully."
log "INFO" "Statistics: Files Considered=${TOTAL_FILES}, Transferred=${FILES_TRANSFERRED}, Transferred Size=${TOTAL_TRANSFERRED_SIZE}, Speedup=${SPEEDUP}"

# Post-sync verification: Cross-compare SHA-256 hashes of mirrored files
SYNC_VERIFIED=true
VERIFICATION_ROWS=()

while IFS= read -r src_file; do
    [ -z "${src_file}" ] && continue
    rel_path="${src_file#"${SOURCE_DIR}/"}"
    dest_file="${DEST_DIR}/${rel_path}"
    
    if [ -f "${dest_file}" ]; then
        src_hash=$(sha256sum "${src_file}" | awk '{print $1}')
        dest_hash=$(sha256sum "${dest_file}" | awk '{print $1}')
        file_bytes=$(stat -c%s "${src_file}")
        
        if [ "${src_hash}" == "${dest_hash}" ]; then
            status="MATCH"
        else
            status="MISMATCH"
            SYNC_VERIFIED=false
        fi
        VERIFICATION_ROWS+=("{\"file\": \"${rel_path}\", \"size\": \"${file_bytes} B\", \"src_hash\": \"${src_hash:0:16}...\", \"dest_hash\": \"${dest_hash:0:16}...\", \"status\": \"${status}\"}")
    else
        SYNC_VERIFIED=false
        VERIFICATION_ROWS+=("{\"file\": \"${rel_path}\", \"size\": \"-\", \"src_hash\": \"-\", \"dest_hash\": \"MISSING\", \"status\": \"MISSING\"}")
    fi
done < <(find "${SOURCE_DIR}" -type f 2>/dev/null || true)

rm -f "${RSYNC_STATS_FILE}"

log "INFO" "Integrity Verification: Sync Verified = ${SYNC_VERIFIED}"

# Export JSON Telemetry
python3 - <<PYEOF
import json, os, datetime

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "source_dir": "${SOURCE_DIR}",
    "dest_dir": "${DEST_DIR}",
    "dry_run": True if "${DRY_RUN}" == "true" else False,
    "delete_prune": True if "${DELETE_PRUNE}" == "true" else False,
    "stats": {
        "total_files": int("${TOTAL_FILES:-0}"),
        "files_transferred": int("${FILES_TRANSFERRED:-0}"),
        "total_file_size": "${TOTAL_FILE_SIZE}",
        "transferred_size": "${TOTAL_TRANSFERRED_SIZE}",
        "literal_data": "${LITERAL_DATA}",
        "speedup": "${SPEEDUP}"
    },
    "sync_verified": True if "${SYNC_VERIFIED}" == "true" else False,
    "files": [
        $(IFS=,; echo "${VERIFICATION_ROWS[*]}")
    ],
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(telemetry, f, indent=2)

print(f"Sync telemetry exported to ${SUMMARY_JSON}")
PYEOF

exit 0
