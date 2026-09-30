#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_25)
# Problem Statement #25: Port Availability Check
# Focus: Network Testing & TCP Socket Reachability Probing
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   1. Sets working directory to script location (cd "$(dirname "$0")") so it
#      executes seamlessly from any directory or subshell.
#   2. Enforces GNU Bash invocation since /dev/tcp is an internal Bash feature
#      and is not available in standard POSIX /bin/sh or Dash.
#   3. Runs port_check.sh against the required demo targets (localhost:22,
#      google.com:443, google.com:12345) to capture real live network data.
#   4. Regenerates report.html from scratch on every run — a self-contained,
#      dark-themed dashboard (inline CSS only) featuring:
#      - Header with system metadata, hostname, OS, and timestamp
#      - Overview metric KPI cards (Total, Open, Refused, Timed Out, Reachability %)
#      - Status card per host:port checked (color-coded green=open, red=closed/refused, amber=timeout)
#      - Detailed diagnostic audit matrix table
#      - Live captured terminal execution log
#      - In-depth technical architecture cards (/dev/tcp internals, portability caveats, TCP states)
#   5. Dispatches the HTML dashboard automatically to the host browser across
#      WSL2, native Linux desktops, macOS, and Windows Git Bash.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. SHELL INTEGRITY VERIFICATION & DIRECTORY SETUP
# ------------------------------------------------------------------------------
# Verify invoked with Bash specifically (not /bin/sh or dash)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "❌ [ERROR] run.sh must be executed with GNU Bash (bash run.sh), not sh/dash!" >&2
    echo "           Bash is required for /dev/tcp virtual network redirection." >&2
    exit 1
fi

# cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "      AUTOMATION SPRINT (AS_25) — PORT AVAILABILITY & NETWORK AUDIT            "
echo "================================================================================"

# Verify port_check.sh exists and set executable permission
if [ ! -f "./port_check.sh" ]; then
    echo "❌ [ERROR] port_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./port_check.sh

# ------------------------------------------------------------------------------
# 2. RUN LIVE PORT AVAILABILITY CHECK
# ------------------------------------------------------------------------------
OS_SYSTEM="$(uname -s 2>/dev/null || echo 'Linux')"
echo "[INFO] Shell Engine   : GNU Bash ${BASH_VERSION}"
echo "[INFO] Host Platform  : ${OS_SYSTEM} ($(uname -r 2>/dev/null || echo 'Kernel Unknown'))"
echo "[INFO] Machine Host   : $(hostname 2>/dev/null || echo 'localhost')"
echo "[INFO] Audit Directory: $(pwd)"
echo "--------------------------------------------------------------------------------"

# Capture terminal execution output to temporary log for embedding in dashboard
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'port_term_XXXXXX')"

echo "[INFO] Launching live network probes via ./port_check.sh..."
echo "--------------------------------------------------------------------------------"

