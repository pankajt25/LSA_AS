#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #30: Logged-in User Report (User Monitoring)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes logged_in_users.sh against live system sessions and sandbox simulation.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_30) — LOGGED-IN USERS MONITORING ENGINE               "
echo "================================================================================"

if [ ! -f "./logged_in_users.sh" ]; then
    echo "[ERROR] logged_in_users.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./logged_in_users.sh

# 2. Run logged_in_users.sh and stream to console while capturing
echo "[INFO] Running logged_in_users.sh on system sessions..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default: Run against live host system
    ./logged_in_users.sh 2>&1 | tee "${TMP_TERM_LOG}"
    AUDIT_EXIT_CODE=$?
    # Also generate sandbox multi-user dataset copy for dashboard presentation
    ./logged_in_users.sh --sandbox >/dev/null 2>&1 || true
    cp logs/user_sessions.json logs/user_sessions_sandbox.json
    # Re-run live to ensure primary JSON is the live system telemetry
    ./logged_in_users.sh >/dev/null 2>&1 || true
else
    ./logged_in_users.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    AUDIT_EXIT_CODE=$?
fi
set -e
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & telemetry
OS_NAME="$(uname -s)"
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
USER_VAL="$(whoami 2>/dev/null || echo 'User')"

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_DISPLAY="${PRETTY_NAME:-$OS_NAME}"
elif [ "${OS_NAME}" = "Darwin" ]; then
    OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    OS_DISPLAY="${OS_NAME}"
fi

JSON_LIVE_PATH="logs/user_sessions.json"
JSON_SANDBOX_PATH="logs/user_sessions_sandbox.json"
LOG_FILE_PATH="logs/user_sessions.log"

if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No session audit log entries recorded yet."
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

total_sessions = live_data.get("total_sessions", 0)
unique_users = live_data.get("unique_users_count", 0)
remote_sessions = live_data.get("remote_sessions", 0)
local_sessions = live_data.get("local_sessions", 0)
live_sessions = live_data.get("sessions", [])

def render_session_rows(sessions_list):
    if not sessions_list:
        return "<tr><td colspan='7' class='center text-muted'>No active user sessions recorded.</td></tr>"
    rows = ""
    for s in sessions_list:
        u = html.escape(str(s.get("user", "")))
        tty = html.escape(str(s.get("tty", "")))
        remote = html.escape(str(s.get("remote_host", "-")))
        stype = html.escape(str(s.get("session_type", "Local")))
        login = html.escape(str(s.get("login_time", "")))
        idle = html.escape(str(s.get("idle", "")))
        idle_desc = html.escape(str(s.get("idle_description", "")))
        what = html.escape(str(s.get("what", "")))

        user_badge = '<span class="badge badge-danger">ROOT</span>' if u == "root" else ''
        type_badge = '<span class="badge badge-warning">REMOTE</span>' if "Remote" in stype else '<span class="badge badge-green">LOCAL</span>'
        
        idle_color = "text-green" if "Active" in idle_desc else ("text-amber" if "m" in idle else "text-muted")

        rows += f"""
        <tr>
            <td class="font-mono text-cyan"><strong>{u}</strong> {user_badge}</td>
            <td class="font-mono text-muted">{tty}</td>
            <td class="font-mono text-amber"><strong>{remote}</strong></td>
            <td class="center">{type_badge}</td>
            <td class="font-mono">{login}</td>
            <td class="font-mono {idle_color}">{idle} ({idle_desc})</td>
            <td class="font-mono"><code class="code-pill">{what}</code></td>
        </tr>
        """
    return rows

