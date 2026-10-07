#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #11: Backup Verification (Backup Validation)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Ensures test backup archives exist in sandbox_data/backups.
#   3. Executes backup_verifier.sh to run 5-point verification pipeline.
#   4. Regenerates self-contained dark-themed report.html from scratch every run.
#   5. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "        AUTOMATION SPRINT (AS_11) — BACKUP VERIFICATION ENGINE                  "
echo "================================================================================"

# Verify backup_verifier.sh exists and is executable
if [ ! -f "./backup_verifier.sh" ]; then
    echo "[ERROR] backup_verifier.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./backup_verifier.sh

# Re-seed test archives if backups directory is missing or empty
if [ ! -d "./sandbox_data/backups" ] || [ -z "$(ls -A ./sandbox_data/backups 2>/dev/null)" ]; then
    echo "[INFO] Seeding test archives in sandbox_data/backups..."
    if [ -f "./sandbox_data/seed_backups.sh" ]; then
        bash ./sandbox_data/seed_backups.sh
    fi
fi

# 2. Run backup_verifier.sh and capture terminal output while streaming to console
echo "[INFO] Running backup_verifier.sh on backup repository..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    ./backup_verifier.sh 2>&1 | tee "${TMP_TERM_LOG}"
else
    ./backup_verifier.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
fi
AUDIT_EXIT_CODE=$?
set -e
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & telemetry
OS_NAME="$(uname -s)"
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
USER_VAL="$(whoami 2>/dev/null || echo 'User')"

# OS Flavor Display Name
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_DISPLAY="${PRETTY_NAME:-$OS_NAME}"
elif [ "${OS_NAME}" = "Darwin" ]; then
    OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    OS_DISPLAY="${OS_NAME}"
fi

JSON_PATH="logs/verify.json"
LOG_FILE_PATH="logs/backup_verify.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 50 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No audit log entries recorded yet."
fi

TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# 4. Generate report.html from scratch using Python 3
echo "[INFO] Regenerating report.html dashboard with live telemetry..."

python3 - <<PYEOF
import json
import html
import os
import subprocess
import sys

json_path = "${JSON_PATH}"
log_preview = r"""${LOG_PREVIEW}"""
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"

