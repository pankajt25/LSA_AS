#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #33: Duplicate File Detection (File Management)
# Script: duplicate_file_detector.sh
#
# PURPOSE:
#   Identifies duplicate files within a specified directory using cryptographic
#   checksums (SHA-256 / MD5).
#   Implements high-performance two-stage collision resolution:
#     1. Inode size indexing (skips hashing files with unique byte counts)
#     2. Cryptographic content hashing (SHA-256 / MD5 on size collisions)
#   Calculates potential disk space recovery metrics:
#     - Number of redundant duplicate file instances
#     - Wasted byte footprint per duplicate set and across entire directory
#     - Group-by-hash inventory listing all redundant filesystem paths
#
# USAGE:
#   ./duplicate_file_detector.sh [OPTIONS] [TARGET_DIR]
#   OPTIONS:
#     -d, --dir <path>       Target directory to scan for duplicates (default: .)
#     -a, --algo <hash>      Hashing algorithm: sha256 (default) or md5
#     -m, --min-size <bytes> Minimum file size threshold (default: 1 byte)
#     -s, --sandbox          Run audit against simulated multi-folder sandbox dataset
#     -j, --json             Emit structured JSON telemetry to stdout
#     -h, --help             Display this help manual
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/duplicate_files.log"
JSON_FILE="${LOG_DIR}/duplicate_files.json"
SANDBOX_DIR="${SCRIPT_DIR}/sandbox_data"

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
HASH_ALGO="sha256"
MIN_SIZE=1
USE_SANDBOX=0
OUTPUT_JSON=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        -a|--algo)
            HASH_ALGO="${2:-sha256}"
            shift 2
            ;;
        -m|--min-size)
            MIN_SIZE="${2:-1}"
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
            echo -e "${CLR_BOLD}Linux System Administration — Duplicate File Detector${CLR_RESET}"
            echo -e "Usage: $0 [OPTIONS] [TARGET_DIR]"
            echo ""
            echo "Options:"
            echo "  -d, --dir <path>       Directory to scan for duplicates (default: .)"
            echo "  -a, --algo <sha256|md5> Cryptographic hash algorithm (default: sha256)"
            echo "  -m, --min-size <bytes> Minimum file size in bytes (default: 1)"
            echo "  -s, --sandbox          Scan simulated multi-tier sandbox repository"
            echo "  -j, --json             Emit machine-readable JSON telemetry"
            echo "  -h, --help             Show this help menu"
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
    TARGET_DIR="${SANDBOX_DIR}"
fi

TARGET_ABS="$(cd "${TARGET_DIR}" 2>/dev/null && pwd || echo "${TARGET_DIR}")"
if [ ! -d "${TARGET_ABS}" ]; then
    echo -e "${CLR_RED}[ERROR] Target directory does not exist: ${TARGET_DIR}${CLR_RESET}" >&2
    exit 1
fi

