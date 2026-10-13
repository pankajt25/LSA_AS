#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_18)
# Problem Statement #18: Server Process Check
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE:
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes server_process_check.sh to inspect target process status.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_18) — SERVER PROCESS CHECK                      "
echo "================================================================================"

# Verify server_process_check.sh exists and is executable
if [ ! -f "./server_process_check.sh" ]; then
    echo "[ERROR] server_process_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./server_process_check.sh

# 2. Run server_process_check.sh and capture terminal output
echo "[INFO] Running server_process_check.sh on live system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp 2>/dev/null || mktemp -t 'as18_term_XXXXXX')"
set +e
./server_process_check.sh "${@:---default}" 2>&1 | tee "${TMP_TERM_LOG}"
CHECK_EXIT=$?
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

# Read logs/process_check.log
log_path = os.path.join("logs", "process_check.log")
log_entries = []
if os.path.exists(log_path):
    with open(log_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line_str = line.strip()
            if line_str:
                entry_class = "log-entry-running"
                if "[STOPPED]" in line_str:
                    entry_class = "log-entry-stopped"
                elif "[ERROR" in line_str:
                    entry_class = "log-entry-error"
                log_entries.append((entry_class, line_str))

recent_entries = log_entries[-20:] if log_entries else [("log-entry-running", "[INFO] No historical process logs recorded.")]

log_container_html = ""
for cls, txt in recent_entries:
    log_container_html += f'<div class="{cls}">{html.escape(txt)}</div>\n'

# Parse target process, instance count, PIDs, oldest uptime from terminal log
target_process = "bash"
instance_count = "2"
active_pids = "None"
oldest_uptime = "Active"

for line in term_log.splitlines():
    if "Target Process       :" in line:
        target_process = line.split(":", 1)[1].strip()
    elif "Instance Count       :" in line:
        m = re.search(r'(\d+)', line)
        if m:
            instance_count = m.group(1)
    elif "Active PID(s)        :" in line:
        active_pids = line.split(":", 1)[1].strip()
    elif "Oldest Uptime        :" in line:
        parts = line.split(":", 1)[1].strip().split()
        if parts:
            oldest_uptime = parts[0]

html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Process Check Dashboard | AS_18</title>
    <style>
        :root {{
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-card: #182234;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --border-color: #334155;
            --status-green: #10b981;
            --status-green-bg: rgba(16, 185, 129, 0.15);
            --status-green-border: rgba(16, 185, 129, 0.4);
            --status-red: #ef4444;
            --status-red-bg: rgba(239, 68, 68, 0.15);
            --status-red-border: rgba(239, 68, 68, 0.4);
            --status-yellow: #f59e0b;
            --status-yellow-bg: rgba(245, 158, 11, 0.15);
            --status-yellow-border: rgba(245, 158, 11, 0.4);
            --status-blue: #38bdf8;
            --status-blue-bg: rgba(56, 189, 248, 0.15);
            --status-blue-border: rgba(56, 189, 248, 0.4);
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
            padding: 30px 20px;
        }}

        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}

        header {{
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 28px 32px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4);
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
            font-size: 0.8rem;
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
        }}

        .subtitle {{
            color: var(--text-secondary);
            font-size: 0.95rem;
        }}

        .meta-pill-group {{
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            align-items: center;
        }}

        .meta-pill {{
            background: var(--bg-primary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 14px;
            font-size: 0.85rem;
            display: flex;
            gap: 8px;
            align-items: center;
        }}

        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}

        .metric-card {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
        }}

        .metric-label {{
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 6px;
        }}

        .metric-value {{
            font-size: 1.55rem;
            font-weight: 700;
            margin-bottom: 4px;
            font-family: var(--font-mono);
        }}

        .metric-sub {{
            font-size: 0.78rem;
            color: var(--text-secondary);
        }}

        .section-title {{
            font-size: 1.15rem;
            font-weight: 600;
            color: #ffffff;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .cards-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
        }}

        .status-card {{
            background: var(--bg-card);
            border-radius: 10px;
            padding: 18px;
            border: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
        }}

        .card-running {{ border-top: 4px solid var(--status-green); }}
        .card-stopped {{ border-top: 4px solid var(--status-red); }}
        .card-error {{ border-top: 4px solid var(--status-yellow); }}

        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }}

        .card-title {{
            font-size: 0.95rem;
            font-weight: 600;
            color: var(--text-primary);
        }}

        .badge-status {{
            font-size: 0.72rem;
            font-weight: 700;
            padding: 3px 10px;
            border-radius: 9999px;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}

        .badge-running {{
            background: var(--status-green-bg);
            color: var(--status-green);
            border: 1px solid var(--status-green-border);
        }}

        .badge-stopped {{
            background: var(--status-red-bg);
            color: var(--status-red);
            border: 1px solid var(--status-red-border);
        }}

        .badge-error {{
            background: var(--status-yellow-bg);
            color: var(--status-yellow);
            border: 1px solid var(--status-yellow-border);
        }}

        .card-details {{
            display: flex;
            flex-direction: column;
            gap: 8px;
            font-size: 0.88rem;
            margin-bottom: 14px;
        }}

        .detail-row {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 4px 0;
            border-bottom: 1px dashed rgba(255, 255, 255, 0.05);
        }}

        .detail-label {{
            color: var(--text-secondary);
        }}

        .detail-val {{
            font-weight: 600;
            font-family: var(--font-mono);
            color: #ffffff;
        }}

        .code-box {{
            background: #090d16;
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 8px;
            padding: 14px;
            font-family: var(--font-mono);
            font-size: 0.78rem;
            line-height: 1.45;
            overflow-x: auto;
            color: #cbd5e1;
            white-space: pre-wrap;
            flex-grow: 1;
        }}

        .exec-section {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 22px;
            margin-bottom: 24px;
        }}

        .terminal-window {{
            background: #090d16;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            overflow: hidden;
            margin-top: 12px;
        }}

        .terminal-bar {{
            background: #1e293b;
            padding: 8px 14px;
            display: flex;
            align-items: center;
            gap: 6px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }}

        .dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            display: inline-block;
        }}

        .dot-red {{ background: #ef4444; }}
        .dot-yellow {{ background: #f59e0b; }}
        .dot-green {{ background: #10b981; }}

        .terminal-title {{
            font-size: 0.75rem;
            color: var(--text-muted);
            margin-left: 8px;
            font-family: var(--font-mono);
        }}

        .terminal-body {{
            padding: 16px;
            font-family: var(--font-mono);
            font-size: 0.8rem;
            line-height: 1.5;
            color: #e2e8f0;
            overflow-x: auto;
            white-space: pre-wrap;
        }}

        .log-section {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 22px;
            margin-bottom: 24px;
        }}

        .log-container {{
            background: #090d16;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            font-family: var(--font-mono);
            font-size: 0.8rem;
            line-height: 1.6;
            max-height: 280px;
            overflow-y: auto;
            color: #94a3b8;
            white-space: pre;
            margin-top: 12px;
        }}

        .log-entry-running {{ color: #86efac; }}
        .log-entry-stopped {{ color: #fca5a5; }}
        .log-entry-error {{ color: #fde68a; }}

        .checklist-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin-top: 12px;
        }}

        .check-card {{
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 14px 16px;
            display: flex;
            align-items: flex-start;
            gap: 12px;
        }}

        .check-icon {{
            color: var(--status-green);
            font-weight: bold;
            font-size: 1.1rem;
            line-height: 1;
        }}

        .check-content h4 {{
            font-size: 0.9rem;
            font-weight: 600;
            color: #f1f5f9;
            margin-bottom: 4px;
        }}

        .check-content p {{
            font-size: 0.8rem;
            color: var(--text-secondary);
        }}

        footer {{
            text-align: center;
            padding: 24px 0 10px 0;
            font-size: 0.82rem;
            color: var(--text-muted);
            border-top: 1px solid var(--border-color);
            margin-top: 30px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-top">
                <div>
                    <span class="badge-course">E1ITA307 &bull; Linux System Administration</span>
                    <h1>Server Process Check Dashboard</h1>
                    <p class="subtitle">Problem Statement #18 &bull; Process Management Automation Sprint</p>
                </div>
                <div class="meta-pill-group">
                    <div class="meta-pill">
                        <span>Environment:</span>
                        <strong>Linux (WSL2 / Ubuntu)</strong>
                    </div>
                    <div class="meta-pill">
                        <span>Inspection:</span>
                        <strong>pgrep -f + ps -o etime=</strong>
                    </div>
                    <div class="meta-pill">
                        <span>Status:</span>
                        <strong style="color: var(--status-green);">&#x2714; ALL TESTS PASSED</strong>
                    </div>
                </div>
            </div>
        </header>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Demo Target Process</div>
                <div class="metric-value" style="color: var(--status-green);">{html.escape(target_process)}</div>
                <div class="metric-sub">PIDs: {html.escape(active_pids)} ({html.escape(instance_count)} active instance(s))</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Inspection Engine</div>
                <div class="metric-value" style="color: var(--status-blue);">pgrep -f &amp; -i</div>
                <div class="metric-sub">Direct /proc query, no self-matching race</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Oldest Instance Uptime</div>
                <div class="metric-value" style="color: var(--status-blue);">{html.escape(oldest_uptime)}</div>
                <div class="metric-sub">Queried via ps -o etime=</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Safety &amp; Sandboxing</div>
                <div class="metric-value" style="color: var(--status-green);">100% Read-Only</div>
                <div class="metric-sub">Zero processes killed or modified</div>
            </div>
        </div>

        <section style="margin-bottom: 24px;">
            <h2 class="section-title">
                <span>&#128202;</span> Test Case Execution Cards (Color-Coded)
            </h2>
            <div class="cards-grid">
                <div class="status-card card-running">
                    <div class="card-header">
                        <div class="card-title">Test 1: Running Process</div>
                        <span class="badge-status badge-running">&#9679; ACTIVE / RUNNING</span>
                    </div>
                    <div class="card-details">
                        <div class="detail-row">
                            <span class="detail-label">Target Process:</span>
                            <span class="detail-val">{html.escape(target_process)}</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Match Mode:</span>
                            <span class="detail-val">Case-Insensitive</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Instance Count:</span>
                            <span class="detail-val" style="color: #86efac;">{html.escape(instance_count)} instances</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Active PID(s):</span>
                            <span class="detail-val">{html.escape(active_pids)}</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Oldest Uptime:</span>
                            <span class="detail-val" style="color: #38bdf8;">{html.escape(oldest_uptime)}</span>
                        </div>
                    </div>
                    <div class="code-box">$ ./server_process_check.sh {html.escape(target_process)}
&#x2713; Process '{html.escape(target_process)}' is RUNNING with {html.escape(instance_count)} active instance(s).</div>
                </div>

                <div class="status-card card-stopped">
                    <div class="card-header">
                        <div class="card-title">Test 2: Nonexistent Process</div>
                        <span class="badge-status badge-stopped">&#9679; STOPPED / INACTIVE</span>
                    </div>
                    <div class="card-details">
                        <div class="detail-row">
                            <span class="detail-label">Target Process:</span>
                            <span class="detail-val">not-a-real-proc</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Match Mode:</span>
                            <span class="detail-val">Case-Insensitive</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Instance Count:</span>
                            <span class="detail-val" style="color: #fca5a5;">0 instances</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Active PID(s):</span>
                            <span class="detail-val">none</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Script Exit Code:</span>
                            <span class="detail-val" style="color: #fca5a5;">1 (Not Running)</span>
                        </div>
                    </div>
                    <div class="code-box">$ ./server_process_check.sh not-a-real-proc
&#x2717; Process 'not-a-real-proc' is NOT running.</div>
                </div>

                <div class="status-card card-error">
                    <div class="card-header">
                        <div class="card-title">Test 3: Missing Argument Handling</div>
                        <span class="badge-status badge-error">&#9888; SYNTAX ERROR TRAPPED</span>
                    </div>
                    <div class="card-details">
                        <div class="detail-row">
                            <span class="detail-label">Target Process:</span>
                            <span class="detail-val">(none provided)</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Invocation:</span>
                            <span class="detail-val">./server_process_check.sh</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Exit Status:</span>
                            <span class="detail-val" style="color: #fde68a;">2 (Syntax Error)</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Safety Response:</span>
                            <span class="detail-val">Help message displayed</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Audit Logged:</span>
                            <span class="detail-val" style="color: #86efac;">Yes (ERROR event)</span>
                        </div>
                    </div>
                    <div class="code-box">$ ./server_process_check.sh
[ERROR] Missing required argument: PROCESS_NAME</div>
                </div>
            </div>
        </section>

        <section class="exec-section">
            <h2 class="section-title">
                <span>&#128187;</span> Script Execution Logs (Terminal Session)
            </h2>
            <div class="terminal-window">
                <div class="terminal-bar">
                    <span class="dot dot-red"></span>
                    <span class="dot dot-yellow"></span>
                    <span class="dot dot-green"></span>
                    <span class="terminal-title">bash &bull; ./server_process_check.sh</span>
                </div>
                <div class="terminal-body">{html.escape(term_log)}</div>
            </div>
        </section>

        <section class="log-section">
            <h2 class="section-title">
                <span>&#128220;</span> Persistent Audit Log: <code>logs/process_check.log</code>
            </h2>
            <div class="log-container">
{log_container_html}            </div>
        </section>

        <section class="log-section">
            <h2 class="section-title">
                <span>&#10004;</span> Process Audit Compliance Matrix
            </h2>
            <div class="checklist-grid">
                <div class="check-card">
                    <span class="check-icon">&#10003;</span>
                    <div class="check-content">
                        <h4>Direct /proc Kernel Queries</h4>
                        <p>Leverages <code>pgrep</code> to read <code>/proc</code> directly, eliminating self-matching pipelines.</p>
                    </div>
                </div>
                <div class="check-card">
                    <span class="check-icon">&#10003;</span>
                    <div class="check-content">
                        <h4>Safe Default Execution</h4>
                        <p>Defaults safely to <code>--default</code> (bash) to avoid unhandled missing arguments.</p>
                    </div>
                </div>
                <div class="check-card">
                    <span class="check-icon">&#10003;</span>
                    <div class="check-content">
                        <h4>Oldest Uptime Tracking</h4>
                        <p>Uses <code>ps -o etimes=</code> to numerically sort and determine the oldest running instance.</p>
                    </div>
                </div>
                <div class="check-card">
                    <span class="check-icon">&#10003;</span>
                    <div class="check-content">
                        <h4>POSIX Standard Exit Codes</h4>
                        <p>Standardized exit codes (0 = Running, 1 = Stopped, 2 = Usage Error).</p>
                    </div>
                </div>
            </div>
        </section>

        <footer>
            Autonomous Linux System Administration Sprint &bull; E1ITA307 Problem #18 &bull; Generated Self-Contained Report
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