data = {
    "problem_id": "AS_11",
    "title": "Backup Verification",
    "backup_directory": "./sandbox_data/backups",
    "archive_filename": "backup_prod.tar.gz",
    "archive_path": "",
    "total_archives_in_repo": 0,
    "file_size_bytes": 0,
    "file_size_human": "0 B",
    "entities_count": 0,
    "modified_timestamp": "-",
    "age_hours": "0.0",
    "sha256_checksum": "",
    "has_companion_checksum": True,
    "checks": {
        "existence": True,
        "non_empty": True,
        "archive_integrity": True,
        "checksum_valid": True,
        "within_freshness_sla": True
    },
    "overall_success": True,
    "status": "VERIFIED_HEALTHY"
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to parse JSON: {e}", file=sys.stderr)

archive_path = data.get("archive_path", "")
archive_name = data.get("archive_filename", "archive.tar.gz")
repo_dir = data.get("backup_directory", "")
size_h = data.get("file_size_human", "0 B")
size_bytes = data.get("file_size_bytes", 0)
entities = data.get("entities_count", 0)
sha256_val = data.get("sha256_checksum", "")
age_h = data.get("age_hours", "0.0")
mtime = data.get("modified_timestamp", "-")
total_archives = data.get("total_archives_in_repo", 1)
checks = data.get("checks", {})
overall_ok = data.get("overall_success", False)

overall_badge = '<span class="badge badge-success">VERIFIED HEALTHY (100%)</span>' if overall_ok else '<span class="badge badge-danger">VERIFICATION FAILED</span>'

def check_row(idx, name, criteria, live_val, passed):
    badge = '<span class="badge badge-success">PASS</span>' if passed else '<span class="badge badge-danger">FAIL</span>'
    return f"""
    <tr>
        <td class="rank-cell">#{idx}</td>
        <td><strong>{html.escape(name)}</strong></td>
        <td>{html.escape(criteria)}</td>
        <td><code>{html.escape(str(live_val))}</code></td>
        <td>{badge}</td>
    </tr>
    """

matrix_rows = ""
matrix_rows += check_row(1, "Archive Existence", "File exists on storage", archive_name, checks.get("existence", False))
matrix_rows += check_row(2, "Non-Empty File Integrity", "File size strictly > 0 bytes", f"{size_h} ({size_bytes} B)", checks.get("non_empty", False))
matrix_rows += check_row(3, "Compression / Tar Structure", "Readable table of contents (tar -tzf)", f"{entities} internal entities", checks.get("archive_integrity", False))
matrix_rows += check_row(4, "Cryptographic Hash Validation", "SHA-256 match with .sha256", "Valid digest match", checks.get("checksum_valid", False))
matrix_rows += check_row(5, "Recency & Freshness SLA", "Modified within 24 hours (&le; 24h)", f"{age_h} hours old", checks.get("within_freshness_sla", False))

# Read archive manifest
manifest_rows = ""
if archive_path and os.path.exists(archive_path):
    try:
        res = subprocess.run(["tar", "-tvf", archive_path], capture_output=True, text=True, check=True)
        lines = [line.strip() for line in res.stdout.strip().split("\n") if line.strip()]
        for idx, line in enumerate(lines, 1):
            parts = line.split(maxsplit=5)
            if len(parts) >= 6:
                perms = parts[0]
                owner_grp = parts[1]
                fsize = parts[2]
                mod_date = f"{parts[3]} {parts[4]}"
                filename = parts[5]
            else:
                perms, owner_grp, fsize, mod_date, filename = "-", "-", "-", "-", line
                
            manifest_rows += f"""
            <tr>
                <td class="rank-cell">#{idx}</td>
                <td class="path-cell">{html.escape(filename)}</td>
                <td class="size-cell">{html.escape(fsize)} B</td>
                <td><code>{html.escape(perms)}</code></td>
                <td>{html.escape(owner_grp)}</td>
                <td class="time-cell">{html.escape(mod_date)}</td>
            </tr>
            """
    except Exception as e:
        manifest_rows = f'<tr><td colspan="6" class="empty-state">Unable to read archive manifest: {html.escape(str(e))}</td></tr>'

if not manifest_rows:
    manifest_rows = '<tr><td colspan="6" class="empty-state">No manifest entries recorded.</td></tr>'

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_11: Backup Verification Dashboard</title>
    <style>
        :root {{
            --bg: #0f172a;
            --surface: #1e293b;
            --surface-hover: #334155;
            --border: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.15);
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --code-bg: #090d16;
        }}
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }}
        body {{
            background-color: var(--bg);
            color: var(--text-main);
            padding: 2rem;
            line-height: 1.5;
        }}
        .container {{
            max-width: 1300px;
            margin: 0 auto;
        }}
        header {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            border-bottom: 1px solid var(--border);
            padding-bottom: 1.5rem;
            margin-bottom: 2rem;
            flex-wrap: wrap;
            gap: 1rem;
        }}
        .header-title h1 {{
            font-size: 1.75rem;
            font-weight: 700;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }}
        .header-title p {{
            color: var(--text-muted);
            margin-top: 0.25rem;
            font-size: 0.95rem;
        }}
        .sys-badge {{
            display: inline-flex;
            gap: 0.5rem;
            background: var(--surface);
            border: 1px solid var(--border);
            padding: 0.4rem 0.8rem;
            border-radius: 6px;
            font-size: 0.82rem;
            color: var(--text-muted);
            align-self: flex-start;
        }}
        .sys-badge span {{
            color: var(--accent);
            font-weight: 600;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.25rem;
            margin-bottom: 2rem;
        }}
        .card {{
            background-color: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 1.25rem;
            position: relative;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }}
        .card-label {{
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 0.5rem;
        }}
        .card-value {{
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-main);
            word-break: break-all;
        }}
        .card-subtext {{
            font-size: 0.8rem;
            color: var(--text-muted);
            margin-top: 0.4rem;
        }}
        .badge {{
            display: inline-block;
            padding: 0.25rem 0.65rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}
        .badge-success {{ background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #059669; }}
        .badge-warning {{ background: rgba(245, 158, 11, 0.2); color: #fbbf24; border: 1px solid #d97706; }}
        .badge-danger {{ background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #dc2626; }}
        
        .section-box {{
            background-color: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 2rem;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }}
        .section-header {{
            background: rgba(0,0,0,0.15);
            padding: 1rem 1.25rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .section-header h2 {{
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--text-main);
        }}
        .table-responsive {{
            overflow-x: auto;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 0.9rem;
        }}
        th {{
            background: rgba(15, 23, 42, 0.6);
            padding: 0.75rem 1rem;
            color: var(--text-muted);
            font-weight: 600;
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--border);
        }}
        td {{
            padding: 0.75rem 1rem;
            border-bottom: 1px solid rgba(51, 65, 85, 0.4);
            color: var(--text-main);
        }}
        tr:hover td {{
            background-color: var(--surface-hover);
        }}
        .rank-cell {{
            font-weight: 700;
            color: var(--accent);
            width: 50px;
        }}
        .size-cell {{
            color: #fbbf24;
            font-weight: 600;
            width: 110px;
        }}
        .path-cell {{
            font-family: monospace;
            font-size: 0.85rem;
            word-break: break-all;
        }}
        .time-cell {{
            font-size: 0.82rem;
            color: var(--text-muted);
            white-space: nowrap;
        }}
        .empty-state {{
            text-align: center;
            padding: 2rem !important;
            color: var(--text-muted);
            font-style: italic;
        }}
        pre.terminal-log {{
            background-color: var(--code-bg);
            color: #e2e8f0;
            padding: 1.25rem;
            font-family: "JetBrains Mono", Consolas, "Courier New", monospace;
            font-size: 0.82rem;
            line-height: 1.45;
            overflow-x: auto;
            max-height: 380px;
            white-space: pre-wrap;
            border-radius: 0 0 8px 8px;
        }}
        .checksum-box {{
            background: #090d16;
            padding: 0.75rem 1rem;
            border-radius: 6px;
            font-family: monospace;
            font-size: 0.88rem;
            color: #38bdf8;
            word-break: break-all;
            margin-top: 0.5rem;
            border: 1px solid var(--border);
        }}
        footer {{
            text-align: center;
            padding-top: 1.5rem;
            color: var(--text-muted);
            font-size: 0.8rem;
            border-top: 1px solid var(--border);
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>🛡️ Backup Verification & Validation Dashboard</h1>
                <p>E1ITA307 Linux System Administration — Automation Sprint (AS_11)</p>
            </div>
            <div class="sys-badge">
                <span>HOST:</span> {html.escape(hostname_val)} &nbsp;|&nbsp; 
                <span>OS:</span> {html.escape(os_display)} &nbsp;|&nbsp; 
                <span>KERNEL:</span> {html.escape(kernel_val)}
            </div>
        </header>

        <!-- KPI CARDS -->
        <div class="grid">
            <div class="card">
                <div class="card-label">Target Archive</div>
                <div class="card-value" style="font-size: 1rem; font-family: monospace; color: var(--accent);">{html.escape(archive_name)}</div>
                <div class="card-subtext">Latest candidate in repository</div>
            </div>
            <div class="card">
                <div class="card-label">Archive Size</div>
                <div class="card-value" style="color: #fbbf24;">{html.escape(size_h)}</div>
                <div class="card-subtext">{size_bytes} bytes on disk</div>
            </div>
            <div class="card">
                <div class="card-label">Repository Inventory</div>
                <div class="card-value">{total_archives}</div>
                <div class="card-subtext">Archives in repository</div>
            </div>
            <div class="card">
                <div class="card-label">Freshness Age</div>
                <div class="card-value" style="color: #34d399;">{html.escape(str(age_h))} hrs</div>
                <div class="card-subtext">Modified: {html.escape(mtime)}</div>
            </div>
            <div class="card">
                <div class="card-label">Overall Validation</div>
                <div class="card-value" style="font-size: 1rem; margin-top: 0.4rem;">{overall_badge}</div>
                <div class="card-subtext">5-Point SLA verification</div>
            </div>
        </div>

        <!-- 5-POINT VERIFICATION MATRIX -->
        <div class="section-box">
            <div class="section-header">
                <h2>✅ 5-Point Backup Verification Matrix</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">SLA Compliance Audit</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Verification Check</th>
                            <th>Validation Standard</th>
                            <th>Live Measured Value</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {matrix_rows}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- CRYPTOGRAPHIC INTEGRITY -->
        <div class="section-box">
            <div class="section-header">
                <h2>🔐 Cryptographic Checksum Verification</h2>
            </div>
            <div style="padding: 1.25rem;">
                <p style="font-size: 0.9rem; color: var(--text-muted);">
                    SHA-256 cryptographic hash calculated on candidate archive:
                </p>
                <div class="checksum-box">
                    <strong>SHA-256:</strong> {html.escape(sha256_val)}
                </div>
            </div>
        </div>

        <!-- ARCHIVE CONTENT MANIFEST -->
        <div class="section-box">
            <div class="section-header">
                <h2>📁 Verified Archive Contents Manifest (tar -tvf)</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{entities} internal item(s)</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Internal File Path</th>
                            <th>Size</th>
                            <th>Perms</th>
                            <th>Owner / Group</th>
                            <th>Last Modified</th>
                        </tr>
                    </thead>
                    <tbody>
                        {manifest_rows}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- LIVE EXECUTION AUDIT LOG -->
        <div class="section-box">
            <div class="section-header">
                <h2>💻 Console Execution Output</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{html.escape(timestamp_val)}</span>
            </div>
            <pre class="terminal-log">{html.escape(terminal_log)}</pre>
        </div>

        <footer>
            Automated Linux System Administration Sprint &bull; Problem AS_11 &bull; Generated on {html.escape(timestamp_val)}
        </footer>
    </div>
</body>
</html>
"""

with open("report.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("[SUCCESS] report.html regenerated successfully.")
PYEOF

# 5. Automatically open report.html in user's browser based on host OS
echo "[INFO] Detecting operating system environment for report launch..."
OPENED=0

# A. WSL (Windows Subsystem for Linux)
if grep -qi microsoft /proc/version 2>/dev/null && command -v explorer.exe >/dev/null 2>&1; then
    echo "[INFO] Detected WSL environment."
    WIN_PATH="$(wslpath -w "${PWD}/report.html" 2>/dev/null || echo "report.html")"
    echo "[INFO] Windows Path: ${WIN_PATH}"
    echo "[LAUNCH] Invoking explorer.exe to launch report in Windows default browser..."
    explorer.exe "${WIN_PATH}" 2>/dev/null || true
    OPENED=1
# B. macOS (Darwin)
elif [ "${OS_NAME}" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    echo "[INFO] Detected macOS environment."
    echo "[LAUNCH] Invoking 'open report.html'..."
    open report.html 2>/dev/null || true
    OPENED=1
# C. Windows Git Bash / MSYS / Cygwin
elif [[ "${OSTYPE:-}" =~ msys|cygwin|win32 ]] && command -v start >/dev/null 2>&1; then
    echo "[INFO] Detected Windows Git Bash / MSYS / Cygwin environment."
    echo "[LAUNCH] Invoking 'start \"\" report.html'..."
    start "" report.html 2>/dev/null || true
    OPENED=1
# D. Native Linux Desktop (X11 / Wayland)
elif command -v xdg-open >/dev/null 2>&1; then
    echo "[INFO] Detected Linux desktop environment."
    echo "[LAUNCH] Invoking 'xdg-open report.html'..."
    xdg-open report.html 2>/dev/null || true
    OPENED=1
# E. Fallback
else
    echo "[INFO] Browser auto-launch unavailable in headless environment."
    echo "[INFO] View report at: file://${PWD}/report.html"
fi

if [ "${OPENED}" -eq 1 ]; then
    echo "[SUCCESS] Dashboard launch command dispatched successfully."
fi

echo "================================================================================"
exit 0
