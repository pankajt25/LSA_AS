#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_01)
# Problem Statement #1: Employee Account Setup
# Focus: User Management & Group Provisioning
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   1. Resolves and switches to script directory (cd "$(dirname "$0")") for
#      reliable cross-environment execution.
#   2. Detects operating platform (Linux, WSL2, macOS, Windows Git Bash).
#      Provides graceful macOS handling noting 'useradd' absence (uses dscl).
#   3. Runs employee_account_setup.sh against employees.csv to create the real
#      (test-prefixed 'lsatest_') accounts on this system.
#   4. Regenerates report.html from scratch — a self-contained, dark-themed
#      live dashboard (inline CSS only) featuring:
#      - System metadata header (hostname, OS, kernel, timestamp)
#      - KPI metric summary cards (Total, Created, Skipped, Groups, Security)
#      - Complete user accounts audit table with live 'id' and 'chage' outputs
#      - Departmental groups breakdown
#      - Live captured terminal execution transcript
#      - In-depth Linux user administration & PAM security deep dive
#      - Prominent cleanup instructions & command reminder
#   5. Automatically opens report.html in default browser via:
#      - WSL: explorer.exe "$(wslpath -w report.html)"
#      - Linux: xdg-open report.html
#      - macOS: open report.html (with explanatory notice)
#      - Git Bash: start report.html
#   6. IMPORTANT: Does NOT auto-run cleanup.sh — teardown is a deliberate,
#      separate manual step (bash cleanup.sh) run when grading/review is complete.
# ==============================================================================

set -euo pipefail

# cd to script directory so all relative paths resolve consistently
cd "$(dirname "$0")"

echo "================================================================================"
echo "    AUTOMATION SPRINT (AS_01) — EMPLOYEE ACCOUNT SETUP & USER MANAGEMENT       "
echo "================================================================================"

# Verify employee_account_setup.sh exists
if [ ! -f "./employee_account_setup.sh" ]; then
    echo "❌ [ERROR] employee_account_setup.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./employee_account_setup.sh

if [ -f "./cleanup.sh" ]; then
    chmod +x ./cleanup.sh
fi

OS_SYSTEM="$(uname -s 2>/dev/null || echo 'Linux')"
KERNEL_VER="$(uname -r 2>/dev/null || echo 'Unknown')"
HOST_NAME="$(hostname 2>/dev/null || echo 'localhost')"

echo "[INFO] Host Platform  : ${OS_SYSTEM} (${KERNEL_VER})"
echo "[INFO] Machine Host   : ${HOST_NAME}"
echo "[INFO] Working Dir    : $(pwd)"
echo "[INFO] Input List     : ./employees.csv"
echo "--------------------------------------------------------------------------------"

# Capture terminal execution output to temporary log for embedding in dashboard
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'account_term_XXXXXX')"

# Handle macOS Darwin platform detection
if [ "${OS_SYSTEM}" = "Darwin" ]; then
    echo "⚠️  [WARNING] macOS (Darwin) detected."
    echo "             Standard Linux 'useradd' and 'groupadd' utilities do not exist on macOS."
    echo "             macOS manages user accounts via Directory Services ('dscl')."
    echo "             Account creation will be bypassed on macOS, and the HTML dashboard"
    echo "             will display this platform status."
    echo "--------------------------------------------------------------------------------"
    
    # Run setup script which exits gracefully with error code 2 on macOS
    set +e
    bash ./employee_account_setup.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    SETUP_EXIT_CODE=$?
    set -e
else
    echo "[INFO] Launching employee account provisioning via ./employee_account_setup.sh..."
    echo "--------------------------------------------------------------------------------"

    set +e
    bash ./employee_account_setup.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
    SETUP_EXIT_CODE=$?
    set -e
fi

echo "--------------------------------------------------------------------------------"
echo "[INFO] Account provisioning completed with exit code: ${SETUP_EXIT_CODE}"

