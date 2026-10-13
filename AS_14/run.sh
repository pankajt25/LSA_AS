#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_14)
# Problem Statement #14: Suspicious IP Detection
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE:
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes suspicious_ip_detector.sh to monitor failed SSH attempts.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_14) — SUSPICIOUS IP DETECTION                   "
echo "================================================================================"

# Verify suspicious_ip_detector.sh exists and is executable
if [ ! -f "./suspicious_ip_detector.sh" ]; then
    echo "[ERROR] suspicious_ip_detector.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./suspicious_ip_detector.sh

# 2. Run suspicious_ip_detector.sh and capture terminal output
echo "[INFO] Running suspicious_ip_detector.sh on live system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'as14_term_XXXXXX')"
set +e
./suspicious_ip_detector.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
DETECTOR_EXIT=$?
set -e
echo "--------------------------------------------------------------------------------"

export TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# 3. Regenerate report.html from scratch using Python 3
echo "[INFO] Regenerating self-contained dark-themed report.html with live data..."

python3 - << 'PYEOF'
import html
import os
import re
import sys
from datetime import datetime

term_log = os.environ.get("TERMINAL_LOG_CONTENT", "")

# Extract fields from output
target_log = "/var/log/auth.log"
source_type = "real system authentication log (/var/log/auth.log)"
threshold = 5
scan_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

for line in term_log.splitlines():
    if "Target Log File :" in line:
        target_log = line.split(":", 1)[1].strip()
    elif "Log Source Type :" in line:
        source_type = line.split(":", 1)[1].strip()
    elif "Alert Threshold :" in line:
        m = re.search(r'(\d+)', line)
        if m:
            threshold = int(m.group(1))
    elif "Scan Started At :" in line:
        scan_time = line.split(":", 1)[1].strip()

# Check for detected suspicious IPs
flagged_ips = []
total_failed_logins = 0
in_table = False
for line in term_log.splitlines():
    if "IP ADDRESS" in line and "ATTEMPTS" in line:
        in_table = True
        continue
    if in_table:
        if line.startswith("---") or line.startswith("==="):
            if len(flagged_ips) > 0:
                in_table = False
            continue
        if "[ALERT]" in line or "[RESULT]" in line or "[STATUS]" in line or "Total" in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 5 and re.match(r'^\d+\.\d+\.\d+\.\d+$', parts[0]):
            flagged_ips.append({
                "ip": parts[0],
                "attempts": int(parts[1]) if parts[1].isdigit() else 0,
                "first_seen": parts[2],
                "last_seen": parts[3],
                "status": parts[4]
            })

for line in term_log.splitlines():
    if "Total Failed Logins Scanned :" in line:
        m = re.search(r':\s*(\d+)', line)
        if m:
            total_failed_logins = int(m.group(1))

if not total_failed_logins and flagged_ips:
    total_failed_logins = sum(item["attempts"] for item in flagged_ips)

is_clean = len(flagged_ips) == 0
threat_status = "CLEAN" if is_clean else "ALERT"
threat_color = "#34d399" if is_clean else "#f87171"
header_border = "var(--success)" if is_clean else "var(--danger)"
header_tag_style = 'color: #34d399; background: rgba(16, 185, 129, 0.12); border-color: rgba(16, 185, 129, 0.25);' if is_clean else 'color: #f87171; background: rgba(239, 68, 68, 0.12); border-color: rgba(239, 68, 68, 0.25);'
primary_offender = "None" if is_clean else f"{flagged_ips[0]['ip']} ({flagged_ips[0]['attempts']} attempts)"
primary_offender_desc = "No malicious activity recorded" if is_clean else "Highest failed login attempts"

if is_clean:
    table_section = f'''
      <div style="padding: 1.5rem; text-align: center; color: var(--success); background: rgba(16, 185, 129, 0.08); border: 1px dashed rgba(16, 185, 129, 0.3); border-radius: 8px;">
        <p style="font-size: 1.15rem; font-weight: 700; margin-bottom: 0.35rem;">✅ No suspicious IP activity found in the current system logs.</p>
        <p style="color: var(--text-muted); font-size: 0.88rem;">Live system source <code>{html.escape(target_log)}</code> was analyzed with threshold &ge; {threshold}. Zero failed SSH login attempts were recorded exceeding threshold.</p>
      </div>
'''
else:
    rows = ""
    for item in flagged_ips:
        rows += f'''
          <tr>
            <td><strong>{html.escape(item["ip"])}</strong></td>
            <td><span style="color: #f87171; font-weight: 700;">{item["attempts"]}</span></td>
            <td>{html.escape(item["first_seen"])}</td>
            <td>{html.escape(item["last_seen"])}</td>
            <td><span class="badge badge-danger">{html.escape(item["status"])}</span></td>
          </tr>'''
    table_section = f'''
      <table class="data-table">
        <thead>
          <tr>
            <th>IP Address</th>
            <th>Failed Attempts</th>
            <th>First Seen</th>
            <th>Last Seen</th>
            <th>Threat Status</th>
          </tr>
        </thead>
        <tbody>
          {rows}
        </tbody>
      </table>
'''

