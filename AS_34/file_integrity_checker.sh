#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #34: File Integrity Check (File Integrity)
# Script: file_integrity_checker.sh
#
# PURPOSE:
#   Cryptographic checksum-based integrity verification system (FIM).
#   Detects unauthorized modifications, file deletions, and rogue file additions.
#   Implements a 4-state integrity lifecycle:
#     1. MATCH / UNCHANGED  : Checksum perfectly matches authoritative baseline
#     2. TAMPERED / MODIFIED: File content altered (hash mismatch - security alert)
#     3. MISSING / DELETED  : Critical baseline file has been removed
#     4. UNTRACKED / NEW    : Rogue or unexpected file injected into directory
#
# USAGE:
#   ./file_integrity_checker.sh [OPTIONS]
#   OPTIONS:
#     -v, --verify           Verify file integrity against baseline (default)
#     -i, --init             Initialize / regenerate baseline checksum manifest
#     -b, --baseline <file>  Specify baseline checksum manifest path
#     -d, --dir <path>       Target directory to inspect
#     -s, --sandbox          Run audit against simulated tampered sandbox environment
#     -j, --json             Emit structured JSON telemetry to stdout
#     -h, --help             Display this help manual
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/integrity_check.log"
JSON_FILE="${LOG_DIR}/integrity_check.json"
DEFAULT_BASELINE="${LOG_DIR}/live_baseline.sha256"

SANDBOX_DIR="${SCRIPT_DIR}/sandbox_data"
SANDBOX_TARGET="${SANDBOX_DIR}/tampered_system"
SANDBOX_BASELINE="${SANDBOX_DIR}/authoritative_baseline.sha256"

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

# Default parameters
MODE="verify"
CUSTOM_BASELINE=""
TARGET_DIR=""
USE_SANDBOX=0
OUTPUT_JSON=0

# Default critical files for live system baseline
DEFAULT_LIVE_FILES=(
    "/etc/passwd"
    "/etc/group"
    "/etc/hosts"
    "/etc/issue"
    "/etc/os-release"
    "/etc/fstab"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verify)
            MODE="verify"
            shift
            ;;
        -i|--init|--generate)
            MODE="init"
            shift
            ;;
        -b|--baseline)
            CUSTOM_BASELINE="${2:-}"
            shift 2
            ;;
        -d|--dir)
            TARGET_DIR="${2:-}"
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
            echo -e "${CLR_BOLD}Linux System Administration — File Integrity Check Engine${CLR_RESET}"
            echo -e "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verify          Verify integrity against baseline (default)"
            echo "  -i, --init            Generate or update baseline checksum manifest"
            echo "  -b, --baseline <file> Custom baseline manifest file path"
            echo "  -d, --dir <path>      Target directory to audit"
            echo "  -s, --sandbox         Audit simulated tampered scenario in sandbox"
            echo "  -j, --json            Emit machine-readable JSON telemetry"
            echo "  -h, --help            Show this help menu"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

# If sandbox mode selected
if [ "${USE_SANDBOX}" -eq 1 ]; then
    TARGET_DIR="${SANDBOX_TARGET}"
    CUSTOM_BASELINE="${SANDBOX_BASELINE}"
fi

# Determine baseline path
if [ -n "${CUSTOM_BASELINE}" ]; then
    BASELINE_FILE="${CUSTOM_BASELINE}"
elif [ -n "${TARGET_DIR}" ]; then
    BASELINE_FILE="${TARGET_DIR}/baseline.sha256"
else
    BASELINE_FILE="${DEFAULT_BASELINE}"
fi

# Ensure live baseline exists if in live mode and baseline doesn't exist yet
if [ "${USE_SANDBOX}" -eq 0 ] && [ ! -f "${BASELINE_FILE}" ] && [ "${MODE}" = "verify" ]; then
    echo -e "${CLR_YELLOW}[INFO] Baseline manifest not found. Initializing live system baseline...${CLR_RESET}"
    MODE="init"
fi

