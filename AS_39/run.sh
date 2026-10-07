#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #39: Disk Space and Inode Utilization Audit
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes disk_inode_check.sh against real live host storage mounts.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_39) — DISK & INODE STORAGE AUDIT ENGINE              "
echo "================================================================================"

# Verify disk_inode_check.sh exists and is executable
if [ ! -f "./disk_inode_check.sh" ]; then
    echo "[ERROR] disk_inode_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./disk_inode_check.sh

# 2. Run disk and inode audit, capturing output
echo "[INFO] Auditing live mounted storage and inode capacities..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"

./disk_inode_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"

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

JSON_PATH="logs/disk_inode_audit.json"
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

thresholds = meta.get("thresholds", {"disk_critical": 80, "inode_critical": 80, "warning": 70})
summary = meta.get("summary", {})
filesystems = meta.get("filesystems", [])

total_audited = summary.get("total_audited", 0)
critical_count = summary.get("critical_exceeded", 0)
warning_count = summary.get("warning", 0)
ok_count = summary.get("ok", 0)
max_disk_pct = summary.get("max_disk_pct", 0)
max_inode_pct = summary.get("max_inode_pct", 0)

# Build table rows HTML
rows_html = []
for fs in filesystems:
    status = fs["status"]
    if status == "CRITICAL":
        badge_cls = "badge-critical"
        bar_color = "var(--accent-red)"
    elif status == "WARNING":
        badge_cls = "badge-warning"
        bar_color = "var(--accent-amber)"
    else:
        badge_cls = "badge-ok"
        bar_color = "var(--accent-green)"
        
    d_pct = fs["disk_pct"]
    i_pct = fs["inode_pct"]
    i_str = fs["inode_pct_str"]
    
    # Progress bar width
    d_bar_w = min(d_pct, 100)
    i_bar_w = min(i_pct, 100) if isinstance(i_pct, int) else 0

    rows_html.append(f"""
    <tr>
        <td style="font-weight: 600;"><code>{html.escape(fs["mount"])}</code></td>
        <td style="color: var(--text-secondary);">{html.escape(fs["filesystem"])}</td>
        <td>{fs["disk_size"]}</td>
        <td>{fs["disk_used"]}</td>
        <td>{fs["disk_avail"]}</td>
        <td style="min-width: 140px;">
            <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 3px;">
                <span>{fs["disk_pct_str"]}</span>
            </div>
            <div class="progress-bar-bg">
                <div class="progress-bar-fill" style="width: {d_bar_w}%; background: {bar_color};"></div>
            </div>
        </td>
        <td>{fs["inodes_total"]}</td>
        <td>{fs["inodes_used"]}</td>
        <td style="min-width: 110px;">
            <div style="font-size: 12px; margin-bottom: 3px;">{i_str}</div>
            {"<div class='progress-bar-bg'><div class='progress-bar-fill' style='width: " + str(i_bar_w) + "%; background: var(--accent-cyan);'></div></div>" if i_str != "N/A" else "<span style='color: var(--text-muted); font-size: 11px;'>Not Applicable</span>"}
        </td>
        <td><span class="task-badge {badge_cls}">{status}</span></td>
    </tr>
    """)

table_rows_str = "".join(rows_html)

# Build alerts section HTML
alerts_html = []
exceeded_fs = [fs for fs in filesystems if fs["status"] in ("CRITICAL", "WARNING")]
if exceeded_fs:
    for e in exceeded_fs:
        alert_cls = "alert-critical" if e["status"] == "CRITICAL" else "alert-warning"
        reasons_text = ", ".join(e["reasons"])
        alerts_html.append(f"""
        <div class="alert-box {alert_cls}">
            <div style="font-weight: 700; font-size: 15px; margin-bottom: 4px;">
                {'🚨 CRITICAL THRESHOLD EXCEEDED' if e['status'] == 'CRITICAL' else '⚠️ WARNING THRESHOLD REACHED'}: <code>{html.escape(e['mount'])}</code> ({html.escape(e['filesystem'])})
            </div>
            <div style="font-size: 14px; margin-bottom: 6px;">
                <strong>Trigger:</strong> {html.escape(reasons_text)} | <strong>Storage:</strong> {e['disk_used']} used of {e['disk_size']} ({e['disk_avail']} free)
            </div>
            <div style="font-size: 13px; color: var(--text-secondary);">
                <strong>Recommendation:</strong> Inspect large files with <code>find {e['mount']} -size +100M</code>, prune stale cache/log trees, or expand volume capacity.
            </div>
        </div>
        """)
