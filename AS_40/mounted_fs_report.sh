#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #40: Mounted File System Space Report
# Script: mounted_fs_report.sh
#
# DESCRIPTION:
#   Audits and displays all currently mounted Linux file systems. For every
#   mount point, it reports:
#     - Device / Filesystem Source
#     - Filesystem Type (ext4, 9p, tmpfs, overlay, etc.)
#     - Mount Point Path
#     - Total Capacity Size
#     - Consumed / Used Space
#     - Available / Free Space
#     - Percentage Utilization (Use %)
#     - Mount Options (Read-Write vs Read-Only, flags)
#     - Architectural Category (Physical, Shared/Network, Virtual, Overlay)
#
# USAGE:
#   ./mounted_fs_report.sh [OPTIONS]
#
# OPTIONS:
#   --sort <field>       Sort by: pct, size, used, avail, mount (Default: pct)
#   --filter <fstype>    Filter results by filesystem type (e.g. ext4, tmpfs, 9p)
#   --all                Include specialized systemd credential mount points
#   --json               Emit structured JSON to logs/mounted_fs_audit.json
#   --help, -h           Display this help message
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/mounted_fs.log"
JSON_FILE="${LOG_DIR}/mounted_fs_audit.json"

mkdir -p "${LOG_DIR}"

# ANSI Colors
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"
CLR_MAGENTA="\033[1;35m"

# Default configuration
SORT_FIELD="pct"
FILTER_TYPE=""
INCLUDE_ALL=false
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
    echo "      LSA AUTOMATION SPRINT (AS_40) — MOUNTED FILE SYSTEM REPORT                "
    echo "================================================================================"
    echo -e "${CLR_RESET}"
}

show_help() {
    print_header
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --sort <field>       Sort field: pct (default), size, used, avail, mount
  --filter <fstype>    Filter by filesystem type (e.g. ext4, tmpfs, 9p, overlay)
  --all                Include micro-mounts like systemd service credentials
  --json               Generate machine-readable logs/mounted_fs_audit.json
  --help, -h           Display this help dialog

Examples:
  ./mounted_fs_report.sh
  ./mounted_fs_report.sh --sort size
  ./mounted_fs_report.sh --filter ext4
  ./mounted_fs_report.sh --all
EOF
    exit 0
}

# Parse Command-Line Options
while [ $# -gt 0 ]; do
    case "$1" in
        --sort)
            SORT_FIELD="$2"
            shift 2
            ;;
        --filter)
            FILTER_TYPE="$2"
            shift 2
            ;;
        --all)
            INCLUDE_ALL=true
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

generate_report() {
    print_header
    local start_time
    start_time="$(date +%s)"
    local timestamp_iso
    timestamp_iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    log_msg "INFO" "Scanning mounted file system tables across Linux VFS..."
    log_msg "INFO" "Configuration: Sort By='${SORT_FIELD}', Filter='${FILTER_TYPE:-All}', IncludeAll=${INCLUDE_ALL}"

    local tmp_df
    tmp_df="$(mktemp)"
    local tmp_mounts
    tmp_mounts="$(mktemp)"

    df -hT > "${tmp_df}"
    cat /proc/mounts > "${tmp_mounts}"

    python3 - <<PYEOF
import sys
import os
import json

sort_field = "${SORT_FIELD}".lower()
filter_type = "${FILTER_TYPE}".lower()
include_all = "${INCLUDE_ALL}".lower() == "true"
emit_json = "${EMIT_JSON}".lower() == "true"
log_file = "${LOG_FILE}"
json_file = "${JSON_FILE}"
timestamp = "${timestamp_iso}"

# Parse /proc/mounts to extract mount options
mount_options_map = {}
with open("${tmp_mounts}", "r") as mf:
    for line in mf:
        parts = line.split()
        if len(parts) >= 4:
            m_point = parts[1]
            opts = parts[3]
            mount_options_map[m_point] = opts

# Parse df -hT
records = []
with open("${tmp_df}", "r") as df:
    lines = df.readlines()
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 7:
            fs_dev = parts[0]
            fs_type = parts[1]
            size_str = parts[2]
            used_str = parts[3]
            avail_str = parts[4]
            use_pct_str = parts[5].rstrip("%")
            mount_point = parts[6]

            if not include_all and "/run/credentials" in mount_point:
                continue

            if filter_type and filter_type not in fs_type.lower():
                continue

            try:
                use_pct = int(use_pct_str)
            except ValueError:
                use_pct = 0

            # Categorize filesystem architecture
            fs_type_lower = fs_type.lower()
            if fs_type_lower in ("ext4", "ext3", "ext2", "xfs", "btrfs", "vfat", "ntfs", "f2fs"):
                category = "Physical Storage"
            elif fs_type_lower in ("9p", "cifs", "nfs", "smbfs", "drvfs"):
                category = "Host / Network Shared"
            elif fs_type_lower in ("tmpfs", "ramfs", "devtmpfs", "sysfs", "proc"):
                category = "In-Memory Virtual"
            elif fs_type_lower in ("overlay", "aufs", "squashfs"):
                category = "Overlay / Container"
            else:
                category = "Specialized VFS"

            opts = mount_options_map.get(mount_point, "rw")
            access_mode = "RO" if opts.startswith("ro") or ",ro" in opts else "RW"

            records.append({
                "device": fs_dev,
                "type": fs_type,
                "category": category,
                "mount": mount_point,
                "size": size_str,
                "used": used_str,
                "avail": avail_str,
                "use_pct": use_pct,
                "use_pct_str": parts[5],
                "access_mode": access_mode,
                "options": opts
            })

# Sorting logic
def parse_size_bytes(s):
    units = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4, "P": 1024**5}
    s = s.strip()
    if not s:
        return 0
    unit = s[-1].upper()
    val_str = s[:-1] if unit in units else s
    try:
        val = float(val_str)
        return int(val * units.get(unit, 1))
    except ValueError:
        return 0

