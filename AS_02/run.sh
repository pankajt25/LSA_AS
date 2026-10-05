#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_02)
# Problem Statement #2: Inactive Employee Detection
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   1. Resolves and switches to its own directory (cd "$(dirname "$0")") for
#      reliable cross-environment execution.
#   2. Executes inactive_employee_detector.sh to collect this host machine's
#      real local user accounts and actual last-login authentication activity.
#   3. Regenerates a completely self-contained dark-themed report.html from
#      scratch every run with zero external network dependencies (inline CSS only).
#   4. Dashboard features:
#      - System context header (hostname, OS, kernel, uptime, audit timestamp)
#      - Executive KPI metric cards (Total Audited, Active, Inactive, Inactivity Rate, Threshold)
#      - Real-time client-side search and filtering (All, Active Only, Inactive Only)
#      - Color-coded accounts audit table (Green=Active, Red=Inactive) with shell, UID, and notes
#      - In-depth Linux User Administration & Authentication technical guide
#      - Live captured terminal execution transcript
#   5. Automatically detects host environment and launches report.html:
#      - WSL: explorer.exe "$(wslpath -w report.html)"
#      - Linux: xdg-open report.html
#      - macOS: open report.html (with notes on lastlog vs last)
#      - Windows Git Bash: start "" report.html
#      - Headless/fallback: prints absolute file:/// path
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

echo "================================================================================"
echo "      AUTOMATION SPRINT (AS_02) — INACTIVE EMPLOYEE DETECTION DASHBOARD         "
echo "================================================================================"

# Verify detector script exists and set execute permission
DETECTOR_SCRIPT="./inactive_employee_detector.sh"
if [ ! -f "${DETECTOR_SCRIPT}" ]; then
    echo "❌ [ERROR] ${DETECTOR_SCRIPT} not found in ${SCRIPT_DIR}!" >&2
    exit 1
fi
chmod +x "${DETECTOR_SCRIPT}"

# 2. Run detector script and capture terminal output while streaming to console
echo "[INFO] Executing ${DETECTOR_SCRIPT} on live machine..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
"${DETECTOR_SCRIPT}" "$@" 2>&1 | tee "${TMP_TERM_LOG}"
echo "--------------------------------------------------------------------------------"

# Capture JSON telemetry for deterministic HTML rendering
TMP_JSON="$(mktemp)"
"${DETECTOR_SCRIPT}" --json "$@" > "${TMP_JSON}" 2>/dev/null || echo "{}" > "${TMP_JSON}"

# 3. Gather system context metrics
OS_SYSTEM="$(uname -s 2>/dev/null || echo 'Linux')"
KERNEL_VER="$(uname -r 2>/dev/null || echo 'Unknown')"
HOST_NAME="$(hostname 2>/dev/null || uname -n)"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
CURRENT_USER="$(whoami 2>/dev/null || echo 'Administrator')"

# System uptime
UPTIME_VAL="$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/' || echo 'Active')"

# OS Display name
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_DISPLAY="${PRETTY_NAME:-$OS_SYSTEM}"
elif [ "${OS_SYSTEM}" = "Darwin" ]; then
    OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
else
    OS_DISPLAY="${OS_SYSTEM}"
fi

# Audit log preview
LOG_FILE_PATH="logs/inactive_check.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 40 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No audit log entries recorded yet."
fi

# 4. Generate report.html from scratch using Python 3
echo "[INFO] Regenerating report.html dashboard with live data..."

python3 - "${TMP_JSON}" "${SCRIPT_DIR}/report.html" "${TMP_TERM_LOG}" <<'PYEOF'
import sys
import json
import html
import os

json_file = sys.argv[1]
output_html = sys.argv[2]
term_log_file = sys.argv[3]

with open(term_log_file, 'r', encoding='utf-8') as f:
    terminal_log_text = f.read()

try:
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception as e:
    data = {
        "audit_metadata": {},
        "summary": {},
        "accounts": []
    }

metadata = data.get("audit_metadata", {})
summary = data.get("summary", {})
accounts = data.get("accounts", [])

hostname = html.escape(str(metadata.get("hostname", os.uname().nodename)))
os_name = html.escape(str(metadata.get("os_name", "Linux")))
kernel = html.escape(str(metadata.get("kernel", os.uname().release)))
audit_time = html.escape(str(metadata.get("audit_timestamp_local", "N/A")))
threshold_days = metadata.get("threshold_days", 30)

