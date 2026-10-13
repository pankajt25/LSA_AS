#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #29: System Inventory (System Inventory)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes system_inventory.sh against live hardware and OS specifications.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_29) — COMPREHENSIVE SYSTEM INVENTORY ENGINE           "
echo "================================================================================"

if [ ! -f "./system_inventory.sh" ]; then
    echo "[ERROR] system_inventory.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./system_inventory.sh

# 2. Run system_inventory.sh and stream to console while capturing
echo "[INFO] Running system_inventory.sh against host specifications..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    ./system_inventory.sh 2>&1 | tee "${TMP_TERM_LOG}"
    INVENTORY_EXIT_CODE=$?
else
    ./system_inventory.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    INVENTORY_EXIT_CODE=$?
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

JSON_PATH="logs/system_inventory.json"
LOG_FILE_PATH="logs/system_inventory.log"

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

sys_info = data.get("system", {})
cpu_info = data.get("cpu", {})
mem_info = data.get("memory", {})
disks = data.get("storage", [])
networks = data.get("network", [])

os_pretty = sys_info.get("os_pretty", os_display)
arch_val = sys_info.get("architecture", "x86_64")
uptime_val = sys_info.get("uptime", "Unknown")
cpu_model = cpu_info.get("model", "Unknown")
cpu_cores = cpu_info.get("cores", 1)
cpu_clock = cpu_info.get("clock_mhz", "N/A")

mem_total = mem_info.get("total_mb", 0)
mem_used = mem_info.get("used_mb", 0)
mem_avail = mem_info.get("available_mb", 0)
mem_pct = mem_info.get("usage_percent", "0%")
mem_pct_val = float(mem_pct.replace("%", "")) if "%" in mem_pct else 0

swap_total = mem_info.get("swap_total_mb", 0)
swap_used = mem_info.get("swap_used_mb", 0)
swap_free = mem_info.get("swap_free_mb", 0)
swap_pct_val = (swap_used / swap_total * 100.0) if swap_total > 0 else 0

# Storage rows
disk_rows = ""
for d in disks:
    fs = html.escape(str(d.get("filesystem", "")))
    size = html.escape(str(d.get("size", "")))
    used = html.escape(str(d.get("used", "")))
    avail = html.escape(str(d.get("available", "")))
    pct = html.escape(str(d.get("use_percent", "")))
    pct_val = float(d.get("use_percent_val", 0))
    mount = html.escape(str(d.get("mount_point", "")))

    bar_color = "progress-fill-red" if pct_val >= 80 else ("progress-fill-yellow" if pct_val >= 60 else "progress-fill-cyan")

    disk_rows += f"""
    <tr>
        <td class="font-mono text-cyan"><strong>{fs}</strong></td>
        <td><span class="badge badge-purple">{mount}</span></td>
        <td class="font-mono">{size}</td>
        <td class="font-mono text-amber">{used}</td>
        <td class="font-mono text-green">{avail}</td>
        <td style="width: 180px;">
            <div class="progress-bar-bg">
                <div class="progress-bar-fill {bar_color}" style="width: {pct_val}%;"></div>
            </div>
            <div class="pct-text">{pct} used</div>
        </td>
    </tr>
    """

if not disk_rows:
    disk_rows = "<tr><td colspan='6' class='center text-muted'>No storage volumes detected.</td></tr>"

# Network rows
net_rows = ""
for n in networks:
    iface = html.escape(str(n.get("interface", "")))
    state = html.escape(str(n.get("state", "UNKNOWN")))
    mac = html.escape(str(n.get("mac_address", "N/A")))
    addrs = html.escape(str(n.get("ip_addresses", "None")))

    state_badge = '<span class="badge badge-green">UP</span>' if state == "UP" else ('<span class="badge badge-danger">DOWN</span>' if state == "DOWN" else f'<span class="badge badge-warning">{state}</span>')

    net_rows += f"""
    <tr>
        <td class="font-mono text-cyan"><strong>{iface}</strong></td>
        <td class="center">{state_badge}</td>
        <td class="font-mono text-muted">{mac}</td>
        <td class="font-mono text-amber">{addrs}</td>
    </tr>
    """

