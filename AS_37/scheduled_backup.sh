#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #37: Cron-Based Automated Project Backup
# Script: scheduled_backup.sh
#
# DESCRIPTION:
#   Implements a production-ready automated project backup pipeline:
#     1. Relative path tarball packaging with gzip or bzip2 compression.
#     2. Non-destructive decompression integrity verification (tar -tzf).
#     3. Cryptographic SHA-256 manifest generation.
#     4. Automated retention policy enforcement (retention days cutoff).
#     5. Built-in Cron automation with strict '# LSA_SPRINT_TEST' tagging.
#     6. Telemetry serialization to logs/backup_metadata.json.
#
# USAGE:
#   ./scheduled_backup.sh [OPTIONS]
#
# OPTIONS:
#   --source <dir>          Path to target project directory to back up
#   --destination <dir>     Output directory for generated archives (default: backups/)
#   --format <gz|bz2>       Compression algorithm: gz or bz2 (default: gz)
#   --retention-days <N>    Purge backups older than N days (default: 14)
#   --schedule [EXPR]       Install backup job in user crontab (default: "0 1 * * *")
#   --verify-cron           Inspect crontab for active LSA test backup job
#   --unschedule            Remove LSA test backup job tagged # LSA_SPRINT_TEST
#   --json                  Generate structured JSON telemetry (default: true)
#   --help, -h              Display this help message
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="${SCRIPT_DIR}/sandbox_data/my_project"
DEFAULT_DEST="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/scheduled_backup.log"
JSON_FILE="${LOG_DIR}/backup_metadata.json"

mkdir -p "${LOG_DIR}" "${DEFAULT_DEST}"

# ANSI Colors
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"

# Default configuration
SOURCE_DIR="${DEFAULT_SOURCE}"
DEST_DIR="${DEFAULT_DEST}"
COMPRESSION="gz"
RETENTION_DAYS=14
ACTION="backup"
CRON_EXPR="0 1 * * *"
EMIT_JSON=true

log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local color=""
    case "${level}" in
        INFO) color="${CLR_CYAN}" ;;
        SUCCESS) color="${CLR_GREEN}" ;;
        WARN) color="${CLR_YELLOW}" ;;
        ERROR) color="${CLR_RED}" ;;
        *) color="${CLR_RESET}" ;;
    esac
    echo -e "${color}[${timestamp}] [${level}] ${message}${CLR_RESET}"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

print_header() {
    echo -e "${CLR_BLUE}${CLR_BOLD}"
    echo "================================================================================"
    echo "         LSA AUTOMATION SPRINT (AS_37) — SCHEDULED BACKUP ENGINE                "
    echo "================================================================================"
    echo -e "${CLR_RESET}"
}

show_help() {
    print_header
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --source <dir>          Target project directory to back up (default: sandbox_data/my_project)
  --destination <dir>     Output directory for backups (default: backups/)
  --format <gz|bz2>       Compression format: gz or bz2 (default: gz)
  --retention-days <days> Backup retention window in days (default: 14)
  --schedule [EXPR]       Schedule automated backup in Cron (default: "0 1 * * *")
  --verify-cron           Check if backup cron job is scheduled
  --unschedule            Remove backup cron job tagged with # LSA_SPRINT_TEST
  --json                  Emit JSON metadata to logs/backup_metadata.json
  --help, -h              Display this help message

Examples:
  ./scheduled_backup.sh
  ./scheduled_backup.sh --source /path/to/project --destination /var/backups
  ./scheduled_backup.sh --schedule "0 3 * * *"
  ./scheduled_backup.sh --verify-cron
  ./scheduled_backup.sh --unschedule
EOF
    exit 0
}

# Parse Command-Line Options
while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --destination)
            DEST_DIR="$2"
            shift 2
            ;;
        --format)
            COMPRESSION="$2"
            shift 2
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --schedule)
            ACTION="schedule"
            if [ $# -gt 1 ] && [[ "$2" != --* ]]; then
                CRON_EXPR="$2"
                shift 2
            else
                shift
            fi
            ;;
        --verify-cron)
            ACTION="verify-cron"
            shift
            ;;
        --unschedule)
            ACTION="unschedule"
            shift
            ;;
        --json)
            EMIT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${CLR_RED}Unknown option: $1${CLR_RESET}" >&2
            show_help
            ;;
    esac
done