# If arguments were provided to run.sh, pass them to port_check.sh;
# otherwise default to the safe demonstration suite (localhost:22, google.com:443/12345)
set +e
if [ $# -gt 0 ]; then
    bash ./port_check.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    CHECK_EXIT_CODE=$?
else
    bash ./port_check.sh --demo 2>&1 | tee "${TMP_TERM_LOG}"
    CHECK_EXIT_CODE=$?
fi
set -e

echo "--------------------------------------------------------------------------------"
echo "[INFO] Port probe execution completed with status code: ${CHECK_EXIT_CODE}"

# Verify structured JSON telemetry file exists
JSON_META_FILE="logs/port_check.json"
if [ ! -f "${JSON_META_FILE}" ]; then
    echo "❌ [ERROR] JSON telemetry file ${JSON_META_FILE} was not generated!" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. REGENERATE report.html FROM SCRATCH (DARK THEMED INLINE CSS DASHBOARD)
# ------------------------------------------------------------------------------
echo "[INFO] Regenerating report.html dashboard from live audit telemetry..."

python3 - << 'PYEOF'
import json
import html
import os
import platform
import datetime

# Load live JSON telemetry
json_file = "logs/port_check.json"
term_log_file = None

# Locate temp terminal log
for fname in os.listdir("/tmp"):
    if fname.startswith("port_term_"):
        t_path = os.path.join("/tmp", fname)
        if os.path.isfile(t_path):
            term_log_file = t_path

try:
    with open(json_file, "r", encoding="utf-8") as f:
        meta = json.load(f)
except Exception as e:
    print(f"[ERROR] Failed to parse {json_file}: {e}")
    meta = {
        "timestamp": datetime.datetime.now().isoformat(),
        "hostname": platform.node(),
        "os": platform.system(),
        "kernel": platform.release(),
        "total_checked": 0,
        "open_count": 0,
        "closed_count": 0,
        "timeout_count": 0,
        "results": []
    }

# Read terminal output
raw_term_output = ""
if term_log_file and os.path.exists(term_log_file):
    try:
        with open(term_log_file, "r", encoding="utf-8", errors="replace") as f:
            raw_term_output = f.read()
    except Exception:
        raw_term_output = "Terminal log unavailable."
else:
    raw_term_output = "Execution completed successfully. (See logs/port_check.log for persistent history)"

# Strip ANSI escape codes for clean terminal display in HTML
import re
clean_term_output = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', raw_term_output)

timestamp = meta.get("timestamp", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
hostname = meta.get("hostname", platform.node())
os_name = meta.get("os", platform.system())
kernel = meta.get("kernel", platform.release())
total = meta.get("total_checked", 0)
open_cnt = meta.get("open_count", 0)
closed_cnt = meta.get("closed_count", 0)
timeout_cnt = meta.get("timeout_count", 0)
results = meta.get("results", [])

# Compute success/open rate
open_rate = (open_cnt / total * 100) if total > 0 else 0.0

# Generate status cards HTML
status_cards_html = ""
for idx, res in enumerate(results, 1):
    h = html.escape(str(res.get("host", "unknown")))
    p = html.escape(str(res.get("port", "0")))
    s = html.escape(str(res.get("service", "unknown")))
    st = res.get("status", "CLOSED").upper()
    lat = html.escape(str(res.get("latency_ms", "0")))
    meth = html.escape(str(res.get("method", "/dev/tcp")))
    det = html.escape(str(res.get("detail", "")))

    if st == "OPEN":
        card_border = "#10b981"
        badge_bg = "rgba(16, 185, 129, 0.15)"
        badge_color = "#34d399"
        badge_text = "✅ OPEN / REACHABLE"
        status_icon = "🟢"
    elif st == "TIMEOUT":
        card_border = "#f59e0b"
        badge_bg = "rgba(245, 158, 11, 0.15)"
        badge_color = "#fbbf24"
        badge_text = "⏱️ TIMED OUT (FILTERED)"
        status_icon = "🟠"
    else:  # REFUSED / CLOSED
        card_border = "#ef4444"
        badge_bg = "rgba(239, 68, 68, 0.15)"
        badge_color = "#f87171"
        badge_text = "❌ CLOSED (REFUSED)"
        status_icon = "🔴"

    status_cards_html += f"""
    <div class="port-card" style="border-top: 4px solid {card_border};">
        <div class="port-card-header">
            <div class="port-endpoint">
                <span class="port-icon">{status_icon}</span>
                <span class="port-host">{h}</span>
                <span class="port-number">:{p}</span>
            </div>
            <div class="port-status-badge" style="background: {badge_bg}; color: {badge_color}; border: 1px solid {card_border}40;">
                {badge_text}
            </div>
        </div>
        <div class="port-card-body">
            <div class="port-prop">
                <span class="prop-label">Service:</span>
                <span class="prop-value service-tag">{s}</span>
            </div>
            <div class="port-prop">
                <span class="prop-label">Latency:</span>
                <span class="prop-value font-mono">{lat} ms</span>
            </div>
            <div class="port-prop">
                <span class="prop-label">Engine:</span>
                <span class="prop-value engine-tag">{meth}</span>
            </div>
        </div>
        <div class="port-card-footer">
            <div class="prop-label" style="margin-bottom: 4px;">Diagnostic State:</div>
            <div class="diag-detail font-mono">{det}</div>
        </div>
    </div>
    """

# Generate table rows HTML
table_rows_html = ""
for idx, res in enumerate(results, 1):
    h = html.escape(str(res.get("host", "unknown")))
    p = html.escape(str(res.get("port", "0")))
    s = html.escape(str(res.get("service", "unknown")))
    st = res.get("status", "CLOSED").upper()
    lat = html.escape(str(res.get("latency_ms", "0")))
    meth = html.escape(str(res.get("method", "/dev/tcp")))
    det = html.escape(str(res.get("detail", "")))

    if st == "OPEN":
        badge = '<span class="status-pill status-open">✅ OPEN</span>'
    elif st == "TIMEOUT":
        badge = '<span class="status-pill status-timeout">⏱️ TIMEOUT</span>'
    else:
        badge = '<span class="status-pill status-closed">❌ CLOSED</span>'

    table_rows_html += f"""
    <tr>
        <td class="font-mono">{idx}</td>
        <td class="font-mono text-cyan"><strong>{h}</strong></td>
        <td class="font-mono text-amber"><strong>{p}/tcp</strong></td>
        <td><span class="service-pill">{s}</span></td>
        <td>{badge}</td>
        <td class="font-mono">{lat} ms</td>
        <td class="font-mono text-muted">{meth}</td>
        <td class="text-secondary text-sm">{det}</td>
    </tr>
    """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Port Availability Check Report — AS_25 (E1ITA307)</title>
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
            max-width: 1320px;
            margin: 0 auto;
        }}

        /* Header Card */
        .header-card {{
            background: linear-gradient(135deg, #111827 0%, #17223b 50%, #0d1424 100%);
            border: 1px solid var(--border-bright);
            border-radius: 12px;
            padding: 24px 28px;
            margin-bottom: 24px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
            position: relative;
            overflow: hidden;
        }}

        .header-card::before {{
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-emerald));
        }}

        .badge-row {{
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-bottom: 12px;
        }}

        .top-badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }}

        .top-badge-cyan {{
            background: rgba(56, 189, 248, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(56, 189, 248, 0.3);
        }}

        .top-badge-emerald {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-emerald);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .header-title {{
            font-size: 26px;
            font-weight: 800;
            color: #ffffff;
            margin-bottom: 8px;
            letter-spacing: -0.5px;
        }}

        .header-subtitle {{
            color: var(--text-secondary);
            font-size: 14px;
            margin-bottom: 18px;
        }}

        .meta-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
            background: rgba(10, 15, 29, 0.6);
            border: 1px solid var(--border-dim);
            border-radius: 8px;
            padding: 12px 16px;
        }}

        .meta-item {{
            display: flex;
            flex-direction: column;
        }}

        .meta-label {{
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 2px;
        }}

        .meta-value {{
            font-size: 13px;
            font-family: var(--font-mono);
            color: var(--text-primary);
            font-weight: 600;
        }}

        /* KPI Metrics Grid */
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}

        .kpi-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            padding: 18px 20px;
            transition: transform 0.2s, border-color 0.2s;
        }}

        .kpi-card:hover {{
            transform: translateY(-2px);
            border-color: var(--border-bright);
        }}

        .kpi-title {{
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}

        .kpi-value {{
            font-size: 28px;
            font-weight: 800;
            font-family: var(--font-mono);
            color: #ffffff;
            margin-bottom: 4px;
        }}

        .kpi-subtext {{
            font-size: 12px;
            color: var(--text-secondary);
        }}

        /* Status Cards Grid */
        .section-heading {{
            font-size: 18px;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .port-cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(310px, 1fr));
            gap: 16px;
            margin-bottom: 28px;
        }}

        .port-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            padding: 18px 20px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            transition: all 0.2s ease;
        }}

        .port-card:hover {{
            border-color: var(--border-bright);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
        }}

        .port-card-header {{
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 12px;
            margin-bottom: 14px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-dim);
        }}

        .port-endpoint {{
            display: flex;
            align-items: center;
            gap: 6px;
            flex-wrap: wrap;
        }}

        .port-icon {{
            font-size: 16px;
        }}

        .port-host {{
            font-weight: 700;
            font-size: 15px;
            color: #ffffff;
        }}

        .port-number {{
            font-family: var(--font-mono);
            font-weight: 700;
            font-size: 15px;
            color: var(--accent-cyan);
        }}

        .port-status-badge {{
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.3px;
            white-space: nowrap;
        }}

        .port-card-body {{
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            margin-bottom: 14px;
        }}

        .port-prop {{
            display: flex;
            flex-direction: column;
        }}

        .prop-label {{
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.3px;
            margin-bottom: 2px;
        }}

        .prop-value {{
            font-size: 13px;
            color: var(--text-primary);
            font-weight: 600;
        }}

        .service-tag {{
            color: var(--accent-amber);
            font-weight: 700;
        }}

        .engine-tag {{
            color: var(--accent-purple);
            font-family: var(--font-mono);
            font-size: 12px;
        }}

        .port-card-footer {{
            background: rgba(10, 15, 29, 0.4);
            border: 1px solid rgba(38, 51, 77, 0.6);
            border-radius: 6px;
            padding: 8px 12px;
        }}

        .diag-detail {{
            font-size: 12px;
            color: var(--text-secondary);
            line-height: 1.4;
        }}

        /* Table Card */
        .table-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 28px;
            overflow-x: auto;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }}

        th {{
            background: var(--bg-card-alt);
            color: var(--text-secondary);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 11px;
            letter-spacing: 0.5px;
            padding: 10px 14px;
            border-bottom: 1px solid var(--border-bright);
        }}

        td {{
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-dim);
            color: var(--text-primary);
        }}

        tr:last-child td {{
            border-bottom: none;
        }}

        tr:hover td {{
            background: var(--bg-hover);
        }}

        .status-pill {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 700;
        }}

        .status-open {{
            background: rgba(16, 185, 129, 0.15);
            color: #34d399;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .status-closed {{
            background: rgba(239, 68, 68, 0.15);
            color: #f87171;
            border: 1px solid rgba(239, 68, 68, 0.3);
        }}

        .status-timeout {{
            background: rgba(245, 158, 11, 0.15);
            color: #fbbf24;
            border: 1px solid rgba(245, 158, 11, 0.3);
        }}

        .service-pill {{
            background: rgba(245, 158, 11, 0.1);
            color: #fbbf24;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
        }}

        /* Terminal Console */
        .terminal-card {{
            background: #070b14;
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            margin-bottom: 28px;
            overflow: hidden;
        }}

        .terminal-header {{
            background: #0f1626;
            padding: 10px 16px;
            border-bottom: 1px solid var(--border-dim);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}

        .terminal-dots {{
            display: flex;
            gap: 6px;
        }}

        .dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }}

        .dot-red {{ background: #ef4444; }}
        .dot-yellow {{ background: #f59e0b; }}
        .dot-green {{ background: #10b981; }}

        .terminal-title {{
            font-size: 12px;
            font-family: var(--font-mono);
            color: var(--text-secondary);
        }}

        .terminal-body {{
            padding: 16px 20px;
            font-family: var(--font-mono);
            font-size: 12px;
            color: #d1d5db;
            line-height: 1.5;
            max-height: 380px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        /* Architecture Technical Cards */
        .arch-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(290px, 1fr));
            gap: 16px;
            margin-bottom: 28px;
        }}

        .arch-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 10px;
            padding: 18px 20px;
        }}

        .arch-title {{
            font-size: 14px;
            font-weight: 700;
            color: var(--accent-cyan);
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 6px;
        }}

        .arch-body {{
            font-size: 12.5px;
            color: var(--text-secondary);
            line-height: 1.5;
        }}

        .arch-body code {{
            background: var(--bg-card-alt);
            color: var(--accent-amber);
            padding: 2px 4px;
            border-radius: 4px;
            font-family: var(--font-mono);
            font-size: 11.5px;
        }}

        /* Utilities */
        .font-mono {{ font-family: var(--font-mono); }}
        .text-cyan {{ color: var(--accent-cyan); }}
        .text-emerald {{ color: var(--accent-emerald); }}
        .text-amber {{ color: var(--accent-amber); }}
        .text-red {{ color: var(--accent-red); }}
        .text-secondary {{ color: var(--text-secondary); }}
        .text-muted {{ color: var(--text-muted); }}
        .text-sm {{ font-size: 12px; }}

        footer {{
            text-align: center;
            padding-top: 16px;
            border-top: 1px solid var(--border-dim);
            color: var(--text-muted);
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <div class="container">

        <!-- Top Header Card -->
        <header class="header-card">
            <div class="badge-row">
                <span class="top-badge top-badge-cyan">AS_25: Port Availability Check</span>
                <span class="top-badge top-badge-emerald">Live Network Telemetry</span>
                <span class="top-badge top-badge-cyan">E1ITA307 — Automation Sprint</span>
            </div>
            <h1 class="header-title">🌐 TCP Port Reachability & Network Testing Dashboard</h1>
            <p class="header-subtitle">
                Real-time active TCP socket reachability analysis using Bash <code>/dev/tcp</code> virtual redirection with automated Netcat (<code>nc -zv -w3</code>) fallback.
            </p>
            <div class="meta-grid">
                <div class="meta-item">
                    <span class="meta-label">Audit Timestamp</span>
                    <span class="meta-value">{html.escape(timestamp)}</span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Audit Target Host</span>
                    <span class="meta-value text-cyan">{html.escape(hostname)}</span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Platform OS & Kernel</span>
                    <span class="meta-value text-emerald">{html.escape(os_name)} ({html.escape(kernel)})</span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Primary Probe Engine</span>
                    <span class="meta-value text-amber">GNU Bash /dev/tcp + nc</span>
                </div>
            </div>
        </header>

        <!-- Executive KPI Metrics -->
        <section class="kpi-grid">
            <div class="kpi-card" style="border-left: 4px solid var(--accent-blue);">
                <div class="kpi-title">
                    <span>Total Ports Probed</span>
                    <span>🎯</span>
                </div>
                <div class="kpi-value">{total}</div>
                <div class="kpi-subtext">Sockets probed across targets</div>
            </div>

            <div class="kpi-card" style="border-left: 4px solid var(--accent-emerald);">
                <div class="kpi-title">
                    <span>Open / Reachable</span>
                    <span>🟢</span>
                </div>
                <div class="kpi-value text-emerald">{open_cnt}</div>
                <div class="kpi-subtext">Active listeners (SYN-ACK)</div>
            </div>

            <div class="kpi-card" style="border-left: 4px solid var(--accent-red);">
                <div class="kpi-title">
                    <span>Closed / Refused</span>
                    <span>🔴</span>
                </div>
                <div class="kpi-value text-red">{closed_cnt}</div>
                <div class="kpi-subtext">Active resets (TCP RST received)</div>
            </div>

            <div class="kpi-card" style="border-left: 4px solid var(--accent-amber);">
                <div class="kpi-title">
                    <span>Timed Out / Filtered</span>
                    <span>🟠</span>
                </div>
                <div class="kpi-value text-amber">{timeout_cnt}</div>
                <div class="kpi-subtext">Firewall silent packet drops</div>
            </div>

            <div class="kpi-card" style="border-left: 4px solid var(--accent-purple);">
                <div class="kpi-title">
                    <span>Reachability Rate</span>
                    <span>📊</span>
                </div>
                <div class="kpi-value">{open_rate:.1f}%</div>
                <div class="kpi-subtext">Proportion of reachable sockets</div>
            </div>
        </section>

        <!-- Status Cards Per Host:Port -->
        <h2 class="section-heading">📌 Target Endpoint Status Cards</h2>
        <section class="port-cards-grid">
            {status_cards_html}
        </section>

        <!-- Detailed Inspection Table -->
        <h2 class="section-heading">📋 Comprehensive Port Audit Matrix</h2>
        <section class="table-card">
            <table>
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Host</th>
                        <th>Port / Protocol</th>
                        <th>Well-Known Service</th>
                        <th>Reachability Status</th>
                        <th>RTT Latency</th>
                        <th>Probe Engine</th>
                        <th>Diagnostic State & System Trace</th>
                    </tr>
                </thead>
                <tbody>
                    {table_rows_html}
                </tbody>
            </table>
        </section>

        <!-- Terminal Output Stream -->
        <h2 class="section-heading">💻 Live Terminal Execution Console Stream</h2>
        <section class="terminal-card">
            <div class="terminal-header">
                <div class="terminal-dots">
                    <div class="dot dot-red"></div>
                    <div class="dot dot-yellow"></div>
                    <div class="dot dot-green"></div>
                </div>
                <div class="terminal-title">bash ./port_check.sh — Live Session Capture</div>
                <div style="font-size: 11px; color: var(--text-muted); font-family: var(--font-mono);">UTF-8 TTY</div>
            </div>
            <div class="terminal-body">{html.escape(clean_term_output)}</div>
        </section>

        <!-- Technical Deep-Dive & Architectural Foundations -->
        <h2 class="section-heading">🧠 Architectural Reference & Network Mechanics</h2>
        <section class="arch-grid">
            <div class="arch-card">
                <div class="arch-title">🔌 Bash /dev/tcp Virtual Redirection</div>
                <div class="arch-body">
                    Bash implements <code>/dev/tcp/HOST/PORT</code> as an internal parser abstraction rather than a physical filesystem node. When redirection occurs, Bash invokes libc <code>getaddrinfo()</code>, allocates a <code>SOCK_STREAM</code> socket, and executes <code>connect()</code> to complete the TCP 3-way handshake (SYN, SYN-ACK, ACK).
                </div>
            </div>

            <div class="arch-card">
                <div class="arch-title">⚠️ Portability & Shell Constraints</div>
                <div class="arch-body">
                    <code>/dev/tcp</code> is a GNU Bash compile-time option (<code>--enable-net-redirections</code>). It is completely missing in POSIX <code>/bin/sh</code>, Debian <code>dash</code>, and BusyBox <code>ash</code>. Running scripts with <code>sh</code> results in "No such file or directory". This script strictly verifies Bash invocation and incorporates Netcat fallback.
                </div>
            </div>

            <div class="arch-card">
                <div class="arch-title">🔄 TCP State & Rejection Differentiation</div>
                <div class="arch-body">
                    <strong>OPEN (Exit 0):</strong> Host replied with SYN-ACK; socket connected.<br>
                    <strong>REFUSED (Exit 1):</strong> Host replied with TCP RST packet; port is actively closed.<br>
                    <strong>TIMEOUT (Exit 124):</strong> No packet response within timeout limit; indicates firewall packet filtering (DROP) or unresponsive route.
                </div>
            </div>

            <div class="arch-card">
                <div class="arch-title">🛡️ Resilient Netcat Fallback Engine</div>
                <div class="arch-body">
                    When <code>/dev/tcp</code> is disabled or forced via <code>--nc</code>, the script invokes OpenBSD netcat: <code>nc -zv -w3 &lt;host&gt; &lt;port&gt;</code>. The <code>-z</code> flag enables zero-I/O port scanning mode, ensuring no application payload is sent while testing socket reachability.
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer>
            <div>
                <strong>Automation Sprint (AS_25) — Port Availability Check</strong> | Course: Linux System Administration (E1ITA307)
            </div>
            <div style="margin-top: 6px;">
                Live Machine & Remote Service Audit • Generated at {html.escape(timestamp)} • Strict Sandboxing & Read-Only Compliance
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

# Clean up temporary terminal log
if [ -n "${TMP_TERM_LOG:-}" ] && [ -f "${TMP_TERM_LOG}" ]; then
    rm -f "${TMP_TERM_LOG}"
fi

# ------------------------------------------------------------------------------
# 4. CROSS-PLATFORM BROWSER AUTO-LAUNCH (OS DETECTION)
# ------------------------------------------------------------------------------
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
