#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_23)
# Problem Statement #23: IP Configuration Report
# Focus: Network Administration & System Audit
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE:
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Detects OS platform and runs ip_config_report.sh to gather live telemetry.
#   3. Regenerates report.html from scratch every run (dark-themed dashboard).
#   4. Dispatches the HTML dashboard automatically to the host browser across
#      WSL2, native Linux desktops, macOS, and Windows Git Bash.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_23) — IP CONFIGURATION REPORT                   "
echo "================================================================================"

# Verify ip_config_report.sh exists and is executable
if [ ! -f "./ip_config_report.sh" ]; then
    echo "[ERROR] ip_config_report.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./ip_config_report.sh

# 2. Branch data gathering and environment detection
OS_SYSTEM="$(uname -s)"
echo "[INFO] Host Kernel Architecture: ${OS_SYSTEM} ($(uname -m 2>/dev/null || echo 'Unknown'))"

# Capture terminal execution output to temporary log for embedding in dashboard
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'ip_term_XXXXXX')"
echo "[INFO] Executing live network audit via ip_config_report.sh..."
echo "--------------------------------------------------------------------------------"
./ip_config_report.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
echo "--------------------------------------------------------------------------------"

# Verify structured JSON telemetry file exists
JSON_META_FILE="reports/.last_report.json"
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

json_path = os.path.join("reports", ".last_report.json")
if not os.path.exists(json_path):
    print(f"[ERROR] Telemetry file not found: {json_path}", file=sys.stderr)
    sys.exit(1)

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

terminal_log = os.environ.get("TERMINAL_LOG_CONTENT", "").strip()

# Extract fields
timestamp = data.get("timestamp", "N/A")
hostname = data.get("hostname", "localhost")
os_distro = data.get("os_distro", "Linux")
kernel = data.get("kernel", "Unknown")
arch = data.get("arch", "x86_64")
tool_used = data.get("tool_used", "iproute2 (ip)")
all_ips_summary = data.get("all_ips_summary", "None")

gw_data = data.get("default_gateway", {})
gw_ip = gw_data.get("ip", "None")
gw_iface = gw_data.get("interface", "None")
gw_proto = gw_data.get("protocol", "kernel")
gw_metric = gw_data.get("metric", "N/A")
gw_raw = gw_data.get("raw", "None")

dns_data = data.get("dns", {})
dns_servers = dns_data.get("servers", [])
dns_search = dns_data.get("search_domains", "")
dns_servers_str = ", ".join(dns_servers) if dns_servers else "None detected"

summary = data.get("summary", {})
total_ifaces = summary.get("total_active_interfaces", 0)
primary_iface = summary.get("primary_interface", "None")
primary_ip = summary.get("primary_ip", "None")

interfaces = data.get("interfaces", [])

# Count loopback vs physical/virtual
loopback_count = sum(1 for iface in interfaces if iface.get("type") == "Loopback" or iface.get("name") == "lo")
phys_count = total_ifaces - loopback_count

# List existing report files
reports_list = []
reports_dir = "reports"
if os.path.exists(reports_dir):
    for fname in sorted(os.listdir(reports_dir), reverse=True):
        if fname.startswith("ip_report_") and fname.endswith(".txt"):
            fpath = os.path.join(reports_dir, fname)
            fsize = os.path.getsize(fpath)
            reports_list.append((fname, f"{fsize} B"))

# Generate Table Rows for Interfaces
table_rows = []
for iface in interfaces:
    name = html.escape(str(iface.get("name", "")))
    state = html.escape(str(iface.get("state", "UNKNOWN")))
    if_type = html.escape(str(iface.get("type", "Unknown")))
    mac = html.escape(str(iface.get("mac", "00:00:00:00:00:00")))
    mtu = html.escape(str(iface.get("mtu", 1500)))
    ipv4 = html.escape(str(iface.get("ipv4", "None")))
    ipv6 = html.escape(str(iface.get("ipv6", "None")))

    state_badge_class = "badge-green" if state == "UP" else "badge-amber"
    
    # Format IPs with badge pills
    ipv4_badges = ""
    if ipv4 and ipv4 != "None":
        for ip_item in ipv4.split(","):
            ip_clean = ip_item.strip()
            if ip_clean:
                ipv4_badges += f'<span class="code-pill ipv4-pill">{ip_clean}</span> '
    else:
        ipv4_badges = '<span class="text-muted">Unassigned</span>'

    ipv6_badges = ""
    if ipv6 and ipv6 != "None":
        for ip_item in ipv6.split(","):
            ip_clean = ip_item.strip()
            if ip_clean:
                ipv6_badges += f'<span class="code-pill ipv6-pill">{ip_clean}</span> '
    else:
        ipv6_badges = '<span class="text-muted">Unassigned</span>'

    row_html = f"""
    <tr>
        <td class="cell-ifname">
            <strong>{name}</strong>
            <div class="if-type-sub">{if_type}</div>
        </td>
        <td><span class="badge {state_badge_class}">{state}</span></td>
        <td><code class="mac-code">{mac}</code></td>
        <td><span class="mtu-val">{mtu} <small>bytes</small></span></td>
        <td>{ipv4_badges}</td>
        <td>{ipv6_badges}</td>
    </tr>
    """
    table_rows.append(row_html)

