#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #32: File Modification Monitor (File Monitoring)
# Script: file_modification_monitor.sh
#
# PURPOSE:
#   Identifies and monitors files within a target project directory modified
#   within a specified time window (default: last 24 hours).
#   Extracts deep filesystem metadata:
#     - Relative and absolute file paths
#     - Precise modification timestamps (mtime)
#     - Elapsed age (hours / minutes ago)
#     - File size (bytes and human-readable)
#     - Owner, group, and octal permissions
#     - File type / extension profiling
#   Calculates telemetry KPIs and time window distributions.
#
# USAGE:
#   ./file_modification_monitor.sh [OPTIONS] [TARGET_DIR]
#   OPTIONS:
#     -d, --dir <path>       Target directory to inspect (default: .)
#     -H, --hours <N>        Time threshold in hours (default: 24)
#     -e, --ext <ext>        Filter by file extension (e.g. .py, .sh)
#     -s, --sandbox          Monitor simulated project repository in sandbox_data
#     -j, --json             Emit machine-readable JSON telemetry
#     -h, --help             Display this help manual
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/modified_files.log"
JSON_FILE="${LOG_DIR}/modified_files.json"
SANDBOX_REPO="${SCRIPT_DIR}/sandbox_data/project_repo"

mkdir -p "${LOG_DIR}"

# ANSI color codes
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[31m"
CLR_GREEN="\033[32m"
CLR_YELLOW="\033[33m"
CLR_BLUE="\033[34m"
CLR_CYAN="\033[36m"
CLR_MAGENTA="\033[35m"

# Default configuration parameters
TARGET_DIR="."
THRESHOLD_HOURS=24
FILTER_EXT=""
USE_SANDBOX=0
OUTPUT_JSON=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        -H|--hours)
            THRESHOLD_HOURS="${2:-24}"
            shift 2
            ;;
        -e|--ext)
            FILTER_EXT="${2:-}"
            shift 2
            ;;
        -s|--sandbox)
            USE_SANDBOX=1
            shift
            ;;
        -j|--json)
            OUTPUT_JSON=1
            shift
            ;;
        -h|--help)
            echo -e "${CLR_BOLD}Linux System Administration — File Modification Monitor${CLR_RESET}"
            echo -e "Usage: $0 [OPTIONS] [TARGET_DIR]"
            echo ""
            echo "Options:"
            echo "  -d, --dir <path>    Specify directory to monitor (default: current directory)"
            echo "  -H, --hours <N>     Time cutoff in hours (default: 24)"
            echo "  -e, --ext <ext>     Filter by file extension (e.g. .py, .log, .md)"
            echo "  -s, --sandbox       Run audit on simulated project repository"
            echo "  -j, --json          Output machine-readable JSON telemetry"
            echo "  -h, --help          Show this help manual"
            exit 0
            ;;
        *)
            if [ -d "$1" ]; then
                TARGET_DIR="$1"
                shift
            else
                echo "Unknown option or invalid directory: $1" >&2
                echo "Run '$0 --help' for usage." >&2
                exit 1
            fi
            ;;
    esac
done

if [ "${USE_SANDBOX}" -eq 1 ]; then
    TARGET_DIR="${SANDBOX_REPO}"
fi

# Resolve absolute path
TARGET_ABS="$(cd "${TARGET_DIR}" 2>/dev/null && pwd || echo "${TARGET_DIR}")"
if [ ! -d "${TARGET_ABS}" ]; then
    echo -e "${CLR_RED}[ERROR] Target directory does not exist: ${TARGET_DIR}${CLR_RESET}" >&2
    exit 1
fi

