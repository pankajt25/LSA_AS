#!/usr/bin/env bash
# ==============================================================================
# Script: archive_old_files.sh
# Purpose: Identify project files older than N days and archive them safely.
# Author: System Administrator (LSA Sprint AS_41)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/archive_${TIMESTAMP}.log"
SUMMARY_JSON="${SCRIPT_DIR}/logs/last_run.json"

# Defaults
SOURCE_DIR="${SCRIPT_DIR}/sandbox_data/projects"
ARCHIVE_DIR="${SCRIPT_DIR}/sandbox_data/archive"
DAYS_THRESHOLD=30
DRY_RUN=false
COMPRESS=true

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
  -s, --source <DIR>       Source directory to scan (default: sandbox_data/projects)
  -a, --archive <DIR>      Archive destination directory (default: sandbox_data/archive)
  -d, --days <DAYS>        Retention threshold in days (files > N days are archived, default: 30)
  -c, --compress           Compress archived files into a tar.gz bundle (default: true)
  --no-compress            Keep files unpacked in archive directory
  -n, --dry-run            Simulate scanning without moving files
  -h, --help               Display this help message
EOF
    exit 0
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -a|--archive)
            ARCHIVE_DIR="$2"
            shift 2
            ;;
        -d|--days)
            DAYS_THRESHOLD="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
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
log "INFO" "LSA Sprint AS_41 - Old Project File Archival Engine"
log "INFO" "Source Directory:     ${SOURCE_DIR}"
log "INFO" "Archive Directory:    ${ARCHIVE_DIR}"
log "INFO" "Age Threshold:        > ${DAYS_THRESHOLD} days"
log "INFO" "Dry Run Mode:         ${DRY_RUN}"
log "INFO" "Compression:          ${COMPRESS}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

# Ensure directories exist
mkdir -p "${SOURCE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# Populate sandbox project files if empty
TOTAL_EXISTING=$(find "${SOURCE_DIR}" -type f 2>/dev/null | wc -l || true)
if [ "${TOTAL_EXISTING}" -eq 0 ]; then
    log "INFO" "Source directory is empty. Generating realistic demo project files with historical mtimes..."
    
    mkdir -p "${SOURCE_DIR}/alpha_project/docs" \
             "${SOURCE_DIR}/alpha_project/builds" \
             "${SOURCE_DIR}/beta_service/logs" \
             "${SOURCE_DIR}/gamma_analytics/reports" \
             "${SOURCE_DIR}/legacy_core/src"

    # Files older than 30 days (Targets for archiving)
    echo "Architecture Document v0.1" > "${SOURCE_DIR}/alpha_project/docs/arch_v0.1_old.pdf"
    touch -d "120 days ago" "${SOURCE_DIR}/alpha_project/docs/arch_v0.1_old.pdf"

    dd if=/dev/urandom of="${SOURCE_DIR}/alpha_project/builds/release_2023_candidate.iso" bs=1024 count=128 status=none
    touch -d "95 days ago" "${SOURCE_DIR}/alpha_project/builds/release_2023_candidate.iso"

    echo "[DEBUG] 2023-01-15 Server startup log dump" > "${SOURCE_DIR}/beta_service/logs/service_2023_debug.log"
    touch -d "65 days ago" "${SOURCE_DIR}/beta_service/logs/service_2023_debug.log"

    echo "Quarterly Financial Analysis Q1 2024" > "${SOURCE_DIR}/gamma_analytics/reports/q1_2024_interim.csv"
    touch -d "48 days ago" "${SOURCE_DIR}/gamma_analytics/reports/q1_2024_interim.csv"

    echo "/* Deprecated driver stub */ int init_old() { return 0; }" > "${SOURCE_DIR}/legacy_core/src/driver_v1.c"
    touch -d "40 days ago" "${SOURCE_DIR}/legacy_core/src/driver_v1.c"

    # Recent files (Must NOT be archived)
    echo "Active project specs 2026" > "${SOURCE_DIR}/alpha_project/docs/specs_current.md"
    touch -d "5 days ago" "${SOURCE_DIR}/alpha_project/docs/specs_current.md"

    echo "[INFO] Current application runtime logs" > "${SOURCE_DIR}/beta_service/logs/runtime_current.log"
    touch -d "1 days ago" "${SOURCE_DIR}/beta_service/logs/runtime_current.log"

    echo "id,metric,value\n1,throughput,9420" > "${SOURCE_DIR}/gamma_analytics/reports/current_metrics.csv"
    touch -d "10 days ago" "${SOURCE_DIR}/gamma_analytics/reports/current_metrics.csv"

    echo "/* Production engine core */ int main() { return 0; }" > "${SOURCE_DIR}/legacy_core/src/main.c"
    touch -d "2 days ago" "${SOURCE_DIR}/legacy_core/src/main.c"

    log "INFO" "Demo files seeded: 5 stale candidates (>30d), 4 active files (<30d)."
fi

# Step 1: Scan for eligible files
log "INFO" "Scanning '${SOURCE_DIR}' for files older than ${DAYS_THRESHOLD} days..."

# Use temporary file to hold scan results
CANDIDATES_LIST="$(mktemp)"
find "${SOURCE_DIR}" -type f -mtime +"${DAYS_THRESHOLD}" > "${CANDIDATES_LIST}"

CANDIDATE_COUNT=$(wc -l < "${CANDIDATES_LIST}")
log "INFO" "Found ${CANDIDATE_COUNT} candidate file(s) exceeding ${DAYS_THRESHOLD} days threshold."

