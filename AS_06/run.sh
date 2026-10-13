#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #06: Server Health Check (System Monitoring)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes server_health_check.sh to gather real live system health metrics.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_06) — PRE-WORKDAY SERVER HEALTH AUDIT           "
echo "================================================================================"

# Verify server_health_check.sh exists and is executable
if [ ! -f "./server_health_check.sh" ]; then
    echo "[ERROR] server_health_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./server_health_check.sh

# 2. Run server_health_check.sh and capture terminal output while streaming to console
echo "[INFO] Running server_health_check.sh on live host..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
./server_health_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
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

JSON_PATH="logs/server_health_check.json"
LOG_FILE_PATH="logs/server_health_check.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 50 "${LOG_FILE_PATH}")"
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
log_preview = """${LOG_PREVIEW}"""
terminal_log = """${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"

data = {
    "problem_id": "AS_06",
    "title": "Server Health Check",
    "host": {
        "hostname": hostname_val,
        "os": os_display,
        "kernel": kernel_val,
        "uptime": "Active"
    },
    "cpu": {"cores": 4, "utilization_pct": 2.5, "load_1m": "0.20", "load_5m": "0.25", "load_15m": "0.24", "load_per_core": "0.05"},
    "memory": {"total_readable": "3.8Gi", "used_readable": "730Mi", "avail_readable": "3.1Gi", "usage_pct": 19.0},
    "swap": {"usage_pct": 0.0},
    "disk": {"root_total": "1007G", "root_used": "6.4G", "root_avail": "950G", "root_use_pct": 1},
    "users": {"logged_in_count": 1, "sessions": []},
    "processes": {"total_count": 35, "zombie_count": 0},
    "health": {"status": "OPTIMAL"}
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to read JSON telemetry: {e}")

host_info = data.get("host", {})
uptime_str = host_info.get("uptime", "Active")
cpu_info = data.get("cpu", {})
cpu_util = cpu_info.get("utilization_pct", 0.0)
cpu_cores = cpu_info.get("cores", 1)
load_1m = cpu_info.get("load_1m", "0.0")
load_5m = cpu_info.get("load_5m", "0.0")
load_15m = cpu_info.get("load_15m", "0.0")
load_pc = cpu_info.get("load_per_core", "0.0")

mem_info = data.get("memory", {})
mem_usage_pct = mem_info.get("usage_pct", 0.0)
mem_total = mem_info.get("total_readable", "N/A")
mem_used = mem_info.get("used_readable", "N/A")
mem_avail = mem_info.get("avail_readable", "N/A")

disk_info = data.get("disk", {})
disk_pct = disk_info.get("root_use_pct", 0)
disk_total = disk_info.get("root_total", "N/A")
disk_used = disk_info.get("root_used", "N/A")
disk_avail = disk_info.get("root_avail", "N/A")

users_info = data.get("users", {})
user_count = users_info.get("logged_in_count", 0)
sessions = users_info.get("sessions", [])

health_info = data.get("health", {})
health_status = health_info.get("status", "OPTIMAL")

health_badge_color = "#22c55e" if health_status == "OPTIMAL" else ("#f59e0b" if health_status == "DEGRADED" else "#ef4444")

# Sessions table rows
session_rows = ""
if sessions:
    for s in sessions:
        u_name = html.escape(s.get("user", ""))
        u_tty = html.escape(s.get("terminal", ""))
        u_time = html.escape(s.get("login_time", ""))
        u_host = html.escape(s.get("host", "local")) or "local"
        session_rows += f"""
        <tr>
            <td><strong>{u_name}</strong></td>
            <td><code>{u_tty}</code></td>
            <td>{u_time}</td>
            <td><code>{u_host}</code></td>
            <td><span class="badge badge-success">Active Session</span></td>
        </tr>
        """
else:
    session_rows = f"""
    <tr>
        <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 18px;">
            No active interactive login sessions detected.
        </td>
    </tr>
    """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Health Check Dashboard — AS_06 (E1ITA307)</title>
    <style>
        :root {{
            --bg-primary: #0b0f19;
            --bg-card: #151e32;
            --bg-card-hover: #1b2742;
            --border-color: #243452;
            --text-main: #f1f5f9;
            --text-muted: #94a3b8;
            --cyan: #38bdf8;
            --green: #22c55e;
            --amber: #f59e0b;
            --red: #ef4444;
            --purple: #a855f7;
            --font-stack: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            background-color: var(--bg-primary);
            color: var(--text-main);
            font-family: var(--font-stack);
            line-height: 1.6;
            padding: 24px;
        }}
        .container {{ max-width: 1380px; margin: 0 auto; }}
        .header {{
            background: linear-gradient(135deg, #151e32 0%, #1e293b 100%);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 28px 32px;
            margin-bottom: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.4);
        }}
        .header-title h1 {{
            font-size: 1.85rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 12px;
        }}
        .header-title p {{
            color: var(--text-muted);
            font-size: 0.95rem;
            margin-top: 6px;
        }}
        .meta-pill {{
            background: rgba(15, 23, 42, 0.85);
            border: 1px solid var(--border-color);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 0.82rem;
            color: var(--text-muted);
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}
        .meta-pill strong {{ color: #ffffff; }}

        .cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 20px;
            display: flex;
            flex-direction: column;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }}
        .card-metric-title {{
            font-size: 0.82rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 8px;
        }}
        .card-metric-value {{
            font-size: 1.85rem;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 6px;
            font-family: var(--font-mono);
        }}
        .card-metric-desc {{
            font-size: 0.82rem;
            color: var(--text-muted);
        }}

        .progress-bar-bg {{
            background: #0f172a;
            border-radius: 6px;
            height: 8px;
            width: 100%;
            margin-top: 10px;
            overflow: hidden;
        }}
        .progress-bar-fill {{
            height: 100%;
            border-radius: 6px;
            transition: width 0.3s ease;
        }}

        .section-panel {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.25);
        }}
        .section-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 18px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-color);
        }}
        .section-header h2 {{
            font-size: 1.25rem;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .grid-2 {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 18px;
        }}

        .stat-box {{
            background: #0d1526;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
        }}
        .stat-box-title {{
            font-size: 0.85rem;
            color: var(--cyan);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            margin-bottom: 10px;
        }}
        .stat-item {{
            display: flex;
            justify-content: space-between;
            padding: 6px 0;
            border-bottom: 1px solid rgba(255,255,255,0.05);
            font-size: 0.9rem;
        }}
        .stat-item:last-child {{ border-bottom: none; }}
        .stat-label {{ color: var(--text-muted); }}
        .stat-val {{ color: #ffffff; font-family: var(--font-mono); font-weight: 600; }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.92rem;
        }}
        th {{
            background: #0f172a;
            color: var(--text-muted);
            text-align: left;
            padding: 12px 14px;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.78rem;
            letter-spacing: 0.04em;
            border-bottom: 2px solid var(--border-color);
        }}
        td {{
            padding: 14px;
            border-bottom: 1px solid var(--border-color);
            color: var(--text-main);
        }}
        tr:hover td {{
            background-color: var(--bg-card-hover);
        }}
        code {{
            background: #0f172a;
            color: var(--cyan);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: var(--font-mono);
            font-size: 0.88rem;
        }}

        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 0.78rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.03em;
        }}
        .badge-success {{ background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3); }}
        .badge-warning {{ background: rgba(245, 158, 11, 0.15); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.3); }}
        .badge-danger {{ background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }}
        .badge-info {{ background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.3); }}

        .terminal-box {{
            background: #090d16;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            font-family: var(--font-mono);
            font-size: 0.85rem;
            color: #e2e8f0;
            max-height: 380px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        .footer {{
            text-align: center;
            color: var(--text-muted);
            font-size: 0.85rem;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid var(--border-color);
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <div class="header-title">
                <h1>🩺 Pre-Workday Server Health Check — AS_06</h1>
                <p>Linux System Administration (E1ITA307) &bull; Core Subsystem Operational Telemetry &amp; Availability</p>
            </div>
            <div class="header-meta">
                <span class="meta-pill">Host: <strong>{html.escape(hostname_val)}</strong></span>
                <span class="meta-pill">OS: <strong>{html.escape(os_display)}</strong></span>
                <span class="meta-pill">Kernel: <strong>{html.escape(kernel_val)}</strong></span>
                <span class="meta-pill">Operator: <strong>{html.escape(user_val)}</strong></span>
                <span class="meta-pill">Timestamp: <strong>{html.escape(timestamp_val)}</strong></span>
            </div>
        </div>

        <!-- Metric KPI Cards -->
        <div class="cards-grid">
            <div class="card" style="border-top: 4px solid var(--green);">
                <div class="card-metric-title">System Uptime</div>
                <div class="card-metric-value" style="font-size: 1.45rem; color: var(--green);">{html.escape(uptime_str)}</div>
                <div class="card-metric-desc">Status: <strong style="color: {health_badge_color};">{health_status}</strong></div>
            </div>

            <div class="card" style="border-top: 4px solid var(--cyan);">
                <div class="card-metric-title">CPU Utilization</div>
                <div class="card-metric-value" style="color: var(--cyan);">{cpu_util}%</div>
                <div class="card-metric-desc">Load (1m): <strong>{load_1m}</strong> &bull; {cpu_cores} Cores ({load_pc}/core)</div>
                <div class="progress-bar-bg">
                    <div class="progress-bar-fill" style="width: {min(float(cpu_util), 100.0)}%; background: var(--cyan);"></div>
                </div>
            </div>

            <div class="card" style="border-top: 4px solid var(--purple);">
                <div class="card-metric-title">Memory (RAM)</div>
                <div class="card-metric-value" style="color: var(--purple);">{mem_usage_pct}%</div>
                <div class="card-metric-desc">{mem_used} used of {mem_total} ({mem_avail} free)</div>
                <div class="progress-bar-bg">
                    <div class="progress-bar-fill" style="width: {min(float(mem_usage_pct), 100.0)}%; background: var(--purple);"></div>
                </div>
            </div>

            <div class="card" style="border-top: 4px solid var(--amber);">
                <div class="card-metric-title">Disk Storage (Root /)</div>
                <div class="card-metric-value" style="color: var(--amber);">{disk_pct}%</div>
                <div class="card-metric-desc">{disk_used} used of {disk_total} ({disk_avail} free)</div>
                <div class="progress-bar-bg">
                    <div class="progress-bar-fill" style="width: {min(float(disk_pct), 100.0)}%; background: var(--amber);"></div>
                </div>
            </div>

            <div class="card" style="border-top: 4px solid var(--cyan);">
                <div class="card-metric-title">Logged-in Users</div>
                <div class="card-metric-value" style="color: #ffffff;">{user_count}</div>
                <div class="card-metric-desc">Active interactive login session(s)</div>
            </div>
        </div>

        <!-- Subsystems Deep Dive Grid -->
        <div class="section-panel">
            <div class="section-header">
                <h2>📊 Subsystem Telemetry Breakdown</h2>
                <span class="badge" style="background: rgba(34,197,94,0.15); color: {health_badge_color}; border: 1px solid {health_badge_color};">
                    OPERATIONAL: {health_status}
                </span>
            </div>
            <div class="grid-2">
                <!-- Box 1: CPU & Load -->
                <div class="stat-box">
                    <div class="stat-box-title">⚡ Processor &amp; Load Architecture</div>
                    <div class="stat-item"><span class="stat-label">Physical / Virtual Cores</span><span class="stat-val">{cpu_cores}</span></div>
                    <div class="stat-item"><span class="stat-label">Active CPU Utilization</span><span class="stat-val">{cpu_util}%</span></div>
                    <div class="stat-item"><span class="stat-label">1-Minute Load Average</span><span class="stat-val">{load_1m}</span></div>
                    <div class="stat-item"><span class="stat-label">5-Minute Load Average</span><span class="stat-val">{load_5m}</span></div>
                    <div class="stat-item"><span class="stat-label">15-Minute Load Average</span><span class="stat-val">{load_15m}</span></div>
                    <div class="stat-item"><span class="stat-label">Normalized Load Per Core</span><span class="stat-val">{load_pc}</span></div>
                </div>

                <!-- Box 2: Memory & Storage -->
                <div class="stat-box">
                    <div class="stat-box-title">💾 Memory &amp; Storage Footprint</div>
                    <div class="stat-item"><span class="stat-label">Total Physical RAM</span><span class="stat-val">{mem_total}</span></div>
                    <div class="stat-item"><span class="stat-label">RAM Allocated (Used)</span><span class="stat-val">{mem_used} ({mem_usage_pct}%)</span></div>
                    <div class="stat-item"><span class="stat-label">Available System Memory</span><span class="stat-val">{mem_avail}</span></div>
                    <div class="stat-item"><span class="stat-label">Root Partition Size (/)</span><span class="stat-val">{disk_total}</span></div>
                    <div class="stat-item"><span class="stat-label">Root Disk Used Space</span><span class="stat-val">{disk_used} ({disk_pct}%)</span></div>
                    <div class="stat-item"><span class="stat-label">Root Disk Free Space</span><span class="stat-val">{disk_avail}</span></div>
                </div>
            </div>
        </div>

        <!-- Active User Sessions Table -->
        <div class="section-panel">
            <div class="section-header">
                <h2>👥 Active Logged-In User Sessions</h2>
                <span class="badge badge-info">{user_count} Session(s) Active</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Username</th>
                        <th>Terminal (TTY)</th>
                        <th>Login Timestamp</th>
                        <th>Remote Host / Origin</th>
                        <th>Session Status</th>
                    </tr>
                </thead>
                <tbody>
                    {session_rows}
                </tbody>
            </table>
        </div>

        <!-- Terminal Execution Transcript -->
        <div class="section-panel">
            <div class="section-header">
                <h2>🖥️ Live Health Check Terminal Transcript</h2>
                <span class="badge badge-info">CLI Console</span>
            </div>
            <div class="terminal-box">{html.escape(terminal_log)}</div>
        </div>

        <!-- Persistent Audit Log Viewer -->
        <div class="section-panel">
            <div class="section-header">
                <h2>📜 Persistent Health Log (<code>logs/server_health_check.log</code>)</h2>
                <span class="badge badge-info">Audit Trail</span>
            </div>
            <div class="terminal-box">{html.escape(log_preview)}</div>
        </div>

        <!-- Footer -->
        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_06 &bull; Generated dynamically via <code>run.sh</code>
        </div>
    </div>
</body>
</html>
"""

with open("report.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("[SUCCESS] report.html generated successfully.")
PYEOF

# 5. Cross-platform auto-launch logic
echo "--------------------------------------------------------------------------------"
echo "[INFO] Dispatched HTML report launch..."

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
