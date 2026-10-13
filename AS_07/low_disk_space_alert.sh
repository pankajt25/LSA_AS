#!/usr/bin/env bash
# ==============================================================================
# Script: low_disk_space_alert.sh
# Purpose: Identify file systems that have crossed 80% utilization and display
#          affected file systems with appropriate warnings (AS_07).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/disk_alert.log"
JSON_FILE="${LOG_DIR}/disk_alert.json"

DEFAULT_THRESHOLD=80

# ANSI Color Codes
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_MAGENTA="\033[35m"

# Flags & Arguments
THRESHOLD="$DEFAULT_THRESHOLD"
OUTPUT_JSON=false
INCLUDE_VIRTUAL=false
SIMULATE_OVERFLOW=false

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
# Usage / Help
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [THRESHOLD]

Audit all mounted file systems and alert if utilization crosses the threshold.

Arguments:
  THRESHOLD               Disk utilization alert threshold percentage (default: ${DEFAULT_THRESHOLD})

Options:
  -t, --threshold <NUM>   Set alert threshold percentage explicitly (e.g. 80, 70, 90)
  --all                   Include virtual / memory filesystems (tmpfs, devtmpfs)
  --simulate              Inject a simulated >80% partition to test alert behavior
  --json                  Output structured JSON telemetry
  -h, --help              Show this usage manual and exit

Examples:
  ./low_disk_space_alert.sh                 # Default audit with 80% threshold
  ./low_disk_space_alert.sh 70              # Custom threshold at 70%
  ./low_disk_space_alert.sh --threshold 85  # Custom threshold at 85%
  ./low_disk_space_alert.sh --json          # Emits JSON telemetry
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --all)
            INCLUDE_VIRTUAL=true
            shift
            ;;
        --simulate)
            SIMULATE_OVERFLOW=true
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

if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
    THRESHOLD="${POSITIONAL[0]}"
fi

# Validate threshold integer
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    echo -e "${COLOR_RED}[ERROR] Invalid threshold '${THRESHOLD}'. Must be an integer between 1 and 100.${COLOR_RESET}" >&2
    exit 2
fi

# ------------------------------------------------------------------------------
# Header Banner
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}        LOW DISK SPACE MONITOR & CAPACITY ALERT ENGINE (AS_07)                   ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Alert Threshold  : ${COLOR_BOLD}${THRESHOLD}% utilization${COLOR_RESET}"
echo -e " Hostname         : $(hostname)"
echo -e " Kernel           : $(uname -r)"
echo -e " Timestamp        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

# ------------------------------------------------------------------------------
# Disk Space Audit
# ------------------------------------------------------------------------------
log "INFO" "Starting disk utilization scan with threshold ${THRESHOLD}%"

RAW_DF="$(mktemp)"

# Use df -P for POSIX portable 1-line format
if [[ "$INCLUDE_VIRTUAL" == true ]]; then
    df -P > "$RAW_DF"
else
    # Exclude systemd pseudo filesystems and zero-sized mounts
    if ! df -P -x tmpfs -x devtmpfs -x squashfs > "$RAW_DF" 2>/dev/null; then
        df -P > "$RAW_DF"
    fi
fi

TOTAL_FS_COUNT=0
AFFECTED_COUNT=0
AFFECTED_LIST=()
ALL_FS_JSON=()
ALERT_FS_JSON=()

