#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #07: Low Disk Space Alert (Disk Monitoring)
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs from anywhere).
#   2. Executes low_disk_space_alert.sh to audit file system utilization.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_07) — LOW DISK SPACE ALERT ENGINE               "
echo "================================================================================"

# Verify low_disk_space_alert.sh exists and is executable
if [ ! -f "./low_disk_space_alert.sh" ]; then
    echo "[ERROR] low_disk_space_alert.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./low_disk_space_alert.sh

# 2. Run low_disk_space_alert.sh and capture terminal output while streaming to console
echo "[INFO] Running low_disk_space_alert.sh on live filesystems..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
set +e
./low_disk_space_alert.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
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

JSON_PATH="logs/disk_alert.json"
LOG_FILE_PATH="logs/disk_alert.log"
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
    "problem_id": "AS_07",
    "title": "Low Disk Space Alert",
    "threshold_pct": 80,
    "total_filesystems_scanned": 9,
    "affected_filesystems_count": 0,
    "status": "HEALTHY",
    "affected_filesystems": [],
    "all_filesystems": []
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[WARN] Failed to read JSON telemetry: {e}")

threshold_val = data.get("threshold_pct", 80)
total_fs = data.get("total_filesystems_scanned", 0)
affected_fs_count = data.get("affected_filesystems_count", 0)
status_str = data.get("status", "HEALTHY")
affected_list = data.get("affected_filesystems", [])
all_list = data.get("all_filesystems", [])

status_badge = "ALL FILESYSTEMS HEALTHY" if affected_fs_count == 0 else f"{affected_fs_count} CRITICAL CAPACITY ALERT(S)"
status_color = "#22c55e" if affected_fs_count == 0 else "#ef4444"

# Table of affected filesystems
alert_rows = ""
if affected_list:
    for a in affected_list:
        dev = html.escape(a.get("device", ""))
        mnt = html.escape(a.get("mount", ""))
        tot = html.escape(str(a.get("total", "")))
        usd = html.escape(str(a.get("used", "")))
        avl = html.escape(str(a.get("available", "")))
        pct = a.get("utilization_pct", 0)
        sev = html.escape(a.get("severity", "WARNING"))

        badge_cls = "badge-danger" if sev in ["CRITICAL", "HIGH"] else "badge-warning"

        alert_rows += f"""
        <tr>
            <td><code>{dev}</code></td>
            <td><strong>{mnt}</strong></td>
            <td>{tot}</td>
            <td>{usd}</td>
            <td><strong style="color: #ef4444;">{avl}</strong></td>
            <td>
                <div style="display:flex; align-items:center; gap:8px;">
                    <span style="font-weight:700; color:#ef4444;">{pct}%</span>
                    <div style="flex-grow:1; background:#0f172a; height:6px; border-radius:3px; overflow:hidden;">
                        <div style="width:{min(pct,100)}%; height:100%; background:#ef4444;"></div>
                    </div>
                </div>
            </td>
            <td><span class="badge {badge_cls}">{sev}</span></td>
        </tr>
        """
else:
    alert_rows = f"""
    <tr>
        <td colspan="7" style="text-align:center; padding: 22px; color: #4ade80;">
            ✅ Optimal disk health. Zero mounted partitions have exceeded the <strong>{threshold_val}%</strong> utilization threshold.
        </td>
    </tr>
    """