TOTAL_FILES_SCANNED=$(find "${SOURCE_DIR}" -type f | wc -l)
TOTAL_BYTES_ARCHIVED=0
ARCHIVED_FILES_JSON="[]"

BATCH_STAMP="$(date +"%Y%m%d_%H%M%S")"
TARGET_BATCH_DIR="${ARCHIVE_DIR}/archive_${BATCH_STAMP}"
ARCHIVE_BUNDLE="${ARCHIVE_DIR}/project_archive_${BATCH_STAMP}.tar.gz"

if [ "${CANDIDATE_COUNT}" -gt 0 ]; then
    if [ "${DRY_RUN}" = false ]; then
        mkdir -p "${TARGET_BATCH_DIR}"
        MANIFEST_FILE="${TARGET_BATCH_DIR}/manifest.txt"
        CHECKSUM_FILE="${TARGET_BATCH_DIR}/checksums.sha256"
        echo "# Archival Manifest created on $(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "${MANIFEST_FILE}"
        echo "# Source: ${SOURCE_DIR}" >> "${MANIFEST_FILE}"
        echo "# Threshold: ${DAYS_THRESHOLD} days" >> "${MANIFEST_FILE}"
        echo "------------------------------------------------------------------" >> "${MANIFEST_FILE}"
    fi

    # Read each candidate and process
    while IFS= read -r filepath; do
        [ -z "${filepath}" ] && continue
        
        # Calculate relative path
        rel_path="${filepath#"${SOURCE_DIR}/"}"
        file_bytes=$(stat -c%s "${filepath}" 2>/dev/null || wc -c < "${filepath}")
        file_mtime=$(stat -c%y "${filepath}" 2>/dev/null || date -r "${filepath}" +"%Y-%m-%d %H:%M:%S")
        file_age_days=$(( ( $(date +%s) - $(stat -c%Y "${filepath}") ) / 86400 ))
        
        TOTAL_BYTES_ARCHIVED=$((TOTAL_BYTES_ARCHIVED + file_bytes))

        log "INFO" "Candidate: ${rel_path} (${file_bytes} B, last modified: ${file_mtime}, age: ${file_age_days}d)"

        if [ "${DRY_RUN}" = false ]; then
            dest_file_path="${TARGET_BATCH_DIR}/${rel_path}"
            mkdir -p "$(dirname "${dest_file_path}")"
            
            # Compute checksum before move
            sha_hash=$(sha256sum "${filepath}" | awk '{print $1}')
            echo "${sha_hash}  ${rel_path}" >> "${CHECKSUM_FILE}"
            echo "${rel_path} | Size: ${file_bytes} bytes | Mtime: ${file_mtime} | Hash: ${sha_hash}" >> "${MANIFEST_FILE}"
            
            # Move file
            mv "${filepath}" "${dest_file_path}"
            log "SUCCESS" "Archived -> ${dest_file_path}"
        fi
    done < "${CANDIDATES_LIST}"

    # Compress if requested and not in dry-run
    if [ "${DRY_RUN}" = false ] && [ "${COMPRESS}" = true ]; then
        log "INFO" "Compressing archive batch into ${ARCHIVE_BUNDLE}..."
        tar -czf "${ARCHIVE_BUNDLE}" -C "${ARCHIVE_DIR}" "archive_${BATCH_STAMP}"
        rm -rf "${TARGET_BATCH_DIR}"
        log "SUCCESS" "Archival bundle created: ${ARCHIVE_BUNDLE} ($(stat -c%s "${ARCHIVE_BUNDLE}") bytes)"
        FINAL_ARCHIVE_PATH="${ARCHIVE_BUNDLE}"
    else
        FINAL_ARCHIVE_PATH="${TARGET_BATCH_DIR}"
    fi

    # Clean empty parent directories in source
    find "${SOURCE_DIR}" -mindepth 1 -type d -empty -delete 2>/dev/null || true
else
    log "INFO" "No files exceeded the age threshold. Nothing to archive."
    FINAL_ARCHIVE_PATH="None"
fi

rm -f "${CANDIDATES_LIST}"

REMAINING_FILES=$(find "${SOURCE_DIR}" -type f | wc -l)
log "INFO" "Archival operation completed."
log "INFO" "Summary: ${CANDIDATE_COUNT} files archived, ${TOTAL_BYTES_ARCHIVED} bytes reclaimed, ${REMAINING_FILES} active files remaining."

# Generate JSON telemetry for run.sh
python3 - <<PYEOF
import json, os, datetime

summary = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "source_dir": "${SOURCE_DIR}",
    "archive_dir": "${ARCHIVE_DIR}",
    "days_threshold": ${DAYS_THRESHOLD},
    "dry_run": True if "${DRY_RUN}" == "true" else False,
    "compressed": True if "${COMPRESS}" == "true" else False,
    "total_scanned_files": ${TOTAL_FILES_SCANNED},
    "archived_count": ${CANDIDATE_COUNT},
    "bytes_reclaimed": ${TOTAL_BYTES_ARCHIVED},
    "remaining_files": ${REMAINING_FILES},
    "archive_artifact": "${FINAL_ARCHIVE_PATH}",
    "log_file": "${LOG_FILE}"
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(summary, f, indent=2)

print(f"Summary telemetry saved to ${SUMMARY_JSON}")
PYEOF

exit 0