if sort_field == "size":
    records.sort(key=lambda r: parse_size_bytes(r["size"]), reverse=True)
elif sort_field == "used":
    records.sort(key=lambda r: parse_size_bytes(r["used"]), reverse=True)
elif sort_field == "avail":
    records.sort(key=lambda r: parse_size_bytes(r["avail"]), reverse=True)
elif sort_field == "mount":
    records.sort(key=lambda r: r["mount"])
else:  # default 'pct'
    records.sort(key=lambda r: r["use_pct"], reverse=True)

# Metrics
total_count = len(records)
rw_count = sum(1 for r in records if r["access_mode"] == "RW")
ro_count = sum(1 for r in records if r["access_mode"] == "RO")
avg_pct = round(sum(r["use_pct"] for r in records) / total_count, 1) if total_count > 0 else 0
categories_count = {}
for r in records:
    cat = r["category"]
    categories_count[cat] = categories_count.get(cat, 0) + 1

# Terminal output
CLR_RESET = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_RED = "\033[1;31m"
CLR_GREEN = "\033[1;32m"
CLR_YELLOW = "\033[1;33m"
CLR_BLUE = "\033[1;34m"
CLR_CYAN = "\033[1;36m"
CLR_MAGENTA = "\033[1;35m"

print(f"\n{CLR_BOLD}{'MOUNT POINT':<22} {'TYPE':<9} {'TOTAL':<8} {'USED':<8} {'AVAIL':<8} {'USE %':<7} {'MODE':<6} {'CATEGORY':<22} {'DEVICE':<16}{CLR_RESET}")
print("-" * 108)

for r in records:
    pct = r["use_pct"]
    if pct >= 80:
        pct_color = CLR_RED
    elif pct >= 60:
        pct_color = CLR_YELLOW
    else:
        pct_color = CLR_GREEN
        
    mode_color = CLR_CYAN if r["access_mode"] == "RW" else CLR_MAGENTA
    m_disp = r["mount"][:21]
    dev_disp = r["device"][:15]
    print(f"{m_disp:<22} {r['type']:<9} {r['size']:<8} {r['used']:<8} {r['avail']:<8} {pct_color}{r['use_pct_str']:<7}{CLR_RESET} {mode_color}{r['access_mode']:<6}{CLR_RESET} {r['category']:<22} {dev_disp:<16}")

print("-" * 108)
print(f"Total Mounted File Systems: {CLR_BOLD}{total_count}{CLR_RESET} ({rw_count} Read-Write, {ro_count} Read-Only) | Average Capacity Use: {CLR_CYAN}{avg_pct}%{CLR_RESET}")

# Telemetry logging
with open(log_file, "a") as lf:
    lf.write(f"[{timestamp}] MOUNT_AUDIT: Mounts={total_count}, RW={rw_count}, RO={ro_count}, AvgPct={avg_pct}%\n")

if emit_json:
    telemetry = {
        "timestamp": timestamp,
        "summary": {
            "total_mounts": total_count,
            "read_write_count": rw_count,
            "read_only_count": ro_count,
            "average_use_pct": avg_pct,
            "categories": categories_count
        },
        "filesystems": records
    }
    with open(json_file, "w", encoding="utf-8") as jf:
        json.dump(telemetry, jf, indent=2)

PYEOF

    rm -f "${tmp_df}" "${tmp_mounts}"

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    log_msg "SUCCESS" "Mounted filesystem report generated in ${duration}s."
}

generate_report