html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Suspicious IP Detection — Automation Sprint Dashboard</title>
  <style>
    :root {{
      --bg-base: #0a0e17;
      --bg-surface: #111827;
      --bg-card: #1f2937;
      --bg-code: #030712;
      --accent-blue: #38bdf8;
      --accent-indigo: #6366f1;
      --text-main: #f3f4f6;
      --text-muted: #9ca3af;
      --text-dim: #6b7280;
      --border-color: #374151;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      background-color: var(--bg-base);
      color: var(--text-main);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.5;
      padding: 2rem 1.5rem;
    }}

    .container {{
      max-width: 1100px;
      margin: 0 auto;
    }}

    .dashboard-header {{
      background: linear-gradient(135deg, #2a1526 0%, #111827 100%);
      border: 1px solid var(--border-color);
      border-left: 6px solid {header_border};
      padding: 2rem;
      border-radius: 12px;
      margin-bottom: 2rem;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
    }}

    .header-tag {{
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-bottom: 0.5rem;
      padding: 0.25rem 0.6rem;
      border-radius: 4px;
      border: 1px solid;
      {header_tag_style}
    }}

    .dashboard-header h1 {{
      font-size: 1.85rem;
      font-weight: 800;
      color: #ffffff;
      margin-bottom: 0.4rem;
      letter-spacing: -0.02em;
    }}

    .dashboard-header p.subtitle {{
      color: var(--text-muted);
      font-size: 0.95rem;
    }}

    .header-stats {{
      display: flex;
      flex-wrap: wrap;
      gap: 1.5rem;
      margin-top: 1.25rem;
      padding-top: 1.25rem;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      font-size: 0.85rem;
      color: var(--text-muted);
    }}

    .header-stats span strong {{
      color: var(--text-main);
    }}

    .section-title {{
      font-size: 1.25rem;
      font-weight: 700;
      color: #ffffff;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}

    .cards-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 1.25rem;
      margin-bottom: 2rem;
    }}

    .card {{
      background: var(--bg-card);
      border-radius: 10px;
      overflow: hidden;
      border: 1px solid var(--border-color);
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }}

    .card-metric-title {{
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-dim);
      margin-bottom: 0.4rem;
    }}

    .card-metric-value {{
      font-size: 2rem;
      font-weight: 800;
      line-height: 1.1;
      margin-bottom: 0.4rem;
    }}

    .card-metric-desc {{
      font-size: 0.82rem;
      color: var(--text-muted);
    }}

    .threat-card {{
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 1.5rem;
      margin-bottom: 2rem;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
    }}

    .threat-card-title {{
      font-size: 1.1rem;
      font-weight: 700;
      color: #ffffff;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}

    .data-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 0.875rem;
    }}

    .data-table th {{
      text-align: left;
      padding: 0.75rem 1rem;
      background: var(--bg-card);
      color: var(--text-dim);
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border-bottom: 1px solid var(--border-color);
    }}

    .data-table td {{
      padding: 0.85rem 1rem;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      color: var(--text-main);
    }}

    .data-table tr:hover td {{
      background: rgba(255, 255, 255, 0.02);
    }}

    .badge {{
      display: inline-block;
      font-size: 0.72rem;
      font-weight: 700;
      padding: 0.25rem 0.6rem;
      border-radius: 9999px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}

    .badge-danger {{
      background: rgba(239, 68, 68, 0.15);
      color: #f87171;
      border: 1px solid rgba(239, 68, 68, 0.3);
    }}

    .badge-safe {{
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.3);
    }}

    .log-section {{
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 1.5rem;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
    }}

    details.log-accordion summary {{
      cursor: pointer;
      user-select: none;
      outline: none;
      list-style: none;
    }}

    details.log-accordion summary::-webkit-details-marker {{
      display: none;
    }}

    .log-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 0.75rem;
    }}

    .log-title {{
      font-size: 1.15rem;
      font-weight: 700;
      color: #ffffff;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}

    .log-toggle-hint {{
      font-size: 0.75rem;
      color: var(--accent-blue);
      background: rgba(56, 189, 248, 0.1);
      padding: 0.2rem 0.5rem;
      border-radius: 4px;
      margin-left: 0.5rem;
    }}

    .log-subtitle {{
      font-size: 0.8rem;
      color: var(--text-muted);
    }}

    .log-viewer {{
      background: var(--bg-code);
      border: 1px solid #1f2937;
      border-radius: 6px;
      padding: 1rem;
      max-height: 340px;
      overflow-y: auto;
      font-family: "Consolas", "Monaco", "Courier New", monospace;
      font-size: 0.82rem;
      color: #38bdf8;
      white-space: pre-wrap;
      word-break: break-all;
      line-height: 1.6;
      margin-top: 0.75rem;
    }}

    .dashboard-footer {{
      text-align: center;
      margin-top: 2.5rem;
      color: var(--text-dim);
      font-size: 0.8rem;
    }}
  </style>
</head>
<body>
  <div class="container">
    <header class="dashboard-header">
      <div class="header-tag">Course: Linux System Administration (E1ITA307)</div>
      <h1>Problem #14: Suspicious IP Detection</h1>
      <p class="subtitle">Automated SSH authentication log analysis, brute-force attack detection, and aggression ranking.</p>
      <div class="header-stats">
        <span>Target Log: <strong>{html.escape(target_log)}</strong></span>
        <span>Detection Threshold: <strong>&ge; {threshold} attempts</strong></span>
        <span>Log Source Type: <strong>{html.escape(source_type)}</strong></span>
        <span>Engine: <strong>suspicious_ip_detector.sh</strong></span>
      </div>
    </header>

    <section>
      <h2 class="section-title">📊 Security Audit Summary</h2>
      <div class="cards-grid">
        <div class="card" style="border-top: 4px solid {threat_color};">
          <div class="card-metric-title">Threat Status</div>
          <div class="card-metric-value" style="color: {threat_color};">{threat_status}</div>
          <div class="card-metric-desc">{len(flagged_ips)} IP addresses exceeded threshold</div>
        </div>
        <div class="card" style="border-top: 4px solid {threat_color};">
          <div class="card-metric-title">Suspicious IPs</div>
          <div class="card-metric-value" style="color: {threat_color};">{len(flagged_ips)}</div>
          <div class="card-metric-desc">{"No brute-force attempts detected" if is_clean else "Threat actors flagged"}</div>
        </div>
        <div class="card" style="border-top: 4px solid var(--accent-blue);">
          <div class="card-metric-title">Failed Logins Scanned</div>
          <div class="card-metric-value" style="color: var(--accent-blue);">{total_failed_logins}</div>
          <div class="card-metric-desc">{"Zero failed SSH password attempts" if total_failed_logins == 0 else "Failed authentication attempts tallied"}</div>
        </div>
        <div class="card" style="border-top: 4px solid {threat_color};">
          <div class="card-metric-title">Primary Offender</div>
          <div class="card-metric-value" style="color: {threat_color}; font-size: 1.5rem;">{html.escape(primary_offender)}</div>
          <div class="card-metric-desc">{primary_offender_desc}</div>
        </div>
      </div>
    </section>

    <section class="threat-card">
      <div class="threat-card-title">
        <span>🎯 IP Analysis &amp; Aggression Ranking</span>
      </div>
      {table_section}
    </section>

    <section class="log-section">
      <details class="log-accordion" open>
        <summary class="log-header">
          <div class="log-title">
            <span>📜 Captured Execution Log</span>
            <span class="log-toggle-hint">Click to toggle</span>
          </div>
          <div class="log-subtitle">Direct output from: <code>./suspicious_ip_detector.sh</code></div>
        </summary>
        <div class="log-viewer"><pre>{html.escape(term_log)}</pre></div>
      </details>
    </section>

    <footer class="dashboard-footer">
      Automation Sprint &mdash; Problem Statement #14 Suspicious IP Detection &bull; Linux System Administration (E1ITA307)
    </footer>
  </div>
</body>
</html>
'''

with open("report.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print("[INFO] report.html regenerated successfully.")
PYEOF

# 4. OS detection and browser dispatch
echo "[INFO] Dispatching dashboard to default browser..."
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
elif [ "${OS_NAME:-$(uname -s)}" = "Darwin" ] && command -v open >/dev/null 2>&1; then
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
