#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #39: Disk Space and Inode Utilization Audit
# Script: disk_inode_check.sh
#
# DESCRIPTION:
#   Audits both storage space (blocks) and inode capacity across all mounted
#   filesystems. Evaluates consumption against configurable warning and
#   critical thresholds, reporting filesystems that exceed limits.
#
# USAGE:
#   ./disk_inode_check.sh [OPTIONS]
#
# OPTIONS:
#   --disk-threshold <N>   Critical threshold for disk space percentage (Default: 80)
#   --inode-threshold <N>  Critical threshold for inode percentage (Default: 80)
#   --warn-threshold <N>   Warning threshold percentage (Default: 70)
#   --all                  Include all virtual and temporary mount points
#   --json                 Generate structured JSON audit log in logs/
#   --help, -h             Display this help message
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/disk_inode.log"
JSON_FILE="${LOG_DIR}/disk_inode_audit.json"

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
DISK_THRESHOLD=80
INODE_THRESHOLD=80
WARN_THRESHOLD=70
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
        CRITICAL) color="${CLR_RED}" ;;
        *) color="${CLR_RESET}" ;;
    esac
    echo -e "${color}[${timestamp}] [${level}] ${message}${CLR_RESET}"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

print_header() {
    echo -e "${CLR_BLUE}${CLR_BOLD}"
    echo "================================================================================"
    echo "       LSA AUTOMATION SPRINT (AS_39) — DISK & INODE UTILIZATION AUDIT           "
    echo "================================================================================"
    echo -e "${CLR_RESET}"
}

show_help() {
    print_header
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --disk-threshold <N>   Disk capacity critical threshold (Default: 80%)
  --inode-threshold <N>  Inode capacity critical threshold (Default: 80%)
  --warn-threshold <N>   Warning threshold percentage (Default: 70%)
  --all                  Audit all mounted filesystems including virtual credentials
  --json                 Emit machine-readable JSON to logs/disk_inode_audit.json
  --help, -h             Display this help dialog

Examples:
  ./disk_inode_check.sh
  ./disk_inode_check.sh --disk-threshold 75 --inode-threshold 80
  ./disk_inode_check.sh --warn-threshold 60 --all
EOF
    exit 0
}

# Parse Command-Line Options
while [ $# -gt 0 ]; do
    case "$1" in
        --disk-threshold)
            DISK_THRESHOLD="$2"
            shift 2
            ;;
        --inode-threshold)
            INODE_THRESHOLD="$2"
            shift 2
            ;;
        --warn-threshold)
            WARN_THRESHOLD="$2"
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

