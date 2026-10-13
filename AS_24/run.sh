#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_24)
# Problem Statement #24: SSH Service Check
# Focus: SSH Administration & Service Monitoring
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   1. Sets working directory to script location (cd "$(dirname "$0")") so it
#      executes seamlessly from any directory or subshell.
#   2. Runs ssh_service_check.sh to capture this machine's live real SSH status.
#   3. Regenerates report.html from scratch on every run — a self-contained,
#      dark-themed dashboard (inline CSS only) featuring:
#      - Header with system metadata and timestamp
#      - Status card color-coded (Green/Amber/Red) displaying active, enabled,
#        and listening socket states together
#      - KPI metric cards, detailed diagnostic audit matrix, live captured
#        terminal output, and system administration remediation commands
#   4. Dispatches the HTML dashboard automatically to the host browser across
#      WSL2, native Linux desktops, macOS, and Windows Git Bash.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_24) — SSH SERVICE STATUS AUDIT                  "
echo "================================================================================"

# Verify ssh_service_check.sh exists and set executable permission
if [ ! -f "./ssh_service_check.sh" ]; then
    echo "[ERROR] ssh_service_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./ssh_service_check.sh

# 2. Execute ssh_service_check.sh to capture live system state
OS_SYSTEM="$(uname -s)"
echo "[INFO] Host Environment: ${OS_SYSTEM} ($(uname -m 2>/dev/null || echo 'Unknown'))"

# Capture terminal execution output to temporary log for embedding in dashboard
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'ssh_term_XXXXXX')"
echo "[INFO] Running live SSH service audit via ./ssh_service_check.sh..."
echo "--------------------------------------------------------------------------------"

# Allow non-zero exit codes from the check script (e.g. exit code 1 when SSH is uninstalled/inactive)
set +e
./ssh_service_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
CHECK_EXIT_CODE=$?
set -e

echo "--------------------------------------------------------------------------------"
echo "[INFO] Service check process completed with status code: ${CHECK_EXIT_CODE}"

# Verify structured JSON telemetry file exists
JSON_META_FILE="logs/ssh_check.json"
if [ ! -f "${JSON_META_FILE}" ]; then
    echo "[ERROR] JSON telemetry file ${JSON_META_FILE} was not generated!" >&2
    rm -f "${TMP_TERM_LOG}"
    exit 1
fi

export TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# 3. Regenerate report.html from scratch every run using Python 3
echo "[INFO] Regenerating self-contained dark-themed report.html from scratch..."

python3 - << 'PYEOF'
import html
import json
import os
import sys

json_path = os.path.join("logs", "ssh_check.json")
if not os.path.exists(json_path):
    print(f"[ERROR] Telemetry file not found: {json_path}", file=sys.stderr)
    sys.exit(1)

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

terminal_log = os.environ.get("TERMINAL_LOG_CONTENT", "").strip()

# Read recent log lines from logs/ssh_check.log
log_path = os.path.join("logs", "ssh_check.log")
recent_logs = []
if os.path.exists(log_path):
    with open(log_path, "r", encoding="utf-8", errors="replace") as f:
        all_lines = f.readlines()
        recent_logs = [line.strip() for line in all_lines[-20:] if line.strip()]

# Extract telemetry fields
timestamp = data.get("timestamp", "N/A")
timestamp_iso = data.get("timestamp_iso", "")
hostname = data.get("hostname", "localhost")
os_distro = data.get("os_distro", "Linux")
kernel = data.get("kernel", "Unknown")
arch = data.get("arch", "x86_64")
is_wsl = data.get("is_wsl", 0)

init_data = data.get("init_system", {})
init_type = init_data.get("type", "unknown")
init_details = init_data.get("details", "N/A")

service_data = data.get("service", {})
detected_name = service_data.get("detected_name", "none")
detection_method = service_data.get("detection_method", "none")
detection_log = service_data.get("detection_log", "")

active_data = data.get("active_check", {})
active_status = active_data.get("status", "unknown")
active_code = active_data.get("exit_code", 99)
active_raw = active_data.get("raw_output", "")
active_explanation = active_data.get("explanation", "")

