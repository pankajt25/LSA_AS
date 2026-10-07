#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #08: Large File Detection (Storage Management)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes large_file_detector.sh to detect files exceeding size threshold.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "         AUTOMATION SPRINT (AS_08) — LARGE FILE DETECTION ENGINE                "
echo "================================================================================"

# Verify large_file_detector.sh exists and is executable
if [ ! -f "./large_file_detector.sh" ]; then
    echo "[ERROR] large_file_detector.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./large_file_detector.sh

# 2. Run large_file_detector.sh and capture terminal output while streaming to console
echo "[INFO] Running large_file_detector.sh on live filesystem..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default live execution: scan /var/log for files > 1M
    ./large_file_detector.sh /var/log 1M 2>&1 | tee "${TMP_TERM_LOG}"
else
    ./large_file_detector.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
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

JSON_PATH="logs/large_files.json"
LOG_FILE_PATH="logs/large_files.log"
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
    "problem_id": "AS_08",
    "title": "Large File Detection",
    "target_directory": "/var/log",
    "size_threshold": "1M",
    "total_matching_files": 0,
    "cumulative_bytes": 0,
    "cumulative_human": "0 B",
    "status": "CLEAN",
    "files": []
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to parse JSON: {e}", file=sys.stderr)

target_dir = data.get("target_directory", "/var/log")
size_threshold = data.get("size_threshold", "1M")
total_files = data.get("total_matching_files", 0)
cumulative_human = data.get("cumulative_human", "0 B")
status = data.get("status", "CLEAN")
files_list = data.get("files", [])

status_badge = '<span class="badge badge-success">CLEAN / NORMAL</span>'
status_desc = 'No files exceeded the size threshold.'
if total_files > 0:
    status_badge = '<span class="badge badge-warning">FILES DETECTED</span>'
    status_desc = f'{total_files} file(s) consume significant disk capacity.'

# Build Table Rows
rows_html = ""
if not files_list:
    rows_html = '<tr><td colspan="7" class="empty-state">No files exceeded the threshold in the scanned directory.</td></tr>'
else:
    for f in files_list:
        rank = f.get("rank", 0)
        size_h = html.escape(str(f.get("size_human", "0 B")))
        perms = html.escape(str(f.get("permissions", "-")))
        owner = html.escape(str(f.get("owner", "-")))
        group = html.escape(str(f.get("group", "-")))
        mod = html.escape(str(f.get("modified", "-")))
        fpath = html.escape(str(f.get("path", "-")))
        
        rows_html += f"""
        <tr>
            <td class="rank-cell">#{rank}</td>
            <td class="size-cell"><strong>{size_h}</strong></td>
            <td><code>{perms}</code></td>
            <td>{owner}:{group}</td>
            <td class="time-cell">{mod}</td>
            <td class="path-cell" title="{fpath}">{fpath}</td>
        </tr>
        """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_08: Large File Detection Dashboard</title>
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
            font-size: 1.65rem;
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
            width: 60px;
        }}
        .size-cell {{
            color: #fbbf24;
            font-weight: 600;
            width: 120px;
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
        .remediation-box {{
            padding: 1.25rem;
            background: rgba(56, 189, 248, 0.05);
            border-left: 4px solid var(--accent);
            font-size: 0.88rem;
            line-height: 1.6;
        }}
        .remediation-box code {{
            background: #090d16;
            padding: 0.15rem 0.4rem;
            border-radius: 4px;
            color: var(--accent);
            font-family: monospace;
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
                <h1>🔍 Large File Detection Dashboard</h1>
                <p>E1ITA307 Linux System Administration — Automation Sprint (AS_08)</p>
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
                <div class="card-label">Target Directory</div>
                <div class="card-value" style="font-size: 1.15rem; font-family: monospace;">{html.escape(target_dir)}</div>
                <div class="card-subtext">Recursive subtree scanned</div>
            </div>
            <div class="card">
                <div class="card-label">Size Threshold</div>
                <div class="card-value" style="color: var(--accent);">&gt; {html.escape(size_threshold)}</div>
                <div class="card-subtext">Filter cutoff limit</div>
            </div>
            <div class="card">
                <div class="card-label">Matching Files</div>
                <div class="card-value">{total_files}</div>
                <div class="card-subtext">{status_desc}</div>
            </div>
            <div class="card">
                <div class="card-label">Cumulative Storage</div>
                <div class="card-value" style="color: #fbbf24;">{html.escape(cumulative_human)}</div>
                <div class="card-subtext">Total consumption of flagged items</div>
            </div>
            <div class="card">
                <div class="card-label">Storage Health Status</div>
                <div class="card-value" style="font-size: 1rem; margin-top: 0.4rem;">{status_badge}</div>
                <div class="card-subtext">Storage triage policy</div>
            </div>
        </div>

        <!-- LARGE FILES INVENTORY TABLE -->
        <div class="section-box">
            <div class="section-header">
                <h2>📁 Detected Large Files Inventory (Sorted by Size Descending)</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{total_files} file(s) displayed</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Rank</th>
                            <th>Size</th>
                            <th>Perms</th>
                            <th>Owner:Group</th>
                            <th>Last Modified</th>
                            <th>File Location / Path</th>
                        </tr>
                    </thead>
                    <tbody>
                        {rows_html}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- REMEDIATION & BEST PRACTICES -->
        <div class="section-box">
            <div class="section-header">
                <h2>🛠️ Storage Remediation & Triage Recommendations</h2>
            </div>
            <div class="remediation-box">
                <p><strong>Recommended Actions for Discovered Large Files:</strong></p>
                <ul style="margin-left: 1.5rem; margin-top: 0.5rem;">
                    <li><strong>Journal Logs:</strong> If <code>/var/log/journal</code> files are accumulating, vacuum old journal archives: <code>sudo journalctl --vacuum-size=200M</code> or <code>sudo journalctl --vacuum-time=7d</code>.</li>
                    <li><strong>Log Rotation:</strong> Ensure <code>logrotate</code> is configured with compression enabled (<code>compress</code> and <code>rotate 4</code> in <code>/etc/logrotate.conf</code>).</li>
                    <li><strong>Core Dumps & Temporary Files:</strong> Clean stale core dumps using <code>coredumpctl</code> or delete orphaned crash traces.</li>
                    <li><strong>Database Exports & Archives:</strong> Move SQL dumps or raw backups to external secondary storage or cold object storage (S3/Glacier).</li>
                </ul>
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
            Automated Linux System Administration Sprint &bull; Problem AS_08 &bull; Generated on {html.escape(timestamp_val)}
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