execute_audit() {
    print_header
    local start_time
    start_time="$(date +%s)"
    local timestamp_iso
    timestamp_iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    log_msg "INFO" "Initiating storage audit across mounted filesystems..."
    log_msg "INFO" "Thresholds: Disk Critical >= ${DISK_THRESHOLD}%, Inode Critical >= ${INODE_THRESHOLD}%, Warning >= ${WARN_THRESHOLD}%"

    # Temporary files for POSIX standard table capture
    local tmp_disk
    tmp_disk="$(mktemp)"
    local tmp_inode
    tmp_inode="$(mktemp)"

    df -hP > "${tmp_disk}"
    df -iP > "${tmp_inode}"

    # Use Python to merge and evaluate with high precision
    python3 - <<PYEOF
import sys
import os
import json

disk_threshold = int("${DISK_THRESHOLD}")
inode_threshold = int("${INODE_THRESHOLD}")
warn_threshold = int("${WARN_THRESHOLD}")
include_all = "${INCLUDE_ALL}".lower() == "true"
emit_json = "${EMIT_JSON}".lower() == "true"
log_file = "${LOG_FILE}"
json_file = "${JSON_FILE}"
timestamp = "${timestamp_iso}"

# Parse df -hP
disk_data = {}
with open("${tmp_disk}", "r") as f:
    lines = f.readlines()
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 6:
            fs = parts[0]
            size = parts[1]
            used = parts[2]
            avail = parts[3]
            use_pct_str = parts[4].rstrip("%")
            try:
                use_pct = int(use_pct_str)
            except ValueError:
                use_pct = 0
            mount = parts[5]
            disk_data[mount] = {
                "filesystem": fs,
                "size": size,
                "used": used,
                "avail": avail,
                "disk_pct": use_pct,
                "disk_pct_str": parts[4]
            }

# Parse df -iP
inode_data = {}
with open("${tmp_inode}", "r") as f:
    lines = f.readlines()
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 6:
            mount = parts[5]
            itotal = parts[1]
            iused = parts[2]
            ifree = parts[3]
            iuse_pct_str = parts[4].rstrip("%")
            if iuse_pct_str == "-" or not iuse_pct_str.isdigit():
                iuse_pct = 0
                display_ipct = "N/A"
            else:
                try:
                    iuse_pct = int(iuse_pct_str)
                    display_ipct = f"{iuse_pct}%"
                except ValueError:
                    iuse_pct = 0
                    display_ipct = "N/A"
            
            inode_data[mount] = {
                "itotal": itotal,
                "iused": iused,
                "ifree": ifree,
                "inode_pct": iuse_pct,
                "inode_pct_str": display_ipct
            }

# Merge datasets
merged_records = []
for mount, d_entry in disk_data.items():
    # Filter pseudo-credential mounts unless requested
    if not include_all and "/run/credentials" in mount:
        continue
    
    i_entry = inode_data.get(mount, {
        "itotal": "N/A",
        "iused": "N/A",
        "ifree": "N/A",
        "inode_pct": 0,
        "inode_pct_str": "N/A"
    })
    
    d_pct = d_entry["disk_pct"]
    i_pct = i_entry["inode_pct"]
    
    # Evaluate severity
    status = "OK"
    reasons = []
    
    if d_pct >= disk_threshold:
        status = "CRITICAL"
        reasons.append(f"Disk {d_pct}% >= {disk_threshold}%")
    elif d_pct >= warn_threshold:
        status = "WARNING"
        reasons.append(f"Disk {d_pct}% >= {warn_threshold}%")
        
    if i_pct >= inode_threshold:
        status = "CRITICAL"
        reasons.append(f"Inodes {i_pct}% >= {inode_threshold}%")
    elif i_pct >= warn_threshold and status != "CRITICAL":
        status = "WARNING"
        reasons.append(f"Inodes {i_pct}% >= {warn_threshold}%")
        
    record = {
        "mount": mount,
        "filesystem": d_entry["filesystem"],
        "disk_size": d_entry["size"],
        "disk_used": d_entry["used"],
        "disk_avail": d_entry["avail"],
        "disk_pct": d_pct,
        "disk_pct_str": d_entry["disk_pct_str"],
        "inodes_total": i_entry["itotal"],
        "inodes_used": i_entry["iused"],
        "inodes_free": i_entry["ifree"],
        "inode_pct": i_pct,
        "inode_pct_str": i_entry["inode_pct_str"],
        "status": status,
        "reasons": reasons
    }
    merged_records.append(record)

# Sort by disk_pct descending
merged_records.sort(key=lambda r: (r["status"] != "CRITICAL", r["status"] != "WARNING", -r["disk_pct"]))

# Summary metrics
total_audited = len(merged_records)
critical_count = sum(1 for r in merged_records if r["status"] == "CRITICAL")
warning_count = sum(1 for r in merged_records if r["status"] == "WARNING")
ok_count = sum(1 for r in merged_records if r["status"] == "OK")
max_disk_pct = max((r["disk_pct"] for r in merged_records), default=0)
max_inode_pct = max((r["inode_pct"] for r in merged_records), default=0)

# Terminal Presentation
CLR_RESET = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_RED = "\033[1;31m"
CLR_GREEN = "\033[1;32m"
CLR_YELLOW = "\033[1;33m"
CLR_CYAN = "\033[1;36m"
CLR_MAGENTA = "\033[1;35m"

print(f"\n{CLR_BOLD}{'MOUNT POINT':<22} {'FILESYSTEM':<18} {'DISK SIZE':<10} {'DISK USED':<10} {'DISK %':<8} {'INODES':<10} {'INODE %':<8} {'STATUS':<10}{CLR_RESET}")
print("-" * 102)

for r in merged_records:
    status_str = r["status"]
    if status_str == "CRITICAL":
        status_disp = f"{CLR_RED}{status_str:<10}{CLR_RESET}"
    elif status_str == "WARNING":
        status_disp = f"{CLR_YELLOW}{status_str:<10}{CLR_RESET}"
    else:
        status_disp = f"{CLR_GREEN}{status_str:<10}{CLR_RESET}"
        
    m_disp = r["mount"][:21]
    fs_disp = r["filesystem"][:17]
    print(f"{m_disp:<22} {fs_disp:<18} {r['disk_size']:<10} {r['disk_used']:<10} {r['disk_pct_str']:<8} {r['inodes_total']:<10} {r['inode_pct_str']:<8} {status_disp}")

print("-" * 102)
print(f"Audited: {total_audited} filesystems | {CLR_GREEN}OK: {ok_count}{CLR_RESET} | {CLR_YELLOW}Warning: {warning_count}{CLR_RESET} | {CLR_RED}Critical Exceeded: {critical_count}{CLR_RESET}")

# Highlight Exceeded Filesystems
exceeded = [r for r in merged_records if r["status"] in ("CRITICAL", "WARNING")]
if exceeded:
    print(f"\n{CLR_YELLOW}{CLR_BOLD}⚠ FILE SYSTEMS REQUIRING ATTENTION:{CLR_RESET}")
    for r in exceeded:
        details = ", ".join(r["reasons"])
        badge = f"{CLR_RED}[CRITICAL]{CLR_RESET}" if r["status"] == "CRITICAL" else f"{CLR_YELLOW}[WARNING]{CLR_RESET}"
        print(f"  {badge} {r['mount']} ({r['filesystem']}) -> {details}")
else:
    print(f"\n{CLR_GREEN}{CLR_BOLD}✔ All monitored filesystems are healthy and within thresholds.{CLR_RESET}")

# Write to log and json
with open(log_file, "a") as lf:
    lf.write(f"[{timestamp}] AUDIT: Audited={total_audited}, Critical={critical_count}, Warning={warning_count}, OK={ok_count}\n")
    for r in exceeded:
        lf.write(f"[{timestamp}] ALERT: {r['status']} on {r['mount']} -> {', '.join(r['reasons'])}\n")

if emit_json:
    telemetry = {
        "timestamp": timestamp,
        "thresholds": {
            "disk_critical": disk_threshold,
            "inode_critical": inode_threshold,
            "warning": warn_threshold
        },
        "summary": {
            "total_audited": total_audited,
            "critical_exceeded": critical_count,
            "warning": warning_count,
            "ok": ok_count,
            "max_disk_pct": max_disk_pct,
            "max_inode_pct": max_inode_pct
        },
        "filesystems": merged_records
    }
    with open(json_file, "w", encoding="utf-8") as jf:
        json.dump(telemetry, jf, indent=2)

PYEOF

    rm -f "${tmp_disk}" "${tmp_inode}"

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    log_msg "SUCCESS" "Storage & Inode audit finished in ${duration}s."
}

execute_audit