# Python-based file modification crawler and metadata engine
MONITOR_OUTPUT=$(python3 - <<PYEOF
import os
import sys
import json
import time
from datetime import datetime, timedelta

target_dir = r"${TARGET_ABS}"
threshold_hours = float("${THRESHOLD_HOURS}")
filter_ext = "${FILTER_EXT}".strip().lower()
if filter_ext and not filter_ext.startswith("."):
    filter_ext = "." + filter_ext

now_epoch = time.time()
cutoff_epoch = now_epoch - (threshold_hours * 3600.0)

all_files_count = 0
modified_files = []
older_files_count = 0
total_modified_bytes = 0

time_brackets = {
    "under_1h": 0,
    "1h_to_6h": 0,
    "6h_to_12h": 0,
    "12h_to_24h": 0,
    "over_24h": 0
}

extension_counts = {}

def format_size(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.2f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"

for root, dirs, files in os.walk(target_dir):
    # Skip version control metadata
    dirs[:] = [d for d in dirs if d not in (".git", ".svn", ".hg", "__pycache__", "node_modules")]
    
    for fname in files:
        fpath = os.path.join(root, fname)
        rel_path = os.path.relpath(fpath, target_dir)
        
        # Filter extension if requested
        _, ext = os.path.splitext(fname)
        ext_lower = ext.lower() or ".none"
        
        try:
            stat_info = os.lstat(fpath)
            # Skip symlinks and special devices
            if not os.path.isfile(fpath) or os.path.islink(fpath):
                continue
            all_files_count += 1
            mtime = stat_info.st_mtime
            age_seconds = max(0, now_epoch - mtime)
            age_hours = age_seconds / 3600.0

            if mtime >= cutoff_epoch:
                if filter_ext and ext_lower != filter_ext:
                    continue
                
                total_modified_bytes += stat_info.st_size
                extension_counts[ext_lower] = extension_counts.get(ext_lower, 0) + 1

                # Bracketing
                if age_hours < 1.0:
                    time_brackets["under_1h"] += 1
                    age_str = f"{int(age_seconds // 60)}m ago"
                elif age_hours < 6.0:
                    time_brackets["1h_to_6h"] += 1
                    age_str = f"{age_hours:.1f}h ago"
                elif age_hours < 12.0:
                    time_brackets["6h_to_12h"] += 1
                    age_str = f"{age_hours:.1f}h ago"
                else:
                    time_brackets["12h_to_24h"] += 1
                    age_str = f"{age_hours:.1f}h ago"

                # Permissions & owner
                perms_octal = oct(stat_info.st_mode)[-3:]
                import pwd
                try:
                    owner_name = pwd.getpwuid(stat_info.st_uid).pw_name
                except Exception:
                    owner_name = str(stat_info.st_uid)

                mtime_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")

                modified_files.append({
                    "relative_path": rel_path,
                    "absolute_path": fpath,
                    "filename": fname,
                    "extension": ext_lower,
                    "size_bytes": stat_info.st_size,
                    "size_human": format_size(stat_info.st_size),
                    "mtime_epoch": mtime,
                    "mtime_formatted": mtime_str,
                    "age_hours": round(age_hours, 2),
                    "age_string": age_str,
                    "owner": owner_name,
                    "permissions": perms_octal
                })
            else:
                older_files_count += 1
                time_brackets["over_24h"] += 1
        except Exception:
            continue

# Sort by modification time descending (most recently modified first)
modified_files.sort(key=lambda x: x["mtime_epoch"], reverse=True)

most_recent_file = modified_files[0]["relative_path"] if modified_files else "None"
mod_ratio = (len(modified_files) / all_files_count * 100.0) if all_files_count > 0 else 0.0

telemetry = {
    "scan_metadata": {
        "target_directory": target_dir,
        "scan_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z"),
        "threshold_hours": threshold_hours,
        "extension_filter": filter_ext or "All Extensions"
    },
    "summary": {
        "total_files_scanned": all_files_count,
        "modified_files_count": len(modified_files),
        "older_files_count": older_files_count,
        "modification_percentage": round(mod_ratio, 1),
        "total_modified_bytes": total_modified_bytes,
        "total_modified_human": format_size(total_modified_bytes),
        "most_recent_file": most_recent_file,
        "time_brackets": time_brackets,
        "top_extensions": extension_counts
    },
    "modified_files": modified_files
}

print(json.dumps(telemetry, indent=2))
PYEOF
)

# Save JSON telemetry
echo "${MONITOR_OUTPUT}" > "${JSON_FILE}"

if [ "${OUTPUT_JSON}" -eq 1 ]; then
    echo "${MONITOR_OUTPUT}"
    exit 0
fi

# Print formatted ANSI terminal report
python3 - <<PYEOF
import json
import sys

raw_json = r"""${MONITOR_OUTPUT}"""
try:
    data = json.loads(raw_json)
