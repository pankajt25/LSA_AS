#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #27: Application Installation (Package Automation)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Runs package_installer.sh to verify catalog and install safe demo packages.
#   3. Captures output from installed demo utilities (cowsay, figlet).
#   4. Regenerates self-contained dark-themed report.html from scratch every run.
#   5. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_27) — APPLICATION INSTALLATION & PACKAGE ENGINE      "
echo "================================================================================"

if [ ! -f "./package_installer.sh" ]; then
    echo "[ERROR] package_installer.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./package_installer.sh
if [ -f "./cleanup.sh" ]; then
    chmod +x ./cleanup.sh
fi

# 2. Run package_installer.sh and stream to console while capturing
echo "[INFO] Executing package_installer.sh on host system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default: non-interactive installation of safe demo packages (cowsay, figlet)
    ./package_installer.sh --demo 2>&1 | tee "${TMP_TERM_LOG}"
    INSTALL_EXIT_CODE=$?
else
    ./package_installer.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    INSTALL_EXIT_CODE=$?
fi
set -e
echo "--------------------------------------------------------------------------------"

# 3. Capture demo output if cowsay or figlet installed
COWSAY_OUTPUT=""
FIGLET_OUTPUT=""
if command -v cowsay >/dev/null 2>&1; then
    COWSAY_OUTPUT="$(cowsay "Automation Sprint AS_27: Package Installation Verified!" 2>/dev/null || true)"
fi
if command -v figlet >/dev/null 2>&1; then
    FIGLET_OUTPUT="$(figlet "Linux Sprint" 2>/dev/null || true)"
fi

# Gather system context
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

JSON_PATH="logs/installation_report.json"
LOG_FILE_PATH="logs/package_installer.log"

if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No installation log entries recorded yet."
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
cowsay_out = r"""${COWSAY_OUTPUT}"""
figlet_out = r"""${FIGLET_OUTPUT}"""
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
install_cmd = data.get("install_command", "sudo apt-get install -y")
total_catalog = data.get("catalog_total", 0)
total_installed = data.get("installed_total", 0)
total_available = data.get("available_total", 0)
packages = data.get("packages", [])

pkg_rows = ""
for p in packages:
    name = html.escape(str(p.get("name", "")))
    cat = html.escape(str(p.get("category", "")))
    desc = html.escape(str(p.get("description", "")))
    inst = p.get("installed", False)
    ver = html.escape(str(p.get("version", "Not Installed")))
    is_demo = p.get("is_safe_demo", False)

    demo_badge = '<span class="badge badge-purple" style="margin-left:6px;">DEMO</span>' if is_demo else ''
    if inst:
        status_badge = '<span class="badge badge-green">INSTALLED</span>'
    else:
        status_badge = '<span class="badge badge-warning">AVAILABLE</span>'

    pkg_rows += f"""
    <tr>
        <td class="font-mono text-cyan"><strong>{name}</strong>{demo_badge}</td>
        <td><span class="badge badge-cyan">{cat}</span></td>
        <td class="center">{status_badge}</td>
        <td class="font-mono {'text-amber' if inst else 'text-muted'}">{ver}</td>
        <td class="text-muted">{desc}</td>
    </tr>
    """

if not pkg_rows:
    pkg_rows = "<tr><td colspan='5' class='center text-muted'>No catalog items found.</td></tr>"

demo_section = ""
if cowsay_out or figlet_out:
    demo_section = f"""
    <div class="card">
        <div class="card-header">
            <h2>✨ Live Package Verification Proof (Installed Demo Utilities)</h2>
            <span class="badge badge-green">EXECUTION CONFIRMED</span>
        </div>
        <div class="grid-2col" style="margin-bottom:0;">
            <div>
                <h3 style="font-size: 0.9rem; margin-bottom: 8px; color: var(--accent-cyan);">cowsay Execution</h3>
                <pre style="max-height: 200px;">{html.escape(cowsay_out)}</pre>
            </div>
            <div>
                <h3 style="font-size: 0.9rem; margin-bottom: 8px; color: var(--accent-yellow);">figlet Banner Generation</h3>
                <pre style="max-height: 200px;">{html.escape(figlet_out)}</pre>
            </div>
        </div>
    </div>
    """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_27: Application Installation Automation Dashboard</title>
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

        .grid-2col {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 24px;
        }}
        @media (max-width: 900px) {{
            .grid-2col {{
                grid-template-columns: 1fr;
            }}
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
        .text-amber {{ color: var(--accent-yellow); }}
        .text-muted {{ color: var(--text-secondary); }}

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
                <h1>📦 AS_27: Application Installation Dashboard</h1>
                <p>Linux System Administration (E1ITA307) &bull; Automated Package Management &amp; Menu Catalog</p>
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
                <div class="kpi-label">Active Package Manager</div>
                <div class="kpi-value text-cyan">{pkg_mgr}</div>
                <div class="kpi-subtext">Backend: {html.escape(install_cmd)}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Applications in Catalog</div>
                <div class="kpi-value">{total_catalog}</div>
                <div class="kpi-subtext">Curated admin tools &amp; utilities</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Currently Installed</div>
                <div class="kpi-value text-green">{total_installed}</div>
                <div class="kpi-subtext">Verified on host system</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Available for Installation</div>
                <div class="kpi-value text-amber">{total_available}</div>
                <div class="kpi-subtext">Ready for menu-driven deployment</div>
            </div>
        </div>

        <!-- APPLICATION CATALOG TABLE -->
        <div class="card">
            <div class="card-header">
                <h2>📋 Application Catalog &amp; Installation Status Matrix</h2>
                <span class="badge badge-cyan">{total_installed}/{total_catalog} INSTALLED</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 160px;">Application</th>
                        <th style="width: 140px;">Category</th>
                        <th class="center" style="width: 120px;">Status</th>
                        <th style="width: 180px;">Version</th>
                        <th>Description</th>
                    </tr>
                </thead>
                <tbody>
                    {pkg_rows}
                </tbody>
            </table>
        </div>

        <!-- DEMO VERIFICATION SECTION -->
        {demo_section}

        <!-- TERMINAL EXECUTION STREAM -->
        <div class="card">
            <div class="card-header">
                <h2>🖥️ Terminal Execution Stream</h2>
                <span class="badge badge-green">STATUS: COMPLETED</span>
            </div>
            <pre>{html.escape(terminal_log)}</pre>
        </div>

        <!-- AUDIT LOG HISTORY -->
        <div class="card">
            <div class="card-header">
                <h2>📜 Persistent Package Manager Log (logs/package_installer.log)</h2>
                <span class="badge badge-cyan">SYSTEM AUDIT TRAIL</span>
            </div>
            <pre>{html.escape(log_preview)}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_27 &bull; Generated dynamically by run.sh
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