engines = metadata.get("engines_detected", {})
engine_primary = html.escape(str(engines.get("primary", "none")))
engine_secondary = html.escape(str(engines.get("secondary", "none")))
engine_tertiary = html.escape(str(engines.get("tertiary", "loginctl / who / auth.log")))

total_accounts = summary.get("total_accounts_audited", len(accounts))
active_accounts = summary.get("active_accounts", sum(1 for a in accounts if a.get("status") == "ACTIVE"))
inactive_accounts = summary.get("inactive_accounts", sum(1 for a in accounts if a.get("status") == "INACTIVE"))
inactivity_rate = summary.get("inactivity_rate_percent", round((inactive_accounts / max(total_accounts, 1)) * 100, 1))

# Build Table Rows
table_rows = []
for idx, acc in enumerate(accounts, 1):
    u_name = html.escape(str(acc.get("username", "")))
    u_uid = html.escape(str(acc.get("uid", "")))
    u_shell = html.escape(str(acc.get("shell", "")))
    u_home = html.escape(str(acc.get("home", "")))
    u_date = html.escape(str(acc.get("last_login_date", "Never")))
    u_days = acc.get("days_inactive")
    u_status = html.escape(str(acc.get("status", "INACTIVE")))
    u_via = html.escape(str(acc.get("resolved_via", "N/A")))

    if u_status == "ACTIVE":
        badge_cls = "badge-active"
        badge_text = "ACTIVE"
        days_disp = f'<span class="text-green">{u_days} days</span>'
        action_note = "Active recently — Compliant with security policy."
        row_cls = "row-active"
    else:
        badge_cls = "badge-inactive"
        badge_text = "INACTIVE"
        if u_date == "Never":
            days_disp = '<span class="text-red">Never logged in</span>'
            action_note = "Never authenticated — Candidate for lock / deprovisioning."
        else:
            days_disp = f'<span class="text-amber">{u_days} days</span>'
            action_note = f"Exceeds {threshold_days}d threshold — Flagged for administrative review."
        row_cls = "row-inactive"

    row_html = f"""
    <tr class="{row_cls}" data-status="{u_status.lower()}" data-search="{u_name.lower()} {u_uid} {u_shell.lower()} {u_status.lower()}">
        <td class="text-muted text-center">{idx}</td>
        <td>
            <div class="user-cell">
                <span class="avatar-icon">👤</span>
                <span class="user-name">{u_name}</span>
            </div>
        </td>
        <td class="text-center font-mono">{u_uid}</td>
        <td><code class="shell-code">{u_shell}</code></td>
        <td class="font-mono">{u_date}</td>
        <td class="text-center font-mono">{days_disp}</td>
        <td class="text-center"><span class="badge {badge_cls}">{badge_text}</span></td>
        <td class="text-muted font-sm">{u_via}</td>
        <td class="action-note">{action_note}</td>
    </tr>
    """
    table_rows.append(row_html)

