#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #34: File Integrity Check (File Integrity)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes file_integrity_checker.sh against live system files.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_34) — FILE INTEGRITY MONITORING ENGINE                "
echo "================================================================================"

if [ ! -f "./file_integrity_checker.sh" ]; then
    echo "[ERROR] file_integrity_checker.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./file_integrity_checker.sh

# 2. Run file_integrity_checker.sh and stream to console while capturing
echo "[INFO] Running file_integrity_checker.sh on system critical files..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default: Verify live system critical files
    ./file_integrity_checker.sh 2>&1 | tee "${TMP_TERM_LOG}"
    AUDIT_EXIT_CODE=$?
    # Also generate sandbox security tampering drill dataset for dashboard presentation
    ./file_integrity_checker.sh --sandbox >/dev/null 2>&1 || true
    cp logs/integrity_check.json logs/integrity_check_sandbox.json
    # Re-run live to ensure primary JSON is the live system telemetry
    ./file_integrity_checker.sh >/dev/null 2>&1 || true
else
    ./file_integrity_checker.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
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

JSON_LIVE_PATH="logs/integrity_check.json"
JSON_SANDBOX_PATH="logs/integrity_check_sandbox.json"
LOG_FILE_PATH="logs/integrity_check.log"

if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No integrity audit log entries recorded yet."
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

live_meta = live_data.get("metadata", {})
live_summary = live_data.get("summary", {})
live_files = live_data.get("file_results", [])

sandbox_meta = sandbox_data.get("metadata", {})
sandbox_summary = sandbox_data.get("summary", {})
sandbox_files = sandbox_data.get("file_results", [])

total_baseline = live_summary.get("total_baseline_files", 0)
intact_count = live_summary.get("intact_files_count", 0)
tampered_count = live_summary.get("tampered_files_count", 0)
missing_count = live_summary.get("missing_files_count", 0)
untracked_count = live_summary.get("untracked_files_count", 0)
verdict_str = live_summary.get("verdict", "UNKNOWN")
score_pct = live_summary.get("integrity_score_pct", 100.0)

def render_table_rows(files_list):
    if not files_list:
        return "<tr><td colspan='5' class='center text-muted'>No integrity records available.</td></tr>"
    rows = ""
    for f in files_list:
        st = html.escape(str(f.get("status", "-")))
        p = html.escape(str(f.get("path", "-")))
        exp = html.escape(str(f.get("expected_hash", "-")))
        act = html.escape(str(f.get("actual_hash", "-")))
        det = html.escape(str(f.get("detail", "-")))

        if st == "UNCHANGED":
            badge_html = '<span class="badge badge-green">UNCHANGED</span>'
        elif st == "TAMPERED":
            badge_html = '<span class="badge badge-danger">TAMPERED</span>'
        elif st == "MISSING":
            badge_html = '<span class="badge badge-yellow">MISSING</span>'
        else:
            badge_html = '<span class="badge badge-purple">UNTRACKED</span>'

        exp_disp = f"{exp[:16]}..." if len(exp) > 16 else exp
        act_disp = f"{act[:16]}..." if len(act) > 16 else act

        rows += f"""
        <tr>
            <td class="center">{badge_html}</td>
            <td class="font-mono text-cyan"><strong>{p}</strong></td>
            <td class="font-mono text-muted" title="{exp}">{exp_disp}</td>
            <td class="font-mono text-amber" title="{act}">{act_disp}</td>
            <td style="font-size: 0.8rem; color: var(--text-secondary);">{det}</td>
        </tr>
        """
    return rows

live_table_html = render_table_rows(live_files)
sandbox_table_html = render_table_rows(sandbox_files)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_34: File Integrity Check Dashboard</title>
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
        .badge-yellow {{ background: rgba(245, 158, 11, 0.2); color: var(--accent-yellow); border: 1px solid rgba(245, 158, 11, 0.3); }}
        .badge-danger {{ background: rgba(239, 68, 68, 0.2); color: var(--accent-red); border: 1px solid rgba(239, 68, 68, 0.3); }}
        .badge-purple {{ background: rgba(168, 85, 247, 0.2); color: var(--accent-purple); border: 1px solid rgba(168, 85, 247, 0.3); }}

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
        .kpi-red::before {{ background: var(--accent-red); }}

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
                <h1>🔒 File Integrity Check Dashboard</h1>
                <p>Linux System Administration (E1ITA307) — Automation Sprint Problem #34</p>
            </div>
            <div class="header-badges">
                <span class="badge badge-cyan">{os_display}</span>
                <span class="badge badge-green">Host: {hostname_val}</span>
                <span class="badge badge-purple">{timestamp_val}</span>
            </div>
        </header>

        <div class="kpi-grid">
            <div class="kpi-card kpi-blue">
                <div class="kpi-title">Baseline Tracked Files</div>
                <div class="kpi-value">{total_baseline}</div>
                <div class="kpi-sub">Cryptographic SHA-256 targets</div>
            </div>
            <div class="kpi-card kpi-green">
                <div class="kpi-title">Integrity Compliance</div>
                <div class="kpi-value">{score_pct}%</div>
                <div class="kpi-sub">{intact_count} / {total_baseline} files intact</div>
            </div>
            <div class="kpi-card kpi-red">
                <div class="kpi-title">Tampered / Modified</div>
                <div class="kpi-value">{tampered_count}</div>
                <div class="kpi-sub">Hash mismatch alerts</div>
            </div>
            <div class="kpi-card kpi-yellow">
                <div class="kpi-title">Missing / Deleted</div>
                <div class="kpi-value">{missing_count}</div>
                <div class="kpi-sub">Critical file removals</div>
            </div>
            <div class="kpi-card kpi-purple">
                <div class="kpi-title">Untracked / Injected</div>
                <div class="kpi-value">{untracked_count}</div>
                <div class="kpi-sub">Rogue unmonitored files</div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>🛡️ Live Host System Critical Files — Integrity Verification</h2>
                <span class="badge badge-green">Verdict: {html.escape(verdict_str)}</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th class="center">Integrity Status</th>
                            <th>Protected File Path</th>
                            <th>Baseline SHA-256</th>
                            <th>Current SHA-256</th>
                            <th>Verification Detail</th>
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
                <h2>🧪 Sandbox Security Tampering Simulation Drill (4-State FIM Lifecycle)</h2>
                <span class="badge badge-danger">Simulated Tampering Incident</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th class="center">Integrity Status</th>
                            <th>Protected File Path</th>
                            <th>Baseline SHA-256</th>
                            <th>Current SHA-256</th>
                            <th>Verification Detail</th>
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
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_34 &bull; Generated dynamically by <code>run.sh</code>
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