except Exception as e:
    print(f"Error parsing telemetry: {e}")
    sys.exit(1)

meta = data.get("scan_metadata", {})
summary = data.get("summary", {})
files = data.get("modified_files", [])

CLR_BOLD = "\033[1m"
CLR_GREEN = "\033[32m"
CLR_CYAN = "\033[36m"
CLR_YELLOW = "\033[33m"
CLR_RED = "\033[31m"
CLR_MAGENTA = "\033[35m"
CLR_RESET = "\033[0m"

print("================================================================================")
print(f" {CLR_BOLD}FILE MODIFICATION MONITOR — LINUX SYSTEM ADMINISTRATION (AS_32){CLR_RESET}")
print("================================================================================")
print(f" Target Directory:  {meta.get('target_directory', '-')}")
print(f" Time Window:       Last {meta.get('threshold_hours', 24)} Hours | Scan Time: {meta.get('scan_timestamp', '-')}")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}SCAN TELEMETRY & MODIFICATION KPIS:{CLR_RESET}")
print(f"  • Total Files Scanned:    {CLR_CYAN}{summary.get('total_files_scanned', 0)}{CLR_RESET}")
print(f"  • Files Modified (<{meta.get('threshold_hours', 24)}h):  {CLR_GREEN}{summary.get('modified_files_count', 0)}{CLR_RESET} ({summary.get('modification_percentage', 0)}% of project)")
print(f"  • Unchanged / Older:      {summary.get('older_files_count', 0)} files")
print(f"  • Cumulative Mod Size:    {CLR_YELLOW}{summary.get('total_modified_human', '0 B')}{CLR_RESET}")
print(f"  • Most Recent Change:     {CLR_MAGENTA}{summary.get('most_recent_file', 'None')}{CLR_RESET}")
brackets = summary.get("time_brackets", {})
print(f"  • Age Distribution:       <1h: {brackets.get('under_1h',0)} | 1-6h: {brackets.get('1h_to_6h',0)} | 6-12h: {brackets.get('6h_to_12h',0)} | 12-24h: {brackets.get('12h_to_24h',0)}")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}FILES MODIFIED WITHIN LAST {meta.get('threshold_hours', 24)} HOURS:{CLR_RESET}")
print(f" {'MODIFIED TIMESTAMP':<19} | {'AGE':<9} | {'SIZE':<9} | {'OWNER':<8} | {'PERM':<4} | {'FILE PATH'}")
print("-" * 96)

if not files:
    print(f"  No files detected with modifications within the last {meta.get('threshold_hours', 24)} hours.")
else:
    for f in files[:35]:
        ts = f.get("mtime_formatted", "-")
        age = f.get("age_string", "-")
        sz = f.get("size_human", "-")
        owner = f.get("owner", "-")
        perm = f.get("permissions", "-")
        rel = f.get("relative_path", "-")
        
        # Color coding by freshness
        if "m ago" in age:
            age_disp = f"{CLR_GREEN}{age:<9}{CLR_RESET}"
        elif float(f.get("age_hours", 24)) <= 6:
            age_disp = f"{CLR_CYAN}{age:<9}{CLR_RESET}"
        else:
            age_disp = f"{CLR_YELLOW}{age:<9}{CLR_RESET}"
            
        print(f" {ts:<19} | {age_disp} | {sz:<9} | {owner:<8} | {perm:<4} | {CLR_BOLD}{rel}{CLR_RESET}")

    if len(files) > 35:
        print(f"  ... and {len(files) - 35} additional modified files (full catalog in report.html)")

print("================================================================================")
PYEOF

# Append execution log entry
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE MODIFICATION MONITOR RUN"
    echo "Directory: ${TARGET_ABS}"
    echo "Threshold: ${THRESHOLD_HOURS} hours"
    echo "Modified files found: $(jq '.summary.modified_files_count' "${JSON_FILE}" 2>/dev/null || echo '0')"
    echo "Cumulative modified size: $(jq -r '.summary.total_modified_human' "${JSON_FILE}" 2>/dev/null || echo '0 B')"
    echo "------------------------------------------------------------"
} >> "${LOG_FILE}"

echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} Audit log saved to: ${LOG_FILE}"
echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} JSON telemetry saved to: ${JSON_FILE}"
