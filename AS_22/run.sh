#!/usr/bin/env bash
# ==============================================================================
# Course: Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #22: Multiple Server Check
# Focus: Network Automation, Multi-Host Probing & Inventory Status Reporting
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes multi_server_check.sh to probe real server inventory in parallel.
#   3. Regenerates a self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in the default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_22) — MULTIPLE SERVER HEALTH CHECK              "
echo "================================================================================"

# Verify multi_server_check.sh exists and is executable
if [ ! -f "./multi_server_check.sh" ]; then
    echo "[ERROR] multi_server_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./multi_server_check.sh

# Verify inventory file exists
if [ ! -f "./servers.txt" ]; then
    echo "[ERROR] servers.txt inventory file not found in $(pwd)!" >&2
    exit 1
fi

# 2. Run multi_server_check.sh and capture terminal output while streaming to console
echo "[INFO] Running multi_server_check.sh on live server inventory..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'msc_term')"
./multi_server_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & live environment metadata for report generation
export OS_NAME="$(uname -s)"
export HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
export KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
export TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
export USER_VAL="$(whoami 2>/dev/null || echo 'User')"

# OS Display Name
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    export OS_DISPLAY="${PRETTY_NAME:-$OS_NAME}"
elif [ "${OS_NAME}" = "Darwin" ]; then
    export OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    export OS_DISPLAY="${OS_NAME}"
fi

# Live Network Route & Interface Telemetry
PRIMARY_IFACE=""
LOCAL_IP=""
DEFAULT_GW=""
DNS_SERVERS=""

if command -v ip >/dev/null 2>&1; then
    DEFAULT_GW="$(ip route 2>/dev/null | grep -E '^default ' | awk '{print $3}' | head -n 1 || echo 'N/A')"
    PRIMARY_IFACE="$(ip route 2>/dev/null | grep -E '^default ' | awk '{print $5}' | head -n 1 || echo 'eth0')"
    if [ -n "${PRIMARY_IFACE}" ] && [ "${PRIMARY_IFACE}" != "N/A" ]; then
        LOCAL_IP="$(ip -4 addr show dev "${PRIMARY_IFACE}" 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -n 1 || echo 'N/A')"
    fi
elif command -v route >/dev/null 2>&1; then
    DEFAULT_GW="$(route -n 2>/dev/null | awk '/^0.0.0.0/ {print $2; exit}' || echo 'N/A')"
fi

[ -z "${DEFAULT_GW}" ] && DEFAULT_GW="N/A"
[ -z "${PRIMARY_IFACE}" ] && PRIMARY_IFACE="eth0"
[ -z "${LOCAL_IP}" ] && LOCAL_IP="N/A"

export PRIMARY_IFACE
export LOCAL_IP
export DEFAULT_GW

# DNS Nameservers
if [ -f /etc/resolv.conf ]; then
    export DNS_SERVERS="$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/, $//' || echo 'System Default')"
else
    export DNS_SERVERS="System Default"
fi

# Read captured terminal output
export TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# Read latest audit log content
LOG_FILE_PATH="logs/multi_server_check.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    export LOG_PREVIEW="$(tail -n 80 "${LOG_FILE_PATH}")"
else
    export LOG_PREVIEW="No audit log entries recorded yet."
fi

# 4. Generate report.html from scratch using inline Python 3 processor
echo "[INFO] Regenerating report.html dashboard with live telemetry..."

python3 - << 'PYEOF'
import html
import os
import re
import sys