if not net_rows:
    net_rows = "<tr><td colspan='4' class='center text-muted'>No network interfaces detected.</td></tr>"

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_29: Comprehensive System Inventory Dashboard</title>
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
            font-size: 1.55rem;
            font-weight: 700;
            color: #fff;
            line-height: 1.2;
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
        .text-green {{ color: var(--accent-green); }}
        .text-amber {{ color: var(--accent-yellow); }}
        .text-muted {{ color: var(--text-secondary); }}

        .progress-bar-bg {{
            background-color: rgba(15, 23, 42, 0.8);
            border-radius: 9999px;
            height: 8px;
            width: 100%;
            overflow: hidden;
            margin-bottom: 4px;
        }}
        .progress-bar-fill {{
            height: 100%;
            border-radius: 9999px;
        }}
        .progress-fill-red {{ background: linear-gradient(90deg, #f87171, #ef4444); }}
        .progress-fill-yellow {{ background: linear-gradient(90deg, #fbbf24, #f59e0b); }}
        .progress-fill-cyan {{ background: linear-gradient(90deg, #38bdf8, #0ea5e9); }}
        .pct-text {{
            font-size: 0.7rem;
            color: var(--text-secondary);
            text-align: right;
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
                <h1>🖥️ AS_29: Comprehensive System Inventory</h1>
                <p>Linux System Administration (E1ITA307) &bull; Hardware, OS, Memory, Storage &amp; Network Audit</p>
            </div>
            <div class="header-badges">
                <span class="badge badge-cyan">{html.escape(os_pretty)}</span>
                <span class="badge badge-purple">{html.escape(hostname_val)}</span>
                <span class="badge badge-green">KERNEL {html.escape(kernel_val)}</span>
                <span class="badge badge-warning">{html.escape(timestamp_val)}</span>
            </div>
        </header>

        <!-- KPI SUMMARY CARDS -->
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-label">Operating System</div>
                <div class="kpi-value text-cyan">{html.escape(os_pretty)}</div>
                <div class="kpi-subtext">Arch: {arch_val} &bull; Uptime: {uptime_val}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Processor (CPU)</div>
                <div class="kpi-value text-green">{cpu_cores} Cores</div>
                <div class="kpi-subtext">{html.escape(cpu_model[:38])}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Physical Memory</div>
                <div class="kpi-value text-amber">{mem_total} MB</div>
                <div class="kpi-subtext">{mem_avail} MB available ({mem_pct} used)</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Storage Partitions</div>
                <div class="kpi-value">{len(disks)} Volumes</div>
                <div class="kpi-subtext">{len(networks)} Network interfaces active</div>
            </div>
        </div>

        <!-- MEMORY ALLOCATION METRIC CARDS -->
        <div class="grid-2col">
            <div class="card" style="margin-bottom:0;">
                <div class="card-header">
                    <h2>🧠 RAM Utilization Breakdown</h2>
                    <span class="badge badge-cyan">{mem_pct} USED</span>
                </div>
                <div style="margin-bottom: 12px;">
                    <div style="display:flex; justify-content:space-between; font-size:0.85rem; margin-bottom:4px;">
                        <span>Used: <strong>{mem_used} MB</strong></span>
                        <span>Available: <strong>{mem_avail} MB</strong> / Total: <strong>{mem_total} MB</strong></span>
                    </div>
                    <div class="progress-bar-bg" style="height: 12px;">
                        <div class="progress-bar-fill progress-fill-cyan" style="width: {mem_pct_val}%;"></div>
                    </div>
                </div>
            </div>

            <div class="card" style="margin-bottom:0;">
                <div class="card-header">
                    <h2>🔄 Swap Space Allocation</h2>
                    <span class="badge badge-purple">{round(swap_pct_val, 1)}% USED</span>
                </div>
                <div style="margin-bottom: 12px;">
                    <div style="display:flex; justify-content:space-between; font-size:0.85rem; margin-bottom:4px;">
                        <span>Used: <strong>{swap_used} MB</strong></span>
                        <span>Free: <strong>{swap_free} MB</strong> / Total: <strong>{swap_total} MB</strong></span>
                    </div>
                    <div class="progress-bar-bg" style="height: 12px;">
                        <div class="progress-bar-fill progress-fill-yellow" style="width: {swap_pct_val}%;"></div>
                    </div>
                </div>
            </div>
        </div>

        <!-- STORAGE VOLUMES TABLE -->
        <div class="card">
            <div class="card-header">
                <h2>💾 Filesystem Partitions &amp; Storage Volumes</h2>
                <span class="badge badge-cyan">{len(disks)} MOUNTED</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Filesystem</th>
                        <th>Mount Point</th>
                        <th>Total Size</th>
                        <th>Used Space</th>
                        <th>Available</th>
                        <th>Storage Utilization</th>
                    </tr>
                </thead>
                <tbody>
                    {disk_rows}
                </tbody>
            </table>
        </div>

        <!-- NETWORK INTERFACES TABLE -->
        <div class="card">
            <div class="card-header">
                <h2>🌐 Network Interfaces &amp; IP Addresses</h2>
                <span class="badge badge-cyan">{len(networks)} INTERFACES</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 140px;">Interface</th>
                        <th class="center" style="width: 100px;">State</th>
                        <th style="width: 220px;">MAC Address</th>
                        <th>Assigned IP Addresses</th>
                    </tr>
                </thead>
                <tbody>
                    {net_rows}
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
                <h2>📜 Persistent Inventory Log (logs/system_inventory.log)</h2>
                <span class="badge badge-cyan">SYSTEM AUDIT TRAIL</span>
            </div>
            <pre>{html.escape(log_preview)}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_29 &bull; Generated dynamically by run.sh
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