enabled_data = data.get("enabled_check", {})
enabled_status = enabled_data.get("status", "unknown")
enabled_code = enabled_data.get("exit_code", 99)
enabled_raw = enabled_data.get("raw_output", "")
enabled_explanation = enabled_data.get("explanation", "")

port_data = data.get("port_check", {})
target_port = port_data.get("port", 22)
port_status = port_data.get("status", "unknown")
port_command = port_data.get("command_used", "ss -tlnp")
port_raw_match = port_data.get("raw_match", "None")
port_process = port_data.get("process", "None")
port_explanation = port_data.get("explanation", "")

eval_data = data.get("evaluation", {})
overall_health = eval_data.get("overall_health", "CRITICAL")
status_icon = eval_data.get("status_icon", "❌")
combined_message = eval_data.get("combined_message", "")
remediation_hint = eval_data.get("remediation_hint", "")

# Determine CSS classes and color themes based on overall health
# Optimal: Green / Emerald
# Warning: Amber / Orange
# Critical: Red / Crimson
if overall_health == "OPTIMAL":
    hero_card_class = "hero-optimal"
    hero_badge_class = "badge-green"
    hero_glow = "rgba(16, 185, 129, 0.2)"
    hero_border = "#10b981"
elif overall_health == "WARNING":
    hero_card_class = "hero-warning"
    hero_badge_class = "badge-amber"
    hero_glow = "rgba(245, 158, 11, 0.2)"
    hero_border = "#f59e0b"
else:
    hero_card_class = "hero-critical"
    hero_badge_class = "badge-red"
    hero_glow = "rgba(239, 68, 68, 0.2)"
    hero_border = "#ef4444"

# Sub-state pill styles
active_pill_class = "pill-green" if active_status == "active" else "pill-red"
enabled_pill_class = "pill-green" if enabled_status == "enabled" else ("pill-amber" if enabled_status in ["static", "masked"] else "pill-red")
port_pill_class = "pill-green" if port_status == "listening" else "pill-red"
service_pill_class = "pill-green" if detected_name in ["ssh", "sshd"] else "pill-red"

# Format audit table rows
audit_steps = [
    {
        "step": "1. Service Detection",
        "target": "ssh then sshd",
        "command": "systemctl cat ssh.service / sshd.service",
        "result": f"{detected_name.upper()} ({detection_method})",
        "status": "PASS" if detected_name != "none" else "INFO",
        "details": detection_log
    },
    {
        "step": "2. Runtime Active State",
        "target": f"Active Daemon ({detected_name})",
        "command": f"systemctl is-active {detected_name}" if detected_name != "none" else "systemctl is-active ssh",
        "result": active_status.upper(),
        "status": "PASS" if active_status == "active" else "FAIL",
        "details": active_explanation
    },
    {
        "step": "3. Boot Persistence",
        "target": f"Auto-start ({detected_name})",
        "command": f"systemctl is-enabled {detected_name}" if detected_name != "none" else "systemctl is-enabled ssh",
        "result": enabled_status.upper(),
        "status": "PASS" if enabled_status == "enabled" else "WARN",
        "details": enabled_explanation
    },
    {
        "step": "4. Port Socket Cross-Check",
        "target": f"TCP Port {target_port}",
        "command": f"{port_command} | grep :{target_port}",
        "result": "LISTENING" if port_status == "listening" else "NOT LISTENING",
        "status": "PASS" if port_status == "listening" else "FAIL",
        "details": f"{port_explanation} — Process: {port_process}"
    },
    {
        "step": "5. Init Architecture",
        "target": "Init System Manager",
        "command": "systemctl is-system-running / init detection",
        "result": init_type.upper(),
        "status": "PASS" if init_type in ["systemd", "launchd"] else "WARN",
        "details": init_details
    }
]