# Table of all scanned filesystems
all_fs_rows = ""
if all_list:
    for item in all_list:
        dev = html.escape(item.get("device", ""))
        mnt = html.escape(item.get("mount", ""))
        tot = html.escape(str(item.get("total", "")))
        usd = html.escape(str(item.get("used", "")))
        avl = html.escape(str(item.get("available", "")))
        pct = item.get("utilization_pct", 0)
        crossed = item.get("crossed_threshold", False)

        bar_color = "#ef4444" if crossed else ("#f59e0b" if pct >= 70 else "#22c55e")
        badge_item = '<span class="badge badge-danger">EXCEEDED</span>' if crossed else '<span class="badge badge-success">OK</span>'

        all_fs_rows += f"""
        <tr>
            <td><code>{dev}</code></td>
            <td><strong>{mnt}</strong></td>
            <td>{tot}</td>
            <td>{usd}</td>
            <td>{avl}</td>
            <td>
                <div style="display:flex; align-items:center; gap:8px;">
                    <span style="width:36px; font-family:var(--font-mono);">{pct}%</span>
                    <div style="flex-grow:1; background:#0f172a; height:6px; border-radius:3px; overflow:hidden;">
                        <div style="width:{min(pct,100)}%; height:100%; background:{bar_color};"></div>
                    </div>
                </div>
            </td>
            <td>{badge_item}</td>
        </tr>
        """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Low Disk Space Alert Dashboard — AS_07 (E1ITA307)</title>
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

        .remed-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 14px;
        }}
        .remed-card {{
            background: #0d1526;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
        }}
        .remed-card h4 {{
            font-size: 0.92rem;
            color: var(--cyan);
            margin-bottom: 6px;
        }}
        .remed-card p {{
            font-size: 0.84rem;
            color: var(--text-muted);
            margin-bottom: 8px;
        }}
        .remed-card code {{
            display: block;
            background: #090d16;
            padding: 6px 10px;
            font-size: 0.82rem;
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
                <h1>💽 Low Disk Space Alert Dashboard — AS_07</h1>
                <p>Linux System Administration (E1ITA307) &bull; Storage Capacity Threshold Auditing &amp; Anomaly Detection</p>
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
                <div class="card-metric-title">Alert Threshold</div>
                <div class="card-metric-value" style="color: var(--cyan);">{threshold_val}%</div>
                <div class="card-metric-desc">Warning triggered if utilization &ge; {threshold_val}%</div>
            </div>

            <div class="card" style="border-top: 4px solid var(--purple);">
                <div class="card-metric-title">Filesystems Scanned</div>
                <div class="card-metric-value" style="color: var(--purple);">{total_fs}</div>
                <div class="card-metric-desc">POSIX portable volume inspection via <code>df -P</code></div>
            </div>

            <div class="card" style="border-top: 4px solid {'var(--green)' if affected_fs_count == 0 else 'var(--red)'};">
                <div class="card-metric-title">Threshold Violations</div>
                <div class="card-metric-value" style="color: {'var(--green)' if affected_fs_count == 0 else 'var(--red)'};">
                    {affected_fs_count}
                </div>
                <div class="card-metric-desc">{'All partitions healthy' if affected_fs_count == 0 else f'{affected_fs_count} partition(s) exceeding threshold'}</div>
            </div>

            <div class="card" style="border-top: 4px solid {'var(--green)' if affected_fs_count == 0 else 'var(--red)'};">
                <div class="card-metric-title">Capacity Status</div>
                <div class="card-metric-value" style="font-size: 1.45rem; color: {'var(--green)' if affected_fs_count == 0 else 'var(--red)'};">
                    {'NORMAL' if affected_fs_count == 0 else 'ALERT'}
                </div>
                <div class="card-metric-desc">{'Safe operational headroom' if affected_fs_count == 0 else 'Actionable low space condition'}</div>
            </div>
        </div>

        <!-- Section 1: Alert Warnings -->
        <div class="section-panel">
            <div class="section-header">
                <h2>⚠️ High-Capacity Utilization Alerts (&ge; {threshold_val}%)</h2>
                <span class="badge" style="background: rgba(34,197,94,0.15); color: {status_color}; border: 1px solid {status_color};">{status_badge}</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Filesystem Device</th>
                        <th>Mount Point</th>
                        <th>Total Size</th>
                        <th>Used Space</th>
                        <th>Available</th>
                        <th>Capacity Utilization</th>
                        <th>Severity</th>
                    </tr>
                </thead>
                <tbody>
                    {alert_rows}
                </tbody>
            </table>
        </div>

        <!-- Section 2: Complete Mounted Storage Inventory -->
        <div class="section-panel">
            <div class="section-header">
                <h2>🗄️ Complete Storage Volume Inventory</h2>
                <span class="badge badge-info">{total_fs} Mounted Partition(s)</span>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Device</th>
                        <th>Mount Point</th>
                        <th>Total Size</th>
                        <th>Used Space</th>
                        <th>Available</th>
                        <th>Utilization Progress</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    {all_fs_rows}
                </tbody>
            </table>
        </div>

        <!-- Section 3: Mitigation Playbook -->
        <div class="section-panel">
            <div class="section-header">
                <h2>🛠️ Storage Remediation &amp; Mitigation Playbook</h2>
            </div>
            <div class="remed-grid">
                <div class="remed-card">
                    <h4>1. Isolate Storage Consumers</h4>
                    <p>Identify the top 10 space-consuming directories on the affected volume:</p>
                    <code>du -sh &lt;mount&gt;/* 2&gt;/dev/null | sort -hr | head -n 10</code>
                </div>
                <div class="remed-card">
                    <h4>2. Clean Systemd Journals</h4>
                    <p>Vacuum systemd journal archives older than 3 days:</p>
                    <code>sudo journalctl --vacuum-time=3d</code>
                </div>
                <div class="remed-card">
                    <h4>3. Purge Package Cache</h4>
                    <p>Remove cached deb/rpm archives from package managers:</p>
                    <code>sudo apt clean &amp;&amp; sudo apt autoremove --purge</code>
                </div>
                <div class="remed-card">
                    <h4>4. Prune Container Footprints</h4>
                    <p>Remove dangling images, build caches, and stopped containers:</p>
                    <code>docker system prune -af --volumes</code>
                </div>
            </div>
        </div>

        <!-- Section 4: Live Terminal Console -->
        <div class="section-panel">
            <div class="section-header">
                <h2>🖥️ Live Monitor Terminal Transcript</h2>
                <span class="badge badge-info">CLI Console</span>
            </div>
            <div class="terminal-box">{html.escape(terminal_log)}</div>
        </div>

        <!-- Section 5: Persistent Audit Log -->
        <div class="section-panel">
            <div class="section-header">
                <h2>📜 Persistent Capacity Audit Log (<code>logs/disk_alert.log</code>)</h2>
                <span class="badge badge-info">Audit Trail</span>
            </div>
            <div class="terminal-box">{html.escape(log_preview)}</div>
        </div>

        <!-- Footer -->
        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint AS_07 &bull; Generated dynamically via <code>run.sh</code>
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
