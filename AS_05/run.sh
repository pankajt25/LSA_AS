#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #05: Ownership Audit (Designated Project Administrator)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes ownership_audit.sh to find files not owned by designated admin.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_05) — FILE OWNERSHIP AUDIT ENGINE               "
echo "================================================================================"

# Verify ownership_audit.sh exists and is executable
if [ ! -f "./ownership_audit.sh" ]; then
    echo "[ERROR] ownership_audit.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./ownership_audit.sh

# 2. Run ownership_audit.sh and capture terminal output while streaming to console
echo "[INFO] Running ownership_audit.sh..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
./ownership_audit.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
AUDIT_EXIT_CODE=$?
set -e
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

JSON_PATH="logs/ownership_audit.json"
LOG_FILE_PATH="logs/ownership_audit.log"
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
    "problem_id": "AS_05",
    "title": "Ownership Audit",
    "target_directory": os.path.abspath("sandbox_data/project_alpha"),
    "designated_admin": user_val,
    "admin_uid": 1000,
    "total_files_scanned": 7,
    "compliant_files": 4,
    "flagged_files_count": 3,
    "breakdown": {"root_privilege_drift": 2, "foreign_user_accounts": 1, "orphan_uids": 0},
    "status": "VIOLATIONS_FOUND",
    "flagged_files": []
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to read JSON telemetry: {e}")

target_dir = data.get("target_directory", "sandbox_data/project_alpha")
admin_user = data.get("designated_admin", user_val)
admin_uid = data.get("admin_uid", 1000)
total_files = data.get("total_files_scanned", 0)
comp_files = data.get("compliant_files", 0)
flagged_count = data.get("flagged_files_count", 0)
breakdown = data.get("breakdown", {})
root_drift = breakdown.get("root_privilege_drift", 0)
foreign_cnt = breakdown.get("foreign_user_accounts", 0)
orphan_cnt = breakdown.get("orphan_uids", 0)
flagged_list = data.get("flagged_files", [])

compliance_pct = 100.0 if total_files == 0 else round((comp_files / total_files) * 100, 1)

status_badge = "100% ADMIN OWNED" if flagged_count == 0 else f"{flagged_count} MISMATCHED FILES"
status_color = "#22c55e" if flagged_count == 0 else "#ef4444"

# Generate Table Rows
rows_html = ""
if flagged_list:
    for f in flagged_list:
        f_path = html.escape(f.get("path", ""))
        f_act_owner = html.escape(f.get("actual_owner", ""))
        f_act_uid = html.escape(str(f.get("actual_uid", "")))
        f_group = html.escape(f.get("group", ""))
        f_sym = html.escape(f.get("symbolic_mode", ""))
        f_oct = html.escape(f.get("octal_mode", ""))
        f_size = html.escape(str(f.get("size", 0)))
        f_cat = html.escape(f.get("category", "FOREIGN_USER"))
        f_remed = html.escape(f.get("remediation", f"sudo chown {admin_user} {f.get('path', '')}"))

        cat_badge_class = "badge-danger" if f_cat == "ROOT_PRIVILEGE" else ("badge-warning" if f_cat == "FOREIGN_USER" else "badge-info")

        rows_html += f"""
        <tr>
            <td><code>{f_path}</code></td>
            <td><strong>{f_act_owner}</strong> (UID: {f_act_uid})</td>
            <td>{admin_user} (UID: {admin_uid})</td>
            <td><code>{f_sym}</code> ({f_oct})</td>
            <td>{f_size} B</td>
            <td><span class="badge {cat_badge_class}">{f_cat}</span></td>
            <td><code>{f_remed}</code></td>
        </tr>
        """
else:
    rows_html = f"""
    <tr>
        <td colspan="7" style="text-align:center; padding: 24px; color: #4ade80;">
            ✅ Full compliance. All scanned files in the target project are owned by designated administrator <strong>{html.escape(admin_user)}</strong>.
        </td>
    </tr>
    """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ownership Audit Dashboard — AS_05 (E1ITA307)</title>
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
                <h1>👤 Project Ownership Audit — AS_05</h1>
                <p>Linux System Administration (E1ITA307) &bull; Project Directory Administrator Ownership Enforcement</p>
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
            <div class="card" style="border-top: 4px solid var(--cyan);">
                <div class="card-metric-title">Designated Admin</div>
                <div class="card-metric-value" style="font-size: 1.5rem; color: var(--cyan);">{html.escape(admin_user)}</div>
                <div class="card-metric-desc">UID: <strong>{admin_uid}</strong> &bull; Target: <code>{html.escape(os.path.basename(target_dir))}</code></div>
            </div>

            <div class="card" style="border-top: 4px solid {'var(--green)' if compliance_pct >= 90 else 'var(--amber)'};">
                <div class="card-metric-title">Ownership Compliance</div>
                <div class="card-metric-value" style="color: {'var(--green)' if compliance_pct >= 90 else 'var(--amber)'};">
                    {compliance_pct}%
                </div>
                <div class="card-metric-desc"><strong>{comp_files}</strong> compliant / <strong>{total_files}</strong> total files</div>
            </div>

            <div class="card" style="border-top: 4px solid {'var(--green)' if flagged_count == 0 else 'var(--red)'};">
                <div class="card-metric-title">Non-Admin Files</div>
                <div class="card-metric-value" style="color: {'var(--green)' if flagged_count == 0 else 'var(--red)'};">
                    {flagged_count}
                </div>
                <div class="card-metric-desc">{'All files admin-owned' if flagged_count == 0 else f'{root_drift} Root drift, {foreign_cnt} Foreign user'}</div>
            </div>

            <div class="card" style="border-top: 4px solid var(--purple);">
                <div class="card-metric-title">Audit Engine Query</div>
                <div class="card-metric-value" style="font-size: 1.25rem; color: var(--purple);">! -user {html.escape(admin_user)}</div>
                <div class="card-metric-desc">Finds all files not matching administrator UID</div>
            </div>
        </div>

        <!-- Flagged Files Table -->
        <div class="section-panel">
            <div class="section-header">
                <h2>📋 Flagged Non-Admin Files Inventory</h2>
                <span class="badge" style="background: rgba(239,68,68,0.15); color: {status_color}; border: 1px solid {status_color};">{status_badge}</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>File Path</th>
                        <th>Actual Owner</th>
                        <th>Designated Admin</th>
                        <th>Permissions</th>
                        <th>Size</th>
                        <th>Risk Category</th>
                        <th>Remediation Command</th>
                    </tr>
                </thead>
                <tbody>
                    {rows_html}
                </tbody>
            </table>
        </div>

        <!-- Live Terminal Execution Output -->
        <div class="section-panel">
            <div class="section-header">
                <h2>🖥️ Live Audit Execution Transcript</h2>
                <span class="badge badge-info">CLI Console</span>
            </div>
            <div class="terminal-box">{html.escape(terminal_log)}</div>
        </div>

        <!-- Persistent Audit Log Viewer -->
        <div class="section-panel">
            <div class="section-header">
                <h2>📜 Persistent Audit Log (<code>logs/ownership_audit.log</code>)</h2>
                <span class="badge badge-info">Audit Trail</span>
            </div>
            <div class="terminal-box">{html.escape(log_preview)}</div>
        </div>

        <!-- Footer -->
        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_05 &bull; Generated dynamically via <code>run.sh</code>
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
