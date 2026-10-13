#!/usr/bin/env bash
# ==============================================================================
# Script: daily_backup.sh
# Purpose: Create a compressed, timestamped, checksummed backup archive of a
#          designated project or system directory (AS_10).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/daily_backup.log"
JSON_FILE="${LOG_DIR}/backup.json"

DEFAULT_SOURCE="${SCRIPT_DIR}/sandbox_data/project"
DEFAULT_DEST="${SCRIPT_DIR}/backups"
DEFAULT_ALGO="gzip"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

# State variables
SOURCE_DIR=""
DEST_DIR=""
ALGO="$DEFAULT_ALGO"
GENERATE_CHECKSUM=true
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
Usage: $(basename "$0") [OPTIONS] [SOURCE_DIRECTORY] [DESTINATION_DIRECTORY]

Create a compressed and timestamped backup archive of a directory.

Arguments:
  SOURCE_DIRECTORY        Directory tree to back up (default: ${DEFAULT_SOURCE})
  DESTINATION_DIRECTORY   Target directory to store archive (default: ${DEFAULT_DEST})

Options:
  -s, --source <DIR>      Specify source directory explicitly
  -d, --dest <DIR>        Specify destination directory explicitly
  -c, --compression <TYPE> Compression type: gzip (default), bzip2, xz
  --no-checksum           Skip generating SHA-256 checksum file
  --sandbox               Target local sandbox_data/project directory
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Examples:
  ./daily_backup.sh                            # Backs up default sandbox project to backups/
  ./daily_backup.sh /etc ./backups             # Backs up /etc to local backups/
  ./daily_backup.sh -s ./sandbox_data/project -d ./backups
  ./daily_backup.sh --json                     # Emits JSON telemetry
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

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
        -c|--compression)
            ALGO="$2"
            shift 2
            ;;
        --no-checksum)
            GENERATE_CHECKSUM=false
            shift
            ;;
        --sandbox)
            SOURCE_DIR="${SCRIPT_DIR}/sandbox_data/project"
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

# Resolve positional parameters
if [[ -z "$SOURCE_DIR" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 1 && -d "${POSITIONAL[0]}" ]]; then
        SOURCE_DIR="${POSITIONAL[0]}"
        if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
            DEST_DIR="${POSITIONAL[1]}"
        fi
    else
        SOURCE_DIR="$DEFAULT_SOURCE"
    fi
else
    if [[ -z "$DEST_DIR" && ${#POSITIONAL[@]} -ge 1 ]]; then
        DEST_DIR="${POSITIONAL[0]}"
    fi
fi

if [[ -z "$DEST_DIR" ]]; then
    DEST_DIR="$DEFAULT_DEST"
fi

# Validation
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Source directory '${SOURCE_DIR}' does not exist.${COLOR_RESET}" >&2
    log "ERROR" "Source directory '${SOURCE_DIR}' does not exist."
    exit 1
fi

mkdir -p "$DEST_DIR"
SOURCE_CANONICAL="$(cd "$SOURCE_DIR" && pwd)"
DEST_CANONICAL="$(cd "$DEST_DIR" && pwd)"

# Determine tar flags based on compression
TAR_EXT="tar.gz"
TAR_FLAG="-czf"
case "$ALGO" in
    gzip)
        TAR_EXT="tar.gz"
        TAR_FLAG="-czf"
        ;;
    bzip2)
        TAR_EXT="tar.bz2"
        TAR_FLAG="-cjf"
        ;;
    xz)
        TAR_EXT="tar.xz"
        TAR_FLAG="-cJf"
        ;;
    *)
        echo -e "${COLOR_RED}[ERROR] Unsupported compression '${ALGO}'. Use gzip, bzip2, or xz.${COLOR_RESET}" >&2
        exit 2
        ;;
esac

SOURCE_BASE="$(basename "$SOURCE_CANONICAL")"
SOURCE_PARENT="$(dirname "$SOURCE_CANONICAL")"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
ARCHIVE_NAME="backup_${SOURCE_BASE}_${TIMESTAMP}.${TAR_EXT}"
ARCHIVE_PATH="${DEST_CANONICAL}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

# ------------------------------------------------------------------------------
# Banner Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}            ENTERPRISE AUTOMATED DAILY BACKUP ENGINE (AS_10)                    ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Source Directory   : ${COLOR_BOLD}${SOURCE_CANONICAL}${COLOR_RESET}"
echo -e " Backup Destination : ${COLOR_BOLD}${DEST_CANONICAL}${COLOR_RESET}"
echo -e " Archive Filename   : ${COLOR_YELLOW}${ARCHIVE_NAME}${COLOR_RESET}"
echo -e " Compression Format : ${COLOR_BOLD}${ALGO^^} (.${TAR_EXT})${COLOR_RESET}"
echo -e " Hostname           : $(hostname)"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

log "INFO" "Starting backup of '${SOURCE_CANONICAL}' into '${ARCHIVE_PATH}'"

# Measure uncompressed size
UNCOMPRESSED_BYTES="$(du -sb "$SOURCE_CANONICAL" 2>/dev/null | cut -f1 || echo 0)"
TOTAL_ITEMS="$(find "$SOURCE_CANONICAL" -type f 2>/dev/null | wc -l | tr -d ' ')"

echo -e "[INFO] Source contents   : ${COLOR_BOLD}${TOTAL_ITEMS}${COLOR_RESET} file(s) across directory tree"
echo -e "[INFO] Uncompressed size : ${COLOR_BOLD}${UNCOMPRESSED_BYTES}${COLOR_RESET} bytes"
echo -e "[INFO] Creating compressed archive with tar..."