# Retrieve environment variables
os_display = os.environ.get("OS_DISPLAY", "Linux").strip()
os_name = os.environ.get("OS_NAME", "Linux").strip()
hostname = os.environ.get("HOSTNAME_VAL", "localhost").strip()
kernel = os.environ.get("KERNEL_VAL", "Unknown").strip()
timestamp = os.environ.get("TIMESTAMP_VAL", "").strip()
user = os.environ.get("USER_VAL", "User").strip()
primary_iface = os.environ.get("PRIMARY_IFACE", "eth0").strip()
local_ip = os.environ.get("LOCAL_IP", "N/A").strip()
default_gw = os.environ.get("DEFAULT_GW", "N/A").strip()
dns_servers = os.environ.get("DNS_SERVERS", "N/A").strip()
terminal_log = os.environ.get("TERMINAL_LOG_CONTENT", "").strip()
log_preview = os.environ.get("LOG_PREVIEW", "").strip()

# Load structured last run records
last_run_path = os.path.join("logs", ".last_run.dat")
meta = {
    "TOTAL": "0",
    "UP": "0",
    "DOWN": "0",
    "AVAIL": "0.0",
    "TIME": "0",
    "MODE": "Parallel Concurrent",
    "TIMESTAMP": timestamp
}
servers = []

