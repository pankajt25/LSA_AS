#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #35: Log Archival (Log Management)
# Script: log_archiver.sh
#
# PURPOSE:
#   Automates the archival and compression of historical log files with
#   ISO-standard timestamps.
#   Implements a defensive log lifecycle pipeline:
#     1. Selective discovery (pattern matching, file size, optional age cutoff)
#     2. Timestamped tarball packaging (tar -czf log_archive_YYYYMMDD_HHMMSS.tar.gz)
#     3. Non-destructive decompression verification (tar -tzf integrity test)
#     4. Cryptographic SHA-256 manifest generation (.sha256)
#     5. Compression telemetry & storage efficiency metrics calculation
#     6. Optional post-verification safe log truncation/purging (--purge)
#
# USAGE:
#   ./log_archiver.sh [OPTIONS]
#   OPTIONS:
#     -s, --source <dir>     Source directory containing logs (default: sandbox active_logs)
#     -o, --output <dir>     Destination archive directory (default: ./archives)
#     -p, --pattern <glob>   File glob pattern (default: *.log)
#     -f, --format <gz|bz2|xz> Compression algorithm (default: gz)
#     -d, --older-than <N>   Only archive logs older than N days
#     --purge                Safely delete source logs after verified archival
#     --sandbox              Archive corporate sandbox active_logs dataset
#     -j, --json             Emit structured JSON telemetry to stdout
#     -h, --help             Display this help manual
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
ARCHIVE_DIR="${SCRIPT_DIR}/archives"
LOG_FILE="${LOG_DIR}/log_archival.log"
JSON_FILE="${LOG_DIR}/log_archival.json"
SANDBOX_LOGS="${SCRIPT_DIR}/sandbox_data/active_logs"

mkdir -p "${LOG_DIR}" "${ARCHIVE_DIR}"

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
SOURCE_DIR="${SANDBOX_LOGS}"
OUTPUT_DIR="${ARCHIVE_DIR}"
FILE_PATTERN="*.log"
COMPRESS_FORMAT="gz"
OLDER_THAN_DAYS=0
PURGE_AFTER_ARCHIVE=0
USE_SANDBOX=0
OUTPUT_JSON=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            SOURCE_DIR="${2:-}"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        -p|--pattern)
            FILE_PATTERN="${2:-*.log}"
            shift 2
            ;;
        -f|--format)
            COMPRESS_FORMAT="${2:-gz}"
            shift 2
            ;;
        -d|--older-than)
            OLDER_THAN_DAYS="${2:-0}"
            shift 2
            ;;
        --purge)
            PURGE_AFTER_ARCHIVE=1
            shift
            ;;
        --sandbox)
            USE_SANDBOX=1
            SOURCE_DIR="${SANDBOX_LOGS}"
            shift
            ;;
        -j|--json)
            OUTPUT_JSON=1
            shift
            ;;
        -h|--help)
            echo -e "${CLR_BOLD}Linux System Administration — Log Archival Engine${CLR_RESET}"
            echo -e "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -s, --source <dir>       Source directory containing logs"
            echo "  -o, --output <dir>       Destination archive storage directory"
            echo "  -p, --pattern <glob>     File matching pattern (default: *.log)"
            echo "  -f, --format <gz|bz2|xz> Compression algorithm (default: gz)"
            echo "  -d, --older-than <N>     Filter logs older than N days"
            echo "  --purge                  Delete source logs after verified archival"
            echo "  --sandbox                Use simulated corporate active logs"
            echo "  -j, --json               Emit machine-readable JSON telemetry"
            echo "  -h, --help               Show this help menu"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

# Resolve absolute paths
SOURCE_ABS="$(cd "${SOURCE_DIR}" 2>/dev/null && pwd || echo "${SOURCE_DIR}")"
mkdir -p "${OUTPUT_DIR}"
OUTPUT_ABS="$(cd "${OUTPUT_DIR}" 2>/dev/null && pwd || echo "${OUTPUT_DIR}")"

if [ ! -d "${SOURCE_ABS}" ]; then
    echo -e "${CLR_RED}[ERROR] Source directory does not exist: ${SOURCE_DIR}${CLR_RESET}" >&2
    exit 1
fi

