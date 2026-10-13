#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_15)
# Problem Statement #15: Error Log Report
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE:
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes error_log_report.sh to analyze system error logs.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_15) — ERROR LOG REPORT                          "
echo "================================================================================"

# Verify error_log_report.sh exists and is executable
if [ ! -f "./error_log_report.sh" ]; then
    echo "[ERROR] error_log_report.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./error_log_report.sh

# 2. Run error_log_report.sh and capture terminal output
echo "[INFO] Running error_log_report.sh on live system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'as15_term_XXXXXX')"
set +e
./error_log_report.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
REPORT_EXIT=$?
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

target_log = "/var/log/syslog"
source_type = "real system log (/var/log/syslog)"
log_size = "0 bytes"
total_lines = "0"
monitored_keywords = "error fail critical fatal warn"
status = "ALERT"
matching_entries = "0"
error_density = "0.0%"

keywords_data = {
    "WARN": {"count": 0, "share": "0.0%", "color": "#f59e0b"},
    "ERROR": {"count": 0, "share": "0.0%", "color": "#f87171"},
    "FAIL": {"count": 0, "share": "0.0%", "color": "#ef4444"},
    "FATAL": {"count": 0, "share": "0.0%", "color": "#dc2626"},
    "CRITICAL": {"count": 0, "share": "0.0%", "color": "#a855f7"}
}

in_breakdown = False

for line in term_log.splitlines():
    if "Target Log File    :" in line:
        target_log = line.split(":", 1)[1].strip()
    elif "Log Source Type    :" in line:
        source_type = line.split(":", 1)[1].strip()
    elif "Log File Size      :" in line:
        log_size = line.split(":", 1)[1].strip()
    elif "Total Log Entries  :" in line:
        total_lines = line.split(":", 1)[1].strip()
    elif "Monitored Keywords :" in line:
        monitored_keywords = line.split(":", 1)[1].strip()
    elif "Status                  :" in line:
        val = line.split(":", 1)[1].strip()
        if "ALERT" in val:
            status = "ALERT"
        elif "OK" in val:
            status = "OK"
    elif "Matching Error Entries  :" in line:
        val = line.split(":", 1)[1].strip()
        m = re.search(r'(\d+)\s*\(([\d\.]+%)\s*of total', val)
        if m:
            matching_entries = f"{int(m.group(1)):,}"
            error_density = m.group(2)
        else:
            m2 = re.search(r'(\d+)', val)
            if m2:
                matching_entries = f"{int(m2.group(1)):,}"
    elif "SECTION 2: SEVERITY" in line:
        in_breakdown = True
        continue
    elif "SECTION 3:" in line:
        in_breakdown = False

    if in_breakdown:
        parts = line.split()
        if len(parts) >= 3 and parts[0] in keywords_data:
            kw = parts[0]
            cnt = int(parts[1]) if parts[1].isdigit() else 0
            share = parts[2]
            keywords_data[kw]["count"] = cnt
            keywords_data[kw]["share"] = share

# Format total lines with comma
try:
    total_lines_formatted = f"{int(total_lines):,}"
except ValueError:
    total_lines_formatted = total_lines

# Find dominant keyword
dominant_kw = "None"
max_count = -1
dominant_share = "0.0%"
dominant_count = 0
for kw, info in keywords_data.items():
    if info["count"] > max_count:
        max_count = info["count"]
        dominant_kw = kw
        dominant_share = info["share"]
        dominant_count = info["count"]

if dominant_count == 0:
    dominant_kw = "None"
    dominant_desc = "No error keywords detected"
else:
    dominant_desc = f"{dominant_count:,} occurrences ({dominant_share} matching share)"

status_color = "#f87171" if status == "ALERT" else "#10b981"
status_desc = "Errors and warnings detected in live log" if status == "ALERT" else "No errors detected in analyzed log"

# Build table rows
table_rows = ""
for kw in ["WARN", "ERROR", "FAIL", "FATAL", "CRITICAL"]:
    info = keywords_data.get(kw, {"count": 0, "share": "0.0%", "color": "#f59e0b"})
    try:
        share_val = float(info["share"].replace("%", ""))
    except ValueError:
        share_val = 0.0
    bar_width = f"{max(share_val, 2.0) if share_val > 0 else 0}%"
    table_rows += f'''
          <tr>
            <td><strong style="color: {info["color"]};">{html.escape(kw)}</strong></td>
            <td>{info["count"]:,}</td>
            <td>{html.escape(info["share"])}</td>
            <td>
              <div class="progress-bar-container">
                <div class="progress-bar-fill" style="width: {bar_width}; background: {info["color"]};"></div>
              </div>
            </td>
          </tr>'''

