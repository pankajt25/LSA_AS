#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #28: Package Verification (Package Management)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes package_verifier.sh against system package database.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_28) — PACKAGE VERIFICATION & AUDIT ENGINE             "
echo "================================================================================"

if [ ! -f "./package_verifier.sh" ]; then
    echo "[ERROR] package_verifier.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./package_verifier.sh

# 2. Run package_verifier.sh and stream to console while capturing
echo "[INFO] Running package_verifier.sh against system package manifest..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    ./package_verifier.sh 2>&1 | tee "${TMP_TERM_LOG}"
    VERIFY_EXIT_CODE=$?
else
    ./package_verifier.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    VERIFY_EXIT_CODE=$?
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

JSON_PATH="logs/package_verification.json"
LOG_FILE_PATH="logs/package_verifier.log"

if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
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

data = {}
if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        data = {"error": str(e)}

pkg_mgr = data.get("package_manager", "apt").upper()
total_checked = data.get("total_checked", 0)
total_installed = data.get("total_installed", 0)
total_missing = data.get("total_missing", 0)
inst_pct = data.get("installed_percentage", "0%")
miss_pct = data.get("missing_percentage", "0%")
packages = data.get("packages", [])

pkg_rows = ""
for idx, p in enumerate(packages, 1):
    name = html.escape(str(p.get("name", "")))
    status = p.get("status", "NOT_INSTALLED")
    installed = p.get("installed", False)
    ver = html.escape(str(p.get("version", "N/A")))
    path = html.escape(str(p.get("path", "N/A")))
    sugg = html.escape(str(p.get("suggestion", "")))

    if installed:
        status_badge = '<span class="badge badge-green">INSTALLED</span>'
        action_col = f'<span class="font-mono text-cyan">{path}</span>'
    else:
        status_badge = '<span class="badge badge-danger">NOT INSTALLED</span>'
        action_col = f'<code class="code-pill text-amber">{sugg}</code>'

    pkg_rows += f"""
    <tr>
        <td class="center font-mono">#{idx}</td>
        <td class="font-mono text-cyan"><strong>{name}</strong></td>
        <td class="center">{status_badge}</td>
        <td class="font-mono {'text-green' if installed else 'text-muted'}">{ver}</td>
        <td>{action_col}</td>
    </tr>
    """

if not pkg_rows:
    pkg_rows = "<tr><td colspan='5' class='center text-muted'>No packages audited.</td></tr>"

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_28: Package Verification &amp; Audit Dashboard</title>
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
                <h1>🔍 AS_28: Package Verification &amp; Audit Dashboard</h1>
                <p>Linux System Administration (E1ITA307) &bull; Package Management &amp; System Dependency Audit</p>
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
                <div class="kpi-label">Audited Packages</div>
                <div class="kpi-value">{total_checked}</div>
                <div class="kpi-subtext">Manifest items evaluated</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Installed Packages</div>
                <div class="kpi-value text-green">{total_installed} <span style="font-size:1rem;font-weight:normal;color:var(--text-secondary);">({inst_pct})</span></div>
                <div class="kpi-subtext">Active binaries and libraries</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Missing Packages</div>
                <div class="kpi-value text-amber">{total_missing} <span style="font-size:1rem;font-weight:normal;color:var(--text-secondary);">({miss_pct})</span></div>
                <div class="kpi-subtext">Requires installation action</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Package Manager</div>
                <div class="kpi-value text-cyan">{pkg_mgr}</div>
                <div class="kpi-subtext">Host system package backend</div>
            </div>
        </div>

        <!-- PACKAGE VERIFICATION MATRIX -->
        <div class="card">
            <div class="card-header">
                <h2>📋 Package Presence, Versions &amp; Remediation Suggestions</h2>
                <span class="badge badge-cyan">{total_installed}/{total_checked} COMPLIANT</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th class="center" style="width: 50px;">Index</th>
                        <th style="width: 160px;">Package Name</th>
                        <th class="center" style="width: 140px;">Status</th>
                        <th style="width: 220px;">Detected Version</th>
                        <th>Binary Location / Suggested Install Command</th>
                    </tr>
                </thead>
                <tbody>
                    {pkg_rows}
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
                <h2>📜 Persistent Verification Log (logs/package_verifier.log)</h2>
                <span class="badge badge-cyan">SYSTEM AUDIT TRAIL</span>
            </div>
            <pre>{html.escape(log_preview)}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_28 &bull; Generated dynamically by run.sh
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
