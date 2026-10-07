#!/usr/bin/env bash
# ==============================================================================
# Script: old_backup_cleaner.sh
# Purpose: Retain recent backups and delete backups older than N days to prevent
#          disk space exhaustion, purging companion checksums (AS_12).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/old_backup_cleaner.log"
JSON_FILE="${LOG_DIR}/cleanup.json"

DEFAULT_BACKUP_DIR="${SCRIPT_DIR}/sandbox_data/backups"
DEFAULT_DAYS=7
DEFAULT_KEEP_MIN=1
DEFAULT_PATTERN="*.tar.gz"

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
KEEP_MIN="$DEFAULT_KEEP_MIN"
FILE_PATTERN="$DEFAULT_PATTERN"
DRY_RUN=true
CLEAN_COMPANION=true
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

Identify and prune backup archives older than N days while preserving recent snapshots.

Arguments:
  DIRECTORY               Backup repository to clean (default: ${DEFAULT_BACKUP_DIR})
  DAYS                    Retention threshold in days (default: ${DEFAULT_DAYS})

Options:
  -d, --days <N>          Retention cutoff in days (archives older than N days removed)
  -t, --target <DIR>      Specify backup directory explicitly
  --keep-min <M>          Minimum latest backups to guarantee retaining (default: ${DEFAULT_KEEP_MIN})
  -p, --pattern <PAT>     Archive match pattern (default: ${DEFAULT_PATTERN})
  --delete, --force       Perform actual archive deletion (default is safe DRY-RUN)
  --dry-run               Simulate deletion without unlinking files (default mode)
  --no-companion          Do not delete companion .sha256/.md5 files
  --sandbox               Target local sandbox_data/backups directory
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Safety Notice:
  By default, $(basename "$0") executes in DRY-RUN simulation mode.
  Pass --delete or --force to execute actual unlinking.

Examples:
  ./old_backup_cleaner.sh                         # Dry-run scan on sandbox backups (>7 days)
  ./old_backup_cleaner.sh --delete                # Delete expired backups older than 7 days
  ./old_backup_cleaner.sh ./sandbox_data/backups 14 # 14-day retention simulation
  ./old_backup_cleaner.sh -d 30 --delete          # Delete backups older than 30 days
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
        --keep-min)
            KEEP_MIN="$2"
            shift 2
            ;;
        -p|--pattern)
            FILE_PATTERN="$2"
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
        --no-companion)
            CLEAN_COMPANION=false
            shift
            ;;
        --sandbox)
            TARGET_DIR="${SCRIPT_DIR}/sandbox_data/backups"
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
        TARGET_DIR="$DEFAULT_BACKUP_DIR"
    else
        TARGET_DIR="$DEFAULT_BACKUP_DIR"
    fi
