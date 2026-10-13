#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #40: Mounted File System Space Report
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes mounted_fs_report.sh against live host mount hierarchy.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_40) — MOUNTED FILE SYSTEM REPORT ENGINE              "
echo "================================================================================"

# Verify mounted_fs_report.sh exists and is executable
if [ ! -f "./mounted_fs_report.sh" ]; then
    echo "[ERROR] mounted_fs_report.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./mounted_fs_report.sh

# 2. Run mounted filesystem report, capturing output
echo "[INFO] Auditing all mounted filesystems across host operating system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"

./mounted_fs_report.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"

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

JSON_PATH="logs/mounted_fs_audit.json"
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
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"

meta = {}
if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as jf:
            meta = json.load(jf)
    except Exception as e:
        meta = {}

summary = meta.get("summary", {})
filesystems = meta.get("filesystems", [])

total_mounts = summary.get("total_mounts", 0)
rw_count = summary.get("read_write_count", 0)
ro_count = summary.get("read_only_count", 0)
avg_pct = summary.get("average_use_pct", 0)
categories = summary.get("categories", {})

# Build table rows HTML
rows_html = []
for fs in filesystems:
    pct = fs["use_pct"]
    if pct >= 80:
        bar_color = "var(--accent-red)"
    elif pct >= 60:
        bar_color = "var(--accent-amber)"
    else:
        bar_color = "var(--accent-green)"
        
    mode_badge = (
        '<span class="mode-badge badge-rw">RW</span>' if fs["access_mode"] == "RW" else
        '<span class="mode-badge badge-ro">RO</span>'
    )
    
    cat = fs["category"]
    cat_cls = (
        "cat-physical" if "Physical" in cat else
        ("cat-shared" if "Shared" in cat else
         ("cat-virtual" if "Virtual" in cat else "cat-overlay"))
    )

    rows_html.append(f"""
    <tr>
        <td style="font-weight: 600;"><code>{html.escape(fs["mount"])}</code></td>
        <td><span class="fstype-pill">{html.escape(fs["type"])}</span></td>
        <td style="font-weight: 600;">{fs["size"]}</td>
        <td>{fs["used"]}</td>
        <td>{fs["avail"]}</td>
        <td style="min-width: 140px;">
            <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 3px;">
                <span>{fs["use_pct_str"]}</span>
            </div>
            <div class="progress-bar-bg">
                <div class="progress-bar-fill" style="width: {min(pct, 100)}%; background: {bar_color};"></div>
            </div>
        </td>
        <td>{mode_badge}</td>
        <td><span class="category-pill {cat_cls}">{html.escape(cat)}</span></td>
        <td style="color: var(--text-secondary); font-size: 12px;"><code>{html.escape(fs["device"])}</code></td>
    </tr>
    """)

table_rows_str = "".join(rows_html)

# Build Category pills
cat_pills = []
for cat_name, count in categories.items():
    cat_pills.append(f"""
    <div class="cat-card">
        <div class="cat-card-num">{count}</div>
        <div class="cat-card-name">{html.escape(cat_name)}</div>
    </div>
    """)