# Process each filesystem line (skipping header)
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Format: Filesystem 1024-blocks Used Available Capacity Mounted on
    fs_dev="$(echo "$line" | awk '{print $1}')"
    [[ "$fs_dev" == "Filesystem" ]] && continue

    (( TOTAL_FS_COUNT++ )) || true

    fs_blocks="$(echo "$line" | awk '{print $2}')"
    fs_used_blocks="$(echo "$line" | awk '{print $3}')"
    fs_avail_blocks="$(echo "$line" | awk '{print $4}')"
    fs_cap_str="$(echo "$line" | awk '{print $5}')"
    fs_cap_num="$(echo "$fs_cap_str" | tr -d '%')"
    fs_mount="$(echo "$line" | awk '{for(i=6;i<=NF;++i) printf "%s ", $i; print ""}' | sed 's/ $//')"

    # Calculate human-readable sizes (G/M)
    fs_total_hr="$(awk -v b="$fs_blocks" 'BEGIN { if (b>=1048576) printf "%.1fG", b/1048576; else printf "%.0fM", b/1024 }')"
    fs_used_hr="$(awk -v b="$fs_used_blocks" 'BEGIN { if (b>=1048576) printf "%.1fG", b/1048576; else printf "%.0fM", b/1024 }')"
    fs_avail_hr="$(awk -v b="$fs_avail_blocks" 'BEGIN { if (b>=1048576) printf "%.1fG", b/1048576; else printf "%.0fM", b/1024 }')"

    # Escape backslashes for valid JSON strings (e.g. C:\ and D:\)
    fs_dev_esc="$(echo "$fs_dev" | sed 's/\\/\\\\/g')"
    fs_mount_esc="$(echo "$fs_mount" | sed 's/\\/\\\\/g')"

    is_alert=false
    severity="NORMAL"
    if (( fs_cap_num >= THRESHOLD )); then
        is_alert=true
        (( AFFECTED_COUNT++ )) || true
        if (( fs_cap_num >= 95 )); then
            severity="CRITICAL"
        elif (( fs_cap_num >= 90 )); then
            severity="HIGH"
        else
            severity="WARNING"
        fi
        AFFECTED_LIST+=("$fs_dev|$fs_mount|$fs_total_hr|$fs_used_hr|$fs_avail_hr|$fs_cap_str|$severity")
        log "ALERT" "Filesystem $fs_dev mounted on $fs_mount crossed threshold: $fs_cap_str (severity: $severity)"
        ALERT_FS_JSON+=("{\"device\":\"$fs_dev_esc\",\"mount\":\"$fs_mount_esc\",\"total\":\"$fs_total_hr\",\"used\":\"$fs_used_hr\",\"available\":\"$fs_avail_hr\",\"utilization_pct\":$fs_cap_num,\"severity\":\"$severity\"}")
    fi

    ALL_FS_JSON+=("{\"device\":\"$fs_dev_esc\",\"mount\":\"$fs_mount_esc\",\"total\":\"$fs_total_hr\",\"used\":\"$fs_used_hr\",\"available\":\"$fs_avail_hr\",\"utilization_pct\":$fs_cap_num,\"crossed_threshold\":$is_alert}")
done < "$RAW_DF"
rm -f "$RAW_DF"

# Optional simulation mode for test verification
if [[ "$SIMULATE_OVERFLOW" == true ]]; then
    (( TOTAL_FS_COUNT++ )) || true
    (( AFFECTED_COUNT++ )) || true
    sim_entry="/dev/mapper/data-vol|/data/storage|500.0G|440.0G|60.0G|88%|WARNING"
    AFFECTED_LIST+=("$sim_entry")
    ALERT_FS_JSON+=("{\"device\":\"/dev/mapper/data-vol\",\"mount\":\"/data/storage\",\"total\":\"500.0G\",\"used\":\"440.0G\",\"available\":\"60.0G\",\"utilization_pct\":88,\"severity\":\"WARNING\"}")
    ALL_FS_JSON+=("{\"device\":\"/dev/mapper/data-vol\",\"mount\":\"/data/storage\",\"total\":\"500.0G\",\"used\":\"440.0G\",\"available\":\"60.0G\",\"utilization_pct\":88,\"crossed_threshold\":true}")
fi

