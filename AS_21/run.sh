#!/usr/bin/env bash
# ==============================================================================
# Course: Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #21: Network Connectivity Check
# Focus: Network Monitoring & Gateway Reachability Verification
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes connectivity_check.sh to probe real gateway and public sanity baseline.
#   3. Regenerates a self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in the default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

# Output banner
echo "================================================================================"
echo "        AUTOMATION SPRINT (AS_21) — NETWORK CONNECTIVITY CHECK                  "
echo "================================================================================"

# Verify connectivity_check.sh exists and is executable
if [ ! -f "./connectivity_check.sh" ]; then
    echo "[ERROR] connectivity_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./connectivity_check.sh

# 2. Run connectivity_check.sh and capture terminal output while streaming to console
echo "[INFO] Running connectivity_check.sh on live network..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
./connectivity_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & live network information for report generation
export OS_NAME="$(uname -s)"
export HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
export KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
export TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S')"
export USER_VAL="$(whoami 2>/dev/null || echo 'User')"

# OS Flavor Display Name
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    export OS_DISPLAY="${PRETTY_NAME:-$OS_NAME}"
elif [ "${OS_NAME}" = "Darwin" ]; then
    export OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    export OS_DISPLAY="${OS_NAME}"
fi

# Live Network Interface and Route Telemetry
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

# DNS resolver from /etc/resolv.conf
if [ -f /etc/resolv.conf ]; then
    export DNS_SERVERS="$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/, $//' || echo 'N/A')"
else
    export DNS_SERVERS="System Default"
fi

# Audit log content (last 60 lines)
LOG_FILE_PATH="logs/connectivity.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    export LOG_PREVIEW="$(tail -n 60 "${LOG_FILE_PATH}")"
else
    export LOG_PREVIEW="No audit log entries recorded yet."
fi

# Read captured terminal execution text
export TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# 4. Generate report.html from scratch using Python 3 helper for rock-solid HTML escaping and data processing
echo "[INFO] Regenerating report.html dashboard with live data..."

python3 - << 'PYEOF'
import html
import os
import re
import sys

# Environment variables from bash
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
term_log = os.environ.get("TERMINAL_LOG_CONTENT", "")
audit_log = os.environ.get("LOG_PREVIEW", "")

target_host = "Unknown"
target_role = "Target"
target_status = "UNKNOWN"
target_loss = "N/A"
target_avg_rtt = "N/A"
target_msg = ""

baseline_host = "8.8.8.8"
baseline_role = "Sanity Baseline"
baseline_status = "UNKNOWN"
baseline_loss = "N/A"
baseline_avg_rtt = "N/A"
baseline_msg = ""

diag_title = "Network Connectivity Evaluation"
diag_detail = "Live network analysis performed."

# Parse Target Host & Role from terminal output
m_target = re.search(r'Target\s*:\s*([^\s]+)\s*\(([^)]+)\)', term_log)
if m_target:
    target_host = m_target.group(1).strip()
    target_role = m_target.group(2).strip()

# Parse Baseline Host
m_base = re.search(r'Baseline\s*:\s*([^\s]+)', term_log)
if m_base:
    baseline_host = m_base.group(1).strip()

# Parse Target Probe line
# e.g.: ❌ Gateway 192.168.32.1 is UNREACHABLE (100% loss)
# e.g.: ✅ Target Host 1.1.1.1 is REACHABLE (0% loss, avg 15.833ms)
# e.g.: ❌ Target Host fake.domain is UNREACHABLE (DNS resolution failure...)
m_tprobe = re.search(r'([✅❌])\s*(Gateway|Target Host|Target|Localhost[^ ]*)\s+([^\s]+)\s+is\s+(REACHABLE|UNREACHABLE)\s*\(([^)]+)\)', term_log)
if m_tprobe:
    icon = m_tprobe.group(1)
    target_role = m_tprobe.group(2)
    target_host = m_tprobe.group(3)
    target_status = m_tprobe.group(4)
    paren = m_tprobe.group(5)
    target_msg = f"{icon} {target_role} {target_host} is {target_status} ({paren})"
    
    # Loss %
    m_loss = re.search(r'([0-9.]+%)\s*loss', paren)
    if m_loss:
        target_loss = m_loss.group(1)
    elif "DNS" in paren:
        target_loss = "100%"
        
    # Avg RTT
    m_rtt = re.search(r'avg\s+([0-9.]+ms)', paren)
    if m_rtt:
        target_avg_rtt = m_rtt.group(1)
    else:
        target_avg_rtt = "N/A"