# High-performance Python-based two-stage checksum crawler
DETECTOR_OUTPUT=$(python3 - <<PYEOF
import os
import sys
import json
import hashlib
from datetime import datetime

target_dir = r"${TARGET_ABS}"
hash_algo = "${HASH_ALGO}".strip().lower()
min_size = int("${MIN_SIZE}")

def get_hasher():
    if hash_algo == "md5":
        return hashlib.md5
    return hashlib.sha256

def hash_file(filepath):
    h = get_hasher()()
    try:
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None

def format_size(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.2f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"

all_files = []
size_map = {}
total_directory_bytes = 0

# Stage 1: File discovery and initial size grouping
for root, dirs, files in os.walk(target_dir):
    dirs[:] = [d for d in dirs if d not in (".git", ".svn", "__pycache__", "node_modules")]
    for fname in files:
        fpath = os.path.join(root, fname)
        try:
            st = os.lstat(fpath)
            if not os.path.isfile(fpath) or os.path.islink(fpath):
                continue
            sz = st.st_size
            total_directory_bytes += sz
            all_files.append((fpath, sz))
            if sz >= min_size:
                size_map.setdefault(sz, []).append(fpath)
        except Exception:
            continue

# Stage 2: Hashing only files that share identical sizes (>1 file per size)
candidate_sizes = {sz: paths for sz, paths in size_map.items() if len(paths) > 1}
hash_map = {}
files_hashed_count = 0

for sz, paths in candidate_sizes.items():
    for p in paths:
        cksum = hash_file(p)
        files_hashed_count += 1
        if cksum:
            hash_map.setdefault((sz, cksum), []).append(p)

# Filter genuine duplicates (groups with >= 2 matching files)
duplicate_groups = []
group_id = 1
total_redundant_files = 0
total_wasted_bytes = 0

for (sz, cksum), paths in hash_map.items():
    if len(paths) > 1:
        redundant_count = len(paths) - 1
        wasted_for_group = redundant_count * sz
        total_redundant_files += redundant_count
        total_wasted_bytes += wasted_for_group

        rel_paths = [os.path.relpath(p, target_dir) for p in paths]
        duplicate_groups.append({
            "group_id": f"DUP-{group_id:03d}",
            "checksum": cksum,
            "algorithm": hash_algo.upper(),
            "file_size_bytes": sz,
            "file_size_human": format_size(sz),
            "copies_count": len(paths),
            "redundant_count": redundant_count,
            "wasted_bytes": wasted_for_group,
            "wasted_human": format_size(wasted_for_group),
            "original_file": rel_paths[0],
            "duplicate_files": rel_paths[1:],
            "all_files": rel_paths
        })
        group_id += 1

# Sort groups by wasted space descending
duplicate_groups.sort(key=lambda x: x["wasted_bytes"], reverse=True)

wasted_ratio = (total_wasted_bytes / total_directory_bytes * 100.0) if total_directory_bytes > 0 else 0.0

telemetry = {
    "scan_metadata": {
        "target_directory": target_dir,
        "algorithm": hash_algo.upper(),
        "min_size_filter": min_size,
        "scan_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    },
    "summary": {
        "total_files_scanned": len(all_files),
        "total_directory_size_bytes": total_directory_bytes,
        "total_directory_size_human": format_size(total_directory_bytes),
        "candidate_collision_sizes": len(candidate_sizes),
        "files_hashed_count": files_hashed_count,
        "duplicate_groups_count": len(duplicate_groups),
        "redundant_files_count": total_redundant_files,
        "wasted_space_bytes": total_wasted_bytes,
        "wasted_space_human": format_size(total_wasted_bytes),
        "wasted_storage_percentage": round(wasted_ratio, 2)
    },
    "duplicate_groups": duplicate_groups
}

print(json.dumps(telemetry, indent=2))
PYEOF
)

# Save JSON telemetry
echo "${DETECTOR_OUTPUT}" > "${JSON_FILE}"

if [ "${OUTPUT_JSON}" -eq 1 ]; then
    echo "${DETECTOR_OUTPUT}"
    exit 0
fi

# Print formatted ANSI terminal report
python3 - <<PYEOF
import json
import sys

raw_json = r"""${DETECTOR_OUTPUT}"""
try:
    data = json.loads(raw_json)
except Exception as e:
    print(f"Error parsing telemetry: {e}")
    sys.exit(1)

meta = data.get("scan_metadata", {})
summary = data.get("summary", {})
groups = data.get("duplicate_groups", [])

CLR_BOLD = "\033[1m"
CLR_GREEN = "\033[32m"
CLR_CYAN = "\033[36m"
CLR_YELLOW = "\033[33m"
CLR_RED = "\033[31m"
CLR_MAGENTA = "\033[35m"
CLR_RESET = "\033[0m"

print("================================================================================")
print(f" {CLR_BOLD}DUPLICATE FILE DETECTOR — LINUX SYSTEM ADMINISTRATION (AS_33){CLR_RESET}")
print("================================================================================")
print(f" Target Directory: {meta.get('target_directory', '-')}")
print(f" Hash Algorithm:   {meta.get('algorithm', 'SHA256')} | Scan Timestamp: {meta.get('scan_timestamp', '-')}")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}DUPLICATE DETECTION & STORAGE METRICS:{CLR_RESET}")
print(f"  • Total Files Scanned:       {CLR_CYAN}{summary.get('total_files_scanned', 0)}{CLR_RESET} ({summary.get('total_directory_size_human', '0 B')})")
print(f"  • Files Hashed (Collisions): {summary.get('files_hashed_count', 0)}")
print(f"  • Duplicate Content Groups:  {CLR_YELLOW}{summary.get('duplicate_groups_count', 0)}{CLR_RESET}")
print(f"  • Redundant File Copies:     {CLR_RED}{summary.get('redundant_files_count', 0)}{CLR_RESET} redundant files")
print(f"  • Recoverable Storage:       {CLR_GREEN}{summary.get('wasted_space_human', '0 B')}{CLR_RESET} ({summary.get('wasted_storage_percentage', 0)}% wasted space)")
print("--------------------------------------------------------------------------------")

if not groups:
    print(f"  {CLR_GREEN}✔ No duplicate files found in the specified directory.{CLR_RESET}")
else:
    print(f" {CLR_BOLD}IDENTIFIED DUPLICATE FILE SETS:{CLR_RESET}")
    for g in groups:
        gid = g.get("group_id", "-")
        ck = g.get("checksum", "-")[:16]
        sz = g.get("file_size_human", "-")
        copies = g.get("copies_count", 0)
        wasted = g.get("wasted_human", "-")
        files = g.get("all_files", [])

        print(f" [{CLR_YELLOW}{gid}{CLR_RESET}] Hash: {CLR_CYAN}{ck}...{CLR_RESET} | Size: {sz} each | Copies: {copies} | Wasted: {CLR_RED}{wasted}{CLR_RESET}")
        for i, f in enumerate(files):
            prefix = "   ├── [Primary]   " if i == 0 else "   └── [Duplicate] "
            color = CLR_GREEN if i == 0 else CLR_MAGENTA
            print(f"{prefix}{color}{f}{CLR_RESET}")
        print("")

print("================================================================================")
PYEOF

# Append execution summary to log file
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DUPLICATE FILE DETECTOR RUN"
    echo "Directory: ${TARGET_ABS}"
    echo "Algorithm: ${HASH_ALGO}"
    echo "Duplicate groups: $(jq '.summary.duplicate_groups_count' "${JSON_FILE}" 2>/dev/null || echo '0')"
    echo "Redundant files: $(jq '.summary.redundant_files_count' "${JSON_FILE}" 2>/dev/null || echo '0')"
    echo "Wasted space: $(jq -r '.summary.wasted_space_human' "${JSON_FILE}" 2>/dev/null || echo '0 B')"
    echo "------------------------------------------------------------"
} >> "${LOG_FILE}"

echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} Audit log saved to: ${LOG_FILE}"
echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} JSON telemetry saved to: ${JSON_FILE}"
