#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #32: File Modification Monitor (File Monitoring)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes file_modification_monitor.sh against live project repository.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_32) — FILE MODIFICATION MONITOR                       "
echo "================================================================================"

if [ ! -f "./file_modification_monitor.sh" ]; then
    echo "[ERROR] file_modification_monitor.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./file_modification_monitor.sh

# 2. Run file_modification_monitor.sh and stream to console while capturing
echo "[INFO] Running file_modification_monitor.sh on project directory (last 24 hours)..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default: Monitor current workspace repository for live 24h modifications
    ./file_modification_monitor.sh --dir ".." 2>&1 | tee "${TMP_TERM_LOG}"
    AUDIT_EXIT_CODE=$?
    # Also generate sandbox project repo dataset for dashboard presentation
    ./file_modification_monitor.sh --sandbox >/dev/null 2>&1 || true
    cp logs/modified_files.json logs/modified_files_sandbox.json
    # Re-run live to ensure primary JSON is the live system telemetry
    ./file_modification_monitor.sh --dir ".." >/dev/null 2>&1 || true
else
    ./file_modification_monitor.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    AUDIT_EXIT_CODE=$?
fi
set -e
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & telemetry
OS_NAME="$(uname -s)"
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_DISPLAY="${PRETTY_NAME:-$OS_NAME}"
elif [ "${OS_NAME}" = "Darwin" ]; then
    OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    OS_DISPLAY="${OS_NAME}"
fi

JSON_LIVE_PATH="logs/modified_files.json"
JSON_SANDBOX_PATH="logs/modified_files_sandbox.json"
LOG_FILE_PATH="logs/modified_files.log"

if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No modification monitor log entries recorded yet."
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

json_live_path = "${JSON_LIVE_PATH}"
json_sandbox_path = "${JSON_SANDBOX_PATH}"
log_preview = r"""${LOG_PREVIEW}"""
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"

live_data = {}
if os.path.exists(json_live_path):
    try:
        with open(json_live_path, "r", encoding="utf-8") as f:
            live_data = json.load(f)
    except Exception as e:
        live_data = {"error": str(e)}

sandbox_data = {}
if os.path.exists(json_sandbox_path):
    try:
        with open(json_sandbox_path, "r", encoding="utf-8") as f:
            sandbox_data = json.load(f)
    except Exception as e:
        sandbox_data = {}

live_meta = live_data.get("scan_metadata", {})
live_summary = live_data.get("summary", {})
live_files = live_data.get("modified_files", [])

sandbox_meta = sandbox_data.get("scan_metadata", {})
sandbox_summary = sandbox_data.get("summary", {})
sandbox_files = sandbox_data.get("modified_files", [])

total_scanned = live_summary.get("total_files_scanned", 0)
modified_count = live_summary.get("modified_files_count", 0)
older_count = live_summary.get("older_files_count", 0)
mod_pct = live_summary.get("modification_percentage", 0)
cum_size = live_summary.get("total_modified_human", "0 B")
most_recent = live_summary.get("most_recent_file", "None")
brackets = live_summary.get("time_brackets", {})

def render_file_rows(file_list, max_rows=30):
    if not file_list:
        return "<tr><td colspan='6' class='center text-muted'>No files modified within this window.</td></tr>"
    rows = ""
    for f in file_list[:max_rows]:
        ts = html.escape(str(f.get("mtime_formatted", "-")))
        age = html.escape(str(f.get("age_string", "-")))
        sz = html.escape(str(f.get("size_human", "-")))
        owner = html.escape(str(f.get("owner", "-")))
        perm = html.escape(str(f.get("permissions", "-")))
        rel = html.escape(str(f.get("relative_path", "-")))

        if "m ago" in age:
            age_badge = f'<span class="badge badge-green">{age}</span>'
        elif float(f.get("age_hours", 24)) <= 6:
            age_badge = f'<span class="badge badge-cyan">{age}</span>'
        else:
            age_badge = f'<span class="badge badge-warning">{age}</span>'

        rows += f"""
        <tr>
            <td class="font-mono text-muted">{ts}</td>
            <td class="center">{age_badge}</td>
            <td class="font-mono text-cyan"><strong>{sz}</strong></td>
            <td class="font-mono">{owner}</td>
            <td class="font-mono text-muted">{perm}</td>
            <td class="font-mono text-amber"><code>{rel}</code></td>
        </tr>
        """
    if len(file_list) > max_rows:
        rows += f"""<tr><td colspan='6' class='center text-muted' style='padding: 10px;'>... and {len(file_list) - max_rows} additional modified files.</td></tr>"""
    return rows