# ------------------------------------------------------------------------------
# Display Alert & Affected Filesystems
# ------------------------------------------------------------------------------
if (( AFFECTED_COUNT > 0 )); then
    echo -e "${COLOR_RED}${COLOR_BOLD}⚠️  ALERT: ${AFFECTED_COUNT} FILE SYSTEM(S) EXCEEDED ${THRESHOLD}% CAPACITY THRESHOLD!${COLOR_RESET}"
    echo ""
    printf "${COLOR_BOLD}%-22s %-22s %-8s %-8s %-8s %-6s %-10s${COLOR_RESET}\n" \
        "FILESYSTEM / DEVICE" "MOUNT POINT" "TOTAL" "USED" "AVAIL" "USE%" "SEVERITY"
    echo "--------------------------------------------------------------------------------"

    for entry in "${AFFECTED_LIST[@]}"; do
        IFS='|' read -r dev mnt tot usd avl pct sev <<< "$entry"
        case "$sev" in
            CRITICAL) col="$COLOR_RED" ;;
            HIGH) col="$COLOR_RED" ;;
            *) col="$COLOR_YELLOW" ;;
        esac
        printf "%-22s %-22s %-8s %-8s %-8s ${col}%-6s %-10s${COLOR_RESET}\n" \
            "$dev" "$mnt" "$tot" "$usd" "$avl" "$pct" "$sev"
    done

    echo ""
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}RECOMMENDED MITIGATION ACTIONS:${COLOR_RESET}"
    echo -e "  1. Review large directories : ${COLOR_CYAN}du -sh <mount_point>/* | sort -hr | head -n 10${COLOR_RESET}"
    echo -e "  2. Clean system log archives: ${COLOR_CYAN}journalctl --vacuum-time=3d${COLOR_RESET}"
    echo -e "  3. Clean package caches     : ${COLOR_CYAN}sudo apt clean${COLOR_RESET}"
    echo -e "  4. Prune unused docker data : ${COLOR_CYAN}docker system prune -f${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}${COLOR_BOLD}✅ HEALTHY: All ${TOTAL_FS_COUNT} mounted file system(s) are within safe capacity limits (< ${THRESHOLD}%).${COLOR_RESET}"
    log "INFO" "All $TOTAL_FS_COUNT filesystems below $THRESHOLD% utilization threshold."
fi

# ------------------------------------------------------------------------------
# Summary Table of All Inspected Filesystems
# ------------------------------------------------------------------------------
echo ""
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}ALL MOUNTED FILE SYSTEMS AUDIT SNAPSHOT:${COLOR_RESET}"
printf "%-24s %-24s %-8s %-8s %-8s %s\n" "FILESYSTEM" "MOUNT POINT" "TOTAL" "USED" "AVAIL" "USE%"
echo "--------------------------------------------------------------------------------"
df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR>1 {printf "%-24s %-24s %-8s %-8s %-8s %s\n", $1, $6, $2, $3, $4, $5}' || df -hP | awk 'NR>1'

# ------------------------------------------------------------------------------
# JSON Serialization
# ------------------------------------------------------------------------------
ALL_JOINED="$(IFS=,; echo "${ALL_FS_JSON[*]}")"
ALERT_JOINED="$(IFS=,; echo "${ALERT_FS_JSON[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_07",
  "title": "Low Disk Space Alert",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "threshold_pct": $THRESHOLD,
  "total_filesystems_scanned": $TOTAL_FS_COUNT,
  "affected_filesystems_count": $AFFECTED_COUNT,
  "status": "$([[ $AFFECTED_COUNT -gt 0 ]] && echo "CAPACITY_WARNING" || echo "HEALTHY")",
  "affected_filesystems": [
    $ALERT_JOINED
  ],
  "all_filesystems": [
    $ALL_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

# ------------------------------------------------------------------------------
# Footer
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_BOLD}SUMMARY RESULTS:${COLOR_RESET}"
echo -e "  Overall Status       : $([[ $AFFECTED_COUNT -gt 0 ]] && echo -e "${COLOR_RED}CAPACITY WARNING (${AFFECTED_COUNT} Filesystems &ge; ${THRESHOLD}%)${COLOR_RESET}" || echo -e "${COLOR_GREEN}HEALTHY (0 Filesystems &ge; ${THRESHOLD}%)${COLOR_RESET}")"
echo -e "  Total Filesystems    : ${TOTAL_FS_COUNT}"
echo -e "  Alert Threshold      : ${THRESHOLD}%"
echo -e "  Audit Telemetry JSON : ${COLOR_CYAN}${JSON_FILE}${COLOR_RESET}"
echo -e "  Persistent Log File  : ${COLOR_CYAN}${LOG_FILE}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

exit $([[ $AFFECTED_COUNT -gt 0 ]] && echo 1 || echo 0)