START_TIME=$(date +%s%N 2>/dev/null || date +%s)

# Execute tar creation using relative path from parent directory
tar $TAR_FLAG "$ARCHIVE_PATH" -C "$SOURCE_PARENT" "$SOURCE_BASE"

END_TIME=$(date +%s%N 2>/dev/null || date +%s)
DURATION_MS=0
if [[ "$START_TIME" =~ ^[0-9]{10,}$ && "$END_TIME" =~ ^[0-9]{10,}$ ]]; then
    DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
fi

# Verify archive existence and calculate compressed size
if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo -e "${COLOR_RED}[FATAL] Archive creation failed! File '${ARCHIVE_PATH}' not found.${COLOR_RESET}" >&2
    log "FATAL" "Archive creation failed for ${ARCHIVE_PATH}"
    exit 3
fi

COMPRESSED_BYTES="$(stat -c "%s" "$ARCHIVE_PATH" 2>/dev/null || echo 0)"

# Compression ratio calculation
RATIO_PCT="0.0%"
if (( UNCOMPRESSED_BYTES > 0 )); then
    RATIO_PCT="$(awk -v c="$COMPRESSED_BYTES" -v u="$UNCOMPRESSED_BYTES" 'BEGIN {
        saved = (1.0 - (c / u)) * 100.0;
        if (saved < 0) saved = 0.0;
        printf "%.1f%%", saved;
    }')"
fi

# Human-readable format helper
format_hr() {
    local b="$1"
    awk -v b="$b" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }'
}

UNCOMP_HR="$(format_hr "$UNCOMPRESSED_BYTES")"
COMP_HR="$(format_hr "$COMPRESSED_BYTES")"

# Archive Integrity Verification (Dry-run test)
echo -e "[INFO] Validating archive integrity with test-read..."
MANIFEST_TMP="$(mktemp)"
if tar -tzf "$ARCHIVE_PATH" > "$MANIFEST_TMP" 2>/dev/null; then
    VERIFY_STATUS="PASSED"
    VERIFY_DISPLAY="${COLOR_GREEN}${COLOR_BOLD}PASSED (Archive integrity verified)${COLOR_RESET}"
    ARCHIVED_FILE_COUNT="$(wc -l < "$MANIFEST_TMP" | tr -d ' ')"
    log "VERIFY" "Archive integrity test passed. ${ARCHIVED_FILE_COUNT} entities inside archive."
else
    VERIFY_STATUS="FAILED"
    VERIFY_DISPLAY="${COLOR_RED}${COLOR_BOLD}FAILED (Archive corrupted)${COLOR_RESET}"
    ARCHIVED_FILE_COUNT=0
    log "ERROR" "Archive integrity test failed!"
fi
rm -f "$MANIFEST_TMP"

# SHA-256 Checksum Generation
SHA256_HASH=""
if [[ "$GENERATE_CHECKSUM" == true ]]; then
    SHA256_HASH="$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)"
    echo "$SHA256_HASH  $(basename "$ARCHIVE_PATH")" > "$CHECKSUM_PATH"
    log "CHECKSUM" "SHA-256 generated: $SHA256_HASH"
    echo -e "[INFO] SHA-256 Checksum  : ${COLOR_CYAN}${SHA256_HASH}${COLOR_RESET}"
fi

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_10",
  "title": "Daily Backup",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "source_directory": "$SOURCE_CANONICAL",
  "destination_directory": "$DEST_CANONICAL",
  "archive_filename": "$ARCHIVE_NAME",
  "archive_path": "$ARCHIVE_PATH",
  "compression_algorithm": "$ALGO",
  "uncompressed_bytes": $UNCOMPRESSED_BYTES,
  "uncompressed_human": "$UNCOMP_HR",
  "compressed_bytes": $COMPRESSED_BYTES,
  "compressed_human": "$COMP_HR",
  "compression_ratio": "$RATIO_PCT",
  "file_count": $TOTAL_ITEMS,
  "verification_status": "$VERIFY_STATUS",
  "sha256_checksum": "$SHA256_HASH",
  "checksum_file": "$CHECKSUM_PATH",
  "duration_ms": $DURATION_MS,
  "status": "$([[ "$VERIFY_STATUS" == "PASSED" ]] && echo "BACKUP_SUCCESS" || echo "BACKUP_FAILED")"
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}BACKUP EXECUTION SUMMARY:${COLOR_RESET}"
echo -e "  Archive Location    : ${COLOR_GREEN}${ARCHIVE_PATH}${COLOR_RESET}"
echo -e "  Archive Size        : ${COLOR_BOLD}${COMP_HR}${COLOR_RESET} (${COMPRESSED_BYTES} bytes)"
echo -e "  Raw Source Size     : ${COLOR_BOLD}${UNCOMP_HR}${COLOR_RESET} (${UNCOMPRESSED_BYTES} bytes)"
echo -e "  Storage Space Saved : ${COLOR_GREEN}${COLOR_BOLD}${RATIO_PCT}${COLOR_RESET} compression reduction"
echo -e "  Archive Integrity   : ${VERIFY_DISPLAY}"
if [[ -n "$SHA256_HASH" ]]; then
echo -e "  Integrity Checksum  : ${COLOR_CYAN}${CHECKSUM_PATH}${COLOR_RESET}"
fi
echo -e "  Telemetry JSON      : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Persistent Audit Log: ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