# ==============================================================================
# CRON JOB MANAGEMENT FUNCTIONS
# ==============================================================================
install_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    local abs_source
    abs_source="$(cd "${SOURCE_DIR}" 2>/dev/null && pwd || echo "${SOURCE_DIR}")"
    local abs_dest
    abs_dest="$(cd "${DEST_DIR}" 2>/dev/null && pwd || echo "${DEST_DIR}")"

    local cron_cmd="/bin/bash \"${SCRIPT_DIR}/scheduled_backup.sh\" --source \"${abs_source}\" --destination \"${abs_dest}\" >> \"${LOG_DIR}/cron_backup.log\" 2>&1 ${cron_tag}"
    local new_entry="${CRON_EXPR} ${cron_cmd}"

    log_msg "INFO" "Installing scheduled backup cron task..."
    log_msg "INFO" "Target Directory : ${abs_source}"
    log_msg "INFO" "Backup Target    : ${abs_dest}"
    log_msg "INFO" "Schedule Cron    : '${CRON_EXPR}' (Tag: ${cron_tag})"

    local current_crontab=""
    current_crontab="$(crontab -l 2>/dev/null || true)"

    local filtered_crontab=""
    if [ -n "${current_crontab}" ]; then
        filtered_crontab="$(echo "${current_crontab}" | grep -v "${cron_tag}" || true)"
    fi

    local updated_crontab
    if [ -n "${filtered_crontab}" ]; then
        updated_crontab="${filtered_crontab}
${new_entry}"
    else
        updated_crontab="${new_entry}"
    fi

    echo "${updated_crontab}" | crontab -
    log_msg "SUCCESS" "Backup cron schedule installed successfully in user crontab."
    log_msg "INFO" "Verifying active crontab entry:"
    crontab -l | grep "${cron_tag}" | while read -r line; do
        echo -e "   ${CLR_GREEN}↳ ${line}${CLR_RESET}"
    done
}

verify_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    log_msg "INFO" "Inspecting user crontab for scheduled LSA backup jobs..."
    local active_jobs
    active_jobs="$(crontab -l 2>/dev/null | grep "${cron_tag}" || true)"

    if [ -n "${active_jobs}" ]; then
        log_msg "SUCCESS" "Active scheduled backup job(s) found:"
        echo "${active_jobs}" | while read -r line; do
            echo -e "   ${CLR_GREEN}✔ ${line}${CLR_RESET}"
        done
        return 0
    else
        log_msg "WARN" "No crontab entry matching '${cron_tag}' is currently installed."
        return 1
    fi
}

remove_cron_job() {
    local cron_tag="# LSA_SPRINT_TEST"
    log_msg "INFO" "Attempting to remove crontab entries matching '${cron_tag}'..."

    local current_crontab=""
    current_crontab="$(crontab -l 2>/dev/null || true)"

    if [ -z "${current_crontab}" ]; then
        log_msg "INFO" "Crontab is already empty. Nothing to remove."
        return 0
    fi

    if ! echo "${current_crontab}" | grep -q "${cron_tag}"; then
        log_msg "INFO" "No entries matching '${cron_tag}' found. System crontab clean."
        return 0
    fi

    local remaining_crontab
    remaining_crontab="$(echo "${current_crontab}" | grep -v "${cron_tag}" || true)"

    if [ -n "$(echo "${remaining_crontab}" | tr -d '[:space:]')" ]; then
        echo "${remaining_crontab}" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi

    log_msg "SUCCESS" "Successfully removed LSA test backup cron job(s)."
}

