#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #12: Old Backup Cleanup (Backup Management)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Seeds reproducible multi-archive backup repository.
#   3. Executes old_backup_cleaner.sh to prune expired archives and companion files.
#   4. Regenerates self-contained dark-themed report.html from scratch every run.
#   5. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "        AUTOMATION SPRINT (AS_12) — OLD BACKUP CLEANUP ENGINE                   "
echo "================================================================================"

# Verify old_backup_cleaner.sh exists and is executable
if [ ! -f "./old_backup_cleaner.sh" ]; then
    echo "[ERROR] old_backup_cleaner.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./old_backup_cleaner.sh

# Re-seed test archives if targeting sandbox or default
if [ $# -eq 0 ] || [[ "$*" =~ --sandbox ]]; then
    echo "[INFO] Seeding backup repository with multi-generation test archives..."
    if [ -f "./sandbox_data/seed_backups.sh" ]; then
        bash ./sandbox_data/seed_backups.sh
    fi
fi

# 2. Run old_backup_cleaner.sh and capture terminal output while streaming to console
echo "[INFO] Running old_backup_cleaner.sh on backup repository..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
if [ $# -eq 0 ]; then
    # Default demo: execute actual deletion of backups older than 7 days
    ./old_backup_cleaner.sh --delete 2>&1 | tee "${TMP_TERM_LOG}"
else
    ./old_backup_cleaner.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
fi
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

JSON_PATH="logs/cleanup.json"
LOG_FILE_PATH="logs/old_backup_cleaner.log"
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
log_preview = r"""${LOG_PREVIEW}"""
terminal_log = r"""${TERMINAL_LOG_CONTENT}"""
hostname_val = "${HOSTNAME_VAL}"
kernel_val = "${KERNEL_VAL}"
os_display = "${OS_DISPLAY}"
timestamp_val = "${TIMESTAMP_VAL}"
user_val = "${USER_VAL}"

data = {
    "problem_id": "AS_12",
    "title": "Old Backup Cleanup",
    "backup_directory": "./sandbox_data/backups",
    "retention_days": 7,
    "keep_minimum_guarantee": 1,
    "dry_run": False,
    "total_archives_evaluated": 0,
    "expired_archives_count": 0,
    "retained_archives_count": 0,
    "reclaimed_bytes": 0,
    "reclaimed_human": "0 B",
    "companions_removed_count": 0,
    "status": "EXPIRED_BACKUPS_CLEANED",
    "pruned_archives": [],
    "retained_archives": []
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to parse JSON: {e}", file=sys.stderr)

repo_dir = data.get("backup_directory", "./sandbox_data/backups")
retention_days = data.get("retention_days", 7)
keep_min = data.get("keep_minimum_guarantee", 1)
dry_run = data.get("dry_run", False)
total_eval = data.get("total_archives_evaluated", 0)
expired_count = data.get("expired_archives_count", 0)
retained_count = data.get("retained_archives_count", 0)
reclaimed_h = data.get("reclaimed_human", "0 B")
reclaimed_b = data.get("reclaimed_bytes", 0)
companions_purged = data.get("companions_removed_count", 0)
pruned_list = data.get("pruned_archives", [])
retained_list = data.get("retained_archives", [])

mode_badge = '<span class="badge badge-danger">ACTIVE PRUNING</span>' if not dry_run else '<span class="badge badge-warning">DRY RUN (SIMULATION)</span>'

# Build Pruned Archives Rows
pruned_rows_html = ""
if not pruned_list:
    pruned_rows_html = '<tr><td colspan="6" class="empty-state">No expired backup archives exceeded the retention window.</td></tr>'
else:
    for f in pruned_list:
        idx = f.get("index", 1)
        fname = html.escape(str(f.get("filename", "-")))
        size_h = html.escape(str(f.get("size_human", "0 B")))
        age_d = html.escape(str(f.get("age_days", 0)))
        mod = html.escape(str(f.get("modified", "-")))
        action = html.escape(str(f.get("action", "-")))
        comp = f.get("companion_cleaned", False)
        comp_badge = '<span class="badge badge-success">PURGED (.sha256)</span>' if comp else '<span class="badge badge-warning">N/A</span>'
        
        pruned_rows_html += f"""
        <tr>
            <td class="rank-cell">#{idx}</td>
            <td class="path-cell" title="{fname}"><strong>{fname}</strong></td>
            <td class="size-cell">{size_h}</td>
            <td><span class="badge badge-danger">{age_d} days</span></td>
            <td class="time-cell">{mod}</td>
            <td>{comp_badge}</td>
        </tr>
        """

# Build Retained Archives Rows
retained_rows_html = ""
if not retained_list:
    retained_rows_html = '<tr><td colspan="6" class="empty-state">No active archives retained.</td></tr>'
else:
    for f in retained_list:
        idx = f.get("index", 1)
        fname = html.escape(str(f.get("filename", "-")))
        size_h = html.escape(str(f.get("size_human", "0 B")))
        age_d = html.escape(str(f.get("age_days", 0)))
        mod = html.escape(str(f.get("modified", "-")))
        action = f.get("action", "")
        reason_badge = '<span class="badge badge-success">ACTIVE RETENTION (&le; 7d)</span>'
        if "SAFEGUARD" in action:
            reason_badge = '<span class="badge badge-warning">MINIMUM SAFEGUARD</span>'
            
        retained_rows_html += f"""
        <tr>
            <td class="rank-cell">#{idx}</td>
            <td class="path-cell" title="{fname}"><strong>{fname}</strong></td>
            <td class="size-cell">{size_h}</td>
            <td><span class="badge badge-success">{age_d} days</span></td>
            <td class="time-cell">{mod}</td>
            <td>{reason_badge}</td>
        </tr>
        """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_12: Old Backup Cleanup Dashboard</title>
    <style>
        :root {{
            --bg: #0f172a;
            --surface: #1e293b;
            --surface-hover: #334155;
            --border: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.15);
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --code-bg: #090d16;
        }}
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }}
        body {{
            background-color: var(--bg);
            color: var(--text-main);
            padding: 2rem;
            line-height: 1.5;
        }}
        .container {{
            max-width: 1300px;
            margin: 0 auto;
        }}
        header {{
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            border-bottom: 1px solid var(--border);
            padding-bottom: 1.5rem;
            margin-bottom: 2rem;
            flex-wrap: wrap;
            gap: 1rem;
        }}
        .header-title h1 {{
            font-size: 1.75rem;
            font-weight: 700;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }}
        .header-title p {{
            color: var(--text-muted);
            margin-top: 0.25rem;
            font-size: 0.95rem;
        }}
        .sys-badge {{
            display: inline-flex;
            gap: 0.5rem;
            background: var(--surface);
            border: 1px solid var(--border);
            padding: 0.4rem 0.8rem;
            border-radius: 6px;
            font-size: 0.82rem;
            color: var(--text-muted);
            align-self: flex-start;
        }}
        .sys-badge span {{
            color: var(--accent);
            font-weight: 600;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.25rem;
            margin-bottom: 2rem;
        }}
        .card {{
            background-color: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 1.25rem;
            position: relative;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }}
        .card-label {{
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 0.5rem;
        }}
        .card-value {{
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-main);
            word-break: break-all;
        }}
        .card-subtext {{
            font-size: 0.8rem;
            color: var(--text-muted);
            margin-top: 0.4rem;
        }}
        .badge {{
            display: inline-block;
            padding: 0.25rem 0.65rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}
        .badge-success {{ background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #059669; }}
        .badge-warning {{ background: rgba(245, 158, 11, 0.2); color: #fbbf24; border: 1px solid #d97706; }}
        .badge-danger {{ background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #dc2626; }}
        
        .section-box {{
            background-color: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 2rem;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }}
        .section-header {{
            background: rgba(0,0,0,0.15);
            padding: 1rem 1.25rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .section-header h2 {{
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--text-main);
        }}
        .table-responsive {{
            overflow-x: auto;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 0.9rem;
        }}
        th {{
            background: rgba(15, 23, 42, 0.6);
            padding: 0.75rem 1rem;
            color: var(--text-muted);
            font-weight: 600;
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--border);
        }}
        td {{
            padding: 0.75rem 1rem;
            border-bottom: 1px solid rgba(51, 65, 85, 0.4);
            color: var(--text-main);
        }}
        tr:hover td {{
            background-color: var(--surface-hover);
        }}
        .rank-cell {{
            font-weight: 700;
            color: var(--accent);
            width: 50px;
        }}
        .size-cell {{
            color: #fbbf24;
            font-weight: 600;
            width: 110px;
        }}
        .path-cell {{
            font-family: monospace;
            font-size: 0.85rem;
            word-break: break-all;
        }}
        .time-cell {{
            font-size: 0.82rem;
            color: var(--text-muted);
            white-space: nowrap;
        }}
        .empty-state {{
            text-align: center;
            padding: 2rem !important;
            color: var(--text-muted);
            font-style: italic;
        }}
        pre.terminal-log {{
            background-color: var(--code-bg);
            color: #e2e8f0;
            padding: 1.25rem;
            font-family: "JetBrains Mono", Consolas, "Courier New", monospace;
            font-size: 0.82rem;
            line-height: 1.45;
            overflow-x: auto;
            max-height: 380px;
            white-space: pre-wrap;
            border-radius: 0 0 8px 8px;
        }}
        .remediation-box {{
            padding: 1.25rem;
            background: rgba(56, 189, 248, 0.05);
            border-left: 4px solid var(--accent);
            font-size: 0.88rem;
            line-height: 1.6;
        }}
        .remediation-box code {{
            background: #090d16;
            padding: 0.15rem 0.4rem;
            border-radius: 4px;
            color: var(--accent);
            font-family: monospace;
        }}
        footer {{
            text-align: center;
            padding-top: 1.5rem;
            color: var(--text-muted);
            font-size: 0.8rem;
            border-top: 1px solid var(--border);
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>🗄️ Old Backup Cleanup & Retention Dashboard</h1>
                <p>E1ITA307 Linux System Administration — Automation Sprint (AS_12)</p>
            </div>
            <div class="sys-badge">
                <span>HOST:</span> {html.escape(hostname_val)} &nbsp;|&nbsp; 
                <span>OS:</span> {html.escape(os_display)} &nbsp;|&nbsp; 
                <span>KERNEL:</span> {html.escape(kernel_val)}
            </div>
        </header>

        <!-- KPI CARDS -->
        <div class="grid">
            <div class="card">
                <div class="card-label">Backup Repository</div>
                <div class="card-value" style="font-size: 1.05rem; font-family: monospace;">{html.escape(repo_dir)}</div>
                <div class="card-subtext">{total_eval} total archives evaluated</div>
            </div>
            <div class="card">
                <div class="card-label">Retention Threshold</div>
                <div class="card-value" style="color: var(--accent);">&gt; {retention_days} Days</div>
                <div class="card-subtext">Min guarantee: {keep_min} latest</div>
            </div>
            <div class="card">
                <div class="card-label">Expired Backups Pruned</div>
                <div class="card-value" style="color: #f87171;">{expired_count}</div>
                <div class="card-subtext">{companions_purged} companion checksum(s) unlinked</div>
            </div>
            <div class="card">
                <div class="card-label">Active Backups Retained</div>
                <div class="card-value" style="color: #34d399;">{retained_count}</div>
                <div class="card-subtext">Preserved within retention window</div>
            </div>
            <div class="card">
                <div class="card-label">Storage Space Reclaimed</div>
                <div class="card-value" style="color: #fbbf24;">{html.escape(reclaimed_h)}</div>
                <div class="card-subtext">{mode_badge}</div>
            </div>
        </div>

        <!-- PRUNED ARCHIVES TABLE -->
        <div class="section-box">
            <div class="section-header">
                <h2>🗑️ Pruned Expired Archives (&gt; {retention_days} Days Old)</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{expired_count} archive(s) pruned</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Archive Filename</th>
                            <th>Archive Size</th>
                            <th>Age</th>
                            <th>Modified Date</th>
                            <th>Companion Checksum</th>
                        </tr>
                    </thead>
                    <tbody>
                        {pruned_rows_html}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- RETAINED ARCHIVES TABLE -->
        <div class="section-box">
            <div class="section-header">
                <h2>✅ Retained Active Backup Archives (Current Generation)</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{retained_count} archive(s) active</span>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Archive Filename</th>
                            <th>Archive Size</th>
                            <th>Age</th>
                            <th>Modified Date</th>
                            <th>Retention Policy Reason</th>
                        </tr>
                    </thead>
                    <tbody>
                        {retained_rows_html}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- ENTERPRISE RETENTION POLICIES -->
        <div class="section-box">
            <div class="section-header">
                <h2>🛡️ Enterprise Retention & Lifecycle Policies</h2>
            </div>
            <div class="remediation-box">
                <p><strong>Backup Lifecycle & Storage Management Standards:</strong></p>
                <ul style="margin-left: 1.5rem; margin-top: 0.5rem;">
                    <li><strong>Grandfather-Father-Son (GFS) Rotation:</strong> Maintain daily differentials for 7 days (Son), weekly rollups for 4 weeks (Father), and monthly snapshots for 12 months (Grandfather).</li>
                    <li><strong>Companion Artifact Hygiene:</strong> Always prune companion metadata (<code>.sha256</code>, <code>.md5</code>, <code>.log</code>) in lockstep with parent archive deletion to prevent inode leakage.</li>
                    <li><strong>Safety Minimum Safeguard:</strong> Never allow cleanup routines to prune all archives. Enforce <code>KEEP_MIN >= 1</code> to safeguard against catastrophic zero-backup scenarios during extended outages.</li>
                    <li><strong>Scheduled Automation:</strong> Schedule pruning immediately after successful backup creation via cron: <code>0 3 * * * /usr/local/bin/old_backup_cleaner.sh -d 7 --delete</code>.</li>
                </ul>
            </div>
        </div>

        <!-- LIVE EXECUTION AUDIT LOG -->
        <div class="section-box">
            <div class="section-header">
                <h2>💻 Console Execution Output</h2>
                <span style="font-size: 0.8rem; color: var(--text-muted);">{html.escape(timestamp_val)}</span>
            </div>
            <pre class="terminal-log">{html.escape(terminal_log)}</pre>
        </div>

        <footer>
            Automated Linux System Administration Sprint &bull; Problem AS_12 &bull; Generated on {html.escape(timestamp_val)}
        </footer>
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
