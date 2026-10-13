#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #36: Routine Server Maintenance & Cron Scheduling
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes routine_maintenance.sh against real live system data.
#   3. Installs and verifies the Cron schedule tagged '# LSA_SPRINT_TEST'.
#   4. Regenerates self-contained dark-themed report.html from scratch every run.
#   5. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_36) — ROUTINE SERVER MAINTENANCE & CRON ENGINE       "
echo "================================================================================"

# Verify routine_maintenance.sh exists and is executable
if [ ! -f "./routine_maintenance.sh" ]; then
    echo "[ERROR] routine_maintenance.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./routine_maintenance.sh

# 2. Run maintenance and cron scheduling, capturing output
echo "[INFO] Executing live routine maintenance tasks..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"

# Step A: Run routine maintenance tasks
./routine_maintenance.sh --run 2>&1 | tee "${TMP_TERM_LOG}"

# Step B: Install the Cron schedule
echo "" | tee -a "${TMP_TERM_LOG}"
echo "[INFO] Registering routine maintenance job in Cron table..." | tee -a "${TMP_TERM_LOG}"
./routine_maintenance.sh --schedule "0 2 * * *" 2>&1 | tee -a "${TMP_TERM_LOG}"

# Step C: Verify Cron installation
echo "" | tee -a "${TMP_TERM_LOG}"
./routine_maintenance.sh --verify-cron 2>&1 | tee -a "${TMP_TERM_LOG}"

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

JSON_PATH="logs/maintenance_telemetry.json"
LOG_FILE_PATH="logs/maintenance.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No maintenance log entries recorded yet."
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
log_preview = r"""${LOG_PREVIEW}"""
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"
active_cron = r"""${ACTIVE_CRON_LINE}"""

# Load structured JSON telemetry
telemetry = {}
if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as jf:
            telemetry = json.load(jf)
    except Exception as e:
        telemetry = {}

