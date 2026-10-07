#!/usr/bin/env bash
# ==============================================================================
# Script: backup_verifier.sh
# Purpose: Verify latest backup file existence, non-emptiness, archive integrity
#          (tar -tzf), calculate SHA-256 checksum, and audit freshness (AS_11).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup_verify.log"
JSON_FILE="${LOG_DIR}/verify.json"

DEFAULT_BACKUP_DIR="${SCRIPT_DIR}/sandbox_data/backups"
DEFAULT_PATTERN="*.tar.gz"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

TARGET_INPUT=""
FILE_PATTERN="$DEFAULT_PATTERN"
OUTPUT_JSON=false

mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY_OR_FILE]

Verify integrity, size, and cryptographic validity of backup archives.

Arguments:
  DIRECTORY_OR_FILE       Backup folder to locate latest archive, or direct archive path
                          (default: ${DEFAULT_BACKUP_DIR})

Options:
  -d, --dir <DIR>         Specify backup directory
  -f, --file <FILE>       Specify explicit backup file to verify
  -p, --pattern <PAT>     Archive file glob pattern (default: ${DEFAULT_PATTERN})
  --sandbox               Target local sandbox_data/backups directory
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Verification Steps:
  1. Archive Discovery  : Locates the most recent backup archive in target folder
  2. Non-Empty Check    : Validates existence and non-zero byte size
  3. Archive Integrity  : Tests decompression and table of contents read (tar -tzf)
  4. Cryptographic Hash : Generates & cross-references SHA-256 integrity checksum
  5. Freshness Audit    : Evaluates backup recency (24-hour SLA window)

Examples:
  ./backup_verifier.sh                           # Verifies latest backup in sandbox_data/backups
  ./backup_verifier.sh ./sandbox_data/backups    # Explicit directory
  ./backup_verifier.sh -f backups/backup.tar.gz  # Verify specific file
  ./backup_verifier.sh --json                    # Emit JSON report
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            TARGET_INPUT="$2"
            shift 2
            ;;
        -f|--file)
            TARGET_INPUT="$2"
            shift 2
            ;;
        -p|--pattern)
            FILE_PATTERN="$2"
            shift 2
            ;;
        --sandbox)
            TARGET_INPUT="${SCRIPT_DIR}/sandbox_data/backups"
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${COLOR_RED}[ERROR] Unknown option: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$TARGET_INPUT" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
        TARGET_INPUT="${POSITIONAL[0]}"
    else
        TARGET_INPUT="$DEFAULT_BACKUP_DIR"
    fi
fi

# ------------------------------------------------------------------------------
# Archive Discovery
# ------------------------------------------------------------------------------
TARGET_ARCHIVE=""
BACKUP_DIR=""

if [[ -f "$TARGET_INPUT" ]]; then
    TARGET_ARCHIVE="$(cd "$(dirname "$TARGET_INPUT")" && pwd)/$(basename "$TARGET_INPUT")"
    BACKUP_DIR="$(dirname "$TARGET_ARCHIVE")"
elif [[ -d "$TARGET_INPUT" ]]; then
    BACKUP_DIR="$(cd "$TARGET_INPUT" && pwd)"
    # Find most recently modified archive file
    LATEST_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.tar" \) -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
    if [[ -n "$LATEST_FILE" ]]; then
        TARGET_ARCHIVE="$LATEST_FILE"
    fi
else
    echo -e "${COLOR_RED}[ERROR] Target '${TARGET_INPUT}' does not exist.${COLOR_RESET}" >&2
    log "ERROR" "Target path '${TARGET_INPUT}' does not exist."
    exit 1
fi

echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}            BACKUP VALIDATION & INTEGRITY VERIFIER ENGINE (AS_11)               ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Backup Repository  : ${COLOR_BOLD}${BACKUP_DIR}${COLOR_RESET}"
echo -e " Target Candidate   : $(if [[ -n "$TARGET_ARCHIVE" ]]; then echo -e "${COLOR_YELLOW}$(basename "$TARGET_ARCHIVE")${COLOR_RESET}"; else echo -e "${COLOR_RED}None Found${COLOR_RESET}"; fi)"
echo -e " Hostname           : $(hostname)"
echo -e " Verification Date  : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

log "INFO" "Starting backup verification on repository '${BACKUP_DIR}'"

# Total archives in repository
TOTAL_ARCHIVES="$(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.tar" \) 2>/dev/null | wc -l | tr -d ' ')"

# ------------------------------------------------------------------------------
# Test 1: Existence Check
# ------------------------------------------------------------------------------
PASS_EXIST=false
if [[ -n "$TARGET_ARCHIVE" && -f "$TARGET_ARCHIVE" ]]; then
    PASS_EXIST=true
    STATUS_EXIST="${COLOR_GREEN}PASS${COLOR_RESET}"
    log "CHECK" "Test 1 (Existence): PASS - Found $TARGET_ARCHIVE"