interface_table_body = "\n".join(table_rows) if table_rows else "<tr><td colspan='6' class='text-center'>No active interfaces found.</td></tr>"

# Generate report file list HTML
report_files_html = ""
for rname, rsize in reports_list[:8]:
    report_files_html += f"""
    <div class="report-file-item">
        <span class="report-file-name">📄 {html.escape(rname)}</span>
        <span class="report-file-meta">{rsize}</span>
    </div>
    """
if not report_files_html:
    report_files_html = "<div class='text-muted'>No historical report files recorded yet.</div>"

# DNS pills
dns_pills = ""
if dns_servers:
    for dns_ip in dns_servers:
        dns_pills += f'<span class="dns-chip">🌐 {html.escape(dns_ip)}</span> '
else:
    dns_pills = '<span class="text-muted">System Default Resolver</span>'

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IP Configuration Report — AS_23 (E1ITA307)</title>
    <style>
        :root {{
            --bg-base: #0b1120;
            --bg-card: #131d35;
            --bg-card-alt: #1a2744;
            --bg-hover: #1e2e54;
            --border-dim: #233252;
            --border-bright: #3b507d;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
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
            line-height: 1.5;
            padding: 24px;
        }}

        .container {{
            max-width: 1320px;
            margin: 0 auto;
        }}

        /* Header Card */
        .header-card {{
            background: linear-gradient(135deg, #131d35 0%, #172547 50%, #0f172a 100%);
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
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-emerald));
        }}

        .header-top {{
            display: flex;
            flex-wrap: wrap;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
            margin-bottom: 12px;
        }}

        .badges-cluster {{
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }}

        .badge {{
            display: inline-flex;
            align-items: center;
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }}

        .badge-cyan {{
            background: rgba(56, 189, 248, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(56, 189, 248, 0.3);
        }}

        .badge-green {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-emerald);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}

        .badge-amber {{
            background: rgba(245, 158, 11, 0.15);
            color: var(--accent-amber);
            border: 1px solid rgba(245, 158, 11, 0.3);
        }}

        .badge-purple {{
            background: rgba(168, 85, 247, 0.15);
            color: var(--accent-purple);
            border: 1px solid rgba(168, 85, 247, 0.3);
        }}

        .header-title {{
            font-size: 1.95rem;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: -0.02em;
            margin-bottom: 6px;
        }}

        .header-subtitle {{
            color: var(--text-secondary);
            font-size: 0.95rem;
            margin-bottom: 18px;
        }}

        .meta-strip {{
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            font-size: 0.85rem;
            color: var(--text-secondary);
            border-top: 1px solid rgba(255, 255, 255, 0.08);
            padding-top: 14px;
        }}

        .meta-item strong {{
            color: #e2e8f0;
        }}

        /* Summary Cards Grid */
        .cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}

        .summary-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 12px;
            padding: 20px;
            transition: transform 0.15s ease, border-color 0.15s ease;
        }}

        .summary-card:hover {{
            transform: translateY(-2px);
            border-color: var(--border-bright);
        }}

        .card-label {{
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--text-muted);
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}

        .card-value {{
            font-size: 1.6rem;
            font-weight: 800;
            color: #ffffff;
            margin-bottom: 6px;
            font-family: var(--font-mono);
            word-break: break-all;
        }}

        .card-subtext {{
            font-size: 0.85rem;
            color: var(--text-secondary);
        }}

        /* Section Layout */
        .section-box {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-dim);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
        }}

        .section-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 18px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-dim);
        }}

        .section-title {{
            font-size: 1.2rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        /* Table Styling */
        .table-responsive {{
            overflow-x: auto;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
            text-align: left;
        }}

        th {{
            background-color: var(--bg-card-alt);
            color: var(--text-secondary);
            font-weight: 700;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-dim);
        }}

        td {{
            padding: 14px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            vertical-align: middle;
        }}

        tr:hover td {{
            background-color: rgba(255, 255, 255, 0.02);
        }}

        .cell-ifname {{
            font-family: var(--font-mono);
            font-size: 1rem;
        }}

        .if-type-sub {{
            font-size: 0.75rem;
            color: var(--text-muted);
            font-family: var(--font-sans);
            margin-top: 2px;
        }}

        .mac-code {{
            font-family: var(--font-mono);
            color: var(--accent-cyan);
            background: rgba(56, 189, 248, 0.08);
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 0.85rem;
        }}

        .mtu-val {{
            font-family: var(--font-mono);
            color: #e2e8f0;
            font-weight: 600;
        }}

        .code-pill {{
            display: inline-block;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            padding: 2px 8px;
            border-radius: 6px;
            margin: 2px 2px 2px 0;
            font-weight: 500;
        }}

        .ipv4-pill {{
            background: rgba(16, 185, 129, 0.12);
            color: #34d399;
            border: 1px solid rgba(16, 185, 129, 0.25);
        }}

        .ipv6-pill {{
            background: rgba(168, 85, 247, 0.12);
            color: #c084fc;
            border: 1px solid rgba(168, 85, 247, 0.25);
        }}

        .dns-chip {{
            display: inline-flex;
            align-items: center;
            background: rgba(59, 130, 246, 0.15);
            color: #60a5fa;
            border: 1px solid rgba(59, 130, 246, 0.3);
            border-radius: 8px;
            padding: 4px 10px;
            font-family: var(--font-mono);
            font-size: 0.85rem;
            margin-right: 6px;
            margin-bottom: 6px;
        }}

        /* Two Column Layout */
        .two-col-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(450px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
        }}

        /* Tech Details List */
        .tech-list {{
            list-style: none;
        }}

        .tech-item {{
            padding: 10px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.9rem;
        }}

        .tech-item:last-child {{
            border-bottom: none;
        }}

        .tech-key {{
            color: var(--text-secondary);
        }}

        .tech-val {{
            color: #f1f5f9;
            font-family: var(--font-mono);
            font-weight: 600;
        }}

        /* Comparison Matrix */
        .comp-table th {{
            background-color: #17223b;
        }}

        .comp-table td {{
            font-size: 0.85rem;
        }}

        .tag-modern {{
            color: var(--accent-emerald);
            font-weight: 700;
        }}

        .tag-legacy {{
            color: var(--accent-amber);
            font-weight: 700;
        }}

        /* Terminal Console Box */
        .terminal-box {{
            background-color: #030712;
            border: 1px solid #1f2937;
            border-radius: 10px;
            padding: 18px;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            color: #cbd5e1;
            white-space: pre-wrap;
            overflow-x: auto;
            max-height: 400px;
            line-height: 1.45;
        }}

        /* Audit File Items */
        .report-file-item {{
            display: flex;
            justify-content: space-between;
            padding: 8px 12px;
            background: var(--bg-card-alt);
            border-radius: 6px;
            margin-bottom: 6px;
            font-size: 0.85rem;
        }}

        .report-file-name {{
            font-family: var(--font-mono);
            color: #e2e8f0;
        }}

        .report-file-meta {{
            color: var(--text-muted);
            font-family: var(--font-mono);
        }}

        /* Footer */
        footer {{
            text-align: center;
            padding: 24px 0 12px 0;
            color: var(--text-muted);
            font-size: 0.85rem;
            border-top: 1px solid var(--border-dim);
            margin-top: 24px;
        }}

        .text-center {{ text-align: center; }}
        .text-muted {{ color: var(--text-muted); }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header Banner -->
        <header class="header-card">
            <div class="header-top">
                <div class="badges-cluster">
                    <span class="badge badge-cyan">Course: E1ITA307</span>
                    <span class="badge badge-purple">Sprint: AS_23</span>
                    <span class="badge badge-green">Status: Live Audit Active</span>
                    <span class="badge badge-amber">Engine: {html.escape(tool_used)}</span>
                </div>
                <div style="font-size: 0.82rem; color: var(--text-muted); font-family: var(--font-mono);">
                    ID: 00944bd8-5d05-4b17-aa54-cdfbae1eaad5
                </div>
            </div>
            <h1 class="header-title">IP Configuration &amp; Network Interface Audit</h1>
            <p class="header-subtitle">
                Real-time kernel telemetry capturing local host identity, routing vectors, hardware MAC bindings, MTU boundaries, and DNS resolvers via netlink sockets.
            </p>
            <div class="meta-strip">
                <div class="meta-item">Timestamp: <strong>{html.escape(timestamp)}</strong></div>
                <div class="meta-item">Host Platform: <strong>{html.escape(os_distro)}</strong></div>
                <div class="meta-item">Kernel: <strong>{html.escape(kernel)}</strong></div>
                <div class="meta-item">Architecture: <strong>{html.escape(arch)}</strong></div>
            </div>
        </header>

        <!-- Summary Cards Grid -->
        <div class="cards-grid">
            <!-- Card 1: Hostname -->
            <div class="summary-card">
                <div class="card-label">
                    <span>Host Identity</span>
                    <span>💻</span>
                </div>
                <div class="card-value" style="color: var(--accent-cyan);">{html.escape(hostname)}</div>
                <div class="card-subtext">All IPs: <code>{html.escape(all_ips_summary)}</code></div>
            </div>

            <!-- Card 2: Primary IPv4 -->
            <div class="summary-card">
                <div class="card-label">
                    <span>Primary IPv4 Address</span>
                    <span>📡</span>
                </div>
                <div class="card-value" style="color: var(--accent-emerald);">{html.escape(primary_ip)}</div>
                <div class="card-subtext">Bound to interface: <strong>{html.escape(primary_iface)}</strong></div>
            </div>

            <!-- Card 3: Default Gateway -->
            <div class="summary-card">
                <div class="card-label">
                    <span>Default Gateway</span>
                    <span>🌐</span>
                </div>
                <div class="card-value" style="color: #60a5fa;">{html.escape(gw_ip)}</div>
                <div class="card-subtext">Egress Dev: <strong>{html.escape(gw_iface)}</strong> (Proto: {html.escape(gw_proto)})</div>
            </div>

            <!-- Card 4: Active Interfaces -->
            <div class="summary-card">
                <div class="card-label">
                    <span>Active Interfaces</span>
                    <span>🔌</span>
                </div>
                <div class="card-value" style="color: var(--accent-amber);">{total_ifaces} <small style="font-size: 0.9rem; color: var(--text-muted);">UP</small></div>
                <div class="card-subtext">{phys_count} Physical/Virtual &bull; {loopback_count} Loopback</div>
            </div>
        </div>

        <!-- Active Network Interfaces Table -->
        <div class="section-box">
            <div class="section-header">
                <h2 class="section-title">
                    <span>Active Network Interfaces &amp; Address Bindings</span>
                </h2>
                <span class="badge badge-cyan">{total_ifaces} Interfaces Detected</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Interface / Type</th>
                            <th>Oper State</th>
                            <th>MAC Hardware Address</th>
                            <th>MTU Limit</th>
                            <th>IPv4 Address / CIDR</th>
                            <th>IPv6 Address / CIDR</th>
                        </tr>
                    </thead>
                    <tbody>
                        {interface_table_body}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Two Column Deep Dive: Routing & DNS -->
        <div class="two-col-grid">
            <!-- Box A: Routing & Gateway Details -->
            <div class="section-box">
                <div class="section-header">
                    <h3 class="section-title">🛣️ Routing Table Telemetry</h3>
                    <span class="badge badge-green">FIB Active</span>
                </div>
                <ul class="tech-list">
                    <li class="tech-item">
                        <span class="tech-key">Default Gateway IP</span>
                        <span class="tech-val">{html.escape(gw_ip)}</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Egress Interface</span>
                        <span class="tech-val">{html.escape(gw_iface)}</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Routing Protocol</span>
                        <span class="tech-val">{html.escape(gw_proto)}</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Route Metric Priority</span>
                        <span class="tech-val">{html.escape(gw_metric)}</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Raw Route Directive</span>
                        <span class="tech-val" style="font-size: 0.78rem;">{html.escape(gw_raw)}</span>
                    </li>
                </ul>
            </div>

            <!-- Box B: DNS Resolver Configuration -->
            <div class="section-box">
                <div class="section-header">
                    <h3 class="section-title">🔎 DNS Resolver Directives</h3>
                    <span class="badge badge-purple">Resolver Active</span>
                </div>
                <div style="margin-bottom: 14px;">
                    <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 6px; font-weight: 700;">Configured Nameservers</div>
                    <div>{dns_pills}</div>
                </div>
                <ul class="tech-list">
                    <li class="tech-item">
                        <span class="tech-key">Search Domains</span>
                        <span class="tech-val">{html.escape(dns_search if dns_search else "None configured")}</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Configuration Source</span>
                        <span class="tech-val">/etc/resolv.conf</span>
                    </li>
                    <li class="tech-item">
                        <span class="tech-key">Resolution Mode</span>
                        <span class="tech-val">System Stub / Dynamic</span>
                    </li>
                </ul>
            </div>
        </div>

        <!-- Architectural Comparison Matrix: iproute2 vs net-tools -->
        <div class="section-box">
            <div class="section-header">
                <h3 class="section-title">⚖️ Architectural Rationale: iproute2 (ip) vs Legacy net-tools (ifconfig/route)</h3>
                <span class="badge badge-amber">Engineering Deep Dive</span>
            </div>
            <div class="table-responsive">
                <table class="comp-table">
                    <thead>
                        <tr>
                            <th style="width: 20%;">Architectural Metric</th>
                            <th style="width: 40%;">Modern iproute2 (<code>ip</code> suite)</th>
                            <th style="width: 40%;">Legacy net-tools (<code>ifconfig</code> / <code>route</code>)</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Kernel Communication</strong></td>
                            <td><span class="tag-modern">AF_NETLINK Sockets:</span> High-throughput, asynchronous, event-driven kernel datagram communication.</td>
                            <td><span class="tag-legacy">Synchronous ioctl():</span> Slow, inflexible system calls incapable of conveying rich modern link state.</td>
                        </tr>
                        <tr>
                            <td><strong>Multi-IP Handling</strong></td>
                            <td><span class="tag-modern">Native First-Class Objects:</span> Dozens of addresses bind directly to a single link without artificial alias syntax.</td>
                            <td><span class="tag-legacy">Archaic Alias Hack:</span> Required virtual sub-interfaces (<code>eth0:0</code>, <code>eth0:1</code>); hides secondary unlabeled IPs.</td>
                        </tr>
                        <tr>
                            <td><strong>Subnet Representation</strong></td>
                            <td><span class="tag-modern">Native CIDR Notation:</span> Standard prefix length notation (<code>/24</code>, <code>/20</code>, <code>/64</code>) used universally.</td>
                            <td><span class="tag-legacy">Dotted Decimal Masks:</span> Verbose <code>netmask 255.255.255.0</code> inherited from legacy classful era.</td>
                        </tr>
                        <tr>
                            <td><strong>Namespaces &amp; Containers</strong></td>
                            <td><span class="tag-modern">Complete Netns Integration:</span> Full control of virtual ethernet, network namespaces, bridges, and VRFs.</td>
                            <td><span class="tag-legacy">Zero Namespace Awareness:</span> Incapable of inspecting or isolating containerized networking environments.</td>
                        </tr>
                        <tr>
                            <td><strong>Policy Routing &amp; FIB</strong></td>
                            <td><span class="tag-modern">Policy Routing (PBR):</span> Manages multiple routing tables, traffic selectors, metrics, and multipath rules.</td>
                            <td><span class="tag-legacy">Single Static Table:</span> Strictly limited to the default kernel destination routing table.</td>
                        </tr>
                        <tr>
                            <td><strong>Distribution Status</strong></td>
                            <td><span class="tag-modern">Default Standard:</span> Actively developed in lockstep with the Linux kernel across all enterprise distributions.</td>
                            <td><span class="tag-legacy">Deprecated:</span> Officially deprecated in ~2009; omitted from Ubuntu, Debian, RHEL, and Fedora default installs.</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Terminal Output Log Box -->
        <div class="section-box">
            <div class="section-header">
                <h3 class="section-title">🖥️ Live Terminal Execution Capture</h3>
                <span class="badge badge-cyan">CLI Output</span>
            </div>
            <div class="terminal-box">{html.escape(terminal_log)}</div>
        </div>

        <!-- Historical Reports Audit Trail -->
        <div class="section-box">
            <div class="section-header">
                <h3 class="section-title">📁 Generated Audit Reports (Inside <code>reports/</code>)</h3>
                <span class="badge badge-purple">{len(reports_list)} Saved Runs</span>
            </div>
            <div>
                {report_files_html}
            </div>
        </div>

        <!-- Footer -->
        <footer>
            <p><strong>Course:</strong> Linux System Administration (E1ITA307) &bull; Automation Sprint AS_23 &bull; IP Configuration Report</p>
            <p style="margin-top: 4px; font-size: 0.8rem;">Live Network Telemetry captured via <code>iproute2</code>. Report auto-regenerated from live system state on every run.</p>
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
elif [ "${OS_SYSTEM}" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    echo "[INFO] Detected macOS Darwin environment."
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