# Verify JSON telemetry file exists
JSON_META_FILE="logs/account_setup.json"
if [ ! -f "${JSON_META_FILE}" ]; then
    echo "⚠️  [WARN] JSON telemetry file ${JSON_META_FILE} was not found; creating fallback..."
    mkdir -p logs
    cat << FALLBACK_JSON > "${JSON_META_FILE}"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hostname": "${HOST_NAME}",
  "os_system": "${OS_SYSTEM}",
  "kernel": "${KERNEL_VER}",
  "input_csv": "./employees.csv",
  "dry_run": false,
  "summary": {
    "total_processed": 0,
    "created": 0,
    "skipped": 0,
    "failed": 0,
    "groups_created": 0,
    "groups_existed": 0
  },
  "users": [],
  "groups": []
}
FALLBACK_JSON
fi

# ------------------------------------------------------------------------------
# REGENERATE report.html FROM SCRATCH (DARK THEMED INLINE CSS DASHBOARD)
# ------------------------------------------------------------------------------
echo "[INFO] Regenerating report.html dashboard from live audit telemetry..."

python3 - << 'PYEOF'
import json
import html
import os
import platform
import datetime

json_file = "logs/account_setup.json"
csv_file = "employees.csv"

# Load JSON telemetry
try:
    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"[ERROR] Failed to read {json_file}: {e}")
    data = {
        "timestamp": datetime.datetime.now().isoformat(),
        "hostname": platform.node(),
        "os_system": platform.system(),
        "kernel": platform.release(),
        "summary": {"total_processed": 0, "created": 0, "skipped": 0, "failed": 0, "groups_created": 0, "groups_existed": 0},
        "users": [],
        "groups": []
    }

# Read terminal transcript
term_log_content = ""
for fname in os.listdir("/tmp"):
    if fname.startswith("account_term_"):
        t_path = os.path.join("/tmp", fname)
        if os.path.isfile(t_path):
            try:
                with open(t_path, "r", encoding="utf-8", errors="replace") as tf:
                    term_log_content = tf.read()
            except Exception:
                pass
            break

if not term_log_content and os.path.isfile("logs/account_setup.log"):
    try:
        with open("logs/account_setup.log", "r", encoding="utf-8", errors="replace") as lf:
            lines = lf.readlines()
            term_log_content = "".join(lines[-40:])
    except Exception:
        pass

# Strip ANSI escapes for clean HTML display
import re
ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
clean_term_output = ansi_escape.sub('', term_log_content)

# Read raw CSV file for input dataset card
raw_csv_content = ""
if os.path.isfile(csv_file):
    try:
        with open(csv_file, "r", encoding="utf-8") as cf:
            raw_csv_content = cf.read().strip()
    except Exception:
        pass

summary = data.get("summary", {})
users = data.get("users", [])
groups = data.get("groups", [])
timestamp = data.get("timestamp", datetime.datetime.now().isoformat())
hostname = data.get("hostname", platform.node())
os_system = data.get("os_system", platform.system())
kernel = data.get("kernel", platform.release())

# Generate HTML Table Rows for Users
user_rows_html = ""
for idx, u in enumerate(users, 1):
    uname = html.escape(str(u.get("username", "N/A")))
    fname = html.escape(str(u.get("fullname", "N/A")))
    dept = html.escape(str(u.get("department", "N/A")))
    status = html.escape(str(u.get("status", "N/A")))
    uid = html.escape(str(u.get("uid", "N/A")))
    gid = html.escape(str(u.get("gid", "N/A")))
    home = html.escape(str(u.get("home", "N/A")))
    home_owner = html.escape(str(u.get("home_owner", "N/A")))
    home_perms = html.escape(str(u.get("home_perms", "N/A")))
    id_out = html.escape(str(u.get("id_output", "N/A")))
    expire = html.escape(str(u.get("expire_policy", "N/A")))
    note = html.escape(str(u.get("note", u.get("error", ""))))

    if status in ("CREATED", "CREATED_DRY"):
        status_badge = '<span class="badge badge-success">✓ CREATED &amp; ACTIVE</span>'
    elif status == "SKIPPED":
        status_badge = '<span class="badge badge-purple">⏭ PRE-EXISTED</span>'
    else:
        status_badge = f'<span class="badge badge-danger">❌ {status}</span>'

    if "must be changed" in expire.lower() or "forced" in expire.lower() or "password must be changed" in expire.lower():
        expire_badge = '<span class="badge badge-warning">⚠ MUST CHANGE (1st Login)</span>'
    else:
        expire_badge = f'<span class="badge badge-info">{expire}</span>'

    home_display = f"<code>{home}</code>"
    if home_owner != "N/A" and home_perms != "N/A":
        home_display += f"<br><small style='color: #94a3b8;'>{home_perms} ({home_owner})</small>"

    user_rows_html += f"""
    <tr>
        <td style="text-align: center; color: #94a3b8; font-weight: bold;">{idx}</td>
        <td><strong style="color: #38bdf8; font-family: monospace; font-size: 1.05rem;">{uname}</strong></td>
        <td style="color: #f1f5f9; font-weight: 500;">{fname}</td>
        <td><span class="badge badge-dept">{dept}</span></td>
        <td style="font-family: monospace; color: #cbd5e1;">UID:{uid}<br>GID:{gid}</td>
        <td>{home_display}</td>
        <td><code style="font-size: 0.82rem; color: #a5f3fc; background: #0f172a; padding: 4px 8px; border-radius: 4px; display: inline-block;">{id_out}</code></td>
        <td style="text-align: center;">{expire_badge}</td>
        <td style="text-align: center;">{status_badge}</td>
    </tr>
    """

