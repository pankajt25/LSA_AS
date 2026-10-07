#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #38: Scheduled Linux System Health Report via Cron
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes scheduled_health_report.sh to harvest live system metrics.
#   3. Installs and verifies the Cron schedule tagged '# LSA_SPRINT_TEST'.
#   4. Regenerates self-contained dark-themed report.html from scratch every run.
#   5. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "   AUTOMATION SPRINT (AS_38) — SCHEDULED SYSTEM HEALTH REPORT ENGINE            "
echo "================================================================================"

# Verify scheduled_health_report.sh exists and is executable
if [ ! -f "./scheduled_health_report.sh" ]; then
    echo "[ERROR] scheduled_health_report.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./scheduled_health_report.sh

# 2. Run report generation and cron registration, capturing output
echo "[INFO] Harvesting live system health metrics..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"

# Step A: Collect live health report
./scheduled_health_report.sh --generate 2>&1 | tee "${TMP_TERM_LOG}"

# Step B: Register the Cron schedule
echo "" | tee -a "${TMP_TERM_LOG}"
echo "[INFO] Registering periodic health report job in Cron table..." | tee -a "${TMP_TERM_LOG}"
./scheduled_health_report.sh --schedule "*/30 * * * *" 2>&1 | tee -a "${TMP_TERM_LOG}"

# Step C: Verify Cron installation
echo "" | tee -a "${TMP_TERM_LOG}"
./scheduled_health_report.sh --verify-cron 2>&1 | tee -a "${TMP_TERM_LOG}"

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

# Active crontab lines matching test tag
ACTIVE_CRON_LINE="$(crontab -l 2>/dev/null | grep "# LSA_SPRINT_TEST" | head -n 1 || echo "Not Scheduled")"

JSON_PATH="logs/health_metrics.json"
LATEST_REPORT="reports/latest_health_report.txt"
if [ -f "${LATEST_REPORT}" ]; then
    REPORT_PREVIEW="$(cat "${LATEST_REPORT}")"
else
    REPORT_PREVIEW="No health report generated yet."
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
report_preview = r"""${REPORT_PREVIEW}"""
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"
active_cron = r"""${ACTIVE_CRON_LINE}"""

meta = {}
if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as jf:
            meta = json.load(jf)
    except Exception as e:
        meta = {}

sys_info = meta.get("system", {})
mem_info = meta.get("memory", {})
storage_info = meta.get("storage", {})

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_38: Scheduled Linux System Health Report via Cron</title>
    <style>
        :root {{
            --bg-primary: #0a0f1d;
            --bg-secondary: #111827;
            --bg-card: #182234;
            --bg-card-hover: #1f2c42;
            --border-color: #27374f;
            --text-primary: #f0f4fc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --accent-cyan: #06b6d4;
            --accent-blue: #3b82f6;
            --accent-green: #10b981;
            --accent-amber: #f59e0b;
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
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #111e33 0%, #1e293b 100%);
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
        .cron-box {{
            background: #0f1623;
            border: 1px solid #1e293b;
            border-radius: 8px;
            padding: 16px;
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
            font-size: 14px;
            color: #38bdf8;
            overflow-x: auto;
            margin-bottom: 16px;
        }}
        .tasks-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }}
        .tasks-table th {{
            background: #111827;
            color: var(--text-secondary);
            font-weight: 600;
            text-align: left;
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-color);
        }}
        .tasks-table td {{
            padding: 14px;
            border-bottom: 1px solid rgba(39, 53, 79, 0.5);
            vertical-align: middle;
        }}
        .tasks-table tr:last-child td {{
            border-bottom: none;
        }}
        .task-badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }}
        .badge-success {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
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
                    <span>📊 Scheduled Linux System Health Report</span>
                    <span class="badge-sprint">AS_38</span>
                </h1>
                <div class="header-subtitle">Linux System Administration (E1ITA307) • Periodic Health Monitoring via Cron</div>
            </div>
            <div class="header-meta">
                <div class="status-pill">MONITORING ACTIVE</div>
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">System Load (1m / 5m / 15m)</div>
                <div class="card-value" style="color: var(--accent-cyan); font-size: 20px;">{sys_info.get("load_1m", "0.00")} • {sys_info.get("load_5m", "0.00")} • {sys_info.get("load_15m", "0.00")}</div>
                <div class="card-sub">{sys_info.get("cpu_cores", 1)} Logical CPU Cores</div>
            </div>
            <div class="card">
                <div class="card-label">Physical Memory (RAM)</div>
                <div class="card-value" style="color: var(--accent-green);">{mem_info.get("used_pct", "0.0")}%</div>
                <div class="card-sub">{mem_info.get("used_mb", 0)}MB used / {mem_info.get("total_mb", 0)}MB total</div>
            </div>
            <div class="card">
                <div class="card-label">Root Storage Utilization</div>
                <div class="card-value" style="color: #ffffff;">{storage_info.get("used_pct", "1%")}</div>
                <div class="card-sub">{storage_info.get("avail", "N/A")} free of {storage_info.get("total", "N/A")}</div>
            </div>
            <div class="card">
                <div class="card-label">System Uptime</div>
                <div class="card-value" style="font-size: 19px; color: var(--accent-purple);">{html.escape(sys_info.get("uptime", "N/A"))}</div>
                <div class="card-sub">Cadence: */30 * * * * (Every 30 min)</div>
            </div>
        </div>

        <!-- Section 1: Cron Automation Registration -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>⏰</span> Cron Schedule Registration & Automation Policy
                </div>
            </div>
            <p style="color: var(--text-secondary); margin-bottom: 12px; font-size: 14px;">
                The Linux system health report is automatically generated periodically using the following active crontab job:
            </p>
            <div class="cron-box">{html.escape(active_cron)}</div>
            <div style="font-size: 13px; color: var(--text-muted); display: flex; gap: 20px; flex-wrap: wrap;">
                <div>🏷️ <strong>Safety Tag:</strong> <code style="color: var(--accent-cyan);"># LSA_SPRINT_TEST</code></div>
                <div>🔄 <strong>Frequency:</strong> Every 30 minutes</div>
                <div>📁 <strong>Reports Archive:</strong> <code>AS_38/reports/</code></div>
            </div>
        </div>

        <!-- Section 2: Health Report Detailed Preview -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>📋</span> Latest System Health Report (Generated via Automation)
                </div>
            </div>
            <div class="log-terminal">{html.escape(report_preview)}</div>
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
            Linux System Administration (E1ITA307) • Automation Sprint • Problem #38 Scheduled Health Report Dashboard
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
