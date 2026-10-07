#!/usr/bin/env bash
# ==============================================================================
# Script: temp_cleaner.sh
# Purpose: Identify and safely clean temporary files not modified for more than
#          N days in a specified directory (AS_09).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/temp_cleaner.log"
JSON_FILE="${LOG_DIR}/temp_cleanup.json"

DEFAULT_DAYS=7
DEFAULT_TARGET="${SCRIPT_DIR}/sandbox_data/tmp"

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

# State variables
TARGET_DIR=""
RETENTION_DAYS="$DEFAULT_DAYS"
DRY_RUN=true
REMOVE_EMPTY_DIRS=false
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
Usage: $(basename "$0") [OPTIONS] [DIRECTORY] [DAYS]

Identify and remove temporary files older than N days from a specified directory.

Arguments:
  DIRECTORY               Target directory to clean (default: ${DEFAULT_TARGET})
  DAYS                    Retention threshold in days (default: ${DEFAULT_DAYS})

Options:
  -d, --days <N>          Retention threshold in days (files older than N days removed)
  -t, --target <DIR>      Specify target directory explicitly
  --delete, --force       Perform actual file deletion (default is safe DRY-RUN)
  --dry-run               Simulate deletion without unlinking files (default mode)
  --empty-dirs            Remove empty directories after cleaning
  --sandbox               Target local sandbox_data/tmp directory
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Safety Notice:
  By default, $(basename "$0") runs in DRY-RUN mode to prevent accidental data loss.
  Pass --delete or --force to execute actual deletion.