# Parse Baseline Probe line
m_bprobe = re.search(r'([✅❌])\s*Baseline Host\s+([^\s]+)\s+is\s+(REACHABLE|UNREACHABLE)\s*\(([^)]+)\)', term_log)
if m_bprobe:
    icon = m_bprobe.group(1)
    baseline_host = m_bprobe.group(2)
    baseline_status = m_bprobe.group(3)
    paren = m_bprobe.group(4)
    baseline_msg = f"{icon} Baseline Host {baseline_host} is {baseline_status} ({paren})"
    
    m_loss = re.search(r'([0-9.]+%)\s*loss', paren)
    if m_loss:
        baseline_loss = m_loss.group(1)
    
    m_rtt = re.search(r'avg\s+([0-9.]+ms)', paren)
    if m_rtt:
        baseline_avg_rtt = m_rtt.group(1)
    else:
        baseline_avg_rtt = "N/A"

# Parse Diagnosis
m_diag = re.search(r'DIAGNOSTIC ASSESSMENT:\s*\n\s*([^\n]+)\s*\n\s*([^\n=]+)', term_log)
if m_diag:
    diag_title = m_diag.group(1).strip()
    diag_detail = m_diag.group(2).strip()

# Check latest entry from audit log for detailed packet counters (min/max/tx/rx)
t_tx = "4"
t_rx = "4" if target_status == "REACHABLE" else "0"
t_min_rtt = "N/A"
t_max_rtt = "N/A"

b_tx = "4"
b_rx = "4" if baseline_status == "REACHABLE" else "0"
b_min_rtt = "N/A"
b_max_rtt = "N/A"

# Regex on audit log for PROBE 1 and PROBE 2
m_t_tx = re.search(r'PROBE 1:[^\n]+\n\s*Status\s*:\s*[^\n]+\n\s*Packets\s*:\s*Transmitted = ([0-9]+), Received = ([0-9]+)', audit_log)
if m_t_tx:
    t_tx = m_t_tx.group(1)
    t_rx = m_t_tx.group(2)

m_t_rtt = re.search(r'PROBE 1:[^\n]+\n(?:[^\n]+\n){2}\s*Round-Trip\s*:\s*Min = ([^,\n]+), Avg = ([^,\n]+), Max = ([^\n]+)', audit_log)
if m_t_rtt:
    t_min_rtt = m_t_rtt.group(1).strip()
    t_max_rtt = m_t_rtt.group(3).strip()

m_b_tx = re.search(r'PROBE 2:[^\n]+\n\s*Status\s*:\s*[^\n]+\n\s*Packets\s*:\s*Transmitted = ([0-9]+), Received = ([0-9]+)', audit_log)
if m_b_tx:
    b_tx = m_b_tx.group(1)
    b_rx = m_b_tx.group(2)

m_b_rtt = re.search(r'PROBE 2:[^\n]+\n(?:[^\n]+\n){2}\s*Round-Trip\s*:\s*Min = ([^,\n]+), Avg = ([^,\n]+), Max = ([^\n]+)', audit_log)
if m_b_rtt:
    b_min_rtt = m_b_rtt.group(1).strip()
    b_max_rtt = m_b_rtt.group(3).strip()

# Target Card Color Theme
if target_status == "REACHABLE":
    t_card_border = "#10b981"
    t_badge_bg = "rgba(16, 185, 129, 0.2)"
    t_badge_color = "#34d399"
    t_badge_text = "REACHABLE"
    t_icon = "✅"