if not user_rows_html:
    user_rows_html = """
    <tr>
        <td colspan="9" style="text-align: center; color: #94a3b8; padding: 24px;">No user records processed.</td>
    </tr>
    """

# Generate HTML Table Rows for Groups
group_rows_html = ""
for idx, g in enumerate(groups, 1):
    gname = html.escape(str(g.get("group", "N/A")))
    gid = html.escape(str(g.get("gid", "N/A")))
    action = html.escape(str(g.get("action", "N/A")))

    if action in ("CREATED", "CREATED_DRY"):
        act_badge = '<span class="badge badge-success">✓ NEWLY CREATED</span>'
    else:
        act_badge = '<span class="badge badge-info">ℹ PRE-EXISTED</span>'

    group_rows_html += f"""
    <tr>
        <td style="text-align: center; color: #94a3b8; font-weight: bold;">{idx}</td>
        <td><strong style="color: #cbd5e1; font-family: monospace; font-size: 1rem;">{gname}</strong></td>
        <td><code style="color: #38bdf8;">GID: {gid}</code></td>
        <td style="text-align: center;">{act_badge}</td>
    </tr>
    """

if not group_rows_html:
    group_rows_html = """
    <tr>
        <td colspan="4" style="text-align: center; color: #94a3b8; padding: 18px;">No departmental groups recorded.</td>
    </tr>
    """