# ==============================================================================
# CORE BACKUP EXECUTION ENGINE
# ==============================================================================
execute_backup() {
    print_header
    local start_time
    start_time="$(date +%s)"

    # Validation
    if [ ! -d "${SOURCE_DIR}" ]; then
        log_msg "ERROR" "Specified source directory '${SOURCE_DIR}' does not exist!"
        exit 1
    fi

    mkdir -p "${DEST_DIR}"
    local abs_source
    abs_source="$(cd "${SOURCE_DIR}" && pwd)"
    local abs_dest
    abs_dest="$(cd "${DEST_DIR}" && pwd)"
    local project_name
    project_name="$(basename "${abs_source}")"

    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local ext="tar.gz"
    local tar_flag="czf"
    local test_flag="tzf"
    if [ "${COMPRESSION}" = "bz2" ]; then
        ext="tar.bz2"
        tar_flag="cjf"
        test_flag="tjf"
    fi

    local archive_filename="backup_${project_name}_${timestamp}.${ext}"
    local archive_path="${abs_dest}/${archive_filename}"
    local checksum_path="${archive_path}.sha256"

    log_msg "INFO" "Target Project   : ${abs_source}"
    log_msg "INFO" "Destination Dir  : ${abs_dest}"
    log_msg "INFO" "Archive Filename : ${archive_filename}"
    log_msg "INFO" "Compression Mode : ${COMPRESSION^^}"

    # Calculate source footprint
    local source_bytes
    source_bytes="$( { du -sb "${abs_source}" 2>/dev/null || true; } | awk 'NR==1 {print $1}')"
    if [ -z "${source_bytes}" ]; then
        source_bytes="$( { du -sk "${abs_source}" 2>/dev/null || true; } | awk 'NR==1 {print $1 * 1024}')"
    fi
    local source_files_count
    source_files_count="$( { find "${abs_source}" -type f 2>/dev/null || true; } | wc -l | tr -d ' ')"
    log_msg "INFO" "Source Footprint : ${source_bytes} bytes (${source_files_count} files)"

    # Execute relative archiving
    local parent_dir
    parent_dir="$(dirname "${abs_source}")"
    local base_target
    base_target="$(basename "${abs_source}")"

    log_msg "INFO" "Creating compressed archive..."
    tar -"${tar_flag}" "${archive_path}" -C "${parent_dir}" "${base_target}"

    if [ ! -f "${archive_path}" ]; then
        log_msg "ERROR" "Archive creation failed. Target file ${archive_path} not found."
        exit 1
    fi

    local archive_bytes
    archive_bytes="$( { stat -c %s "${archive_path}" 2>/dev/null || stat -f %z "${archive_path}" 2>/dev/null || true; } | head -n 1)"
    [ -z "${archive_bytes}" ] && archive_bytes=0
    log_msg "SUCCESS" "Archive generated successfully: ${archive_bytes} bytes"

    # Non-destructive decompression test
    log_msg "INFO" "Performing non-destructive archive integrity test (tar -${test_flag})..."
    if tar -"${test_flag}" "${archive_path}" >/dev/null 2>&1; then
        log_msg "SUCCESS" "Archive integrity test PASSED (zero corruption detected)."
    else
        log_msg "ERROR" "Archive integrity verification FAILED! Corrupt tarball."
        exit 1
    fi

    # Cryptographic SHA-256 verification manifest
    log_msg "INFO" "Generating SHA-256 cryptographic checksum manifest..."
    local sha256_hash
    sha256_hash="$(sha256sum "${archive_path}" | awk '{print $1}')"
    echo "${sha256_hash}  ${archive_filename}" > "${checksum_path}"
    log_msg "SUCCESS" "SHA-256: ${sha256_hash}"

    # Compression calculations
    local space_saved=0
    local ratio_pct="0.0"
    if [ "${source_bytes}" -gt 0 ]; then
        space_saved=$((source_bytes - archive_bytes))
        ratio_pct="$(awk "BEGIN {printf \"%.2f\", (1 - (${archive_bytes} / ${source_bytes})) * 100}")"
    fi
    log_msg "INFO" "Space Saved      : ${space_saved} bytes (${ratio_pct}% reduction)"

    # Enforce retention policy
    local purged_count=0
    if [ "${RETENTION_DAYS}" -gt 0 ]; then
        log_msg "INFO" "Applying retention policy (pruning archives older than ${RETENTION_DAYS} days)..."
        local old_archives
        old_archives="$(find "${abs_dest}" -name "backup_${project_name}_*.${ext}" -mtime "+${RETENTION_DAYS}" 2>/dev/null || true)"
        if [ -n "${old_archives}" ]; then
            while IFS= read -r old_file; do
                if [ -f "${old_file}" ]; then
                    rm -f "${old_file}" "${old_file}.sha256"
                    ((purged_count++)) || true
                    log_msg "WARN" "Purged expired archive: $(basename "${old_file}")"
                fi
            done <<< "${old_archives}"
        fi
        log_msg "SUCCESS" "Retention audit complete: ${purged_count} expired archive(s) purged."
    fi

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    log_msg "SUCCESS" "Automated project backup completed in ${duration}s."

    # Serialize JSON metadata
    if [ "${EMIT_JSON}" = true ]; then
        cat <<JEOF > "${JSON_FILE}"
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "execution_seconds": ${duration},
  "project": {
    "name": "${project_name}",
    "source_path": "${abs_source}",
    "files_count": ${source_files_count},
    "source_bytes": ${source_bytes}
  },
  "archive": {
    "filename": "${archive_filename}",
    "path": "${archive_path}",
    "size_bytes": ${archive_bytes},
    "format": "${COMPRESSION}",
    "sha256": "${sha256_hash}",
    "integrity": "VERIFIED",
    "space_saved_bytes": ${space_saved},
    "compression_ratio_pct": ${ratio_pct}
  },
  "retention": {
    "retention_days": ${RETENTION_DAYS},
    "purged_archives": ${purged_count}
  }
}
JEOF
        log_msg "SUCCESS" "Backup telemetry serialized to ${JSON_FILE}"
    fi
}

# Dispatch
case "${ACTION}" in
    backup)
        execute_backup
        ;;
    schedule)
        install_cron_job
        ;;
    verify-cron)
        verify_cron_job
        ;;
    unschedule)
        remove_cron_job
        ;;
esac