# Python-based discovery, archival, verification, and telemetry engine
ARCHIVE_OUTPUT=$(python3 - <<PYEOF
import os
import sys
import json
import fnmatch
import time
import subprocess
import hashlib
from datetime import datetime

source_dir = r"${SOURCE_ABS}"
output_dir = r"${OUTPUT_ABS}"
file_pattern = "${FILE_PATTERN}"
compress_format = "${COMPRESS_FORMAT}".lower()
older_than_days = float("${OLDER_THAN_DAYS}")
purge_after = bool(${PURGE_AFTER_ARCHIVE})
use_sandbox = bool(${USE_SANDBOX})

now_epoch = time.time()
age_cutoff_epoch = now_epoch - (older_than_days * 86400.0) if older_than_days > 0 else now_epoch + 86400.0

def format_size(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.2f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

# 1. Discover eligible logs
selected_files = []
total_uncompressed_bytes = 0

for root, dirs, files in os.walk(source_dir):
    for fname in files:
        if fnmatch.fnmatch(fname, file_pattern):
            fpath = os.path.join(root, fname)
            try:
                st = os.lstat(fpath)
                if not os.path.isfile(fpath) or os.path.islink(fpath):
                    continue
                if older_than_days > 0 and st.st_mtime > age_cutoff_epoch:
                    continue
                rel_path = os.path.relpath(fpath, source_dir)
                total_uncompressed_bytes += st.st_size
                mtime_str = datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
                selected_files.append({
                    "relative_path": rel_path,
                    "absolute_path": fpath,
                    "size_bytes": st.st_size,
                    "size_human": format_size(st.st_size),
                    "mtime_formatted": mtime_str
                })
            except Exception:
                continue

if not selected_files:
    telemetry = {
        "status": "NO_FILES_FOUND",
        "message": f"No files matched pattern '{file_pattern}' in '{source_dir}'.",
        "selected_files_count": 0,
        "selected_files": []
    }
    print(json.dumps(telemetry, indent=2))
    sys.exit(0)

# Sort files alphabetically
selected_files.sort(key=lambda x: x["relative_path"])

# 2. Construct timestamped archive file name
timestamp_token = datetime.now().strftime("%Y%m%d_%H%M%S")
ext_map = {"gz": "tar.gz", "bz2": "tar.bz2", "xz": "tar.xz"}
tar_flag_map = {"gz": "-czf", "bz2": "-cjf", "xz": "-cJf"}
test_flag_map = {"gz": "-tzf", "bz2": "-tjf", "xz": "-tJf"}

archive_ext = ext_map.get(compress_format, "tar.gz")
tar_create_flag = tar_flag_map.get(compress_format, "-czf")
tar_test_flag = test_flag_map.get(compress_format, "-tzf")

archive_filename = f"log_archive_{timestamp_token}.{archive_ext}"
archive_fullpath = os.path.join(output_dir, archive_filename)
checksum_fullpath = f"{archive_fullpath}.sha256"

# 3. Create compressed archive using native GNU tar
file_rel_args = [f["relative_path"] for f in selected_files]
tar_cmd = ["tar", tar_create_flag, archive_fullpath, "-C", source_dir] + file_rel_args

try:
    sub_res = subprocess.run(tar_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
except subprocess.CalledProcessError as e:
    telemetry = {
        "status": "ERROR",
        "error": f"Tar execution failed: {e.stderr}",
        "selected_files_count": len(selected_files)
    }
    print(json.dumps(telemetry, indent=2))
    sys.exit(1)

# 4. Decompression integrity verification test
test_cmd = ["tar", tar_test_flag, archive_fullpath]
try:
    test_res = subprocess.run(test_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    archive_verified = True
    integrity_status = "VERIFIED_INTEGRITY_OK"
except subprocess.CalledProcessError as e:
    archive_verified = False
    integrity_status = f"VERIFICATION_FAILED: {e.stderr}"

# 5. Cryptographic checksum calculation
archive_sha256 = sha256_file(archive_fullpath)
with open(checksum_fullpath, "w", encoding="utf-8") as f:
    f.write(f"{archive_sha256}  {archive_filename}\n")

# 6. Storage compression metrics
compressed_bytes = os.path.getsize(archive_fullpath)
space_saved_bytes = max(0, total_uncompressed_bytes - compressed_bytes)
compression_ratio = round((1.0 - (compressed_bytes / total_uncompressed_bytes)) * 100.0, 1) if total_uncompressed_bytes > 0 else 0.0

# 7. Optional purge
purged_files_count = 0
if purge_after and archive_verified:
    for f in selected_files:
        try:
            os.remove(f["absolute_path"])
            purged_files_count += 1
        except Exception:
            pass

telemetry = {
    "status": "SUCCESS",
    "metadata": {
        "source_directory": source_dir,
        "output_directory": output_dir,
        "archive_file": archive_filename,
        "archive_path": archive_fullpath,
        "checksum_file": f"{archive_filename}.sha256",
        "sha256_hash": archive_sha256,
        "compression_format": compress_format.upper(),
        "archival_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z"),
        "integrity_verification": integrity_status
    },
    "metrics": {
        "files_archived_count": len(selected_files),
        "uncompressed_bytes": total_uncompressed_bytes,
        "uncompressed_human": format_size(total_uncompressed_bytes),
        "compressed_bytes": compressed_bytes,
        "compressed_human": format_size(compressed_bytes),
        "space_saved_bytes": space_saved_bytes,
        "space_saved_human": format_size(space_saved_bytes),
        "compression_ratio_pct": compression_ratio,
        "source_logs_purged": purged_files_count
    },
    "archived_files": selected_files
}

print(json.dumps(telemetry, indent=2))
PYEOF
)

# Save JSON telemetry
echo "${ARCHIVE_OUTPUT}" > "${JSON_FILE}"

if [ "${OUTPUT_JSON}" -eq 1 ]; then
    echo "${ARCHIVE_OUTPUT}"
    exit 0
fi

# Print formatted ANSI terminal report
python3 - <<PYEOF
import json
import sys

raw_json = r"""${ARCHIVE_OUTPUT}"""
try:
    data = json.loads(raw_json)
except Exception as e:
    print(f"Error parsing telemetry: {e}")
    sys.exit(1)

meta = data.get("metadata", {})
metrics = data.get("metrics", {})
files = data.get("archived_files", [])

CLR_BOLD = "\033[1m"
CLR_GREEN = "\033[32m"
CLR_CYAN = "\033[36m"
CLR_YELLOW = "\033[33m"
CLR_RED = "\033[31m"
CLR_MAGENTA = "\033[35m"
CLR_RESET = "\033[0m"

print("================================================================================")
print(f" {CLR_BOLD}LOG ARCHIVAL & COMPRESSION ENGINE — LINUX SYSADMIN (AS_35){CLR_RESET}")
print("================================================================================")
print(f" Source Logs:   {meta.get('source_directory', '-')}")
print(f" Archive Target: {meta.get('archive_file', '-')}")
print(f" Timestamp:     {meta.get('archival_timestamp', '-')} | Format: {meta.get('compression_format', 'GZ')}")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}ARCHIVAL EFFICIENCY & TELEMETRY KPIS:{CLR_RESET}")
print(f"  • Files Archived:        {CLR_CYAN}{metrics.get('files_archived_count', 0)}{CLR_RESET} log files")
print(f"  • Original Payload:      {metrics.get('uncompressed_human', '0 B')}")
print(f"  • Compressed Archive:    {CLR_GREEN}{metrics.get('compressed_human', '0 B')}{CLR_RESET}")
print(f"  • Storage Space Saved:   {CLR_YELLOW}{metrics.get('space_saved_human', '0 B')}{CLR_RESET} ({metrics.get('compression_ratio_pct', 0)}% reduction)")
print(f"  • Integrity Check:       {CLR_GREEN}{meta.get('integrity_verification', '-')}{CLR_RESET}")
print(f"  • SHA-256 Digest:        {CLR_CYAN}{meta.get('sha256_hash', '-')[:24]}...{CLR_RESET}")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}ARCHIVED LOG FILES MANIFEST:{CLR_RESET}")
print(f" {'LAST MODIFIED':<19} | {'SIZE':<10} | {'LOG FILE PATH'}")
print("-" * 96)

for f in files:
    ts = f.get("mtime_formatted", "-")
    sz = f.get("size_human", "-")
    rel = f.get("relative_path", "-")
    print(f" {ts:<19} | {sz:<10} | {CLR_BOLD}{rel}{CLR_RESET}")

print("================================================================================")
PYEOF

# Append execution log entry
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOG ARCHIVAL COMPLETED"
    echo "Archive: $(jq -r '.metadata.archive_file' "${JSON_FILE}" 2>/dev/null || echo '-')"
    echo "Files archived: $(jq '.metrics.files_archived_count' "${JSON_FILE}" 2>/dev/null || echo '0')"
    echo "Space saved: $(jq -r '.metrics.space_saved_human' "${JSON_FILE}" 2>/dev/null || echo '0 B')"
    echo "SHA256: $(jq -r '.metadata.sha256_hash' "${JSON_FILE}" 2>/dev/null || echo '-')"
    echo "------------------------------------------------------------"
} >> "${LOG_FILE}"

echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} Audit log saved to: ${LOG_FILE}"
echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} JSON telemetry saved to: ${JSON_FILE}"