live_rows = render_session_rows(live_sessions)
sandbox_sessions = sandbox_data.get("sessions", [])
sandbox_rows = render_session_rows(sandbox_sessions)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_30: Logged-in User Report Dashboard</title>
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
        .badge-danger {{ background: rgba(239, 68, 68, 0.2); color: var(--accent-red); border: 1px solid rgba(239, 68, 68, 0.3); }}
        .badge-warning {{ background: rgba(245, 158, 11, 0.2); color: var(--accent-yellow); border: 1px solid rgba(245, 158, 11, 0.3); }}
        .badge-purple {{ background: rgba(168, 85, 247, 0.2); color: var(--accent-purple); border: 1px solid rgba(168, 85, 247, 0.3); }}

        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .kpi-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}
        .kpi-card:hover {{
            transform: translateY(-2px);
            border-color: var(--accent-cyan);
        }}
        .kpi-label {{
            font-size: 0.8rem;
            text-transform: uppercase;
            color: var(--text-secondary);
            font-weight: 600;
            margin-bottom: 8px;
        }}
        .kpi-value {{
            font-size: 1.85rem;
            font-weight: 700;
            color: #fff;
        }}
        .kpi-subtext {{
            font-size: 0.75rem;
            color: var(--text-secondary);
            margin-top: 6px;
        }}

        .card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 24px;
        }}
        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-color);
        }}
        .card-header h2 {{
            font-size: 1.15rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.875rem;
        }}
        th {{
            background-color: rgba(15, 23, 42, 0.6);
            color: var(--text-secondary);
            text-align: left;
            padding: 10px 14px;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.75rem;
            border-bottom: 1px solid var(--border-color);
        }}
        td {{
            padding: 12px 14px;
            border-bottom: 1px solid rgba(51, 65, 85, 0.4);
            color: #e2e8f0;
        }}
        tr:hover td {{
            background-color: rgba(51, 65, 85, 0.25);
        }}
        .center {{ text-align: center; }}
        .font-mono {{ font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }}
        .text-cyan {{ color: var(--accent-cyan); }}
        .text-green {{ color: var(--accent-green); }}
        .text-amber {{ color: var(--accent-yellow); }}
        .text-muted {{ color: var(--text-secondary); }}

        .code-pill {{
            background: #0b1120;
            border: 1px solid var(--border-color);
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 0.8rem;
            color: #cbd5e1;
        }}

        pre {{
            background-color: #0b1120;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.8rem;
            color: #cbd5e1;
            overflow-x: auto;
            max-height: 320px;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        .footer {{
            text-align: center;
            font-size: 0.8rem;
            color: var(--text-secondary);
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
                <h1>👥 AS_30: Active Logged-in User Report</h1>
                <p>Linux System Administration (E1ITA307) &bull; Terminal Sessions, Remote IPs &amp; Idle Monitoring</p>
            </div>
            <div class="header-badges">
                <span class="badge badge-cyan">{html.escape(os_display)}</span>
                <span class="badge badge-purple">{html.escape(hostname_val)}</span>
                <span class="badge badge-green">KERNEL {html.escape(kernel_val)}</span>
                <span class="badge badge-warning">{html.escape(timestamp_val)}</span>
            </div>
        </header>

        <!-- KPI SUMMARY CARDS -->
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-label">Active Host Sessions</div>
                <div class="kpi-value text-cyan">{total_sessions}</div>
                <div class="kpi-subtext">Currently connected terminals</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Unique Logged-in Users</div>
                <div class="kpi-value text-green">{unique_users}</div>
                <div class="kpi-subtext">Distinct accounts in active use</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Local Console / TTY</div>
                <div class="kpi-value">{local_sessions}</div>
                <div class="kpi-subtext">Local terminal sessions</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Remote Network Sessions</div>
                <div class="kpi-value text-amber">{remote_sessions}</div>
                <div class="kpi-subtext">Inbound SSH/network sessions</div>
            </div>
        </div>

        <!-- LIVE HOST SESSIONS TABLE -->
        <div class="card">
            <div class="card-header">
                <h2>🟢 Live Host Active Sessions &bull; Real System Telemetry</h2>
                <span class="badge badge-green">{total_sessions} SESSION{'S' if total_sessions != 1 else ''} ACTIVE</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 140px;">Username</th>
                        <th style="width: 100px;">Terminal</th>
                        <th style="width: 180px;">Remote Host / IP</th>
                        <th class="center" style="width: 110px;">Type</th>
                        <th style="width: 110px;">Login Time</th>
                        <th style="width: 150px;">Idle Time</th>
                        <th>Active Process / Command</th>
                    </tr>
                </thead>
                <tbody>
                    {live_rows}
                </tbody>
            </table>
        </div>

        <!-- MULTI-USER ENTERPRISE DRILL TABLE -->
        <div class="card">
            <div class="card-header">
                <h2>🏢 Multi-User Corporate Scenario Drill &bull; Simulated Environment</h2>
                <span class="badge badge-purple">{len(sandbox_sessions)} SESSIONS AUDITED</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 140px;">Username</th>
                        <th style="width: 100px;">Terminal</th>
                        <th style="width: 180px;">Remote Host / IP</th>
                        <th class="center" style="width: 110px;">Type</th>
                        <th style="width: 110px;">Login Time</th>
                        <th style="width: 150px;">Idle Time</th>
                        <th>Active Process / Command</th>
                    </tr>
                </thead>
                <tbody>
                    {sandbox_rows}
                </tbody>
            </table>
        </div>

        <!-- TERMINAL EXECUTION STREAM -->
        <div class="card">
            <div class="card-header">
                <h2>🖥️ Terminal Audit Stream</h2>
                <span class="badge badge-green">STATUS: COMPLETED</span>
            </div>
            <pre>{html.escape(terminal_log)}</pre>
        </div>

        <!-- AUDIT LOG HISTORY -->
        <div class="card">
            <div class="card-header">
                <h2>📜 Persistent Session Log (logs/user_sessions.log)</h2>
                <span class="badge badge-cyan">SYSTEM AUDIT TRAIL</span>
            </div>
            <pre>{html.escape(log_preview)}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_30 &bull; Generated dynamically by run.sh
        </div>
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