Examples:
  ./temp_cleaner.sh                           # Dry-run scan on sandbox_data/tmp (>7 days)
  ./temp_cleaner.sh --delete                  # Delete sandbox files older than 7 days
  ./temp_cleaner.sh ./sandbox_data/tmp 10     # Dry-run scan for files older than 10 days
  ./temp_cleaner.sh -d 3 --delete             # Delete files older than 3 days
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --delete|--force)
            DRY_RUN=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --empty-dirs)
            REMOVE_EMPTY_DIRS=true
            shift
            ;;
        --sandbox)
            TARGET_DIR="${SCRIPT_DIR}/sandbox_data/tmp"
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
if [[ -z "$TARGET_DIR" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 1 && -d "${POSITIONAL[0]}" ]]; then
        TARGET_DIR="${POSITIONAL[0]}"
        if [[ ${#POSITIONAL[@]} -ge 2 && "${POSITIONAL[1]}" =~ ^[0-9]+$ ]]; then
            RETENTION_DAYS="${POSITIONAL[1]}"
        fi
    elif [[ ${#POSITIONAL[@]} -ge 1 && "${POSITIONAL[0]}" =~ ^[0-9]+$ ]]; then
        RETENTION_DAYS="${POSITIONAL[0]}"
        TARGET_DIR="$DEFAULT_TARGET"
    else
        TARGET_DIR="$DEFAULT_TARGET"
    fi
else
    if [[ ${#POSITIONAL[@]} -ge 1 && "${POSITIONAL[0]}" =~ ^[0-9]+$ ]]; then
        RETENTION_DAYS="${POSITIONAL[0]}"
    fi
fi

# Validation
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Target directory '${TARGET_DIR}' does not exist.${COLOR_RESET}" >&2
    log "ERROR" "Target directory '${TARGET_DIR}' does not exist."
    exit 1
fi
TARGET_DIR_CANONICAL="$(cd "$TARGET_DIR" && pwd)"

# Critical System Directory Safety Guard
RESTRICTED_ROOTS=("/" "/etc" "/bin" "/sbin" "/usr" "/boot" "/lib" "/lib64" "/dev" "/proc" "/sys" "/home" "/root")
for r in "${RESTRICTED_ROOTS[@]}"; do
    if [[ "$TARGET_DIR_CANONICAL" == "$r" ]]; then
        echo -e "${COLOR_RED}[FATAL] Safety refusal: Target directory cannot be critical system path '$r'.${COLOR_RESET}" >&2
        log "FATAL" "Attempted to run cleaner on protected system path '$r'."
        exit 3
    fi
done

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || (( RETENTION_DAYS < 0 )); then
    echo -e "${COLOR_RED}[ERROR] Retention days must be a non-negative integer: '${RETENTION_DAYS}'${COLOR_RESET}" >&2
    exit 2
fi

# ------------------------------------------------------------------------------
# Banner Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         TEMPORARY FILE CLEANUP & STORAGE HYGIENE ENGINE (AS_09)                ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Directory   : ${COLOR_BOLD}${TARGET_DIR_CANONICAL}${COLOR_RESET}"
echo -e " Retention Cutoff   : ${COLOR_BOLD}> ${RETENTION_DAYS} day(s) unmodified${COLOR_RESET}"
echo -e " Execution Mode     : $(if [[ "$DRY_RUN" == true ]]; then echo -e "${COLOR_YELLOW}${COLOR_BOLD}DRY-RUN (Simulation - No files deleted)${COLOR_RESET}"; else echo -e "${COLOR_RED}${COLOR_BOLD}ACTIVE (Actual Deletion)${COLOR_RESET}"; fi)"
echo -e " Hostname           : $(hostname)"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

log "INFO" "Initiating cleanup scan on '${TARGET_DIR_CANONICAL}', threshold: >${RETENTION_DAYS} days, dry_run: ${DRY_RUN}"

# ------------------------------------------------------------------------------
# Scan & Identification Execution
# ------------------------------------------------------------------------------
NOW_EPOCH=$(date +%s)
THRESHOLD_SECONDS=$(( RETENTION_DAYS * 86400 ))

# Collect all files in target directory
CANDIDATE_LIST="$(mktemp)"
ALL_FILES_COUNT=0
STALE_FILES_COUNT=0
RETAINED_FILES_COUNT=0
RECLAIMED_BYTES=0

# Use find to locate files with mtime > RETENTION_DAYS
# find -mtime +N matches files modified at least (N+1)*24 hours ago.
# For exact day threshold, find -mtime +$(( RETENTION_DAYS - 1 )) or seconds comparison.
# Let's inspect all files and calculate exact day age for full precision.
find "$TARGET_DIR_CANONICAL" -type f ! -name "populate_sandbox.sh" ! -name ".*" 2>/dev/null > "$CANDIDATE_LIST" || true

JSON_STALE_FILES=()
JSON_RETAINED_FILES=()

printf "${COLOR_BOLD}%-4s %-12s %-10s %-20s %-14s %s${COLOR_RESET}\n" \
    "#" "SIZE" "AGE(DAYS)" "MODIFIED" "ACTION" "FILE PATH"
echo "--------------------------------------------------------------------------------"

INDEX=0
while IFS= read -r fpath; do
    [[ -z "$fpath" ]] && continue
    (( ALL_FILES_COUNT++ )) || true
    (( INDEX++ )) || true

    mtime_epoch="$(stat -c "%Y" "$fpath" 2>/dev/null || echo "$NOW_EPOCH")"
    mtime_str="$(stat -c "%y" "$fpath" 2>/dev/null | cut -d'.' -f1 || echo "Unknown")"
    fsize="$(stat -c "%s" "$fpath" 2>/dev/null || echo 0)"
    
    age_seconds=$(( NOW_EPOCH - mtime_epoch ))
    age_days=$(( age_seconds / 86400 ))

    fsize_hr="$(awk -v b="$fsize" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }')"

    esc_path="$(echo "$fpath" | sed 's/"/\\"/g')"

    if (( age_days >= RETENTION_DAYS )); then
        (( STALE_FILES_COUNT++ )) || true
        (( RECLAIMED_BYTES += fsize )) || true

        if [[ "$DRY_RUN" == true ]]; then
            action_label="WOULD_DELETE"
            action_display="${COLOR_YELLOW}WOULD_DELETE${COLOR_RESET}"
            log "DRY_RUN" "Identified stale file for deletion: $fpath ($fsize_hr, ${age_days}d old)"
        else
            if rm -f "$fpath" 2>/dev/null; then
                action_label="DELETED"
                action_display="${COLOR_RED}DELETED${COLOR_RESET}"
                log "DELETED" "Removed stale file: $fpath ($fsize_hr, ${age_days}d old)"
            else
                action_label="FAILED_DELETE"
                action_display="${COLOR_RED}FAILED${COLOR_RESET}"
                log "ERROR" "Failed to remove stale file: $fpath"
            fi
        fi

        printf "%-4s %-12s %-10s %-20s %-20b %s\n" \
            "#${INDEX}" "$fsize_hr" "${age_days}d" "$mtime_str" "$action_display" "$fpath"

        JSON_STALE_FILES+=("{\"path\":\"$esc_path\",\"size_bytes\":$fsize,\"size_human\":\"$fsize_hr\",\"age_days\":$age_days,\"modified\":\"$mtime_str\",\"action\":\"$action_label\"}")
    else
        (( RETAINED_FILES_COUNT++ )) || true
        action_label="RETAINED"
        action_display="${COLOR_GREEN}RETAINED${COLOR_RESET}"
        log "RETAINED" "Retained active file: $fpath (${age_days}d old < ${RETENTION_DAYS}d)"

        printf "%-4s %-12s %-10s %-20s %-20b %s\n" \
            "#${INDEX}" "$fsize_hr" "${age_days}d" "$mtime_str" "$action_display" "$fpath"

        JSON_RETAINED_FILES+=("{\"path\":\"$esc_path\",\"size_bytes\":$fsize,\"size_human\":\"$fsize_hr\",\"age_days\":$age_days,\"modified\":\"$mtime_str\",\"action\":\"$action_label\"}")
    fi
done < "$CANDIDATE_LIST"

rm -f "$CANDIDATE_LIST"

# Clean empty directories if requested
EMPTY_DIRS_REMOVED=0
if [[ "$REMOVE_EMPTY_DIRS" == true && "$DRY_RUN" == false ]]; then
    while IFS= read -r edir; do
        [[ -z "$edir" ]] && continue
        if [[ "$edir" != "$TARGET_DIR_CANONICAL" ]]; then
            rmdir "$edir" 2>/dev/null && (( EMPTY_DIRS_REMOVED++ )) || true
            log "CLEANUP" "Removed empty directory: $edir"
        fi
    done < <(find "$TARGET_DIR_CANONICAL" -type d -empty)
fi

RECLAIMED_HR="$(awk -v b="$RECLAIMED_BYTES" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GB", b/1073741824;
    else if (b >= 1048576) printf "%.2f MB", b/1048576;
    else if (b >= 1024) printf "%.2f KB", b/1024;
    else printf "%d B", b;
}')"

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_STALE_JOINED="$(IFS=,; echo "${JSON_STALE_FILES[*]}")"
JSON_RETAINED_JOINED="$(IFS=,; echo "${JSON_RETAINED_FILES[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_09",
  "title": "Temporary File Cleanup",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "target_directory": "$TARGET_DIR_CANONICAL",
  "retention_days": $RETENTION_DAYS,
  "dry_run": $DRY_RUN,
  "all_files_count": $ALL_FILES_COUNT,
  "stale_files_count": $STALE_FILES_COUNT,
  "retained_files_count": $RETAINED_FILES_COUNT,
  "reclaimed_bytes": $RECLAIMED_BYTES,
  "reclaimed_human": "$RECLAIMED_HR",
  "status": "$([[ $STALE_FILES_COUNT -gt 0 ]] && echo "STALE_FILES_DETECTED" || echo "CLEAN")",
  "stale_files": [
    $JSON_STALE_JOINED
  ],
  "retained_files": [
    $JSON_RETAINED_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}CLEANUP SUMMARY:${COLOR_RESET}"
echo -e "  Total Files Evaluated : ${COLOR_BOLD}${ALL_FILES_COUNT}${COLOR_RESET}"
echo -e "  Stale Files Identified: ${COLOR_YELLOW}${COLOR_BOLD}${STALE_FILES_COUNT}${COLOR_RESET} (> ${RETENTION_DAYS} days)"
echo -e "  Active Files Retained : ${COLOR_GREEN}${COLOR_BOLD}${RETAINED_FILES_COUNT}${COLOR_RESET} (&le; ${RETENTION_DAYS} days)"
echo -e "  Storage Space Reclaimed: ${COLOR_BOLD}${RECLAIMED_HR}${COLOR_RESET} (${RECLAIMED_BYTES} bytes)"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  Notice                : ${COLOR_YELLOW}Dry-run mode active. Run with --delete to unlink stale files.${COLOR_RESET}"
else
    echo -e "  Notice                : ${COLOR_GREEN}Stale files unlinked from filesystem.${COLOR_RESET}"
fi
echo -e "  Telemetry JSON File   : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Audit Log File        : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