else
    STATUS_EXIST="${COLOR_RED}FAIL${COLOR_RESET}"
    log "ERROR" "Test 1 (Existence): FAIL - No backup archives found in repository."
    echo -e "[1/5] Archive Existence Check      : [ ${STATUS_EXIST} ]"
    echo -e "${COLOR_RED}[FATAL] No backup archive found to verify!${COLOR_RESET}" >&2
    exit 2
fi
echo -e "[1/5] Archive Existence Check      : [ ${STATUS_EXIST} ] (${TARGET_ARCHIVE})"

# ------------------------------------------------------------------------------
# Test 2: Non-Empty File Check & Sizing
# ------------------------------------------------------------------------------
PASS_NONEMPTY=false
FILE_SIZE_BYTES=0
FILE_SIZE_HR="0 B"

if [[ -s "$TARGET_ARCHIVE" ]]; then
    PASS_NONEMPTY=true
    FILE_SIZE_BYTES="$(stat -c "%s" "$TARGET_ARCHIVE" 2>/dev/null || echo 0)"
    FILE_SIZE_HR="$(awk -v b="$FILE_SIZE_BYTES" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }')"
    STATUS_NONEMPTY="${COLOR_GREEN}PASS${COLOR_RESET}"
    log "CHECK" "Test 2 (Non-Empty): PASS - Size is ${FILE_SIZE_BYTES} bytes (${FILE_SIZE_HR})"
else
    STATUS_NONEMPTY="${COLOR_RED}FAIL${COLOR_RESET}"
    log "ERROR" "Test 2 (Non-Empty): FAIL - File size is 0 bytes."
fi
echo -e "[2/5] Non-Empty Integrity Check    : [ ${STATUS_NONEMPTY} ] (${FILE_SIZE_HR}, ${FILE_SIZE_BYTES} bytes)"

# ------------------------------------------------------------------------------
# Test 3: Archive Container Integrity (tar read test)
# ------------------------------------------------------------------------------
PASS_TAR_INTEGRITY=false
ITEMS_COUNT=0
TAR_ERROR=""

# Detect appropriate tar flags
TAR_READ_FLAG="-tf"
if [[ "$TARGET_ARCHIVE" =~ \.(tar\.gz|tgz)$ ]]; then
    TAR_READ_FLAG="-tzf"
elif [[ "$TARGET_ARCHIVE" =~ \.tar\.bz2$ ]]; then
    TAR_READ_FLAG="-tjf"
elif [[ "$TARGET_ARCHIVE" =~ \.tar\.xz$ ]]; then
    TAR_READ_FLAG="-tJf"
fi

TAR_OUT="$(mktemp)"
TAR_ERR="$(mktemp)"
if tar $TAR_READ_FLAG "$TARGET_ARCHIVE" > "$TAR_OUT" 2> "$TAR_ERR"; then
    PASS_TAR_INTEGRITY=true
    ITEMS_COUNT="$(wc -l < "$TAR_OUT" | tr -d ' ')"
    STATUS_TAR="${COLOR_GREEN}PASS${COLOR_RESET}"
    log "CHECK" "Test 3 (Tar Integrity): PASS - Verified ${ITEMS_COUNT} archived entities."
else
    TAR_ERROR="$(cat "$TAR_ERR")"
    STATUS_TAR="${COLOR_RED}FAIL${COLOR_RESET}"
    log "ERROR" "Test 3 (Tar Integrity): FAIL - Tar error: ${TAR_ERROR}"
fi
rm -f "$TAR_OUT" "$TAR_ERR"

echo -e "[3/5] Archive Container Integrity  : [ ${STATUS_TAR} ] (${ITEMS_COUNT} entities inside archive)"

# ------------------------------------------------------------------------------
# Test 4: Cryptographic Checksum Validation
# ------------------------------------------------------------------------------
PASS_CHECKSUM=false
SHA256_COMPUTED="$(sha256sum "$TARGET_ARCHIVE" | cut -d' ' -f1)"
CHECKSUM_FILE="${TARGET_ARCHIVE}.sha256"
CHECKSUM_DETAIL=""

if [[ -f "$CHECKSUM_FILE" ]]; then
    # Verify using sha256sum tool
    if (cd "$(dirname "$TARGET_ARCHIVE")" && sha256sum -c "$(basename "$CHECKSUM_FILE")" >/dev/null 2>&1); then
        PASS_CHECKSUM=true
        CHECKSUM_DETAIL="Verified against companion .sha256"
        STATUS_CHECKSUM="${COLOR_GREEN}PASS${COLOR_RESET}"
        log "CHECK" "Test 4 (Checksum): PASS - Cryptographic match confirmed (${SHA256_COMPUTED})"
    else
        STATUS_CHECKSUM="${COLOR_RED}FAIL${COLOR_RESET}"
        CHECKSUM_DETAIL="Hash mismatch with companion .sha256"
        log "ERROR" "Test 4 (Checksum): FAIL - Hash mismatch!"
    fi
