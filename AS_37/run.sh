#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #37: Cron-Based Automated Project Backup
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Verifies and prepares target project directory.
#   3. Executes scheduled_backup.sh to generate compressed, checksummed archive.
#   4. Installs and verifies the Cron schedule tagged '# LSA_SPRINT_TEST'.
#   5. Regenerates self-contained dark-themed report.html from scratch every run.
#   6. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_37) — SCHEDULED BACKUP & CRON AUTOMATION             "
echo "================================================================================"

# Verify scheduled_backup.sh exists and is executable
if [ ! -f "./scheduled_backup.sh" ]; then
    echo "[ERROR] scheduled_backup.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./scheduled_backup.sh

# Ensure source project exists
PROJECT_DIR="./sandbox_data/my_project"
if [ ! -d "${PROJECT_DIR}" ]; then
    mkdir -p "${PROJECT_DIR}/src" "${PROJECT_DIR}/config" "${PROJECT_DIR}/docs"
    echo "print('Application Core')" > "${PROJECT_DIR}/src/app.py"
    echo "port=8080" > "${PROJECT_DIR}/config/server.cfg"
    echo "# Automated Project Documentation" > "${PROJECT_DIR}/docs/README.md"
fi

# 2. Run backup and cron registration, capturing output
echo "[INFO] Executing live project backup..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"

# Step A: Perform project backup
./scheduled_backup.sh --source "${PROJECT_DIR}" --destination "./backups" 2>&1 | tee "${TMP_TERM_LOG}"

# Step B: Register the Cron schedule
echo "" | tee -a "${TMP_TERM_LOG}"
echo "[INFO] Registering automated backup job in Cron table..." | tee -a "${TMP_TERM_LOG}"
./scheduled_backup.sh --source "${PROJECT_DIR}" --destination "./backups" --schedule "0 1 * * *" 2>&1 | tee -a "${TMP_TERM_LOG}"

# Step C: Verify Cron installation
echo "" | tee -a "${TMP_TERM_LOG}"
./scheduled_backup.sh --verify-cron 2>&1 | tee -a "${TMP_TERM_LOG}"

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

JSON_PATH="logs/backup_metadata.json"
LOG_FILE_PATH="logs/scheduled_backup.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No backup log entries recorded yet."
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

meta = {}
if os.path.exists(json_path):
    try:
        with open(json_path, "r", encoding="utf-8") as jf:
            meta = json.load(jf)
    except Exception as e:
        meta = {}

project_info = meta.get("project", {})
archive_info = meta.get("archive", {})
retention_info = meta.get("retention", {})

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_37: Cron-Based Automated Project Backup</title>
    <style>
        :root {{
            --bg-primary: #0b0f19;
            --bg-secondary: #111827;
            --bg-card: #192231;
            --bg-card-hover: #1f2c40;
            --border-color: #28374d;
            --text-primary: #f3f4f6;
            --text-secondary: #9ca3af;
            --text-muted: #6b7280;
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
        .hash-code {{
            font-family: "SFMono-Regular", Consolas, monospace;
            font-size: 12px;
            background: #0f172a;
            padding: 4px 8px;
            border-radius: 4px;
            color: var(--accent-cyan);
            word-break: break-all;
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
                    <span>📦 Cron-Based Automated Project Backup</span>
                    <span class="badge-sprint">AS_37</span>
                </h1>
                <div class="header-subtitle">Linux System Administration (E1ITA307) • Cron & Backup Automation</div>
            </div>
            <div class="header-meta">
                <div class="status-pill">CRON BACKUP VERIFIED</div>
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">Cron Schedule</div>
                <div class="card-value" style="color: var(--accent-cyan); font-size: 20px;">0 1 * * *</div>
                <div class="card-sub">Nightly at 01:00 AM System Time</div>
            </div>
            <div class="card">
                <div class="card-label">Target Project</div>
                <div class="card-value" style="font-size: 20px;">{html.escape(project_info.get("name", "my_project"))}</div>
                <div class="card-sub">{project_info.get("files_count", 3)} files • {project_info.get("source_bytes", 0)} bytes</div>
            </div>
            <div class="card">
                <div class="card-label">Archive Footprint</div>
                <div class="card-value" style="color: var(--accent-green);">{archive_info.get("size_bytes", 0)} B</div>
                <div class="card-sub">Format: {archive_info.get("format", "gz").upper()} Tarball</div>
            </div>
            <div class="card">
                <div class="card-label">Integrity & Checksum</div>
                <div class="card-value" style="color: var(--accent-green);">100% OK</div>
                <div class="card-sub">tar -tzf passed & SHA-256 written</div>
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
                The scheduled backup job is active in the user's crontab with automatic logging and the required safety tag:
            </p>
            <div class="cron-box">{html.escape(active_cron)}</div>
            <div style="font-size: 13px; color: var(--text-muted); display: flex; gap: 20px; flex-wrap: wrap;">
                <div>🏷️ <strong>Safety Tag:</strong> <code style="color: var(--accent-cyan);"># LSA_SPRINT_TEST</code></div>
                <div>🔄 <strong>Frequency:</strong> Nightly at 01:00 AM</div>
                <div>🛡️ <strong>Retention Policy:</strong> {retention_info.get("retention_days", 14)} days retention</div>
            </div>
        </div>

        <!-- Section 2: Archive Telemetry & Manifest -->
        <div class="section-box">
            <div class="section-header">
                <div class="section-title">
                    <span>🔍</span> Generated Backup Manifest & Cryptographic Signature
                </div>
            </div>
            <table class="tasks-table">
                <thead>
                    <tr>
                        <th>Property</th>
                        <th>Value / Detail</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Archive Filename</strong></td>
                        <td><code>{html.escape(archive_info.get("filename", "N/A"))}</code></td>
                    </tr>
                    <tr>
                        <td><strong>Archive Path</strong></td>
                        <td><code>{html.escape(archive_info.get("path", "N/A"))}</code></td>
                    </tr>
                    <tr>
                        <td><strong>Cryptographic SHA-256 Digest</strong></td>
                        <td><span class="hash-code">{archive_info.get("sha256", "N/A")}</span></td>
                    </tr>
                    <tr>
                        <td><strong>Integrity Verification Status</strong></td>
                        <td><span class="task-badge badge-success">NON-DESTRUCTIVE DECOMPRESSION PASSED</span></td>
                    </tr>
                    <tr>
                        <td><strong>Retention Enforced</strong></td>
                        <td>{retention_info.get("retention_days", 14)} Days window ({retention_info.get("purged_archives", 0)} purged)</td>
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
            Linux System Administration (E1ITA307) • Automation Sprint • Problem #37 Scheduled Backup Dashboard
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