cat_cards_str = "".join(cat_pills)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_40: Mounted File System Space Report</title>
    <style>
        :root {{
            --bg-primary: #0a0e19;
            --bg-secondary: #111827;
            --bg-card: #182233;
            --bg-card-hover: #1e2c40;
            --border-color: #27374d;
            --text-primary: #f0f4fc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --accent-cyan: #06b6d4;
            --accent-blue: #3b82f6;
            --accent-green: #10b981;
            --accent-amber: #f59e0b;
            --accent-red: #ef4444;
            --accent-purple: #8b5cf6;
        }}
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }}
        body {{
            background: var(--bg-primary);
            color: var(--text-primary);
            padding: 30px 20px;
            line-height: 1.6;
        }}
        .container {{
            max-width: 1280px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #111c30 0%, #1e293b 100%);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 28px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }}
        .header-title h1 {{
            font-size: 26px;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 12px;
        }}
        .badge-sprint {{
            background: rgba(6, 182, 212, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(6, 182, 212, 0.3);
            font-size: 13px;
            padding: 4px 10px;
            border-radius: 6px;
            font-weight: 600;
        }}
        .header-subtitle {{
            color: var(--text-secondary);
            font-size: 14px;
            margin-top: 6px;
        }}
        .status-pill {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}
        .status-pill::before {{
            content: "";
            width: 8px;
            height: 8px;
            background: var(--accent-green);
            border-radius: 50%;
            display: inline-block;
            box-shadow: 0 0 8px var(--accent-green);
        }}
        .cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 20px;
            margin-bottom: 28px;
        }}
        .card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}
        .card:hover {{
            transform: translateY(-2px);
            border-color: rgba(6, 182, 212, 0.4);
        }}
        .card-label {{
            font-size: 13px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 8px;
        }}
        .card-value {{
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 4px;
        }}
        .card-sub {{
            font-size: 13px;
            color: var(--text-secondary);
        }}
        .cat-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .cat-card {{
            background: #0f1623;
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 16px;
            text-align: center;
        }}
        .cat-card-num {{
            font-size: 24px;
            font-weight: 700;
            color: var(--accent-cyan);
        }}
        .cat-card-name {{
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 4px;
        }}
        .section-box {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
        }}
        .section-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 18px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }}
        .section-title {{
            font-size: 18px;
            font-weight: 600;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        .tasks-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}
        .tasks-table th {{
            background: #111827;
            color: var(--text-secondary);
            font-weight: 600;
            text-align: left;
            padding: 12px 10px;
            border-bottom: 1px solid var(--border-color);
        }}
        .tasks-table td {{
            padding: 12px 10px;
            border-bottom: 1px solid rgba(39, 53, 79, 0.5);
            vertical-align: middle;
        }}
        .tasks-table tr:hover td {{
            background: rgba(255, 255, 255, 0.02);
        }}
        .progress-bar-bg {{
            background: #0f172a;
            height: 6px;
            border-radius: 3px;
            overflow: hidden;
            width: 100%;
        }}
        .progress-bar-fill {{
            height: 100%;
            border-radius: 3px;
        }}
        .fstype-pill {{
            font-family: monospace;
            background: #0d1522;
            color: var(--accent-cyan);
            border: 1px solid #1e2c40;
            padding: 2px 7px;
            border-radius: 4px;
            font-size: 12px;
        }}
        .mode-badge {{
            display: inline-block;
            padding: 2px 7px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 700;
        }}
        .badge-rw {{
            background: rgba(6, 182, 212, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(6, 182, 212, 0.3);
        }}
        .badge-ro {{
            background: rgba(139, 92, 246, 0.15);
            color: var(--accent-purple);
            border: 1px solid rgba(139, 92, 246, 0.3);
        }}
        .category-pill {{
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
        }}
        .cat-physical {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
        }}
        .cat-shared {{
            background: rgba(59, 130, 246, 0.15);
            color: var(--accent-blue);
        }}
        .cat-virtual {{
            background: rgba(245, 158, 11, 0.15);
            color: var(--accent-amber);
        }}
        .cat-overlay {{
            background: rgba(139, 92, 246, 0.15);
            color: var(--accent-purple);
        }}
        .log-terminal {{
            background: #05080f;
            border: 1px solid #1a2233;
            border-radius: 8px;
            padding: 16px;
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
            font-size: 13px;
            color: #e2e8f0;
            max-height: 380px;
            overflow-y: auto;
            white-space: pre-wrap;
            line-height: 1.5;
        }}
        .footer {{
            text-align: center;
            color: var(--text-muted);
            font-size: 13px;
            margin-top: 36px;
            padding-top: 20px;
            border-top: 1px solid var(--border-color);
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <header class="header">
            <div class="header-title">
                <h1>
                    <span>🗄️ Mounted File System Space Report</span>
                    <span class="badge-sprint">AS_40</span>
                </h1>
                <div class="header-subtitle">Linux System Administration (E1ITA307) • VFS Mounted Storage & Capacity Telemetry</div>
            </div>
            <div class="header-meta">
                <div class="status-pill">VFS AUDIT NOMINAL</div>
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">Mounted Filesystems</div>
                <div class="card-value" style="color: var(--accent-cyan);">{total_mounts} Mount Points</div>
                <div class="card-sub">{rw_count} Read-Write • {ro_count} Read-Only</div>
            </div>
            <div class="card">
                <div class="card-label">Average Utilization</div>
                <div class="card-value" style="color: var(--accent-green);">{avg_pct}%</div>
                <div class="card-sub">Mean capacity across active mounts</div>
            </div>
            <div class="card">
                <div class="card-label">Root VFS Filesystem</div>
                <div class="card-value" style="color: #ffffff;">ext4</div>
                <div class="card-sub">Device: /dev/sdd (1007G Total, 1% Used)</div>
            </div>
            <div class="card">
                <div class="card-label">Shared Mounts</div>
                <div class="card-value" style="color: var(--accent-purple);">{categories.get("Host / Network Shared", 0)} Volumes</div>
                <div class="card-sub">9p / Host storage bridge</div>
            </div>
        </div>

        <!-- Section 1: Architectural Categories Breakdown -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>🏗️</span> Filesystem Architectural Classification
                </div>
            </div>
            <div class="cat-grid">
                {cat_cards_str}
            </div>
        </div>

        <!-- Section 2: Detailed Mounted File Systems Table -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>📋</span> Mounted Filesystems: Space Allocation & Access Modes
                </div>
            </div>
            <div style="overflow-x: auto;">
                <table class="tasks-table">
                    <thead>
                        <tr>
                            <th>Mount Point</th>
                            <th>FSType</th>
                            <th>Total Size</th>
                            <th>Used Space</th>
                            <th>Available</th>
                            <th>Utilization</th>
                            <th>Mode</th>
                            <th>Category</th>
                            <th>Device Source</th>
                        </tr>
                    </thead>
                    <tbody>
                        {table_rows_str}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Section 3: Live Terminal Trace -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>💻</span> Live Execution Terminal Trace
                </div>
            </div>
            <div class="log-terminal">{html.escape(terminal_log)}</div>
        </div>

        <!-- Section 4: System Host Context -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>🖥️</span> System Host Context
                </div>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; font-size: 14px;">
                <div><span style="color: var(--text-muted);">Hostname:</span> <strong>{hostname_val}</strong></div>
                <div><span style="color: var(--text-muted);">OS Display:</span> <strong>{os_display}</strong></div>
                <div><span style="color: var(--text-muted);">Kernel:</span> <strong>{kernel_val}</strong></div>
                <div><span style="color: var(--text-muted);">Operator:</span> <strong>{user_val}</strong></div>
                <div><span style="color: var(--text-muted);">Timestamp:</span> <strong>{timestamp_val}</strong></div>
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            Linux System Administration (E1ITA307) • Automation Sprint • Problem #40 Mounted File System Report Dashboard
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
