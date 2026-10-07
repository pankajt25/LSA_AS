#!/usr/bin/env bash
# ==============================================================================
# Script: large_file_detector.sh
# Purpose: Identify files exceeding a specified size threshold and display
#          their locations, sizes, and attributes for storage triage (AS_08).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/large_files.log"
JSON_FILE="${LOG_DIR}/large_files.json"

DEFAULT_DIR="/var/log"
DEFAULT_SIZE="10M"
DEFAULT_LIMIT=20

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_MAGENTA="\033[35m"

# Variables
SEARCH_DIR=""
SIZE_THRESHOLD=""
LIMIT="$DEFAULT_LIMIT"
OUTPUT_JSON=false

# ------------------------------------------------------------------------------
# Logging Helper
# ------------------------------------------------------------------------------
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# Help Manual
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY] [SIZE_THRESHOLD]

Identify files exceeding a specified size threshold to assist storage remediation.

Arguments:
  DIRECTORY               Target directory tree to inspect (default: ${DEFAULT_DIR})
  SIZE_THRESHOLD          Size cutoff (e.g., 10M, 500k, 1G, 100M) (default: ${DEFAULT_SIZE})

Options:
  -d, --dir <DIR>         Specify directory explicitly
  -s, --size <SIZE>       Specify size threshold explicitly (e.g., 5M, 50M, 1G)
  -n, --limit <NUM>       Limit output to top N largest matching files (default: ${DEFAULT_LIMIT})
  --sandbox               Target local sandbox_data directory
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Examples:
  ./large_file_detector.sh                     # Scans /var/log for files > 10M
  ./large_file_detector.sh /var 20M            # Scans /var for files > 20M
  ./large_file_detector.sh ./sandbox_data 5M   # Scans local sandbox for files > 5M
  ./large_file_detector.sh --json              # Emits JSON telemetry
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            SEARCH_DIR="$2"
            shift 2
            ;;
        -s|--size)
            SIZE_THRESHOLD="$2"
            shift 2
            ;;
        -n|--limit)
            LIMIT="$2"
            shift 2
            ;;
        --sandbox)
            SEARCH_DIR="${SCRIPT_DIR}/sandbox_data"
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
if [[ -z "$SEARCH_DIR" ]]; then
    if [[ ${#POSITIONAL[@]} -ge 1 && -d "${POSITIONAL[0]}" ]]; then
        SEARCH_DIR="${POSITIONAL[0]}"
        if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
            SIZE_THRESHOLD="${POSITIONAL[1]}"
        fi
    elif [[ ${#POSITIONAL[@]} -ge 1 && "${POSITIONAL[0]}" =~ ^[0-9]+[kKmMgGtT]?$ ]]; then
        SIZE_THRESHOLD="${POSITIONAL[0]}"
        SEARCH_DIR="$DEFAULT_DIR"
    else
        SEARCH_DIR="$DEFAULT_DIR"
    fi
else
    # SEARCH_DIR was set by flag (e.g. --sandbox or -d)
    if [[ -z "$SIZE_THRESHOLD" && ${#POSITIONAL[@]} -ge 1 && "${POSITIONAL[0]}" =~ ^[0-9]+[kKmMgGtT]?$ ]]; then
        SIZE_THRESHOLD="${POSITIONAL[0]}"
    fi
fi

if [[ -z "$SIZE_THRESHOLD" ]]; then
    SIZE_THRESHOLD="$DEFAULT_SIZE"
fi

# Validate target directory
if [[ ! -d "$SEARCH_DIR" ]]; then
    echo -e "${COLOR_RED}[ERROR] Search directory '${SEARCH_DIR}' does not exist or is not a directory.${COLOR_RESET}" >&2
    log "ERROR" "Search directory '${SEARCH_DIR}' not found."
    exit 1
fi
SEARCH_DIR_CANONICAL="$(cd "$SEARCH_DIR" && pwd)"

# Validate size threshold syntax (e.g. 10M, 500k, 1G, 1048576)
if ! [[ "$SIZE_THRESHOLD" =~ ^[0-9]+[kKmMgGtT]?$ ]]; then
    echo -e "${COLOR_RED}[ERROR] Invalid size threshold '${SIZE_THRESHOLD}'. Use format: 10M, 500k, 1G.${COLOR_RESET}" >&2
    exit 2
fi

# Convert threshold suffix for GNU find (-size +10M)
FIND_SIZE="$SIZE_THRESHOLD"
# If no unit specified, default to bytes (c)
if [[ "$FIND_SIZE" =~ ^[0-9]+$ ]]; then
    FIND_SIZE="${FIND_SIZE}c"
fi

# ------------------------------------------------------------------------------
# Banner Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         STORAGE MANAGEMENT: LARGE FILE DETECTION ENGINE (AS_08)                 ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Target Directory : ${COLOR_BOLD}${SEARCH_DIR_CANONICAL}${COLOR_RESET}"
echo -e " Size Threshold   : ${COLOR_BOLD}> ${SIZE_THRESHOLD}${COLOR_RESET}"
echo -e " Display Limit    : Top ${LIMIT} largest matching file(s)"
echo -e " Hostname         : $(hostname)"
echo -e " Timestamp        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Scan & Detection Execution
# ------------------------------------------------------------------------------
log "INFO" "Executing large file scan on '${SEARCH_DIR_CANONICAL}' for files > ${SIZE_THRESHOLD}"

RAW_RESULTS="$(mktemp)"

# Find matching files, extract size in bytes and path, sort descending by size
# Format: size_bytes<TAB>path
find "$SEARCH_DIR_CANONICAL" -type f -size +"$FIND_SIZE" -printf "%s\t%p\n" 2>/dev/null | sort -nr > "$RAW_RESULTS" || true

TOTAL_MATCHES="$(wc -l < "$RAW_RESULTS" | tr -d ' ')"
TOTAL_BYTES=0
if [[ $TOTAL_MATCHES -gt 0 ]]; then
    TOTAL_BYTES="$(awk '{sum += $1} END {print sum+0}' "$RAW_RESULTS")"
fi

# Format human readable total
TOTAL_HR="$(awk -v b="$TOTAL_BYTES" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GB", b/1073741824;
    else if (b >= 1048576) printf "%.2f MB", b/1048576;
    else if (b >= 1024) printf "%.2f KB", b/1024;
    else printf "%d B", b;
}')"

echo -e "[INFO] Matching files found: ${COLOR_BOLD}${TOTAL_MATCHES}${COLOR_RESET}"
echo -e "[INFO] Cumulative storage  : ${COLOR_BOLD}${TOTAL_HR}${COLOR_RESET} (${TOTAL_BYTES} bytes)"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

JSON_ITEMS=()
RANK=0

if [[ $TOTAL_MATCHES -gt 0 ]]; then
    printf "${COLOR_BOLD}%-4s %-12s %-10s %-12s %-12s %-16s %s${COLOR_RESET}\n" \
        "RANK" "SIZE" "PERMS" "OWNER" "GROUP" "MODIFIED" "LOCATION / FILE PATH"
    echo "--------------------------------------------------------------------------------"

    while IFS=$'\t' read -r bytes path; do
        [[ -z "$path" ]] && continue
        (( RANK++ )) || true

        # Human-readable size
        size_hr="$(awk -v b="$bytes" 'BEGIN {
            if (b >= 1073741824) printf "%.2f GB", b/1073741824;
            else if (b >= 1048576) printf "%.2f MB", b/1048576;
            else if (b >= 1024) printf "%.2f KB", b/1024;
            else printf "%d B", b;
        }')"

        perms="$(stat -c "%A" "$path" 2>/dev/null || echo "???")"
        owner="$(stat -c "%U" "$path" 2>/dev/null || echo "???")"
        group="$(stat -c "%G" "$path" 2>/dev/null || echo "???")"
        mod_time="$(stat -c "%y" "$path" 2>/dev/null | cut -d'.' -f1 || echo "???")"

        # Print top N rows
        if (( RANK <= LIMIT )); then
            printf "%-4s ${COLOR_YELLOW}%-12s${COLOR_RESET} %-10s %-12s %-12s %-16s %s\n" \
                "#${RANK}" "$size_hr" "$perms" "$owner" "$group" "$mod_time" "$path"
        fi

        log "LARGE_FILE" "Rank #$RANK: $path ($size_hr, $bytes bytes, $owner:$group)"

        # Escape path for JSON
        esc_path="$(echo "$path" | sed 's/"/\\"/g')"
        JSON_ITEMS+=("{\"rank\":$RANK,\"path\":\"$esc_path\",\"size_bytes\":$bytes,\"size_human\":\"$size_hr\",\"owner\":\"$owner\",\"group\":\"$group\",\"permissions\":\"$perms\",\"modified\":\"$mod_time\"}")
    done < "$RAW_RESULTS"

    if (( TOTAL_MATCHES > LIMIT )); then
        echo -e "${COLOR_CYAN}... and $(( TOTAL_MATCHES - LIMIT )) more file(s) exceeding threshold (view report.html for full inventory).${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_GREEN}${COLOR_BOLD}✅ No files found exceeding ${SIZE_THRESHOLD} in '${SEARCH_DIR_CANONICAL}'.${COLOR_RESET}"
    echo -e "Storage utilization in target directory is within expected thresholds."
    log "INFO" "No files exceeding $SIZE_THRESHOLD in $SEARCH_DIR_CANONICAL"
fi

rm -f "$RAW_RESULTS"

# ------------------------------------------------------------------------------
# JSON Telemetry Serialization
# ------------------------------------------------------------------------------
JSON_ITEMS_JOINED="$(IFS=,; echo "${JSON_ITEMS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_08",
  "title": "Large File Detection",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "target_directory": "$SEARCH_DIR_CANONICAL",
  "size_threshold": "$SIZE_THRESHOLD",
  "total_matching_files": $TOTAL_MATCHES,
  "cumulative_bytes": $TOTAL_BYTES,
  "cumulative_human": "$TOTAL_HR",
  "status": "$([[ $TOTAL_MATCHES -gt 0 ]] && echo "LARGE_FILES_FOUND" || echo "CLEAN")",
  "files": [
    $JSON_ITEMS_JOINED
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
echo -e "${COLOR_BOLD}DETECTION SUMMARY:${COLOR_RESET}"
echo -e "  Files Exceeding ${SIZE_THRESHOLD}: ${COLOR_BOLD}${TOTAL_MATCHES}${COLOR_RESET} file(s)"
echo -e "  Total Space Consumed   : ${COLOR_BOLD}${TOTAL_HR}${COLOR_RESET}"
echo -e "  Telemetry JSON File    : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Persistent Audit Log   : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit 0