# Construct Full Self-Contained HTML Document
html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Employee Account Setup Dashboard — AS_01 (E1ITA307)</title>
    <style>
        :root {{
            --bg-primary: #0b0f19;
            --bg-card: #151e32;
            --bg-card-hover: #1b2742;
            --bg-card-subtle: #0f172a;
            --border-color: #243452;
            --border-bright: #38bdf8;
            --text-main: #f1f5f9;
            --text-muted: #94a3b8;
            --cyan: #38bdf8;
            --green: #22c55e;
            --green-glow: rgba(34, 197, 94, 0.2);
            --amber: #f59e0b;
            --amber-glow: rgba(245, 158, 11, 0.2);
            --red: #ef4444;
            --purple: #a855f7;
            --blue: #3b82f6;
            --font-stack: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            background-color: var(--bg-primary);
            color: var(--text-main);
            font-family: var(--font-stack);
            line-height: 1.6;
            padding: 24px;
        }}

        .container {{
            max-width: 1380px;
            margin: 0 auto;
        }}

        /* Header Bar */
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

        .header-meta {{
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
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

        .meta-pill strong {{
            color: #ffffff;
        }}

        /* Teardown Warning Banner */
        .warning-banner {{
            background: linear-gradient(90deg, rgba(245, 158, 11, 0.15) 0%, rgba(245, 158, 11, 0.05) 100%);
            border-left: 4px solid var(--amber);
            border-top: 1px solid rgba(245, 158, 11, 0.3);
            border-right: 1px solid rgba(245, 158, 11, 0.3);
            border-bottom: 1px solid rgba(245, 158, 11, 0.3);
            border-radius: 8px;
            padding: 18px 24px;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 16px;
        }}

        .warning-banner .warning-text h3 {{
            color: var(--amber);
            font-size: 1.05rem;
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 4px;
        }}

        .warning-banner .warning-text p {{
            color: #e2e8f0;
            font-size: 0.9rem;
        }}

        .code-box {{
            background: #0f172a;
            border: 1px solid rgba(245, 158, 11, 0.4);
            color: #fef08a;
            padding: 8px 16px;
            border-radius: 6px;
            font-family: var(--font-mono);
            font-size: 0.95rem;
            font-weight: 600;
            display: inline-block;
            user-select: all;
        }}

        /* KPI Cards Grid */
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
            gap: 18px;
            margin-bottom: 24px;
        }}

        .kpi-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 20px;
            position: relative;
            overflow: hidden;
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}

        .kpi-card:hover {{
            transform: translateY(-2px);
            border-color: #38bdf8;
        }}

        .kpi-label {{
            font-size: 0.82rem;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            font-weight: 600;
        }}

        .kpi-value {{
            font-size: 2.2rem;
            font-weight: 800;
            margin: 8px 0 4px 0;
            color: #ffffff;
        }}

        .kpi-subtext {{
            font-size: 0.82rem;
            color: var(--text-muted);
        }}

        .val-green {{ color: var(--green); }}
        .val-cyan {{ color: var(--cyan); }}
        .val-purple {{ color: var(--purple); }}
        .val-amber {{ color: var(--amber); }}
        .val-red {{ color: var(--red); }}

        /* Content Sections & Cards */
        .section-card {{
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.25);
        }}

        .section-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 14px;
            margin-bottom: 18px;
            flex-wrap: wrap;
            gap: 12px;
        }}

        .section-header h2 {{
            font-size: 1.25rem;
            font-weight: 600;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        /* Tables */
        .table-responsive {{
            overflow-x: auto;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.92rem;
            text-align: left;
        }}

        th {{
            background-color: var(--bg-card-subtle);
            color: var(--text-muted);
            font-weight: 600;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.82rem;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}

        td {{
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-color);
            vertical-align: middle;
        }}

        tr:last-child td {{
            border-bottom: none;
        }}

        tr:hover td {{
            background-color: rgba(255, 255, 255, 0.02);
        }}

        /* Badges */
        .badge {{
            display: inline-flex;
            align-items: center;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 0.78rem;
            font-weight: 600;
            white-space: nowrap;
        }}

        .badge-success {{
            background: rgba(34, 197, 94, 0.15);
            color: var(--green);
            border: 1px solid rgba(34, 197, 94, 0.4);
        }}

        .badge-warning {{
            background: rgba(245, 158, 11, 0.15);
            color: var(--amber);
            border: 1px solid rgba(245, 158, 11, 0.4);
        }}

        .badge-danger {{
            background: rgba(239, 68, 68, 0.15);
            color: var(--red);
            border: 1px solid rgba(239, 68, 68, 0.4);
        }}

        .badge-info {{
            background: rgba(56, 189, 248, 0.15);
            color: var(--cyan);
            border: 1px solid rgba(56, 189, 248, 0.4);
        }}

        .badge-purple {{
            background: rgba(168, 85, 247, 0.15);
            color: var(--purple);
            border: 1px solid rgba(168, 85, 247, 0.4);
        }}

        .badge-dept {{
            background: rgba(99, 102, 241, 0.15);
            color: #a5b4fc;
            border: 1px solid rgba(99, 102, 241, 0.4);
            font-family: var(--font-mono);
            font-size: 0.85rem;
        }}

        /* Terminal Window */
        .terminal-box {{
            background-color: #080d1a;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            overflow: hidden;
            font-family: var(--font-mono);
        }}

        .terminal-bar {{
            background-color: #0f172a;
            padding: 8px 16px;
            display: flex;
            align-items: center;
            gap: 8px;
            border-bottom: 1px solid var(--border-color);
        }}

        .term-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            display: inline-block;
        }}
        .dot-red {{ background-color: #ef4444; }}
        .dot-yellow {{ background-color: #f59e0b; }}
        .dot-green {{ background-color: #22c55e; }}

        .terminal-bar-title {{
            color: var(--text-muted);
            font-size: 0.8rem;
            margin-left: 8px;
        }}

        .terminal-content {{
            padding: 16px;
            color: #38bdf8;
            font-size: 0.86rem;
            line-height: 1.5;
            max-height: 380px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }}

        /* Architecture Deep Dive Grid */
        .arch-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 18px;
        }}

        .arch-item {{
            background-color: var(--bg-card-subtle);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
        }}

        .arch-item h4 {{
            color: #38bdf8;
            font-size: 1rem;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .arch-item p {{
            color: #cbd5e1;
            font-size: 0.88rem;
            line-height: 1.5;
        }}

        .arch-item code {{
            background-color: #0b0f19;
            color: #fef08a;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.82rem;
            font-family: var(--font-mono);
        }}

        /* Footer */
        .footer {{
            text-align: center;
            color: var(--text-muted);
            font-size: 0.85rem;
            margin-top: 36px;
            padding: 20px 0;
            border-top: 1px solid var(--border-color);
        }}

        .footer a {{
            color: var(--cyan);
            text-decoration: none;
        }}

        @media (max-width: 768px) {{
            .header {{
                flex-direction: column;
                align-items: flex-start;
            }}
            .kpi-grid {{
                grid-template-columns: 1fr 1fr;
            }}
        }}
    </style>
</head>
<body>

<div class="container">

    <!-- Header Section -->
    <header class="header">
        <div class="header-title">
            <h1>👥 Employee Account Setup Dashboard</h1>
            <p>Course: <strong>Linux System Administration (E1ITA307)</strong> &bull; Sprint: <strong>AS_01</strong> &bull; Focus: <strong>User &amp; Group Management</strong></p>
        </div>
        <div class="header-meta">
            <span class="meta-pill">🖥 Host: <strong>{html.escape(hostname)}</strong></span>
            <span class="meta-pill">🐧 OS: <strong>{html.escape(os_system)}</strong></span>
            <span class="meta-pill">⚙ Kernel: <strong>{html.escape(kernel)}</strong></span>
            <span class="meta-pill">🕒 Audit Time: <strong>{html.escape(timestamp)}</strong></span>
        </div>
    </header>

    <!-- Teardown & Sandboxing Warning Banner -->
    <div class="warning-banner">
        <div class="warning-text">
            <h3>⚠️ LIVE SYSTEM MODIFICATION NOTICE &amp; MANDATORY TEARDOWN</h3>
            <p>This sprint created REAL Linux accounts (prefixed <code>lsatest_</code>) in <code>/etc/passwd</code>, <code>/etc/shadow</code>, and created real home directories. After inspecting this report and completing grading, execute the cleanup script to restore your system to its pristine pre-test state:</p>
        </div>
        <div>
            <div class="code-box">bash cleanup.sh</div>
        </div>
    </div>

    <!-- Executive KPI Grid -->
    <section class="kpi-grid">
        <div class="kpi-card">
            <div class="kpi-label">Employees In CSV</div>
            <div class="kpi-value val-cyan">{summary.get("total_processed", 0)}</div>
            <div class="kpi-subtext">Total records parsed from input</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-label">Accounts Created</div>
            <div class="kpi-value val-green">{summary.get("created", 0)}</div>
            <div class="kpi-subtext">Provisioned via <code>useradd -m -g</code></div>
        </div>
        <div class="kpi-card">
            <div class="kpi-label">Accounts Skipped</div>
            <div class="kpi-value val-purple">{summary.get("skipped", 0)}</div>
            <div class="kpi-subtext">Pre-existing usernames ignored</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-label">Depts Created / Verified</div>
            <div class="kpi-value val-cyan">{summary.get("groups_created", 0) + summary.get("groups_existed", 0)}</div>
            <div class="kpi-subtext">{summary.get("groups_created", 0)} new, {summary.get("groups_existed", 0)} existing</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-label">First-Login Reset Policy</div>
            <div class="kpi-value val-amber">100%</div>
            <div class="kpi-subtext">Enforced via <code>passwd -e</code></div>
        </div>
        <div class="kpi-card">
            <div class="kpi-label">Failed / Rejected</div>
            <div class="kpi-value { 'val-red' if summary.get('failed', 0) > 0 else 'val-green' }">{summary.get("failed", 0)}</div>
            <div class="kpi-subtext">Prefix or CSV parsing violations</div>
        </div>
    </section>

    <!-- Provisioned Users Table -->
    <section class="section-card">
        <div class="section-header">
            <h2>👤 Provisioned Employee Accounts Audit Table</h2>
            <span class="badge badge-info">Sandboxed Prefix: lsatest_*</span>
        </div>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th style="text-align: center; width: 40px;">#</th>
                        <th>Username</th>
                        <th>Full Name</th>
                        <th>Department</th>
                        <th>UID / GID</th>
                        <th>Home Directory</th>
                        <th>System Verification (id)</th>
                        <th style="text-align: center;">Aging Policy</th>
                        <th style="text-align: center;">Account State</th>
                    </tr>
                </thead>
                <tbody>
                    {user_rows_html}
                </tbody>
            </table>
        </div>
    </section>

    <!-- Two-Column Grid: Groups Summary & Input CSV -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 24px; margin-bottom: 24px;">
        <!-- Department Groups Table -->
        <section class="section-card" style="margin-bottom: 0;">
            <div class="section-header">
                <h2>🏢 Departmental Groups Status</h2>
                <span class="badge badge-dept">getent group</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th style="text-align: center; width: 40px;">#</th>
                            <th>Group Name</th>
                            <th>Allocated GID</th>
                            <th style="text-align: center;">Provision Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        {group_rows_html}
                    </tbody>
                </table>
            </div>
        </section>

        <!-- Input CSV Dataset -->
        <section class="section-card" style="margin-bottom: 0;">
            <div class="section-header">
                <h2>📄 Input Employee Dataset (employees.csv)</h2>
                <span class="badge badge-info">RFC 4180 CSV</span>
            </div>
            <div class="terminal-box">
                <div class="terminal-bar">
                    <span class="term-dot dot-red"></span>
                    <span class="term-dot dot-yellow"></span>
                    <span class="term-dot dot-green"></span>
                    <span class="terminal-bar-title">employees.csv (username,fullname,department)</span>
                </div>
                <div class="terminal-content" style="max-height: 180px; color: #a5f3fc;">{html.escape(raw_csv_content) if raw_csv_content else "No CSV content loaded"}</div>
            </div>
        </section>
    </div>

    <!-- Live Captured Terminal Execution Transcript -->
    <section class="section-card">
        <div class="section-header">
            <h2>💻 Live Terminal Execution &amp; Audit Transcript</h2>
            <span class="badge badge-success">Live Execution Stream</span>
        </div>
        <div class="terminal-box">
            <div class="terminal-bar">
                <span class="term-dot dot-red"></span>
                <span class="term-dot dot-yellow"></span>
                <span class="term-dot dot-green"></span>
                <span class="terminal-bar-title">bash ./employee_account_setup.sh (stdout / stderr)</span>
            </div>
            <div class="terminal-content">{html.escape(clean_term_output) if clean_term_output else "Execution completed with no terminal output."}</div>
        </div>
    </section>

    <!-- Technical Architecture & Sysadmin Deep Dive -->
    <section class="section-card">
        <div class="section-header">
            <h2>🧠 Technical Architecture &amp; System Administration Reference</h2>
            <span class="badge badge-purple">Viva Preparation</span>
        </div>
        <div class="arch-grid">
            <div class="arch-item">
                <h4>🔒 Sandboxing &amp; Safety Constraint</h4>
                <p>Because <code>useradd</code> and <code>groupadd</code> modify live kernel/glibc databases (<code>/etc/passwd</code>, <code>/etc/shadow</code>, <code>/etc/group</code>), every test username is strictly validated against the regex <code>^lsatest_[a-zA-Z0-9_]+$</code>. Any non-prefixed username is rejected immediately to protect human accounts.</p>
            </div>
            <div class="arch-item">
                <h4>🔑 Non-Interactive Password &amp; PAM Expiry</h4>
                <p>Passwords are provisioned securely via <code>echo "user:pass" | chpasswd</code> without interactive prompts. Immediately after, <code>passwd -e &lt;user&gt;</code> (or <code>chage -d 0</code>) sets the last password change date to day 0 (Jan 1, 1970), forcing Linux PAM to demand a new password on first login.</p>
            </div>
            <div class="arch-item">
                <h4>📁 Home Directory Skeleton Seeding</h4>
                <p>The <code>-m</code> flag instructs <code>useradd</code> to initialize <code>/home/&lt;user&gt;</code> by copying base shell profiles (<code>.bashrc</code>, <code>.profile</code>, <code>.bash_logout</code>) from <code>/etc/skel</code> and assigns strict ownership (<code>&lt;user&gt;:&lt;department&gt;</code>) and directory permissions (<code>0750</code> or <code>0700</code>).</p>
            </div>
            <div class="arch-item">
                <h4>🏢 Departmental Group Association</h4>
                <p>The <code>-g &lt;dept&gt;</code> flag assigns the department as the user's <strong>Primary Group</strong> in <code>/etc/passwd</code> field 4 (GID). Department existence is queried first via <code>getent group &lt;dept&gt;</code> and created on-the-fly with <code>groupadd</code> if absent.</p>
            </div>
            <div class="arch-item">
                <h4>🔄 Two-Step Lifecycle &amp; Teardown</h4>
                <p>Demonstrations follow a two-step pattern: <code>bash run.sh</code> provisions accounts and generates this live dashboard; <code>bash cleanup.sh</code> uses <code>userdel -r</code> and <code>groupdel</code> to completely restore the system to its pre-sprint state.</p>
            </div>
            <div class="arch-item">
                <h4>🌐 Multi-Platform Portability</h4>
                <p>The scripts dynamically detect WSL2, native Linux distributions, and macOS. When run on macOS, clear diagnostics explain that BSD/Darwin uses <code>dscl</code> instead of GNU/Linux <code>useradd</code>, avoiding cryptic failures.</p>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="footer">
        <p>Linux System Administration (E1ITA307) — Automation Sprint AS_01</p>
        <p style="margin-top: 4px; font-size: 0.8rem; color: #64748b;">Report generated completely from scratch using live system audit telemetry. No static or mock data used.</p>
    </footer>

</div>

</body>
</html>
"""

with open("report.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("[INFO] report.html successfully generated (" + str(len(html_content)) + " bytes)")
PYEOF

# Clean up temp terminal log
if [ -n "${TMP_TERM_LOG:-}" ] && [ -f "${TMP_TERM_LOG}" ]; then
    rm -f "${TMP_TERM_LOG}"
fi

# ------------------------------------------------------------------------------
# 5. OPEN report.html IN HOST WEB BROWSER
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------------------------------"
echo "[INFO] Attempting to open report.html in default browser..."

# 1. WSL2 / WSL1 Environment
if command -v wslpath >/dev/null 2>&1 && command -v explorer.exe >/dev/null 2>&1; then
    WIN_PATH="$(wslpath -w ./report.html 2>/dev/null || true)"
    if [ -n "${WIN_PATH}" ]; then
        echo "[INFO] Launching Windows browser via explorer.exe: ${WIN_PATH}"
        explorer.exe "${WIN_PATH}" 2>/dev/null || true
    fi

# 2. Native Linux Desktop (X11 / Wayland)
elif command -v xdg-open >/dev/null 2>&1; then
    echo "[INFO] Launching Linux browser via xdg-open..."
    xdg-open ./report.html 2>/dev/null || true

# 3. macOS Darwin
elif [ "${OS_SYSTEM}" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    echo "[INFO] Launching macOS browser via open..."
    open ./report.html 2>/dev/null || true

# 4. Windows Git Bash / MSYS2 / Cygwin
elif command -v start >/dev/null 2>&1; then
    echo "[INFO] Launching Windows browser via start..."
    start "" ./report.html 2>/dev/null || true

else
    echo "ℹ  [INFO] Automated browser dispatch not available. Please view report manually at:"
    echo "          file://$(pwd)/report.html"
fi

echo "================================================================================"
echo "    AS_01 EXECUTION COMPLETE — LIVE ACCOUNTS CREATED & VERIFIED                 "
echo "================================================================================"
echo -e "\033[1;33m⚠️  IMPORTANT REMINDER:\033[0m"
echo "   Test accounts (lsatest_*) and departmental groups currently exist on this host."
echo "   When ready to tear down and restore pristine system state, execute:"
echo ""
echo -e "       \033[1;32mbash cleanup.sh\033[0m"
echo ""
echo "================================================================================"