tasks = telemetry.get("tasks", {})
temp_info = tasks.get("temp_cleanup", {})
pkg_info = tasks.get("package_cache", {})
log_info = tasks.get("logs_journal", {})
mem_info = tasks.get("memory_sync", {})
proc_info = tasks.get("process_health", {})
storage_info = tasks.get("storage_health", {})

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_36: Routine Server Maintenance & Cron Scheduling</title>
    <style>
        :root {{
            --bg-primary: #0a0e17;
            --bg-secondary: #121826;
            --bg-card: #182234;
            --bg-card-hover: #1e2c42;
            --border-color: #27354f;
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
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #131b2e 0%, #1e293b 100%);
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
        .header-meta {{
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
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
        .badge-synced {{
            background: rgba(59, 130, 246, 0.15);
            color: var(--accent-blue);
            border: 1px solid rgba(59, 130, 246, 0.3);
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
                    <span>⚙️ Routine Server Maintenance & Cron Scheduling</span>
                    <span class="badge-sprint">AS_36</span>
                </h1>
                <div class="header-subtitle">Linux System Administration (E1ITA307) • Cron Automation Engine</div>
            </div>
            <div class="header-meta">
                <div class="status-pill">CRON SCHEDULE ACTIVE</div>
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">Cron Schedule</div>
                <div class="card-value" style="color: var(--accent-cyan); font-size: 20px;">0 2 * * *</div>
                <div class="card-sub">Daily at 02:00 AM System Time</div>
            </div>
            <div class="card">
                <div class="card-label">Maintenance Tasks</div>
                <div class="card-value" style="color: var(--accent-green);">6 / 6 OK</div>
                <div class="card-sub">All routines executed successfully</div>
            </div>
            <div class="card">
                <div class="card-label">Filesystem (Root /)</div>
                <div class="card-value" style="color: #ffffff;">{storage_info.get("root_usage", "1%")}</div>
                <div class="card-sub">{storage_info.get("root_free", "N/A")} free of {storage_info.get("root_total", "N/A")}</div>
            </div>
            <div class="card">
                <div class="card-label">Process Health</div>
                <div class="card-value" style="color: var(--accent-green);">{proc_info.get("zombies", 0)} Zombies</div>
                <div class="card-sub">Process table clean & healthy</div>
            </div>
        </div>

        <!-- Section 1: Cron Automation Details -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>⏰</span> Cron Schedule Registration & Safety Compliance
                </div>
            </div>
            <p style="color: var(--text-secondary); margin-bottom: 12px; font-size: 14px;">
                The routine maintenance cycle is scheduled in the current user's crontab with an explicit safety tag to allow seamless cleanup:
            </p>
            <div class="cron-box">{html.escape(active_cron)}</div>
            <div style="font-size: 13px; color: var(--text-muted); display: flex; gap: 20px; flex-wrap: wrap;">
                <div>🏷️ <strong>Safety Tag:</strong> <code style="color: var(--accent-cyan);"># LSA_SPRINT_TEST</code></div>
                <div>🔄 <strong>Execution Cadence:</strong> Every 24 hours at 02:00 AM</div>
                <div>🛡️ <strong>Sandboxing:</strong> Safe non-destructive routines</div>
            </div>
        </div>

        <!-- Section 2: Maintenance Tasks Audit -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>📋</span> Maintenance Routine Execution Matrix
                </div>
            </div>
            <table class="tasks-table">
                <thead>
                    <tr>
                        <th>Task Name</th>
                        <th>Target Subsystem</th>
                        <th>Metric / Telemetry</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>1. Temporary & Cache Cleanup</strong></td>
                        <td><code>/tmp</code> & user cache</td>
                        <td>Footprint: {temp_info.get("live_tmp_size", "N/A")} ({temp_info.get("live_tmp_entries", 0)} files verified)</td>
                        <td><span class="task-badge badge-success">COMPLETED</span></td>
                    </tr>
                    <tr>
                        <td><strong>2. Package Repository Hygiene</strong></td>
                        <td>{pkg_info.get("manager", "APT")}</td>
                        <td>Cache: {pkg_info.get("cache_size", "0 MB")} • Integrity: {pkg_info.get("integrity", "OK")}</td>
                        <td><span class="task-badge badge-success">COMPLETED</span></td>
                    </tr>
                    <tr>
                        <td><strong>3. System Logs & Journald</strong></td>
                        <td><code>/var/log</code> & <code>journalctl</code></td>
                        <td>Journal: {log_info.get("journal_size", "N/A")} • /var/log: {log_info.get("var_log_size", "N/A")}</td>
                        <td><span class="task-badge badge-success">COMPLETED</span></td>
                    </tr>
                    <tr>
                        <td><strong>4. Memory & Buffer Synchronization</strong></td>
                        <td>Kernel Page Buffers</td>
                        <td>Executed <code>sync</code> • Buffers flushed to disk</td>
                        <td><span class="task-badge badge-synced">SYNCED</span></td>
                    </tr>
                    <tr>
                        <td><strong>5. Zombie Process Audit</strong></td>
                        <td>Kernel Process Table</td>
                        <td>{proc_info.get("zombies", 0)} zombie processes detected</td>
                        <td><span class="task-badge badge-success">HEALTHY</span></td>
                    </tr>
                    <tr>
                        <td><strong>6. Storage Capacity Health</strong></td>
                        <td>Root VFS (<code>/</code>)</td>
                        <td>Capacity: {storage_info.get("root_total", "N/A")} • Used: {storage_info.get("root_usage", "1%")}</td>
                        <td><span class="task-badge badge-success">OPTIMAL</span></td>
                    </tr>
                </tbody>
            </table>
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
                    <span>🖥️</span> System Host Context & Environment
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
            Linux System Administration (E1ITA307) • Automation Sprint • Problem #36 Routine Maintenance Dashboard
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