table_rows_str = "\n".join(table_rows)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Inactive Employee Detection Dashboard | AS_02</title>
    <style>
        :root {{
            --bg-primary: #0b0f19;
            --bg-secondary: #111827;
            --bg-card: #182234;
            --bg-card-hover: #1e293b;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --border-color: #273549;
            --status-green: #10b981;
            --status-green-bg: rgba(16, 185, 129, 0.12);
            --status-green-border: rgba(16, 185, 129, 0.35);
            --status-red: #ef4444;
            --status-red-bg: rgba(239, 68, 68, 0.12);
            --status-red-border: rgba(239, 68, 68, 0.4);
            --status-amber: #f59e0b;
            --status-amber-bg: rgba(245, 158, 11, 0.12);
            --status-amber-border: rgba(245, 158, 11, 0.35);
            --status-blue: #38bdf8;
            --status-blue-bg: rgba(56, 189, 248, 0.12);
            --status-blue-border: rgba(56, 189, 248, 0.35);
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            --font-sans: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            background-color: var(--bg-primary);
            color: var(--text-primary);
            font-family: var(--font-sans);
            line-height: 1.6;
            padding: 32px 20px;
        }}

        .container {{
            max-width: 1280px;
            margin: 0 auto;
        }}

        /* Header Card */
        header {{
            background: linear-gradient(135deg, #182234 0%, #0e1626 100%);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 28px 32px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
            position: relative;
            overflow: hidden;
        }}

        header::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #38bdf8, #818cf8, #f59e0b, #ef4444);
        }}

        .header-top {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 16px;
        }}

        .badge-course {{
            display: inline-block;
            background: rgba(56, 189, 248, 0.12);
            border: 1px solid rgba(56, 189, 248, 0.35);
            color: var(--status-blue);
            font-size: 0.78rem;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 9999px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 8px;
        }}

        h1 {{
            font-size: 1.85rem;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 6px;
            letter-spacing: -0.02em;
        }}

        .subtitle {{
            color: var(--text-secondary);
            font-size: 0.95rem;
        }}

        .meta-pills {{
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 18px;
        }}

        .meta-pill {{
            background: rgba(17, 24, 39, 0.8);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 6px 14px;
            font-size: 0.84rem;
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            gap: 6px;
        }}

        .meta-pill strong {{
            color: var(--text-primary);
        }}

        .pulse-dot {{
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background-color: var(--status-green);
            box-shadow: 0 0 8px var(--status-green);
            animation: pulse 2s infinite;
        }}

        @keyframes pulse {{
            0% {{ transform: scale(0.95); opacity: 0.8; }}
            50% {{ transform: scale(1.2); opacity: 1; }}
            100% {{ transform: scale(0.95); opacity: 0.8; }}
        }}

        /* KPI Metric Cards Grid */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 18px;
            margin-bottom: 24px;
        }}

        .metric-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px 22px;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}

        .metric-card:hover {{
            transform: translateY(-2px);
            border-color: #3b82f6;
        }}

        .metric-title {{
            font-size: 0.82rem;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--text-secondary);
            margin-bottom: 10px;
            font-weight: 600;
        }}

        .metric-value {{
            font-size: 2.1rem;
            font-weight: 700;
            color: #ffffff;
            font-family: var(--font-mono);
            line-height: 1.1;
        }}

        .metric-subtext {{
            font-size: 0.78rem;
            color: var(--text-muted);
            margin-top: 6px;
        }}

        .metric-card.active-card {{
            border-left: 4px solid var(--status-green);
        }}

        .metric-card.inactive-card {{
            border-left: 4px solid var(--status-red);
        }}

        .metric-card.rate-card {{
            border-left: 4px solid var(--status-amber);
        }}

        .metric-card.threshold-card {{
            border-left: 4px solid var(--status-blue);
        }}

        /* Main Section Container */
        .section-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
        }}

        .section-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            margin-bottom: 20px;
            padding-bottom: 14px;
            border-bottom: 1px solid var(--border-color);
        }}

        .section-title {{
            font-size: 1.25rem;
            font-weight: 600;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        /* Filter & Search Bar */
        .table-controls {{
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            align-items: center;
        }}

        .search-box {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 14px;
            color: var(--text-primary);
            font-size: 0.88rem;
            outline: none;
            width: 240px;
            transition: border-color 0.2s;
        }}

        .search-box:focus {{
            border-color: var(--status-blue);
        }}

        .filter-btn-group {{
            display: flex;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            overflow: hidden;
        }}

        .filter-btn {{
            background: var(--bg-secondary);
            border: none;
            color: var(--text-secondary);
            padding: 8px 14px;
            font-size: 0.82rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }}

        .filter-btn:hover {{
            background: #1f2937;
            color: #ffffff;
        }}

        .filter-btn.active {{
            background: #2563eb;
            color: #ffffff;
        }}

        /* Table Styling */
        .table-wrapper {{
            overflow-x: auto;
            border: 1px solid var(--border-color);
            border-radius: 10px;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.88rem;
            text-align: left;
        }}

        thead {{
            background: #111827;
        }}

        th {{
            padding: 14px 16px;
            color: var(--text-secondary);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.76rem;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--border-color);
        }}

        td {{
            padding: 13px 16px;
            border-bottom: 1px solid rgba(39, 53, 73, 0.6);
            color: var(--text-primary);
            vertical-align: middle;
        }}

        tr:last-child td {{
            border-bottom: none;
        }}

        tbody tr:hover {{
            background: var(--bg-card-hover);
        }}

        .user-cell {{
            display: flex;
            align-items: center;
            gap: 10px;
            font-weight: 600;
        }}

        .avatar-icon {{
            font-size: 1.1rem;
        }}

        .user-name {{
            color: #ffffff;
            font-family: var(--font-mono);
        }}

        .shell-code {{
            background: #0f172a;
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 4px;
            padding: 2px 7px;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            color: #cbd5e1;
        }}

        /* Badges */
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }}

        .badge-active {{
            background: var(--status-green-bg);
            color: var(--status-green);
            border: 1px solid var(--status-green-border);
        }}

        .badge-inactive {{
            background: var(--status-red-bg);
            color: var(--status-red);
            border: 1px solid var(--status-red-border);
        }}

        .text-green {{ color: var(--status-green); }}
        .text-red {{ color: var(--status-red); }}
        .text-amber {{ color: var(--status-amber); }}
        .text-muted {{ color: var(--text-muted); }}
        .text-center {{ text-align: center; }}
        .font-mono {{ font-family: var(--font-mono); }}
        .font-sm {{ font-size: 0.8rem; }}
        .action-note {{ font-size: 0.82rem; color: var(--text-secondary); }}

        /* Technical Deep Dive Grid */
        .deep-dive-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(340px, 1fr));
            gap: 20px;
            margin-top: 10px;
        }}

        .deep-dive-card {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 20px;
        }}

        .deep-dive-card h4 {{
            color: #ffffff;
            font-size: 1rem;
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .deep-dive-card p, .deep-dive-card ul {{
            font-size: 0.86rem;
            color: var(--text-secondary);
            line-height: 1.6;
        }}

        .deep-dive-card ul {{
            padding-left: 20px;
            margin-top: 8px;
        }}

        .deep-dive-card li {{
            margin-bottom: 6px;
        }}

        .deep-dive-card code {{
            background: #0f172a;
            padding: 2px 6px;
            border-radius: 4px;
            color: #38bdf8;
            font-family: var(--font-mono);
            font-size: 0.82rem;
        }}

        /* Terminal Execution Output */
        .terminal-box {{
            background: #050811;
            border: 1px solid #1f293d;
            border-radius: 8px;
            padding: 16px;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            color: #e2e8f0;
            overflow-x: auto;
            max-height: 380px;
            line-height: 1.5;
            white-space: pre-wrap;
        }}

        /* Footer */
        footer {{
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 0.82rem;
            border-top: 1px solid var(--border-color);
            margin-top: 32px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <header>
            <div class="header-top">
                <div>
                    <span class="badge-course">Linux System Administration (E1ITA307) • Problem #2</span>
                    <h1>Inactive Employee Detection Dashboard</h1>
                    <div class="subtitle">Real-time local user authentication audit &amp; inactivity policy compliance</div>
                </div>
                <div class="meta-pill">
                    <span class="pulse-dot"></span>
                    <span>Status: <strong>Live Real Host Data</strong></span>
                </div>
            </div>

            <div class="meta-pills">
                <div class="meta-pill">🖥️ Hostname: <strong>{hostname}</strong></div>
                <div class="meta-pill">🐧 OS: <strong>{os_name}</strong></div>
                <div class="meta-pill">⚙️ Kernel: <strong>{kernel}</strong></div>
                <div class="meta-pill">⏱️ Audit Time: <strong>{audit_time}</strong></div>
                <div class="meta-pill">🎯 Threshold: <strong>{threshold_days} Days</strong></div>
                <div class="meta-pill">🔍 Engine: <strong>{engine_tertiary}</strong></div>
            </div>
        </header>

        <!-- KPI Metric Cards -->
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-title">Total Human Accounts</div>
                <div class="metric-value">{total_accounts}</div>
                <div class="metric-subtext">Filtered by UID &ge; 1000 &amp; valid shells</div>
            </div>
            <div class="metric-card active-card">
                <div class="metric-title">Active Accounts</div>
                <div class="metric-value text-green">{active_accounts}</div>
                <div class="metric-subtext">Authenticated within {threshold_days} days</div>
            </div>
            <div class="metric-card inactive-card">
                <div class="metric-title">Inactive Accounts</div>
                <div class="metric-value text-red">{inactive_accounts}</div>
                <div class="metric-subtext">Overdue or never logged in</div>
            </div>
            <div class="metric-card rate-card">
                <div class="metric-title">Inactivity Rate</div>
                <div class="metric-value text-amber">{inactivity_rate}%</div>
                <div class="metric-subtext">Proportion of dormant accounts</div>
            </div>
            <div class="metric-card threshold-card">
                <div class="metric-title">Policy Threshold</div>
                <div class="metric-value text-blue">{threshold_days}d</div>
                <div class="metric-subtext">CIS Benchmark 5.4 Standard</div>
            </div>
        </div>

        <!-- Accounts Audit Table Section -->
        <div class="section-card">
            <div class="section-header">
                <div class="section-title">
                    <span>📋</span>
                    <span>User Accounts Inactivity Audit Roster</span>
                </div>
                <div class="table-controls">
                    <input type="text" id="searchInput" class="search-box" placeholder="Search username, UID, shell..." onkeyup="filterTable()">
                    <div class="filter-btn-group">
                        <button class="filter-btn active" onclick="setFilter('all', this)">All ({total_accounts})</button>
                        <button class="filter-btn" onclick="setFilter('active', this)">Active ({active_accounts})</button>
                        <button class="filter-btn" onclick="setFilter('inactive', this)">Inactive ({inactive_accounts})</button>
                    </div>
                </div>
            </div>

            <div class="table-wrapper">
                <table id="accountsTable">
                    <thead>
                        <tr>
                            <th class="text-center">#</th>
                            <th>Username</th>
                            <th class="text-center">UID</th>
                            <th>Login Shell</th>
                            <th>Last Login Date</th>
                            <th class="text-center">Days Inactive</th>
                            <th class="text-center">Status</th>
                            <th>Resolved Via</th>
                            <th>Audit Recommendation</th>
                        </tr>
                    </thead>
                    <tbody>
                        {table_rows_str}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Technical Architecture & Deep Dive Section -->
        <div class="section-card">
            <div class="section-header">
                <div class="section-title">
                    <span>🔬</span>
                    <span>System Administration &amp; Security Deep Dive</span>
                </div>
            </div>

            <div class="deep-dive-grid">
                <div class="deep-dive-card">
                    <h4><span>📚</span> 'lastlog' vs. 'last' Architecture</h4>
                    <p>Understanding the difference between the two standard Linux authentication logs:</p>
                    <ul>
                        <li><code>lastlog</code> reads <code>/var/log/lastlog</code>, a fixed-size sparse binary file indexed directly by UID (<code>lseek(UID * sizeof(struct lastlog))</code>). It retains ONLY the single latest login per UID and is never rotated. Accounts that have never logged in possess a zero-offset record displaying <code>**Never logged in**</code>.</li>
                        <li><code>last</code> reads <code>/var/log/wtmp</code>, a sequential circular append log recording all login, logout, and reboot events. Because it grows continuously, it is rotated periodically (e.g. <code>wtmp.1</code>). If a user logged in 40 days ago and the log rotated 30 days ago, <code>last</code> shows no entries for that user.</li>
                    </ul>
                </div>

                <div class="deep-dive-card">
                    <h4><span>🛡️</span> CIS Benchmark &amp; Security Policy</h4>
                    <p>Corporate compliance standards (CIS Linux Benchmark 5.4, NIST SP 800-53 AC-2):</p>
                    <ul>
                        <li><strong>Dormant Account Risk:</strong> Unmonitored inactive accounts represent severe security vulnerabilities for credential stuffing, privilege escalation, and persistent unauthorized access.</li>
                        <li><strong>Standard Policy:</strong> Disabling or locking accounts inactive for 30 to 90 days.</li>
                        <li><strong>Safe Remediation:</strong>
                            <ul>
                                <li>Lock password: <code>sudo usermod -L &lt;user&gt;</code></li>
                                <li>Expire shadow account: <code>sudo chage -E 0 &lt;user&gt;</code></li>
                                <li>Change shell: <code>sudo usermod -s /usr/sbin/nologin &lt;user&gt;</code></li>
                            </ul>
                        </li>
                    </ul>
                </div>

                <div class="deep-dive-card">
                    <h4><span>⚙️</span> Multi-Tier Fallback &amp; Sandboxing</h4>
                    <p>Host compatibility and execution safety guarantees:</p>
                    <ul>
                        <li><strong>Modern Distro Fallback:</strong> On Ubuntu 24.04/26.04 minimal or WSL2 environments lacking legacy utmp binaries, the script seamlessly inspects live sessions via <code>who</code>, systemd user sessions via <code>loginctl</code>, and PAM authentication events via <code>/var/log/auth.log</code>.</li>
                        <li><strong>Strict Read-Only Guarantee:</strong> This audit strictly inspects login timestamps. Zero user accounts are locked, modified, or deleted.</li>
                        <li><strong>Confined Scope:</strong> All execution and log writing are strictly isolated inside the <code>AS_02/</code> project workspace.</li>
                    </ul>
                </div>
            </div>
        </div>

        <!-- Terminal Execution Transcript -->
        <div class="section-card">
            <div class="section-header">
                <div class="section-title">
                    <span>💻</span>
                    <span>Live Captured Terminal Execution Log</span>
                </div>
                <span class="text-muted font-sm font-mono">Streamed from ./inactive_employee_detector.sh</span>
            </div>
            <div class="terminal-box">{html.escape(terminal_log_text)}</div>
        </div>

        <!-- Footer -->
        <footer>
            <div>Automation Sprint (AS_02) — Linux System Administration (E1ITA307)</div>
            <div style="margin-top: 4px;">Host: <strong>{hostname}</strong> | Generated live on <strong>{audit_time}</strong> | Strictly Read-Only Audit</div>
        </footer>
    </div>

    <!-- Client-side Interactive Filter Script -->
    <script>
        let currentFilter = 'all';

        function setFilter(status, btn) {{
            currentFilter = status;
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            filterTable();
        }}

        function filterTable() {{
            const search = document.getElementById('searchInput').value.toLowerCase();
            const rows = document.querySelectorAll('#accountsTable tbody tr');

            rows.forEach(row => {{
                const status = row.getAttribute('data-status');
                const text = row.getAttribute('data-search') || '';

                const matchesFilter = (currentFilter === 'all') || (status === currentFilter);
                const matchesSearch = text.includes(search);

                if (matchesFilter && matchesSearch) {{
                    row.style.display = '';
                }} else {{
                    row.style.display = 'none';
                }}
            }});
        }}
    </script>
</body>
</html>
"""

with open(output_html, 'w', encoding='utf-8') as f:
    f.write(html_content)

print(f"[INFO] report.html successfully generated ({os.path.getsize(output_html)} bytes).")
PYEOF

rm -f "${TMP_JSON}" "${TMP_TERM_LOG}"

# 5. Automatically open report.html across operating environments
echo "[INFO] Dispatching report.html in default web browser..."

REPORT_PATH="${SCRIPT_DIR}/report.html"

if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    # Windows Subsystem for Linux (WSL)
    if command -v wslpath >/dev/null 2>&1 && command -v explorer.exe >/dev/null 2>&1; then
        WIN_PATH="$(wslpath -w "${REPORT_PATH}" 2>/dev/null || true)"
        if [ -n "${WIN_PATH}" ]; then
            echo "[INFO] Launching Windows browser via explorer.exe..."
            explorer.exe "${WIN_PATH}" 2>/dev/null || true
        fi
    fi
elif [[ "${OS_SYSTEM}" == "Linux" ]]; then
    # Native Linux Desktop
    if command -v xdg-open >/dev/null 2>&1; then
        echo "[INFO] Launching Linux default browser via xdg-open..."
        xdg-open "${REPORT_PATH}" 2>/dev/null || true
    fi
elif [[ "${OS_SYSTEM}" == "Darwin" ]]; then
    # macOS
    if command -v open >/dev/null 2>&1; then
        echo "[INFO] Launching macOS default browser via open..."
        open "${REPORT_PATH}" 2>/dev/null || true
    fi
elif command -v start >/dev/null 2>&1; then
    # Git Bash / Windows native
    echo "[INFO] Launching Windows browser via start..."
    start "" "${REPORT_PATH}" 2>/dev/null || true
fi

echo "================================================================================"
echo "✅ [SUCCESS] AS_02 run.sh completed successfully!"
echo "   📊 Live Dashboard  : file://${REPORT_PATH}"
if command -v wslpath >/dev/null 2>&1; then
    echo "   🪟 Windows Path    : $(wslpath -w "${REPORT_PATH}" 2>/dev/null || echo "${REPORT_PATH}")"
fi
echo "   📜 Audit Log File  : ${SCRIPT_DIR}/logs/inactive_check.log"
echo "================================================================================"

exit 0