# Handle INIT mode (Generate baseline)
if [ "${MODE}" = "init" ]; then
    echo -e "${CLR_CYAN}[INFO] Generating cryptographic SHA-256 baseline manifest...${CLR_RESET}"
    TMP_BASE="$(mktemp)"
    if [ -n "${TARGET_DIR}" ] && [ -d "${TARGET_DIR}" ]; then
        (
            cd "${TARGET_DIR}"
            find . -maxdepth 2 -type f ! -name "*.sha256" -exec sha256sum {} + | sort > "${TMP_BASE}"
        )
    else
        for f in "${DEFAULT_LIVE_FILES[@]}"; do
            if [ -f "$f" ]; then
                sha256sum "$f" >> "${TMP_BASE}"
            fi
        done
    fi
    mv "${TMP_BASE}" "${BASELINE_FILE}"
    echo -e "${CLR_GREEN}[SUCCESS] Baseline generated with $(wc -l < "${BASELINE_FILE}") files: ${BASELINE_FILE}${CLR_RESET}"
    if [ "${OUTPUT_JSON}" -eq 0 ]; then
        exit 0
    fi
fi

# Verification Engine (Python)
CHECKER_OUTPUT=$(python3 - <<PYEOF
import os
import sys
import json
import hashlib
from datetime import datetime

baseline_file = r"${BASELINE_FILE}"
target_dir = r"${TARGET_DIR}".strip()
use_sandbox = bool(${USE_SANDBOX})

def sha256_file(filepath):
    h = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None

baseline_entries = {}
if os.path.exists(baseline_file):
    with open(baseline_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            if len(parts) == 2:
                expected_hash = parts[0]
                filepath = parts[1].lstrip("*")
                baseline_entries[filepath] = expected_hash

results = []
intact_count = 0
tampered_count = 0
missing_count = 0
untracked_count = 0

checked_paths = set()

# Check each entry from baseline
for rel_path, exp_hash in baseline_entries.items():
    if target_dir:
        abs_path = os.path.normpath(os.path.join(target_dir, rel_path))
        display_path = rel_path
    else:
        abs_path = rel_path
        display_path = rel_path

    checked_paths.add(os.path.normpath(abs_path))

    if not os.path.exists(abs_path):
        missing_count += 1
        results.append({
            "path": display_path,
            "status": "MISSING",
            "expected_hash": exp_hash,
            "actual_hash": "FILE_NOT_FOUND",
            "size_bytes": 0,
            "detail": "Critical file was deleted or cannot be accessed."
        })
    else:
        actual_hash = sha256_file(abs_path)
        sz = os.path.getsize(abs_path)
        if actual_hash == exp_hash:
            intact_count += 1
            results.append({
                "path": display_path,
                "status": "UNCHANGED",
                "expected_hash": exp_hash,
                "actual_hash": actual_hash,
                "size_bytes": sz,
                "detail": "Cryptographic digest matches baseline perfectly."
            })
        else:
            tampered_count += 1
            results.append({
                "path": display_path,
                "status": "TAMPERED",
                "expected_hash": exp_hash,
                "actual_hash": actual_hash or "READ_ERROR",
                "size_bytes": sz,
                "detail": "Checksum mismatch detected! Content was modified."
            })

# If target directory provided, check for untracked / new files
if target_dir and os.path.exists(target_dir):
    for root, dirs, files in os.walk(target_dir):
        dirs[:] = [d for d in dirs if d not in (".git", "__pycache__")]
        for fname in files:
            if fname.endswith(".sha256"):
                continue
            fpath = os.path.normpath(os.path.join(root, fname))
            if fpath not in checked_paths:
                untracked_count += 1
                rel_fpath = os.path.relpath(fpath, target_dir)
                curr_hash = sha256_file(fpath)
                sz = os.path.getsize(fpath)
                results.append({
                    "path": rel_fpath,
                    "status": "UNTRACKED",
                    "expected_hash": "NOT_IN_BASELINE",
                    "actual_hash": curr_hash or "READ_ERROR",
                    "size_bytes": sz,
                    "detail": "New file present in directory but absent from baseline."
                })

total_baseline_files = len(baseline_entries)
violations_total = tampered_count + missing_count + untracked_count
verdict = "PASSED (100% Intact)" if violations_total == 0 else f"COMPROMISED ({violations_total} Violations Detected)"
score = round((intact_count / total_baseline_files * 100.0), 1) if total_baseline_files > 0 else 0.0

telemetry = {
    "metadata": {
        "baseline_manifest": baseline_file,
        "target_directory": target_dir or "System Critical Files",
        "mode": "Sandbox Simulation" if use_sandbox else "Live System Audit",
        "algorithm": "SHA-256",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    },
    "summary": {
        "total_baseline_files": total_baseline_files,
        "intact_files_count": intact_count,
        "tampered_files_count": tampered_count,
        "missing_files_count": missing_count,
        "untracked_files_count": untracked_count,
        "total_violations": violations_total,
        "integrity_score_pct": score,
        "verdict": verdict
    },
    "file_results": results
}

print(json.dumps(telemetry, indent=2))
PYEOF
)

# Save JSON telemetry
echo "${CHECKER_OUTPUT}" > "${JSON_FILE}"

if [ "${OUTPUT_JSON}" -eq 1 ]; then
    echo "${CHECKER_OUTPUT}"
    exit 0
fi

# Print formatted ANSI terminal report
python3 - <<PYEOF
import json
import sys

raw_json = r"""${CHECKER_OUTPUT}"""
try:
    data = json.loads(raw_json)
except Exception as e:
    print(f"Error parsing telemetry: {e}")
    sys.exit(1)

meta = data.get("metadata", {})
summary = data.get("summary", {})
files = data.get("file_results", [])

CLR_BOLD = "\033[1m"
CLR_GREEN = "\033[32m"
CLR_CYAN = "\033[36m"
CLR_YELLOW = "\033[33m"
CLR_RED = "\033[31m"
CLR_MAGENTA = "\033[35m"
CLR_RESET = "\033[0m"

print("================================================================================")
print(f" {CLR_BOLD}FILE INTEGRITY CHECKER — LINUX SYSTEM ADMINISTRATION (AS_34){CLR_RESET}")
print("================================================================================")
print(f" Target:   {meta.get('target_directory', '-')} | Mode: {meta.get('mode', '-')}")
print(f" Baseline: {meta.get('baseline_manifest', '-')} | Algorithm: {meta.get('algorithm', 'SHA-256')}")
print("--------------------------------------------------------------------------------")
verdict_str = summary.get("verdict", "")
verdict_color = CLR_GREEN if "PASSED" in verdict_str else CLR_RED
print(f" {CLR_BOLD}INTEGRITY VERDICT: {verdict_color}{verdict_str}{CLR_RESET}")
print(f"  • Baseline Items:   {summary.get('total_baseline_files', 0)} files")
print(f"  • Intact / Valid:   {CLR_GREEN}{summary.get('intact_files_count', 0)}{CLR_RESET} ({summary.get('integrity_score_pct', 0)}% integrity compliance)")
print(f"  • Tampered / Mod:   {CLR_RED}{summary.get('tampered_files_count', 0)}{CLR_RESET} files")
print(f"  • Missing / Del:    {CLR_YELLOW}{summary.get('missing_files_count', 0)}{CLR_RESET} files")
print(f"  • Untracked / New:  {CLR_MAGENTA}{summary.get('untracked_files_count', 0)}{CLR_RESET} files")
print("--------------------------------------------------------------------------------")
print(f" {CLR_BOLD}DETAILED INTEGRITY STATUS PER FILE:{CLR_RESET}")
print(f" {'STATUS':<12} | {'EXPECTED HASH (SHA-256)':<24} | {'ACTUAL HASH':<24} | {'FILE PATH'}")
print("-" * 96)

for f in files:
    st = f.get("status", "-")
    p = f.get("path", "-")
    exp = f.get("expected_hash", "-")[:22] + ".." if len(f.get("expected_hash", "-")) > 24 else f.get("expected_hash", "-")
    act = f.get("actual_hash", "-")[:22] + ".." if len(f.get("actual_hash", "-")) > 24 else f.get("actual_hash", "-")

    if st == "UNCHANGED":
        st_badge = f"{CLR_GREEN}[UNCHANGED] {CLR_RESET}"
    elif st == "TAMPERED":
        st_badge = f"{CLR_RED}[TAMPERED]  {CLR_RESET}"
    elif st == "MISSING":
        st_badge = f"{CLR_YELLOW}[MISSING]   {CLR_RESET}"
    else:
        st_badge = f"{CLR_MAGENTA}[UNTRACKED] {CLR_RESET}"

    print(f" {st_badge} | {exp:<24} | {act:<24} | {CLR_BOLD}{p}{CLR_RESET}")

print("================================================================================")
PYEOF

# Append execution log entry
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE INTEGRITY CHECK RUN"
    echo "Mode: $([ ${USE_SANDBOX} -eq 1 ] && echo 'Sandbox' || echo 'Live')"
    echo "Verdict: $(jq -r '.summary.verdict' "${JSON_FILE}" 2>/dev/null || echo 'Unknown')"
    echo "Violations: $(jq '.summary.total_violations' "${JSON_FILE}" 2>/dev/null || echo '0')"
    echo "------------------------------------------------------------"
} >> "${LOG_FILE}"

echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} Audit log saved to: ${LOG_FILE}"
echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} JSON telemetry saved to: ${JSON_FILE}"