html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Error Log Report — Automation Sprint Dashboard</title>
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
      background: linear-gradient(135deg, #2e1d10 0%, #111827 100%);
      border: 1px solid var(--border-color);
      border-left: 6px solid var(--warning);
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
      color: #fbbf24;
      margin-bottom: 0.5rem;
      background: rgba(245, 158, 11, 0.12);
      padding: 0.25rem 0.6rem;
      border-radius: 4px;
      border: 1px solid rgba(245, 158, 11, 0.25);
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

    .breakdown-card {{
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 1.5rem;
      margin-bottom: 2rem;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
    }}

    .breakdown-card-title {{
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

    .progress-bar-container {{
      width: 100%;
      height: 8px;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 4px;
      overflow: hidden;
    }}

    .progress-bar-fill {{
      height: 100%;
      border-radius: 4px;
      transition: width 0.3s ease;
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
      <h1>Problem #15: Error Log Report</h1>
      <p class="subtitle">Automated severity classification, keyword frequency distribution, and chronological tracking.</p>
      <div class="header-stats">
        <span>Target Log: <strong>{html.escape(target_log)}</strong></span>
        <span>Keywords Monitored: <strong>{html.escape(monitored_keywords)}</strong></span>
        <span>Total Analyzed Lines: <strong>{total_lines_formatted}</strong></span>
        <span>Engine: <strong>error_log_report.sh</strong></span>
      </div>
    </header>

    <section>
      <h2 class="section-title">📊 Executive Log Audit Summary</h2>
      <div class="cards-grid">
        <div class="card" style="border-top: 4px solid {status_color};">
          <div class="card-metric-title">Health Status</div>
          <div class="card-metric-value" style="color: {status_color};">{status}</div>
          <div class="card-metric-desc">{status_desc}</div>
        </div>
        <div class="card" style="border-top: 4px solid var(--danger);">
          <div class="card-metric-title">Matching Error Entries</div>
          <div class="card-metric-value" style="color: #f87171;">{matching_entries}</div>
          <div class="card-metric-desc">{error_density} error density across entries</div>
        </div>
        <div class="card" style="border-top: 4px solid var(--accent-blue);">
          <div class="card-metric-title">Total Lines Analyzed</div>
          <div class="card-metric-value" style="color: var(--accent-blue);">{total_lines_formatted}</div>
          <div class="card-metric-desc">{html.escape(log_size)} inspected</div>
        </div>
        <div class="card" style="border-top: 4px solid var(--warning);">
          <div class="card-metric-title">Dominant Keyword</div>
          <div class="card-metric-value" style="color: #fbbf24;">{html.escape(dominant_kw)}</div>
          <div class="card-metric-desc">{dominant_desc}</div>
        </div>
      </div>
    </section>

    <section class="breakdown-card">
      <div class="breakdown-card-title">
        <span>🔍 Severity &amp; Keyword Distribution Breakdown</span>
      </div>
      <table class="data-table">
        <thead>
          <tr>
            <th>Monitored Keyword</th>
            <th>Matching Lines</th>
            <th>Share (%)</th>
            <th>Visual Distribution</th>
          </tr>
        </thead>
        <tbody>
          {table_rows}
        </tbody>
      </table>
    </section>

    <section class="log-section">
      <details class="log-accordion" open>
        <summary class="log-header">
          <div class="log-title">
            <span>📜 Captured Execution Log</span>
            <span class="log-toggle-hint">Click to toggle</span>
          </div>
          <div class="log-subtitle">Direct output from: <code>./error_log_report.sh</code></div>
        </summary>
        <div class="log-viewer"><pre>{html.escape(term_log)}</pre></div>
      </details>
    </section>

    <footer class="dashboard-footer">
      Automation Sprint &mdash; Problem Statement #15 Error Log Report &bull; Linux System Administration (E1ITA307)
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