else:
    t_card_border = "#ef4444"
    t_badge_bg = "rgba(239, 68, 68, 0.2)"
    t_badge_color = "#f87171"
    t_badge_text = "UNREACHABLE"
    t_icon = "❌"

# Baseline Card Color Theme
if baseline_status == "REACHABLE":
    b_card_border = "#10b981"
    b_badge_bg = "rgba(16, 185, 129, 0.2)"
    b_badge_color = "#34d399"
    b_badge_text = "REACHABLE"
    b_icon = "✅"
else:
    b_card_border = "#ef4444"
    b_badge_bg = "rgba(239, 68, 68, 0.2)"
    b_badge_color = "#f87171"
    b_badge_text = "UNREACHABLE"
    b_icon = "❌"

# Banner diagnosis styling
if "Operational" in diag_title or "Full" in diag_title:
    banner_border = "#10b981"
    banner_bg = "linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(6, 78, 59, 0.25) 100%)"
    banner_badge = "STATUS: FULL CONNECTIVITY"
    banner_badge_color = "#34d399"
elif "Internet Accessible" in diag_title or "ICMP" in diag_title:
    banner_border = "#38bdf8"
    banner_bg = "linear-gradient(135deg, rgba(56, 189, 248, 0.15) 0%, rgba(12, 74, 110, 0.25) 100%)"
    banner_badge = "STATUS: INTERNET ACCESSIBLE (ICMP FILTERED)"
    banner_badge_color = "#38bdf8"
elif "Local" in diag_title:
    banner_border = "#f59e0b"
    banner_bg = "linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(120, 53, 15, 0.25) 100%)"
    banner_badge = "STATUS: LOCAL NETWORK ONLY"
    banner_badge_color = "#fbbf24"
else:
    banner_border = "#ef4444"
    banner_bg = "linear-gradient(135deg, rgba(239, 68, 68, 0.15) 0%, rgba(127, 29, 29, 0.25) 100%)"
    banner_badge = "STATUS: ALERT / ATTENTION NEEDED"
    banner_badge_color = "#f87171"

target_loss_color = "#34d399" if target_loss == "0%" else "#f87171"
target_rtt_color = "#38bdf8" if target_avg_rtt != "N/A" else "#94a3b8"