else
    if [[ ${#POSITIONAL[@]} -ge 1 && "${POSITIONAL[0]}" =~ ^[0-9]+$ ]]; then
        RETENTION_DAYS="${POSITIONAL[0]}"
    fi
fi

# Validation
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Target backup directory '${TARGET_DIR}' does not exist.${COLOR_RESET}" >&2
    log "ERROR" "Target backup directory '${TARGET_DIR}' does not exist."
    exit 1
fi
TARGET_DIR_CANONICAL="$(cd "$TARGET_DIR" && pwd)"

# Protection against critical system directories
RESTRICTED_ROOTS=("/" "/etc" "/bin" "/sbin" "/usr" "/boot" "/lib" "/lib64" "/dev" "/proc" "/sys" "/home" "/root")
for r in "${RESTRICTED_ROOTS[@]}"; do
    if [[ "$TARGET_DIR_CANONICAL" == "$r" ]]; then
        echo -e "${COLOR_RED}[FATAL] Safety refusal: Target cannot be root system path '$r'.${COLOR_RESET}" >&2
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
echo -e "${COLOR_CYAN}${COLOR_BOLD}         BACKUP RETENTION & OLD ARCHIVE PRUNING ENGINE (AS_12)                  ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Backup Repository  : ${COLOR_BOLD}${TARGET_DIR_CANONICAL}${COLOR_RESET}"
echo -e " Retention Window   : ${COLOR_BOLD}> ${RETENTION_DAYS} day(s) eligible for pruning${COLOR_RESET}"
echo -e " Minimum Guaranteed : Keep at least ${COLOR_BOLD}${KEEP_MIN}${COLOR_RESET} newest backup(s)"
echo -e " Purge Companions   : $(if [[ "$CLEAN_COMPANION" == true ]]; then echo "Enabled (.sha256, .md5)"; else echo "Disabled"; fi)"
echo -e " Execution Mode     : $(if [[ "$DRY_RUN" == true ]]; then echo -e "${COLOR_YELLOW}${COLOR_BOLD}DRY-RUN (Simulation - No files deleted)${COLOR_RESET}"; else echo -e "${COLOR_RED}${COLOR_BOLD}ACTIVE (Actual Deletion)${COLOR_RESET}"; fi)"
echo -e " Hostname           : $(hostname)"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

log "INFO" "Starting backup cleanup scan on '${TARGET_DIR_CANONICAL}', retention: >${RETENTION_DAYS}d, keep_min: ${KEEP_MIN}, dry_run: ${DRY_RUN}"

# ------------------------------------------------------------------------------
# Archive Discovery & Age Calculation
# ------------------------------------------------------------------------------
NOW_EPOCH=$(date +%s)

# Locate all archive files matching pattern or standard archive formats, sorted newest first
ARCHIVE_LIST="$(mktemp)"
find "$TARGET_DIR_CANONICAL" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.tar" \) -printf "%T@\t%s\t%p\n" 2>/dev/null | sort -nr > "$ARCHIVE_LIST" || true

TOTAL_ARCHIVES="$(wc -l < "$ARCHIVE_LIST" | tr -d ' ')"
EXPIRED_COUNT=0
RETAINED_COUNT=0
RECLAIMED_BYTES=0
COMPANIONS_REMOVED=0

JSON_PRUNED_ITEMS=()
JSON_RETAINED_ITEMS=()

printf "${COLOR_BOLD}%-4s %-12s %-10s %-20s %-16s %s${COLOR_RESET}\n" \
    "#" "SIZE" "AGE(DAYS)" "MODIFIED" "POLICY ACTION" "ARCHIVE FILENAME"
echo "--------------------------------------------------------------------------------"

INDEX=0
while IFS=$'\t' read -r mtime_float bytes fpath; do
    [[ -z "$fpath" ]] && continue
    (( INDEX++ )) || true

    mtime_epoch="${mtime_float%%.*}"
    mtime_str="$(stat -c "%y" "$fpath" 2>/dev/null | cut -d'.' -f1 || echo "Unknown")"
    fname="$(basename "$fpath")"
    
    age_seconds=$(( NOW_EPOCH - mtime_epoch ))
    age_days=$(( age_seconds / 86400 ))

    fsize_hr="$(awk -v b="$bytes" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }')"

    esc_path="$(echo "$fpath" | sed 's/"/\\"/g')"
    esc_name="$(echo "$fname" | sed 's/"/\\"/g')"

    # Check companion checksum
    comp_file="${fpath}.sha256"
    has_companion=false
    if [[ -f "$comp_file" ]]; then
        has_companion=true
    fi

    # Evaluation logic:
    # If within keep_min, unconditionally retain
    if (( INDEX <= KEEP_MIN )); then
        (( RETAINED_COUNT++ )) || true
        action_label="RETAINED_MIN_SAFEGUARD"
        action_disp="${COLOR_GREEN}RETAIN (SAFEGUARD)${COLOR_RESET}"
        log "RETAIN" "Retained latest backup by safeguard: $fname (${age_days}d old)"

        printf "%-4s %-12s %-10s %-20s %-26b %s\n" \
            "#${INDEX}" "$fsize_hr" "${age_days}d" "$mtime_str" "$action_disp" "$fname"

        JSON_RETAINED_ITEMS+=("{\"index\":$INDEX,\"filename\":\"$esc_name\",\"path\":\"$esc_path\",\"size_bytes\":$bytes,\"size_human\":\"$fsize_hr\",\"age_days\":$age_days,\"modified\":\"$mtime_str\",\"action\":\"$action_label\"}")
    elif (( age_days > RETENTION_DAYS )); then
        # Expired - Prune candidate
        (( EXPIRED_COUNT++ )) || true
        (( RECLAIMED_BYTES += bytes )) || true

        if [[ "$DRY_RUN" == true ]]; then
            action_label="WOULD_DELETE"
            action_disp="${COLOR_YELLOW}WOULD_PRUNE${COLOR_RESET}"
            log "DRY_RUN" "Identified expired backup for pruning: $fname (${fsize_hr}, ${age_days}d old)"
        else
            # Actual deletion
            rm -f "$fpath"
            if [[ "$CLEAN_COMPANION" == true && -f "$comp_file" ]]; then
                rm -f "$comp_file"
                (( COMPANIONS_REMOVED++ )) || true
                log "PRUNE" "Unlinked companion checksum: $(basename "$comp_file")"
            fi
            action_label="DELETED"
            action_disp="${COLOR_RED}PRUNED / DELETED${COLOR_RESET}"
            log "PRUNE" "Deleted expired backup: $fname (${fsize_hr}, ${age_days}d old)"
        fi

        printf "%-4s %-12s %-10s %-20s %-26b %s\n" \
            "#${INDEX}" "$fsize_hr" "${age_days}d" "$mtime_str" "$action_disp" "$fname"

        JSON_PRUNED_ITEMS+=("{\"index\":$INDEX,\"filename\":\"$esc_name\",\"path\":\"$esc_path\",\"size_bytes\":$bytes,\"size_human\":\"$fsize_hr\",\"age_days\":$age_days,\"modified\":\"$mtime_str\",\"action\":\"$action_label\",\"companion_cleaned\":$has_companion}")
    else
        # Within retention threshold
        (( RETAINED_COUNT++ )) || true
        action_label="RETAINED_WITHIN_WINDOW"
        action_disp="${COLOR_GREEN}RETAIN (ACTIVE)${COLOR_RESET}"
        log "RETAIN" "Retained active backup within retention window: $fname (${age_days}d old &le; ${RETENTION_DAYS}d)"

        printf "%-4s %-12s %-10s %-20s %-26b %s\n" \
            "#${INDEX}" "$fsize_hr" "${age_days}d" "$mtime_str" "$action_disp" "$fname"

        JSON_RETAINED_ITEMS+=("{\"index\":$INDEX,\"filename\":\"$esc_name\",\"path\":\"$esc_path\",\"size_bytes\":$bytes,\"size_human\":\"$fsize_hr\",\"age_days\":$age_days,\"modified\":\"$mtime_str\",\"action\":\"$action_label\"}")
    fi
done < "$ARCHIVE_LIST"

rm -f "$ARCHIVE_LIST"

RECLAIMED_HR="$(awk -v b="$RECLAIMED_BYTES" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GB", b/1073741824;
    else if (b >= 1048576) printf "%.2f MB", b/1048576;
    else if (b >= 1024) printf "%.2f KB", b/1024;
    else printf "%d B", b;
}')"

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_PRUNED_JOINED="$(IFS=,; echo "${JSON_PRUNED_ITEMS[*]}")"
JSON_RETAINED_JOINED="$(IFS=,; echo "${JSON_RETAINED_ITEMS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_12",
  "title": "Old Backup Cleanup",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $NOW_EPOCH,
  "hostname": "$(hostname)",
  "backup_directory": "$TARGET_DIR_CANONICAL",
  "retention_days": $RETENTION_DAYS,
  "keep_minimum_guarantee": $KEEP_MIN,
  "dry_run": $DRY_RUN,
  "total_archives_evaluated": $TOTAL_ARCHIVES,
  "expired_archives_count": $EXPIRED_COUNT,
  "retained_archives_count": $RETAINED_COUNT,
  "reclaimed_bytes": $RECLAIMED_BYTES,
  "reclaimed_human": "$RECLAIMED_HR",
  "companions_removed_count": $COMPANIONS_REMOVED,
  "status": "$([[ $EXPIRED_COUNT -gt 0 ]] && echo "EXPIRED_BACKUPS_CLEANED" || echo "CLEAN")",
  "pruned_archives": [
    $JSON_PRUNED_JOINED
  ],
  "retained_archives": [
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
echo -e "  Total Archives Evaluated: ${COLOR_BOLD}${TOTAL_ARCHIVES}${COLOR_RESET}"
echo -e "  Expired Archives Pruned : ${COLOR_YELLOW}${COLOR_BOLD}${EXPIRED_COUNT}${COLOR_RESET} (> ${RETENTION_DAYS} days)"
echo -e "  Active Archives Retained: ${COLOR_GREEN}${COLOR_BOLD}${RETAINED_COUNT}${COLOR_RESET} (&le; ${RETENTION_DAYS} days / safeguard)"
echo -e "  Storage Space Reclaimed : ${COLOR_BOLD}${RECLAIMED_HR}${COLOR_RESET} (${RECLAIMED_BYTES} bytes)"
if [[ "$CLEAN_COMPANION" == true && "$DRY_RUN" == false ]]; then
    echo -e "  Companion Files Purged  : ${COLOR_CYAN}${COMPANIONS_REMOVED}${COLOR_RESET} checksum file(s)"
fi
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  Notice                  : ${COLOR_YELLOW}Dry-run mode active. Run with --delete to prune expired archives.${COLOR_RESET}"
else
    echo -e "  Notice                  : ${COLOR_GREEN}Expired archives and associated checksums unlinked.${COLOR_RESET}"
fi
echo -e "  Telemetry JSON File     : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Audit Log File          : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