if os.path.exists(last_run_path):
    with open(last_run_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("# METADATA|"):
                parts = line[len("# METADATA|"):].split("|")
                for p in parts:
                    if "=" in p:
                        k, v = p.split("=", 1)
                        meta[k.strip()] = v.strip()
            elif "|" in line:
                # Format: INDEX|TARGET|LABEL|STATUS|LOSS_PCT|AVG_RTT|MIN_RTT|MAX_RTT|SENT|RECEIVED|ERR_NOTE
                fields = line.split("|")
                if len(fields) >= 11:
                    servers.append({
                        "index": fields[0],
                        "target": fields[1],
                        "label": fields[2],
                        "status": fields[3],
                        "loss": fields[4],
                        "avg_rtt": fields[5],
                        "min_rtt": fields[6],
                        "max_rtt": fields[7],
                        "sent": fields[8],
                        "received": fields[9],
                        "note": fields[10]
                    })

total_count = int(meta.get("TOTAL", len(servers)) or len(servers))
up_count = int(meta.get("UP", 0) or 0)
down_count = int(meta.get("DOWN", 0) or 0)
avail_pct = meta.get("AVAIL", "0.0")
exec_time = meta.get("TIME", "0")
exec_mode = meta.get("MODE", "Parallel Concurrent")
scan_ts = meta.get("TIMESTAMP", timestamp)

# Build table rows HTML
table_rows = []
for s in servers:
    status_cls = "badge-up" if s["status"] == "UP" else "badge-down"
    status_icon = "●"
    
    # Loss progress bar color
    try:
        loss_val = float(s["loss"].replace("%", ""))
    except ValueError:
        loss_val = 0.0
    
    if loss_val == 0.0:
        bar_color = "#22c55e"
    elif loss_val < 100.0:
        bar_color = "#eab308"
    else:
        bar_color = "#ef4444"
        
    avg_rtt_display = html.escape(s["avg_rtt"])
    if s["avg_rtt"] != "N/A":
        avg_rtt_display = f"<span class='latency-val'>{avg_rtt_display}</span>"
    else:
        avg_rtt_display = "<span class='text-muted'>N/A</span>"
        
    min_max_display = "N/A"
    if s["min_rtt"] != "N/A" and s["max_rtt"] != "N/A":
        min_max_display = f"<span class='text-sm text-secondary'>{html.escape(s['min_rtt'])} / {html.escape(s['max_rtt'])}</span>"
    else:
        min_max_display = "<span class='text-muted'>N/A</span>"

    packets_display = f"<strong>{html.escape(s['received'])}</strong> / {html.escape(s['sent'])}"
    
    # Row filter class
    filter_cls = "row-up" if s["status"] == "UP" else "row-down"
    
    row_html = f"""
    <tr class="server-row {filter_cls}">
        <td class="col-target">
            <div class="target-name">{html.escape(s["target"])}</div>
            <div class="target-sub">{html.escape(s["label"])}</div>
        </td>
        <td class="col-status">
            <span class="badge {status_cls}">{status_icon} {html.escape(s["status"])}</span>
        </td>
        <td class="col-loss">
            <div class="loss-container">
                <div class="loss-bar-bg">
                    <div class="loss-bar-fill" style="width: {loss_val}%; background-color: {bar_color};"></div>
                </div>
                <span class="loss-text">{html.escape(s["loss"])}</span>
            </div>
        </td>
        <td class="col-rtt">{avg_rtt_display}</td>
        <td class="col-minmax">{min_max_display}</td>
        <td class="col-packets">{packets_display}</td>
        <td class="col-note">
            <span class="note-pill {'note-ok' if s['status'] == 'UP' else 'note-err'}">{html.escape(s["note"])}</span>
        </td>
    </tr>
    """
    table_rows.append(row_html)

table_rows_html = "\n".join(table_rows)

# Strip ANSI codes from terminal log for clean display
ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
clean_terminal_log = ansi_escape.sub('', terminal_log)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Multiple Server Health Check — AS_22 Dashboard</title>
    <style>
        :root {{
            --bg-primary: #0b0f19;
            --bg-secondary: #111827;
            --bg-card: #1f2937;
            --bg-card-hover: #283548;
            --border-color: #374151;
            --border-accent: #4b5563;
            --text-primary: #f9fafb;
            --text-secondary: #9ca3af;
            --text-muted: #6b7280;
            --accent-cyan: #06b6d4;
            --accent-blue: #3b82f6;
            --accent-purple: #8b5cf6;
            --status-green: #10b981;
            --status-green-bg: rgba(16, 185, 129, 0.15);
            --status-red: #ef4444;
            --status-red-bg: rgba(239, 68, 68, 0.15);
            --status-yellow: #f59e0b;
            --status-yellow-bg: rgba(245, 158, 11, 0.15);
            --shadow-subtle: 0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -1px rgba(0, 0, 0, 0.2);
            --shadow-glow: 0 0 20px rgba(6, 182, 212, 0.15);
            --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            background-color: var(--bg-primary);
            color: var(--text-primary);
            font-family: var(--font-family);
            line-height: 1.5;
            padding: 24px;
            min-height: 100vh;
        }}

        .dashboard-container {{
            max-width: 1280px;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            gap: 24px;
        }}

        /* Header Card */
        .header-card {{
            background: linear-gradient(135deg, rgba(31, 41, 55, 0.9) 0%, rgba(17, 24, 39, 0.95) 100%);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 28px 32px;
            box-shadow: var(--shadow-subtle), var(--shadow-glow);
            position: relative;
            overflow: hidden;
        }}

        .header-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 4px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-purple));
        }}

        .header-top {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 16px;
            margin-bottom: 20px;
        }}

        .header-title-group h1 {{
            font-size: 26px;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 12px;
        }}

        .header-subtitle {{
            font-size: 14px;
            color: var(--text-secondary);
            margin-top: 4px;
        }}

        .header-badges {{
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }}

        .badge-pill {{
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 9999px;
            border: 1px solid var(--border-color);
            background-color: rgba(255, 255, 255, 0.05);
            color: var(--text-secondary);
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}

        .badge-cyan {{
            background-color: rgba(6, 182, 212, 0.15);
            color: var(--accent-cyan);
            border-color: rgba(6, 182, 212, 0.3);
        }}

        .badge-purple {{
            background-color: rgba(139, 92, 246, 0.15);
            color: var(--accent-purple);
            border-color: rgba(139, 92, 246, 0.3);
        }}

        /* System Info Strip */
        .system-strip {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            padding-top: 16px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
            font-size: 13px;
        }}

        .sys-item {{
            display: flex;
            flex-direction: column;
            gap: 2px;
        }}

        .sys-label {{
            color: var(--text-muted);
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            font-weight: 600;
        }}

        .sys-val {{
            color: var(--text-primary);
            font-family: var(--font-mono);
            font-size: 12px;
            word-break: break-all;
        }}

        /* Metrics Summary Grid */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
        }}

        .metric-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 20px 24px;
            box-shadow: var(--shadow-subtle);
            display: flex;
            flex-direction: column;
            gap: 8px;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}

        .metric-card:hover {{
            transform: translateY(-2px);
            border-color: var(--border-accent);
        }}

        .metric-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .metric-title {{
            font-size: 12px;
            color: var(--text-secondary);
            text-transform: uppercase;
            font-weight: 600;
            letter-spacing: 0.04em;
        }}

        .metric-icon {{
            font-size: 18px;
        }}

        .metric-value {{
            font-size: 32px;
            font-weight: 700;
            line-height: 1.1;
        }}

        .val-cyan {{ color: var(--accent-cyan); }}
        .val-green {{ color: var(--status-green); }}
        .val-red {{ color: var(--status-red); }}
        .val-purple {{ color: var(--accent-purple); }}

        .metric-subtext {{
            font-size: 12px;
            color: var(--text-muted);
        }}

        /* Main Table Section */
        .table-section {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 24px;
            box-shadow: var(--shadow-subtle);
            display: flex;
            flex-direction: column;
            gap: 20px;
        }}

        .table-toolbar {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }}

        .toolbar-title {{
            font-size: 18px;
            font-weight: 600;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .filter-controls {{
            display: flex;
            gap: 8px;
            background-color: var(--bg-secondary);
            padding: 4px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }}

        .filter-btn {{
            background: none;
            border: none;
            color: var(--text-secondary);
            font-size: 12px;
            font-weight: 600;
            padding: 6px 14px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.15s ease;
        }}

        .filter-btn:hover {{
            color: var(--text-primary);
        }}

        .filter-btn.active {{
            background-color: var(--bg-card);
            color: var(--text-primary);
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
        }}

        .table-responsive {{
            overflow-x: auto;
            border-radius: 10px;
            border: 1px solid var(--border-color);
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 13px;
        }}

        th {{
            background-color: var(--bg-secondary);
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 11px;
            letter-spacing: 0.05em;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-color);
            white-space: nowrap;
        }}

        td {{
            padding: 14px 16px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            vertical-align: middle;
        }}

        tr:last-child td {{
            border-bottom: none;
        }}

        tr.server-row:hover td {{
            background-color: var(--bg-card-hover);
        }}

        .col-target {{
            min-width: 220px;
        }}

        .target-name {{
            font-family: var(--font-mono);
            font-weight: 600;
            color: var(--text-primary);
            font-size: 14px;
        }}

        .target-sub {{
            font-size: 11px;
            color: var(--text-secondary);
            margin-top: 2px;
        }}

        .badge {{
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 6px;
            letter-spacing: 0.03em;
        }}

        .badge-up {{
            background-color: var(--status-green-bg);
            color: var(--status-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .badge-down {{
            background-color: var(--status-red-bg);
            color: var(--status-red);
            border: 1px solid rgba(239, 68, 68, 0.3);
        }}

        /* Loss Bar */
        .loss-container {{
            display: flex;
            align-items: center;
            gap: 8px;
            min-width: 110px;
        }}

        .loss-bar-bg {{
            flex: 1;
            height: 6px;
            background-color: rgba(255, 255, 255, 0.1);
            border-radius: 3px;
            overflow: hidden;
        }}

        .loss-bar-fill {{
            height: 100%;
            border-radius: 3px;
        }}

        .loss-text {{
            font-family: var(--font-mono);
            font-size: 12px;
            width: 36px;
            text-align: right;
            font-weight: 600;
        }}

        .latency-val {{
            font-family: var(--font-mono);
            font-weight: 600;
            color: var(--accent-cyan);
        }}

        .text-secondary {{ color: var(--text-secondary); }}
        .text-muted {{ color: var(--text-muted); }}
        .text-sm {{ font-size: 11px; }}

        .col-packets {{
            font-family: var(--font-mono);
            font-size: 12px;
            white-space: nowrap;
        }}

        .note-pill {{
            display: inline-block;
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 4px;
            max-width: 240px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}

        .note-ok {{
            background-color: rgba(16, 185, 129, 0.1);
            color: var(--status-green);
        }}

        .note-err {{
            background-color: rgba(239, 68, 68, 0.1);
            color: var(--status-red);
        }}

        /* Technical Reference Cards */
        .architecture-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 16px;
        }}

        .info-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 20px;
            box-shadow: var(--shadow-subtle);
        }}

        .info-card h3 {{
            font-size: 14px;
            font-weight: 600;
            color: var(--accent-cyan);
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
            text-transform: uppercase;
            letter-spacing: 0.03em;
        }}

        .info-card p, .info-card li {{
            font-size: 13px;
            color: var(--text-secondary);
            line-height: 1.6;
        }}

        .info-card ul {{
            padding-left: 18px;
            margin-top: 8px;
        }}

        .info-card code {{
            background-color: var(--bg-secondary);
            color: #e2e8f0;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: var(--font-mono);
            font-size: 12px;
        }}

        /* Collapsible Section */
        details.console-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            overflow: hidden;
            box-shadow: var(--shadow-subtle);
        }}

        details.console-card summary {{
            padding: 16px 20px;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
            background-color: var(--bg-secondary);
            color: var(--text-primary);
            user-select: none;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}

        details.console-card summary:hover {{
            color: var(--accent-cyan);
        }}

        .console-body {{
            padding: 16px 20px;
            background-color: #0d1117;
            overflow-x: auto;
        }}

        pre.code-block {{
            font-family: var(--font-mono);
            font-size: 12px;
            line-height: 1.45;
            color: #c9d1d9;
            margin: 0;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        /* Footer */
        .footer {{
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
            padding: 16px;
            border-top: 1px solid var(--border-color);
        }}

        .footer a {{
            color: var(--accent-cyan);
            text-decoration: none;
        }}

        .footer a:hover {{
            text-decoration: underline;
        }}
    </style>
</head>
<body>
    <div class="dashboard-container">
        
        <!-- Header Card -->
        <header class="header-card">
            <div class="header-top">
                <div class="header-title-group">
                    <h1>
                        <span>⚡ Multi-Server Health Check</span>
                    </h1>
                    <div class="header-subtitle">
                        Course: Linux System Administration (E1ITA307) — Automation Sprint (Problem Statement #22)
                    </div>
                </div>
                <div class="header-badges">
                    <span class="badge-pill badge-cyan">Network Automation</span>
                    <span class="badge-pill badge-purple">{html.escape(exec_mode)}</span>
                    <span class="badge-pill">Self-Contained Report</span>
                </div>
            </div>

            <div class="system-strip">
                <div class="sys-item">
                    <span class="sys-label">Target Machine</span>
                    <span class="sys-val">{html.escape(hostname)}</span>
                </div>
                <div class="sys-item">
                    <span class="sys-label">Operating System</span>
                    <span class="sys-val">{html.escape(os_display)}</span>
                </div>
                <div class="sys-item">
                    <span class="sys-label">Kernel Version</span>
                    <span class="sys-val">{html.escape(kernel)}</span>
                </div>
                <div class="sys-item">
                    <span class="sys-label">Default Gateway</span>
                    <span class="sys-val">{html.escape(default_gw)}</span>
                </div>
                <div class="sys-item">
                    <span class="sys-label">Local Egress IP</span>
                    <span class="sys-val">{html.escape(local_ip)} ({html.escape(primary_iface)})</span>
                </div>
                <div class="sys-item">
                    <span class="sys-label">Audit Timestamp</span>
                    <span class="sys-val">{html.escape(scan_ts)}</span>
                </div>
            </div>
        </header>

        <!-- Metric Summary Cards -->
        <section class="metrics-grid">
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-title">Total Targets</span>
                    <span class="metric-icon">🖥️</span>
                </div>
                <div class="metric-value val-cyan">{total_count}</div>
                <div class="metric-subtext">Configured in servers.txt</div>
            </div>

            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-title">Servers Reachable (UP)</span>
                    <span class="metric-icon">✅</span>
                </div>
                <div class="metric-value val-green">{up_count}</div>
                <div class="metric-subtext">Responding to ICMP echo</div>
            </div>

            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-title">Servers Down</span>
                    <span class="metric-icon">❌</span>
                </div>
                <div class="metric-value val-red">{down_count}</div>
                <div class="metric-subtext">100% loss or ICMP filtered</div>
            </div>

            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-title">Fleet Availability</span>
                    <span class="metric-icon">📊</span>
                </div>
                <div class="metric-value val-purple">{avail_pct}%</div>
                <div class="metric-subtext">Success ratio across targets</div>
            </div>

            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-title">Execution Wall-Time</span>
                    <span class="metric-icon">⏱️</span>
                </div>
                <div class="metric-value">{exec_time}s</div>
                <div class="metric-subtext">Parallel backgrounded &amp; wait</div>
            </div>
        </section>

        <!-- Table Section -->
        <section class="table-section">
            <div class="table-toolbar">
                <div class="toolbar-title">
                    <span>📡 Target Inventory Health Status</span>
                </div>
                <div class="filter-controls">
                    <button class="filter-btn active" onclick="filterTable('all', this)">All ({total_count})</button>
                    <button class="filter-btn" onclick="filterTable('up', this)">UP Only ({up_count})</button>
                    <button class="filter-btn" onclick="filterTable('down', this)">DOWN Only ({down_count})</button>
                </div>
            </div>

            <div class="table-responsive">
                <table id="serverTable">
                    <thead>
                        <tr>
                            <th>Target Host &amp; Role</th>
                            <th>Status</th>
                            <th>Packet Loss</th>
                            <th>Average RTT</th>
                            <th>Min / Max RTT</th>
                            <th>Packets (Recv/Sent)</th>
                            <th>Diagnostic Note</th>
                        </tr>
                    </thead>
                    <tbody>
                        {table_rows_html}
                    </tbody>
                </table>
            </div>
        </section>

        <!-- Technical Reference Grid -->
        <section class="architecture-grid">
            <div class="info-card">
                <h3>⚡ Parallel vs. Sequential Concurrency</h3>
                <p>
                    Sequential execution iterates over targets one-by-one with runtime <code>O(N × timeout)</code>. 
                    If 5 hosts are unreachable with a 2s timeout, sequential probing stalls for 10+ seconds.
                </p>
                <ul>
                    <li><strong>Parallel Model:</strong> Probes are launched concurrently as subshells (<code>&amp;</code>) writing to numbered slot files, synchronized via bash <code>wait</code>.</li>
                    <li><strong>Wall-Clock Scalability:</strong> Total runtime collapses to <code>O(timeout)</code> (~2-3 seconds for entire fleet).</li>
                    <li><strong>Deterministic Order:</strong> Preserves inventory configuration ordering upon table rendering.</li>
                </ul>
            </div>

            <div class="info-card">
                <h3>🔍 Network Diagnostic Nuance</h3>
                <p>
                    Why do certain targets report <strong>DOWN</strong> in this live test?
                </p>
                <ul>
                    <li><strong>192.168.32.1 (WSL2 Gateway):</strong> The default gateway is the Hyper-V virtual switch adapter. Windows Defender Firewall drops incoming ICMP Echo Requests by default, while routing external WAN traffic normally.</li>
                    <li><strong>192.0.2.1 (TEST-NET-1):</strong> Reserved by RFC 5737 for documentation and benchmarking. It is intentionally non-routable on the public Internet, verifying proper 100% loss trapping.</li>
                </ul>
            </div>

            <div class="info-card">
                <h3>🛠️ Cross-Platform Portability</h3>
                <p>
                    Network probe flags diverge across Unix distributions and Windows environments:
                </p>
                <ul>
                    <li><strong>Linux (iputils):</strong> <code>ping -c 2 -W 2 &lt;host&gt;</code> (packet count and hard timeout).</li>
                    <li><strong>macOS (BSD):</strong> <code>ping -c 2 -t 2 &lt;host&gt;</code> (timeout flag <code>-t</code>).</li>
                    <li><strong>Windows Native:</strong> <code>ping -n 2 -w 2000 &lt;host&gt;</code> (count <code>-n</code> and millisecond timeout <code>-w</code>).</li>
                </ul>
            </div>
        </section>

        <!-- Live Terminal Log Accordion -->
        <details class="console-card">
            <summary>
                <span>💻 Raw Terminal Execution Output (Captured from live run)</span>
                <span style="font-size: 12px; color: var(--text-muted);">Click to toggle</span>
            </summary>
            <div class="console-body">
                <pre class="code-block">{html.escape(clean_terminal_log)}</pre>
            </div>
        </details>

        <!-- Chronological Audit Log Accordion -->
        <details class="console-card">
            <summary>
                <span>📜 Chronological Audit Log (logs/multi_server_check.log)</span>
                <span style="font-size: 12px; color: var(--text-muted);">Click to toggle</span>
            </summary>
            <div class="console-body">
                <pre class="code-block">{html.escape(log_preview)}</pre>
            </div>
        </details>

        <!-- Footer -->
        <footer class="footer">
            Linux System Administration (E1ITA307) — Automation Sprint Problem #22 &bull; Multiple Server Check<br>
            Automated Live Telemetry Generated at {html.escape(timestamp)} on {html.escape(hostname)}
        </footer>

    </div>

    <!-- Client-side Interactive Filter Script -->
    <script>
        function filterTable(type, btn) {{
            document.querySelectorAll('.filter-btn').forEach(function(b) {{ b.classList.remove('active'); }});
            btn.classList.add('active');

            const rows = document.querySelectorAll('#serverTable tbody tr');
            rows.forEach(function(row) {{
                if (type === 'all') {{
                    row.style.display = '';
                }} else if (type === 'up') {{
                    row.style.display = row.classList.contains('row-up') ? '' : 'none';
                }} else if (type === 'down') {{
                    row.style.display = row.classList.contains('row-down') ? '' : 'none';
                }}
            }});
        }}
    </script>
</body>
</html>
"""

report_path = "report.html"
with open(report_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[SUCCESS] report.html regenerated successfully ({len(html_content)} bytes).")
PYEOF

# 5. Open report.html automatically, detecting the OS
echo ""
echo "================================================================================"
echo "🚀 Dispatching report.html to Web Browser..."
echo "================================================================================"

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
# E. Python Webbrowser module fallback
elif command -v python3 >/dev/null 2>&1; then
    echo "[INFO] Attempting browser launch via python3 -m webbrowser..."
    python3 -m webbrowser "file://${PWD}/report.html" 2>/dev/null || true
    OPENED=1
# F. Headless / Terminal Fallback
else
    echo "[INFO] Web browser auto-launch unavailable in current terminal/headless environment."
    echo "[INFO] You can view report.html directly using either:"
    if grep -qi microsoft /proc/version 2>/dev/null && command -v wslpath >/dev/null 2>&1; then
        echo "       explorer.exe \"$(wslpath -w "${PWD}/report.html")\""
    fi
    echo "       file://${PWD}/report.html"
fi

if [ "${OPENED}" -eq 1 ]; then
    echo "[SUCCESS] Dashboard launch command dispatched successfully."
fi

echo "================================================================================"
exit 0