else
    # Checksum generated on the fly as baseline
    PASS_CHECKSUM=true
    CHECKSUM_DETAIL="Generated on-the-fly (No companion .sha256)"
    STATUS_CHECKSUM="${COLOR_YELLOW}PASS (Calculated)${COLOR_RESET}"
    log "CHECK" "Test 4 (Checksum): Computed baseline SHA-256 (${SHA256_COMPUTED})"
fi
echo -e "[4/5] SHA-256 Checksum Validation  : [ ${STATUS_CHECKSUM} ] (${CHECKSUM_DETAIL})"
echo -e "      Hash: ${COLOR_CYAN}${SHA256_COMPUTED}${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Test 5: Freshness & SLA Window Check
# ------------------------------------------------------------------------------
PASS_FRESHNESS=false
MTIME_EPOCH="$(stat -c "%Y" "$TARGET_ARCHIVE" 2>/dev/null || date +%s)"
MTIME_STR="$(stat -c "%y" "$TARGET_ARCHIVE" 2>/dev/null | cut -d'.' -f1 || echo "Unknown")"
NOW_EPOCH="$(date +%s)"
AGE_SECONDS=$(( NOW_EPOCH - MTIME_EPOCH ))
AGE_HOURS="$(awk -v s="$AGE_SECONDS" 'BEGIN { printf "%.1f", s / 3600 }')"

# Threshold: 24 hours (86400 seconds)
if (( AGE_SECONDS <= 86400 )); then
    PASS_FRESHNESS=true
    STATUS_FRESHNESS="${COLOR_GREEN}PASS${COLOR_RESET}"
    log "CHECK" "Test 5 (Freshness): PASS - Archive age is ${AGE_HOURS}h (within 24h SLA)"
else
    STATUS_FRESHNESS="${COLOR_YELLOW}WARNING${COLOR_RESET}"
    log "WARN" "Test 5 (Freshness): WARN - Archive age is ${AGE_HOURS}h (exceeds 24h SLA)"
fi
echo -e "[5/5] Backup Freshness / Recency   : [ ${STATUS_FRESHNESS} ] (${AGE_HOURS}h old, modified: ${MTIME_STR})"

# ------------------------------------------------------------------------------
# Overall Assessment
# ------------------------------------------------------------------------------
OVERALL_SUCCESS=true
if [[ "$PASS_EXIST" != true || "$PASS_NONEMPTY" != true || "$PASS_TAR_INTEGRITY" != true || "$PASS_CHECKSUM" != true ]]; then
    OVERALL_SUCCESS=false
fi

OVERALL_STATUS_TEXT="VERIFIED_HEALTHY"
if [[ "$OVERALL_SUCCESS" != true ]]; then
    OVERALL_STATUS_TEXT="VERIFICATION_FAILED"
fi

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_11",
  "title": "Backup Verification",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $NOW_EPOCH,
  "hostname": "$(hostname)",
  "backup_directory": "$BACKUP_DIR",
  "archive_filename": "$(basename "$TARGET_ARCHIVE")",
  "archive_path": "$TARGET_ARCHIVE",
  "total_archives_in_repo": $TOTAL_ARCHIVES,
  "file_size_bytes": $FILE_SIZE_BYTES,
  "file_size_human": "$FILE_SIZE_HR",
  "entities_count": $ITEMS_COUNT,
  "modified_timestamp": "$MTIME_STR",
  "age_hours": $AGE_HOURS,
  "sha256_checksum": "$SHA256_COMPUTED",
  "has_companion_checksum": $([[ -f "$CHECKSUM_FILE" ]] && echo true || echo false),
  "checks": {
    "existence": $PASS_EXIST,
    "non_empty": $PASS_NONEMPTY,
    "archive_integrity": $PASS_TAR_INTEGRITY,
    "checksum_valid": $PASS_CHECKSUM,
    "within_freshness_sla": $PASS_FRESHNESS
  },
  "overall_success": $OVERALL_SUCCESS,
  "status": "$OVERALL_STATUS_TEXT"
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}VERIFICATION SUMMARY:${COLOR_RESET}"
if [[ "$OVERALL_SUCCESS" == true ]]; then
    echo -e "  Overall Status       : ${COLOR_GREEN}${COLOR_BOLD}✅ ARCHIVE VALIDATED (100% HEALTHY)${COLOR_RESET}"
else
    echo -e "  Overall Status       : ${COLOR_RED}${COLOR_BOLD}❌ ARCHIVE VALIDATION FAILED${COLOR_RESET}"
fi
echo -e "  Verified File        : ${COLOR_YELLOW}$(basename "$TARGET_ARCHIVE")${COLOR_RESET}"
echo -e "  Archive Size         : ${COLOR_BOLD}${FILE_SIZE_HR}${COLOR_RESET} (${FILE_SIZE_BYTES} bytes)"
echo -e "  Internal Entities    : ${COLOR_BOLD}${ITEMS_COUNT}${COLOR_RESET} files/directories"
echo -e "  SHA-256 Digest       : ${COLOR_CYAN}${SHA256_COMPUTED}${COLOR_RESET}"
echo -e "  Telemetry JSON       : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Audit Log File       : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