live_table_html = render_file_rows(live_files)
sandbox_table_html = render_file_rows(sandbox_files)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_32: File Modification Monitor Dashboard</title>
    <style>
        :root {{
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-card: #1e293b;
            --border-color: #334155;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent-cyan: #38bdf8;
            --accent-green: #10b981;
            --accent-yellow: #f59e0b;
            --accent-red: #ef4444;
            --accent-purple: #a855f7;
        }}
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.5;
            padding: 24px;
        }}
        .container {{
            max-width: 1280px;
            margin: 0 auto;
        }}
        header {{
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }}
        .header-title h1 {{
            font-size: 1.75rem;
            font-weight: 700;
            color: #fff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        .header-title p {{
            color: var(--text-secondary);
            font-size: 0.9rem;
            margin-top: 4px;
        }}
        .header-badges {{
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }}
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }}
        .badge-cyan {{ background: rgba(56, 189, 248, 0.2); color: var(--accent-cyan); border: 1px solid rgba(56, 189, 248, 0.3); }}
        .badge-green {{ background: rgba(16, 185, 129, 0.2); color: var(--accent-green); border: 1px solid rgba(16, 185, 129, 0.3); }}
        .badge-warning {{ background: rgba(245, 158, 11, 0.2); color: var(--accent-yellow); border: 1px solid rgba(245, 158, 11, 0.3); }}
        .badge-purple {{ background: rgba(168, 85, 247, 0.2); color: var(--accent-purple); border: 1px solid rgba(168, 85, 247, 0.3); }}
        .badge-muted {{ background: rgba(148, 163, 184, 0.15); color: var(--text-secondary); border: 1px solid rgba(148, 163, 184, 0.25); }}

        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .kpi-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }}
        .kpi-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
        }}
        .kpi-blue::before {{ background: var(--accent-cyan); }}
        .kpi-green::before {{ background: var(--accent-green); }}
        .kpi-yellow::before {{ background: var(--accent-yellow); }}
        .kpi-purple::before {{ background: var(--accent-purple); }}

        .kpi-title {{
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 8px;
        }}
        .kpi-value {{
            font-size: 1.85rem;
            font-weight: 700;
            color: #fff;
        }}
        .kpi-sub {{
            font-size: 0.75rem;
            color: var(--text-secondary);
            margin-top: 4px;
        }}

        .card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            margin-bottom: 24px;
            overflow: hidden;
        }}
        .card-header {{
            padding: 16px 20px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .card-header h2 {{
            font-size: 1.1rem;
            font-weight: 600;
            color: #fff;
        }}
        .table-responsive {{
            overflow-x: auto;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            text-align: left;
        }}
        th {{
            background: #182234;
            padding: 12px 16px;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border-color);
        }}
        td {{
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.85rem;
        }}
        tr:last-child td {{
            border-bottom: none;
        }}
        tr:hover td {{
            background: rgba(255, 255, 255, 0.02);
        }}
        .font-mono {{
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        }}
        .text-cyan {{ color: var(--accent-cyan); }}
        .text-green {{ color: var(--accent-green); }}
        .text-amber {{ color: var(--accent-yellow); }}
        .text-muted {{ color: var(--text-secondary); }}
        .center {{ text-align: center; }}

        pre.terminal-log {{
            background: #090d16;
            color: #a5b4fc;
            padding: 16px;
            border-radius: 8px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.8rem;
            overflow-x: auto;
            max-height: 280px;
            white-space: pre-wrap;
            border: 1px solid #1e293b;
        }}
        footer {{
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.8rem;
            margin-top: 32px;
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>⏱️ File Modification Monitor Dashboard</h1>
                <p>Linux System Administration (E1ITA307) — Automation Sprint Problem #32</p>
            </div>
            <div class="header-badges">
                <span class="badge badge-cyan">{os_display}</span>
                <span class="badge badge-green">Host: {hostname_val}</span>
                <span class="badge badge-purple">{timestamp_val}</span>
            </div>
        </header>

        <div class="kpi-grid">
            <div class="kpi-card kpi-blue">
                <div class="kpi-title">Files Scanned</div>
                <div class="kpi-value">{total_scanned}</div>
                <div class="kpi-sub">Total project items checked</div>
            </div>
            <div class="kpi-card kpi-green">
                <div class="kpi-title">Modified (&lt;24 Hours)</div>
                <div class="kpi-value">{modified_count}</div>
                <div class="kpi-sub">{mod_pct}% of total repository</div>
            </div>
            <div class="kpi-card kpi-yellow">
                <div class="kpi-title">Cumulative Mod Size</div>
                <div class="kpi-value">{cum_size}</div>
                <div class="kpi-sub">Size of recent file delta</div>
            </div>
            <div class="kpi-card kpi-purple">
                <div class="kpi-title">Time Window Breakdown</div>
                <div class="kpi-value">&lt;1h: {brackets.get('under_1h',0)}</div>
                <div class="kpi-sub">1-6h: {brackets.get('1h_to_6h',0)} | 6-12h: {brackets.get('6h_to_12h',0)} | 12-24h: {brackets.get('12h_to_24h',0)}</div>
            </div>
            <div class="kpi-card kpi-blue">
                <div class="kpi-title">Unchanged / Older</div>
                <div class="kpi-value">{older_count}</div>
                <div class="kpi-sub">Files older than 24 hours</div>
            </div>
            <div class="kpi-card kpi-green">
                <div class="kpi-title">Latest Changed File</div>
                <div class="kpi-value" style="font-size: 1rem; word-break: break-all;">{html.escape(most_recent[:32])}</div>
                <div class="kpi-sub">Most fresh project asset</div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>📁 Live Project Repository — Files Modified Within Last 24 Hours</h2>
                <span class="badge badge-cyan">Live Target: {html.escape(live_meta.get("target_directory", "-")[-45:])}</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Modified Timestamp</th>
                            <th class="center">Elapsed Age</th>
                            <th>Size</th>
                            <th>Owner</th>
                            <th>Perm</th>
                            <th>Relative Path</th>
                        </tr>
                    </thead>
                    <tbody>
                        {live_table_html}
                    </tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>🧪 Sandbox Project Simulation Drill (Known 24h &gt;24h Dataset)</h2>
                <span class="badge badge-warning">Simulated Project Data</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Modified Timestamp</th>
                            <th class="center">Elapsed Age</th>
                            <th>Size</th>
                            <th>Owner</th>
                            <th>Perm</th>
                            <th>Relative Path</th>
                        </tr>
                    </thead>
                    <tbody>
                        {sandbox_table_html}
                    </tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>🖥️ Live Console Execution Log</h2>
                <span class="badge badge-green">Execution Output</span>
            </div>
            <div style="padding: 16px;">
                <pre class="terminal-log">{html.escape(terminal_log)}</pre>
            </div>
        </div>

        <footer>
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_32 &bull; Generated dynamically by <code>run.sh</code>
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