table_rows_html = ""
for item in audit_steps:
    status_badge = "badge-green" if item["status"] == "PASS" else ("badge-amber" if item["status"] in ["WARN", "INFO"] else "badge-red")
    table_rows_html += f"""
    <tr>
        <td><strong>{html.escape(item["step"])}</strong></td>
        <td><code>{html.escape(item["target"])}</code></td>
        <td><code class="cmd-snippet">{html.escape(item["command"])}</code></td>
        <td><span class="badge {status_badge}">{html.escape(item["result"])}</span></td>
        <td class="text-secondary">{html.escape(item["details"])}</td>
    </tr>
    """

# Format recent log items
recent_logs_html = ""
for line in recent_logs:
    css_class = "log-line-default"
    if "SUCCESS" in line or "OPTIMAL" in line:
        css_class = "log-line-success"
    elif "WARN" in line:
        css_class = "log-line-warn"
    elif "ERROR" in line or "CRITICAL" in line:
        css_class = "log-line-error"
    recent_logs_html += f'<div class="log-row {css_class}">{html.escape(line)}</div>\n'

if not recent_logs_html:
    recent_logs_html = "<div class='text-muted'>No audit logs recorded yet.</div>"

# Generate complete standalone HTML
html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSH Service Check Report — AS_24 (E1ITA307)</title>
    <style>
        :root {{
            --bg-base: #0a0f1d;
            --bg-card: #111827;
            --bg-card-alt: #1a2234;
            --bg-hover: #1f293d;
            --border-dim: #26334d;
            --border-bright: #3b4d70;
            --text-primary: #f9fafb;
            --text-secondary: #9ca3af;
            --text-muted: #6b7280;
            --accent-cyan: #38bdf8;
            --accent-blue: #3b82f6;
            --accent-emerald: #10b981;
            --accent-amber: #f59e0b;
            --accent-red: #ef4444;
            --accent-purple: #a855f7;
            --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        }}

        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            background-color: var(--bg-base);
            color: var(--text-primary);
            font-family: var(--font-sans);
            line-height: 1.6;
            padding: 24px;
        }}

        .container {{
            max-width: 1280px;
            margin: 0 auto;
        }}

        /* Header Card */
        .header-card {{
            background: linear-gradient(135deg, #111827 0%, #17223b 50%, #0d1424 100%);
            border: 1px solid var(--border-bright);
            border-radius: 14px;
            padding: 28px;
            margin-bottom: 24px;
            box-shadow: 0 10px 30px -5px rgba(0, 0, 0, 0.5);
            position: relative;
            overflow: hidden;
        }}

        .header-card::before {{
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-purple));
        }}

        .header-title-row {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 16px;
            margin-bottom: 16px;
        }}

        .header-titles h1 {{
            font-size: 26px;
            font-weight: 800;
            letter-spacing: -0.5px;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .header-titles .subtitle {{
            font-size: 14px;
            color: var(--accent-cyan);
            font-weight: 500;
            margin-top: 4px;
        }}

        .meta-pills {{
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 12px;
        }}

        .meta-pill {{
            background-color: var(--bg-card-alt);
            border: 1px solid var(--border-dim);
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 12px;
            color: var(--text-secondary);
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }}

        .meta-pill strong {{
            color: var(--text-primary);
        }}

        /* HERO STATUS CARD */
        .hero-status-card {{
            border-radius: 14px;
            padding: 28px;
            margin-bottom: 24px;
            border: 1px solid var(--border-bright);
            box-shadow: 0 12px 35px -8px {hero_glow};
            transition: all 0.2s ease;
            position: relative;
        }}

        .hero-optimal {{
            background: linear-gradient(135deg, rgba(16, 185, 129, 0.12) 0%, rgba(17, 24, 39, 0.95) 100%);
            border-left: 6px solid var(--accent-emerald);
        }}

        .hero-warning {{
            background: linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(17, 24, 39, 0.95) 100%);
            border-left: 6px solid var(--accent-amber);
        }}

        .hero-critical {{
            background: linear-gradient(135deg, rgba(239, 68, 68, 0.12) 0%, rgba(17, 24, 39, 0.95) 100%);
            border-left: 6px solid var(--accent-red);
        }}

        .hero-headline-wrap {{
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 18px;
        }}

        .hero-icon {{
            font-size: 40px;
            line-height: 1;
        }}

        .hero-headline {{
            font-size: 20px;
            font-weight: 700;
            color: #ffffff;
            line-height: 1.4;
        }}

        .hero-breakdown {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 14px;
            margin-top: 16px;
            padding-top: 16px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
        }}

        .breakdown-item {{
            background: rgba(0, 0, 0, 0.25);
            padding: 12px 16px;
            border-radius: 8px;
            border: 1px solid var(--border-dim);
        }}

        .breakdown-label {{
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 4px;
        }}

        .breakdown-val {{
            font-size: 14px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 6px;
        }}

        /* KPI METRIC CARDS */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 18px;
            margin-bottom: 24px;
        }}

        .metric-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 12px;
            padding: 20px;
            position: relative;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
        }}

        .metric-title {{
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-secondary);
            margin-bottom: 8px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .metric-value {{
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 6px;
            font-family: var(--font-mono);
        }}

        .metric-sub {{
            font-size: 12px;
            color: var(--text-muted);
            line-height: 1.4;
        }}

        /* Status Badges & Pills */
        .badge {{
            display: inline-block;
            padding: 3px 10px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.3px;
        }}

        .badge-green {{
            background-color: rgba(16, 185, 129, 0.15);
            color: var(--accent-emerald);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .badge-amber {{
            background-color: rgba(245, 158, 11, 0.15);
            color: var(--accent-amber);
            border: 1px solid rgba(245, 158, 11, 0.3);
        }}

        .badge-red {{
            background-color: rgba(239, 68, 68, 0.15);
            color: var(--accent-red);
            border: 1px solid rgba(239, 68, 68, 0.3);
        }}

        .pill-green {{ color: var(--accent-emerald); }}
        .pill-amber {{ color: var(--accent-amber); }}
        .pill-red {{ color: var(--accent-red); }}

        /* SECTION CARDS & TABLES */
        .section-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 14px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 18px rgba(0, 0, 0, 0.3);
        }}

        .section-header {{
            font-size: 18px;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 10px;
            border-bottom: 1px solid var(--border-dim);
            padding-bottom: 12px;
        }}

        .data-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}

        .data-table th {{
            background-color: var(--bg-card-alt);
            color: var(--text-secondary);
            font-weight: 600;
            text-align: left;
            padding: 12px 14px;
            border-bottom: 2px solid var(--border-dim);
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .data-table td {{
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-dim);
            vertical-align: middle;
        }}

        .data-table tr:hover td {{
            background-color: var(--bg-hover);
        }}

        .cmd-snippet {{
            font-family: var(--font-mono);
            font-size: 12px;
            background: #0f172a;
            padding: 2px 6px;
            border-radius: 4px;
            color: var(--accent-cyan);
            border: 1px solid #1e293b;
        }}

        /* TERMINAL LOG EMBED */
        .terminal-box {{
            background-color: #070b14;
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            overflow: hidden;
            font-family: var(--font-mono);
        }}

        .terminal-bar {{
            background-color: #0f172a;
            padding: 8px 14px;
            display: flex;
            align-items: center;
            gap: 8px;
            border-bottom: 1px solid var(--border-dim);
        }}

        .term-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            display: inline-block;
        }}
        .dot-red {{ background-color: #ef4444; }}
        .dot-yellow {{ background-color: #f59e0b; }}
        .dot-green {{ background-color: #10b981; }}
        .term-title {{
            font-size: 11px;
            color: var(--text-muted);
            margin-left: 8px;
        }}

        .terminal-content {{
            padding: 16px;
            max-height: 380px;
            overflow-y: auto;
            color: #d1d5db;
            font-size: 12px;
            line-height: 1.5;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        /* LOG AUDIT FEED */
        .log-feed {{
            background-color: #070b14;
            border: 1px solid var(--border-dim);
            border-radius: 8px;
            padding: 14px;
            max-height: 260px;
            overflow-y: auto;
            font-family: var(--font-mono);
            font-size: 12px;
        }}

        .log-row {{
            padding: 4px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.04);
            white-space: pre-wrap;
        }}

        .log-line-default {{ color: var(--text-secondary); }}
        .log-line-success {{ color: var(--accent-emerald); }}
        .log-line-warn {{ color: var(--accent-amber); }}
        .log-line-error {{ color: var(--accent-red); }}

        /* REMEDIATION / ADMIN GUIDE BOX */
        .guide-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 16px;
            margin-top: 14px;
        }}

        .guide-card {{
            background-color: var(--bg-card-alt);
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            padding: 18px;
        }}

        .guide-card h4 {{
            font-size: 14px;
            color: var(--accent-cyan);
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .code-block {{
            background-color: #0b1120;
            border: 1px solid var(--border-dim);
            border-radius: 6px;
            padding: 10px 12px;
            font-family: var(--font-mono);
            font-size: 12px;
            color: #e2e8f0;
            margin-top: 6px;
            overflow-x: auto;
        }}

        /* FOOTER */
        .footer {{
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 32px;
            padding-top: 20px;
            border-top: 1px solid var(--border-dim);
        }}

        .footer strong {{
            color: var(--text-secondary);
        }}
    </style>
</head>
<body>
    <div class="container">

        <!-- HEADER CARD -->
        <header class="header-card">
            <div class="header-title-row">
                <div class="header-titles">
                    <h1>🛡️ SSH Service Check Dashboard</h1>
                    <div class="subtitle">Course: Linux System Administration (E1ITA307) — Automation Sprint #24</div>
                </div>
                <div>
                    <span class="badge {hero_badge_class}">{overall_health} STATUS</span>
                </div>
            </div>

            <div class="meta-pills">
                <div class="meta-pill">🖥️ Host: <strong>{html.escape(hostname)}</strong></div>
                <div class="meta-pill">🐧 OS: <strong>{html.escape(os_distro)}</strong></div>
                <div class="meta-pill">⚙️ Kernel: <strong>{html.escape(kernel)}</strong></div>
                <div class="meta-pill">🏗️ Arch: <strong>{html.escape(arch)}</strong></div>
                <div class="meta-pill">🔄 Init: <strong>{html.escape(init_type)}</strong></div>
                <div class="meta-pill">🕒 Checked: <strong>{html.escape(timestamp)}</strong></div>
                <div class="meta-pill">⚡ Environment: <strong>{"WSL2 Linux" if is_wsl else "Native Linux"}</strong></div>
            </div>
        </header>

        <!-- HERO STATUS CARD -->
        <section class="hero-status-card {hero_card_class}">
            <div class="hero-headline-wrap">
                <div class="hero-icon">{status_icon}</div>
                <div>
                    <div class="hero-headline">{html.escape(combined_message)}</div>
                    <div style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">
                        {html.escape(remediation_hint)}
                    </div>
                </div>
            </div>

            <div class="hero-breakdown">
                <div class="breakdown-item">
                    <div class="breakdown-label">Service Candidate</div>
                    <div class="breakdown-val">
                        <span class="{service_pill_class}">●</span> {html.escape(detected_name)}
                    </div>
                </div>
                <div class="breakdown-item">
                    <div class="breakdown-label">Runtime State</div>
                    <div class="breakdown-val">
                        <span class="{active_pill_class}">●</span> {html.escape(active_status.upper())}
                    </div>
                </div>
                <div class="breakdown-item">
                    <div class="breakdown-label">Boot Persistence</div>
                    <div class="breakdown-val">
                        <span class="{enabled_pill_class}">●</span> {html.escape(enabled_status.upper())}
                    </div>
                </div>
                <div class="breakdown-item">
                    <div class="breakdown-label">Port {target_port} Socket</div>
                    <div class="breakdown-val">
                        <span class="{port_pill_class}">●</span> {html.escape("LISTENING" if port_status == "listening" else "NOT LISTENING")}
                    </div>
                </div>
            </div>
        </section>

        <!-- KPI METRICS GRID -->
        <section class="metrics-grid">
            <div class="metric-card">
                <div class="metric-title">
                    <span>1. Service Name Detection</span>
                    <span class="badge {hero_badge_class}">{html.escape(detected_name)}</span>
                </div>
                <div class="metric-value">{html.escape(detected_name)}</div>
                <div class="metric-sub">{html.escape(detection_method)}</div>
            </div>

            <div class="metric-card">
                <div class="metric-title">
                    <span>2. Runtime Active State</span>
                    <span class="badge {'badge-green' if active_status == 'active' else 'badge-red'}">{html.escape(active_status.upper())}</span>
                </div>
                <div class="metric-value">{html.escape(active_status.upper())}</div>
                <div class="metric-sub">{html.escape(active_explanation)}</div>
            </div>

            <div class="metric-card">
                <div class="metric-title">
                    <span>3. Boot Persistence</span>
                    <span class="badge {'badge-green' if enabled_status == 'enabled' else ('badge-amber' if enabled_status in ['static', 'masked'] else 'badge-red')}">{html.escape(enabled_status.upper())}</span>
                </div>
                <div class="metric-value">{html.escape(enabled_status.upper())}</div>
                <div class="metric-sub">{html.escape(enabled_explanation)}</div>
            </div>

            <div class="metric-card">
                <div class="metric-title">
                    <span>4. Port {target_port} Socket</span>
                    <span class="badge {'badge-green' if port_status == 'listening' else 'badge-red'}">{"LISTEN" if port_status == "listening" else "CLOSED"}</span>
                </div>
                <div class="metric-value">{"LISTENING" if port_status == "listening" else "NOT BOUND"}</div>
                <div class="metric-sub">Process: {html.escape(port_process)}</div>
            </div>
        </section>

        <!-- TECHNICAL AUDIT MATRIX TABLE -->
        <section class="section-card">
            <div class="section-header">
                <span>📋 Technical Inspection & Diagnostic Matrix</span>
            </div>
            <table class="data-table">
                <thead>
                    <tr>
                        <th style="width: 22%;">Audit Step</th>
                        <th style="width: 18%;">Target Subject</th>
                        <th style="width: 25%;">Execution Command / Probe</th>
                        <th style="width: 15%;">State / Output</th>
                        <th style="width: 20%;">Diagnostic Findings</th>
                    </tr>
                </thead>
                <tbody>
                    {table_rows_html}
                </tbody>
            </table>
        </section>

        <!-- LIVE TERMINAL EXECUTION LOG -->
        <section class="section-card">
            <div class="section-header">
                <span>💻 Live Terminal Execution Output</span>
            </div>
            <div class="terminal-box">
                <div class="terminal-bar">
                    <span class="term-dot dot-red"></span>
                    <span class="term-dot dot-yellow"></span>
                    <span class="term-dot dot-green"></span>
                    <span class="term-title">bash ./ssh_service_check.sh — stdout & stderr</span>
                </div>
                <pre class="terminal-content"><code>{html.escape(terminal_log)}</code></pre>
            </div>
        </section>

        <!-- RECENT AUDIT LOG FEED -->
        <section class="section-card">
            <div class="section-header">
                <span>📜 Persistent Chronological Audit Trail (logs/ssh_check.log)</span>
            </div>
            <div class="log-feed">
                {recent_logs_html}
            </div>
        </section>

        <!-- SYSADMIN REMEDIATION & VIVA GUIDE -->
        <section class="section-card">
            <div class="section-header">
                <span>💡 System Administrator Quick Reference & Remediation</span>
            </div>
            <p style="font-size: 13px; color: var(--text-secondary); margin-bottom: 12px;">
                Reference commands for provisioning, enabling, and managing SSH daemons across different Linux distribution families:
            </p>
            <div class="guide-grid">
                <div class="guide-card">
                    <h4>🐧 Debian / Ubuntu Family ('ssh.service')</h4>
                    <p style="font-size: 12px; color: var(--text-muted);">Package: <code>openssh-server</code> | Unit: <code>ssh.service</code></p>
                    <div class="code-block">
# Install OpenSSH server
sudo apt-get update && sudo apt-get install openssh-server

# Enable and start SSH service immediately
sudo systemctl enable --now ssh

# Verify active status and port listening
systemctl status ssh
ss -tlnp | grep :22</div>
                </div>

                <div class="guide-card">
                    <h4>🎩 RHEL / CentOS / Fedora Family ('sshd.service')</h4>
                    <p style="font-size: 12px; color: var(--text-muted);">Package: <code>openssh-server</code> | Unit: <code>sshd.service</code></p>
                    <div class="code-block">
# Install OpenSSH server
sudo dnf install openssh-server

# Enable and start SSH daemon immediately
sudo systemctl enable --now sshd

# Allow SSH through firewall
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --reload</div>
                </div>

                <div class="guide-card">
                    <h4>🍏 macOS Darwin ('Remote Login')</h4>
                    <p style="font-size: 12px; color: var(--text-muted);">Managed via <code>systemsetup</code> and <code>launchd</code></p>
                    <div class="code-block">
# Query Remote Login status
sudo systemsetup -getremotelogin

# Enable Remote Login (SSH)
sudo systemsetup -setremotelogin on

# Verify TCP port 22 binding
lsof -iTCP:22 -sTCP:LISTEN -P -n</div>
                </div>
            </div>
        </section>

        <!-- FOOTER -->
        <footer class="footer">
            <div>
                <strong>Automation Sprint (AS_24) — SSH Service Check</strong> | Course: Linux System Administration (E1ITA307)
            </div>
            <div style="margin-top: 6px;">
                Live Machine Audit • Generated at {html.escape(timestamp)} • Strict Sandboxing & Read-Only Compliance
            </div>
        </footer>

    </div>
</body>
</html>
"""

report_html_path = "report.html"
with open(report_html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[SUCCESS] report.html successfully generated ({len(html_content)} bytes).")
PYEOF

# 4. Automatically open report.html detecting OS
echo "================================================================================"
echo "🚀 Dispatching report.html to Web Browser..."
echo "================================================================================"

OPENED=0

# A. Windows Subsystem for Linux (WSL)
if grep -qi microsoft /proc/version 2>/dev/null && command -v explorer.exe >/dev/null 2>&1; then
    echo "[INFO] Detected Windows Subsystem for Linux (WSL) environment."
    WIN_PATH="$(wslpath -w "${PWD}/report.html" 2>/dev/null || echo "report.html")"
    echo "[INFO] Resolved Windows Path: ${WIN_PATH}"
    echo "[LAUNCH] Invoking explorer.exe..."
    explorer.exe "${WIN_PATH}" 2>/dev/null || true
    OPENED=1
# B. macOS (Darwin)
elif [ "${OS_SYSTEM}" = "Darwin" ]; then
    echo "[INFO] Detected macOS Darwin environment."
    if command -v systemsetup >/dev/null 2>&1; then
        echo "[INFO] macOS Remote Login status: $(systemsetup -getremotelogin 2>&1 || echo 'unavailable')"
    fi
    if command -v open >/dev/null 2>&1; then
        echo "[LAUNCH] Invoking 'open report.html'..."
        open report.html 2>/dev/null || true
        OPENED=1
    fi
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
# E. Python Webbrowser fallback
elif command -v python3 >/dev/null 2>&1; then
    echo "[INFO] Attempting browser launch via python3 -m webbrowser..."
    python3 -m webbrowser "file://${PWD}/report.html" 2>/dev/null || true
    OPENED=1
# F. Headless / Terminal Fallback
else
    echo "[INFO] Web browser auto-launch unavailable in current terminal/headless environment."
fi

echo "[INFO] Universal File Path to View Report:"
if grep -qi microsoft /proc/version 2>/dev/null && command -v wslpath >/dev/null 2>&1; then
    echo "       Windows Path : $(wslpath -w "${PWD}/report.html" 2>/dev/null)"
fi
echo "       Linux Path   : ${PWD}/report.html"
echo "       File URL     : file://${PWD}/report.html"

if [ "${OPENED}" -eq 1 ]; then
    echo "[SUCCESS] Dashboard launch command dispatched successfully."
fi

echo "================================================================================"
exit 0