else:
    alerts_html.append("""
    <div style="background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 8px; padding: 16px; color: var(--accent-green);">
        ✔ <strong>All Audited Filesystems Nominal:</strong> Neither disk space nor inode consumption exceeds configured thresholds.
    </div>
    """)
alerts_str = "".join(alerts_html)

overall_status_pill = (
    '<div class="status-pill-red">CRITICAL ALERTS DETECTED</div>' if critical_count > 0 else
    ('<div class="status-pill-yellow">WARNINGS DETECTED</div>' if warning_count > 0 else
     '<div class="status-pill-green">ALL MOUNTS HEALTHY</div>')
)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_39: Disk Space & Inode Utilization Audit</title>
    <style>
        :root {{
            --bg-primary: #0a0e1a;
            --bg-secondary: #121826;
            --bg-card: #182234;
            --bg-card-hover: #1e2c42;
            --border-color: #27364f;
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
            max-width: 1240px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #111d33 0%, #1e293b 100%);
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
        .status-pill-green {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
        }}
        .status-pill-yellow {{
            background: rgba(245, 158, 11, 0.15);
            color: var(--accent-amber);
            border: 1px solid rgba(245, 158, 11, 0.3);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
        }}
        .status-pill-red {{
            background: rgba(239, 68, 68, 0.15);
            color: var(--accent-red);
            border: 1px solid rgba(239, 68, 68, 0.3);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
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
        .alert-box {{
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 12px;
        }}
        .alert-critical {{
            background: rgba(239, 68, 68, 0.12);
            border: 1px solid rgba(239, 68, 68, 0.4);
            color: #fca5a5;
        }}
        .alert-warning {{
            background: rgba(245, 158, 11, 0.12);
            border: 1px solid rgba(245, 158, 11, 0.4);
            color: #fde68a;
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
        .task-badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 700;
            text-align: center;
        }}
        .badge-ok {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}
        .badge-warning {{
            background: rgba(245, 158, 11, 0.15);
            color: var(--accent-amber);
            border: 1px solid rgba(245, 158, 11, 0.3);
        }}
        .badge-critical {{
            background: rgba(239, 68, 68, 0.15);
            color: var(--accent-red);
            border: 1px solid rgba(239, 68, 68, 0.3);
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
                    <span>💾 Disk Space & Inode Utilization Audit</span>
                    <span class="badge-sprint">AS_39</span>
                </h1>
                <div class="header-subtitle">Linux System Administration (E1ITA307) • Storage Capacity & Inode Monitoring</div>
            </div>
            <div class="header-meta">
                {overall_status_pill}
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">Audited Mounts</div>
                <div class="card-value" style="color: var(--accent-cyan);">{total_audited} Filesystems</div>
                <div class="card-sub">{ok_count} OK • {warning_count} Warning • {critical_count} Critical</div>
            </div>
            <div class="card">
                <div class="card-label">Peak Disk Space</div>
                <div class="card-value" style="color: {'var(--accent-red)' if max_disk_pct >= thresholds['disk_critical'] else ('var(--accent-amber)' if max_disk_pct >= thresholds['warning'] else 'var(--accent-green)')};">{max_disk_pct}%</div>
                <div class="card-sub">Highest disk capacity utilized</div>
            </div>
            <div class="card">
                <div class="card-label">Peak Inodes</div>
                <div class="card-value" style="color: var(--accent-purple);">{max_inode_pct}%</div>
                <div class="card-sub">Highest inode table utilized</div>
            </div>
            <div class="card">
                <div class="card-label">Active Thresholds</div>
                <div class="card-value" style="font-size: 18px; color: #ffffff;">Disk: {thresholds['disk_critical']}% • Inode: {thresholds['inode_critical']}%</div>
                <div class="card-sub">Warning threshold: {thresholds['warning']}%</div>
            </div>
        </div>

        <!-- Section 1: Alert Panel -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>🚨</span> Threshold Policy Evaluation & Alerts
                </div>
            </div>
            {alerts_str}
        </div>

        <!-- Section 2: Filesystem Storage & Inode Audit Matrix -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>📋</span> Mounted Filesystems: Disk Space & Inode Utilization Matrix
                </div>
            </div>
            <div style="overflow-x: auto;">
                <table class="tasks-table">
                    <thead>
                        <tr>
                            <th>Mount Point</th>
                            <th>Filesystem</th>
                            <th>Size</th>
                            <th>Used</th>
                            <th>Avail</th>
                            <th>Disk Use %</th>
                            <th>Inodes</th>
                            <th>I-Used</th>
                            <th>Inode %</th>
                            <th>Status</th>
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
            Linux System Administration (E1ITA307) • Automation Sprint • Problem #39 Disk & Inode Check Dashboard
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