baseline_loss_color = "#34d399" if baseline_loss == "0%" else "#f87171"
baseline_rtt_color = "#38bdf8" if baseline_avg_rtt != "N/A" else "#94a3b8"

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Connectivity Check — Automation Sprint (AS_21)</title>
    <style>
        :root {{
            --bg-body: #0b1120;
            --bg-card: #131d35;
            --bg-card-alt: #1a2744;
            --border-color: #273553;
            --text-main: #f1f5f9;
            --text-muted: #94a3b8;
            --accent-cyan: #38bdf8;
            --accent-green: #10b981;
            --accent-red: #ef4444;
            --accent-amber: #f59e0b;
            --accent-purple: #818cf8;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            --font-sans: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }}

        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            background-color: var(--bg-body);
            color: var(--text-main);
            font-family: var(--font-sans);
            line-height: 1.5;
            padding: 24px;
        }}

        .container {{
            max-width: 1280px;
            margin: 0 auto;
        }}

        header {{
            background: linear-gradient(180deg, #1e293b 0%, var(--bg-card) 100%);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
        }}

        .badge-row {{
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-bottom: 12px;
        }}

        .badge {{
            display: inline-flex;
            align-items: center;
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.05em;
            text-transform: uppercase;
        }}

        .badge-cyan {{
            background-color: rgba(56, 189, 248, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(56, 189, 248, 0.3);
        }}

        .badge-green {{
            background-color: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .badge-purple {{
            background-color: rgba(129, 140, 248, 0.15);
            color: var(--accent-purple);
            border: 1px solid rgba(129, 140, 248, 0.3);
        }}

        h1 {{
            font-size: 1.85rem;
            font-weight: 800;
            color: #ffffff;
            margin-bottom: 6px;
            letter-spacing: -0.02em;
        }}

        .subtitle {{
            color: var(--text-muted);
            font-size: 0.95rem;
            margin-bottom: 20px;
        }}

        .meta-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
            gap: 12px;
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
        }}

        .meta-item {{
            background-color: var(--bg-card-alt);
            padding: 10px 14px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }}

        .meta-label {{
            font-size: 0.72rem;
            text-transform: uppercase;
            font-weight: 700;
            color: var(--text-muted);
            letter-spacing: 0.05em;
            margin-bottom: 2px;
        }}

        .meta-value {{
            font-size: 0.92rem;
            font-weight: 600;
            color: #ffffff;
            font-family: var(--font-mono);
            word-break: break-all;
        }}

        /* Assessment Banner */
        .assessment-banner {{
            background: {banner_bg};
            border: 1px solid {banner_border};
            border-radius: 12px;
            padding: 20px 24px;
            margin-bottom: 24px;
            box-shadow: 0 10px 20px -5px rgba(0, 0, 0, 0.25);
        }}

        .banner-header {{
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 8px;
            flex-wrap: wrap;
            gap: 10px;
        }}

        .banner-title {{
            font-size: 1.25rem;
            font-weight: 700;
            color: #ffffff;
        }}

        .banner-badge {{
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 800;
            color: {banner_badge_color};
            background: rgba(0, 0, 0, 0.4);
            border: 1px solid {banner_border};
            letter-spacing: 0.05em;
        }}

        .banner-desc {{
            color: #cbd5e1;
            font-size: 0.92rem;
            line-height: 1.6;
        }}

        /* Target Cards Grid */
        .cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
            gap: 24px;
            margin-bottom: 24px;
        }}

        .status-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
            display: flex;
            flex-direction: column;
        }}

        .card-header {{
            padding: 18px 20px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            justify-content: space-between;
            background-color: var(--bg-card-alt);
        }}

        .card-header-left {{
            display: flex;
            align-items: center;
            gap: 12px;
        }}

        .card-icon {{
            font-size: 1.4rem;
        }}

        .card-title {{
            font-size: 1.1rem;
            font-weight: 700;
            color: #ffffff;
        }}

        .card-role {{
            font-size: 0.75rem;
            color: var(--text-muted);
            text-transform: uppercase;
            font-weight: 600;
            letter-spacing: 0.05em;
        }}

        .status-pill {{
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.05em;
            text-transform: uppercase;
        }}

        .card-body {{
            padding: 20px;
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 16px;
        }}

        .metric-row {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }}

        .metric-box {{
            background-color: var(--bg-body);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px 14px;
        }}

        .metric-box-title {{
            font-size: 0.72rem;
            color: var(--text-muted);
            text-transform: uppercase;
            font-weight: 700;
            letter-spacing: 0.05em;
            margin-bottom: 4px;
        }}

        .metric-box-val {{
            font-size: 1.4rem;
            font-weight: 800;
            font-family: var(--font-mono);
        }}

        .sub-metrics {{
            background-color: var(--bg-card-alt);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px 16px;
            font-size: 0.85rem;
            display: flex;
            flex-direction: column;
            gap: 6px;
        }}

        .sub-metric-item {{
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .sub-label {{
            color: var(--text-muted);
        }}

        .sub-val {{
            font-family: var(--font-mono);
            font-weight: 600;
            color: #e2e8f0;
        }}

        .summary-box {{
            background-color: var(--bg-body);
            border-left: 3px solid var(--accent-cyan);
            border-radius: 4px;
            padding: 10px 12px;
            font-family: var(--font-mono);
            font-size: 0.8rem;
            color: #94a3b8;
            word-break: break-all;
        }}

        /* Context & Routing Details */
        .section-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
        }}

        .section-title {{
            font-size: 1.15rem;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .table-responsive {{
            overflow-x: auto;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.88rem;
            text-align: left;
        }}

        th {{
            background-color: var(--bg-card-alt);
            color: var(--accent-cyan);
            padding: 10px 14px;
            font-weight: 700;
            border-bottom: 2px solid var(--border-color);
            text-transform: uppercase;
            font-size: 0.72rem;
            letter-spacing: 0.05em;
        }}

        td {{
            padding: 10px 14px;
            border-bottom: 1px solid var(--border-color);
            color: #e2e8f0;
        }}

        tr:hover td {{
            background-color: rgba(255, 255, 255, 0.02);
        }}

        /* Monospace Logs */
        pre.log-display {{
            background-color: #050914;
            color: #38bdf8;
            border: 1px solid #1e293b;
            border-radius: 8px;
            padding: 16px;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            line-height: 1.5;
            max-height: 380px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        footer {{
            text-align: center;
            color: var(--text-muted);
            font-size: 0.8rem;
            padding: 24px 0 12px 0;
            border-top: 1px solid var(--border-color);
        }}

        .code-pill {{
            background-color: var(--bg-card-alt);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: var(--font-mono);
            color: var(--accent-cyan);
            border: 1px solid var(--border-color);
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- HEADER -->
        <header>
            <div class="badge-row">
                <span class="badge badge-cyan">Course: E1ITA307</span>
                <span class="badge badge-purple">Sprint: AS_21</span>
                <span class="badge badge-green">Live Telemetry</span>
            </div>
            <h1>Network Connectivity Check &amp; Gateway Monitor</h1>
            <div class="subtitle">
                Automated ICMP Echo Reachability Analysis, Packet Loss Accounting &amp; Round-Trip Telemetry
            </div>
            <div class="meta-grid">
                <div class="meta-item">
                    <div class="meta-label">Execution Timestamp</div>
                    <div class="meta-value">{html.escape(timestamp)}</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Hostname &amp; User</div>
                    <div class="meta-value">{html.escape(hostname)} ({html.escape(user)})</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Operating System</div>
                    <div class="meta-value">{html.escape(os_display)}</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Kernel Version</div>
                    <div class="meta-value">{html.escape(kernel)}</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Active Interface</div>
                    <div class="meta-value">{html.escape(primary_iface)} ({html.escape(local_ip)})</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Detected Gateway</div>
                    <div class="meta-value">{html.escape(default_gw)}</div>
                </div>
            </div>
        </header>

        <!-- DIAGNOSTIC ASSESSMENT BANNER -->
        <div class="assessment-banner">
            <div class="banner-header">
                <div class="banner-title">{html.escape(diag_title)}</div>
                <div class="banner-badge">{html.escape(banner_badge)}</div>
            </div>
            <div class="banner-desc">{html.escape(diag_detail)}</div>
        </div>

        <!-- STATUS CARDS (TARGET & BASELINE) -->
        <div class="cards-grid">
            <!-- TARGET / GATEWAY CARD -->
            <div class="status-card" style="border-top: 4px solid {t_card_border};">
                <div class="card-header">
                    <div class="card-header-left">
                        <span class="card-icon">{t_icon}</span>
                        <div>
                            <div class="card-title">{html.escape(target_host)}</div>
                            <div class="card-role">{html.escape(target_role)}</div>
                        </div>
                    </div>
                    <span class="status-pill" style="background: {t_badge_bg}; color: {t_badge_color}; border: 1px solid {t_badge_color};">
                        {html.escape(t_badge_text)}
                    </span>
                </div>
                <div class="card-body">
                    <div class="metric-row">
                        <div class="metric-box">
                            <div class="metric-box-title">Packet Loss</div>
                            <div class="metric-box-val" style="color: {target_loss_color};">
                                {html.escape(target_loss)}
                            </div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-box-title">Average RTT</div>
                            <div class="metric-box-val" style="color: {target_rtt_color};">
                                {html.escape(target_avg_rtt)}
                            </div>
                        </div>
                    </div>
                    <div class="sub-metrics">
                        <div class="sub-metric-item">
                            <span class="sub-label">Packets Transmitted / Received</span>
                            <span class="sub-val">{html.escape(t_tx)} sent / {html.escape(t_rx)} recv</span>
                        </div>
                        <div class="sub-metric-item">
                            <span class="sub-label">Latency Range (Min / Max)</span>
                            <span class="sub-val">{html.escape(t_min_rtt)} / {html.escape(t_max_rtt)}</span>
                        </div>
                        <div class="sub-metric-item">
                            <span class="sub-label">Probe Status Line</span>
                            <span class="sub-val">{html.escape(target_msg)}</span>
                        </div>
                    </div>
                    <div class="summary-box">
                        <strong>Architectural Note:</strong> Gateway detection executed via <span class="code-pill">ip route | grep default | awk '{{print $3}}'</span>. When run inside WSL2 or cloud environments, virtual switch adapters frequently filter ICMP echo requests while allowing full TCP/UDP WAN forwarding.
                    </div>
                </div>
            </div>

            <!-- SANITY BASELINE CARD -->
            <div class="status-card" style="border-top: 4px solid {b_card_border};">
                <div class="card-header">
                    <div class="card-header-left">
                        <span class="card-icon">{b_icon}</span>
                        <div>
                            <div class="card-title">{html.escape(baseline_host)}</div>
                            <div class="card-role">{html.escape(baseline_role)} (Public Reference)</div>
                        </div>
                    </div>
                    <span class="status-pill" style="background: {b_badge_bg}; color: {b_badge_color}; border: 1px solid {b_badge_color};">
                        {html.escape(b_badge_text)}
                    </span>
                </div>
                <div class="card-body">
                    <div class="metric-row">
                        <div class="metric-box">
                            <div class="metric-box-title">Packet Loss</div>
                            <div class="metric-box-val" style="color: {baseline_loss_color};">
                                {html.escape(baseline_loss)}
                            </div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-box-title">Average RTT</div>
                            <div class="metric-box-val" style="color: {baseline_rtt_color};">
                                {html.escape(baseline_avg_rtt)}
                            </div>
                        </div>
                    </div>
                    <div class="sub-metrics">
                        <div class="sub-metric-item">
                            <span class="sub-label">Packets Transmitted / Received</span>
                            <span class="sub-val">{html.escape(b_tx)} sent / {html.escape(b_rx)} recv</span>
                        </div>
                        <div class="sub-metric-item">
                            <span class="sub-label">Latency Range (Min / Max)</span>
                            <span class="sub-val">{html.escape(b_min_rtt)} / {html.escape(b_max_rtt)}</span>
                        </div>
                        <div class="sub-metric-item">
                            <span class="sub-label">Probe Status Line</span>
                            <span class="sub-val">{html.escape(baseline_msg)}</span>
                        </div>
                    </div>
                    <div class="summary-box">
                        <strong>Sanity Baseline Rationale:</strong> Probing a resilient global Anycast DNS resolver (<span class="code-pill">8.8.8.8</span>) eliminates false alarms caused by gateway-level ICMP filtering and confirms whether the machine has active WAN Internet connectivity.
                    </div>
                </div>
            </div>
        </div>

        <!-- NETWORK CONFIGURATION & TRIANGULATION MATRIX -->
        <div class="section-card">
            <div class="section-title">🌐 Live Network Configuration &amp; Routing Context</div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Parameter</th>
                            <th>Active Value</th>
                            <th>Detection / Extraction Mechanism</th>
                            <th>Operational Significance</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Default Gateway</strong></td>
                            <td><span class="code-pill">{html.escape(default_gw)}</span></td>
                            <td><code>ip route | grep default | awk '{{print $3}}'</code></td>
                            <td>Primary next-hop router for all non-local outbound traffic</td>
                        </tr>
                        <tr>
                            <td><strong>Host IP Address</strong></td>
                            <td><span class="code-pill">{html.escape(local_ip)}</span></td>
                            <td><code>ip -4 addr show dev {html.escape(primary_iface)}</code></td>
                            <td>Local network interface address bound for socket traffic</td>
                        </tr>
                        <tr>
                            <td><strong>Primary Interface</strong></td>
                            <td><span class="code-pill">{html.escape(primary_iface)}</span></td>
                            <td>Derived from route table egress interface column ($5)</td>
                            <td>Physical or virtual network adapter processing ICMP packets</td>
                        </tr>
                        <tr>
                            <td><strong>DNS Resolvers</strong></td>
                            <td><span class="code-pill">{html.escape(dns_servers)}</span></td>
                            <td><code>grep -E '^nameserver' /etc/resolv.conf</code></td>
                            <td>Nameserver addresses used for domain resolution</td>
                        </tr>
                        <tr>
                            <td><strong>Probe Packet Count</strong></td>
                            <td><span class="code-pill">4 packets (-c 4)</span></td>
                            <td>Configured bounded count flag</td>
                            <td>Guarantees bounded probe runtime; never unbounded</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TRIANGULATION MATRIX REFERENCE -->
        <div class="section-card">
            <div class="section-title">🛡️ Triangulation Matrix: Distinguishing Network Failure Modes</div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Gateway Status</th>
                            <th>Sanity Baseline (8.8.8.8)</th>
                            <th>Diagnostic Verdict</th>
                            <th>Root Cause &amp; Administrative Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr style="background: rgba(16, 185, 129, 0.05);">
                            <td><strong style="color: #34d399;">REACHABLE (0% loss)</strong></td>
                            <td><strong style="color: #34d399;">REACHABLE (0% loss)</strong></td>
                            <td><strong>✅ All Systems Operational</strong></td>
                            <td>Full local and WAN connectivity. Packets flow seamlessly through gateway to the Internet.</td>
                        </tr>
                        <tr style="background: rgba(56, 189, 248, 0.05);">
                            <td><strong style="color: #f87171;">UNREACHABLE (100% loss)</strong></td>
                            <td><strong style="color: #34d399;">REACHABLE (0% loss)</strong></td>
                            <td><strong>🌐 Internet Accessible (ICMP Filtered)</strong></td>
                            <td>WAN routing is operational, but gateway drops ICMP echo. Common on WSL2 virtual switch, Azure, and enterprise routers.</td>
                        </tr>
                        <tr style="background: rgba(245, 158, 11, 0.05);">
                            <td><strong style="color: #34d399;">REACHABLE (0% loss)</strong></td>
                            <td><strong style="color: #f87171;">UNREACHABLE (100% loss)</strong></td>
                            <td><strong>⚠️ Local Network Only</strong></td>
                            <td>Local LAN/WLAN is up, but WAN uplink is severed. Inspect ISP modem, fiber link, or upstream router peering.</td>
                        </tr>
                        <tr style="background: rgba(239, 68, 68, 0.05);">
                            <td><strong style="color: #f87171;">UNREACHABLE (100% loss)</strong></td>
                            <td><strong style="color: #f87171;">UNREACHABLE (100% loss)</strong></td>
                            <td><strong>❌ Complete Network Outage</strong></td>
                            <td>Host is isolated. Verify physical cable, Wi-Fi association, DHCP lease, or restart local network stack.</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- RECENT TERMINAL EXECUTION PREVIEW -->
        <div class="section-card">
            <div class="section-title">💻 Captured Terminal Execution Output</div>
            <pre class="log-display">{html.escape(term_log.strip())}</pre>
        </div>

        <!-- PERSISTENT AUDIT LOG HISTORY -->
        <div class="section-card">
            <div class="section-title">📜 Chronological Audit Trail (<span class="code-pill">logs/connectivity.log</span>)</div>
            <pre class="log-display">{html.escape(audit_log.strip())}</pre>
        </div>

        <!-- FOOTER -->
        <footer>
            <div>Linux System Administration (E1ITA307) — Automation Sprint (AS_21)</div>
            <div style="margin-top: 4px;">Single Command to Re-run: <span class="code-pill">bash run.sh</span></div>
        </footer>
    </div>
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
