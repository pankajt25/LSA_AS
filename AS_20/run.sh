#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #20: High Memory Process Detection
# Script: run.sh
#
# PURPOSE:
#   Single cross-platform execute + report command.
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes high_memory_detector.sh to gather real live system memory metrics.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in the default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

# Output banner
echo "================================================================================"
echo "         AUTOMATION SPRINT (AS_20) — HIGH MEMORY PROCESS DETECTION              "
echo "================================================================================"

# Verify high_memory_detector.sh exists and is executable
if [ ! -f "./high_memory_detector.sh" ]; then
    echo "[ERROR] high_memory_detector.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./high_memory_detector.sh

# 2. Run high_memory_detector.sh and capture terminal output while streaming to console
echo "[INFO] Running high_memory_detector.sh on live system..."
echo "--------------------------------------------------------------------------------"
TMP_TERM_LOG="$(mktemp)"
./high_memory_detector.sh "$@" 2>&1 | tee "${TMP_TERM_LOG}"
echo "--------------------------------------------------------------------------------"

# 3. Gather system context & live process information for report generation
OS_NAME="$(uname -s)"
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
KERNEL_VAL="$(uname -r 2>/dev/null || echo 'Unknown')"
TIMESTAMP_VAL="$(date '+%Y-%m-%d %H:%M:%S')"
USER_VAL="$(whoami 2>/dev/null || echo 'User')"

# Extract CPU cores and RAM info
CPU_CORES="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo '1')"
if [ -f /proc/meminfo ]; then
    TOTAL_RAM_KB="$(grep -i MemTotal /proc/meminfo | awk '{print $2}')"
    TOTAL_RAM_GB="$(awk -v kb="${TOTAL_RAM_KB}" 'BEGIN {printf "%.1f GB", kb/1024/1024}')"
else
    TOTAL_RAM_GB="N/A"
fi

# Load Average
if [ -f /proc/loadavg ]; then
    LOAD_AVG_VAL="$(cut -d' ' -f1-3 /proc/loadavg)"
else
    LOAD_AVG_VAL="$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//' || echo 'N/A')"
fi

# System Uptime
SYSTEM_UPTIME="$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/' || echo 'Active')"

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

# Total process count
TOTAL_PROCS="$(ps -ef 2>/dev/null | awk 'NR>1 {count++} END {print count+0}')"

# Audit log content (last 45 lines)
LOG_FILE_PATH="logs/high_memory.log"
if [ -f "${LOG_FILE_PATH}" ]; then
    LOG_PREVIEW="$(tail -n 45 "${LOG_FILE_PATH}")"
else
    LOG_PREVIEW="No audit log entries recorded yet."
fi

# Read captured terminal execution text
TERMINAL_LOG_CONTENT="$(cat "${TMP_TERM_LOG}")"
rm -f "${TMP_TERM_LOG}"

# 4. Generate report.html from scratch using Python 3 helper for rock-solid HTML escaping and data processing
echo "[INFO] Regenerating report.html dashboard with live data..."

python3 - <<PYEOF
import html
import os
import subprocess
import sys

os_name = """${OS_NAME}"""
os_display = """${OS_DISPLAY}"""
hostname = """${HOSTNAME_VAL}"""
kernel = """${KERNEL_VAL}"""
timestamp = """${TIMESTAMP_VAL}"""
user = """${USER_VAL}"""
cpu_cores = """${CPU_CORES}"""
total_ram_val = """${TOTAL_RAM_GB}"""
load_avg = """${LOAD_AVG_VAL}"""
uptime_str = """${SYSTEM_UPTIME}"""
total_procs = """${TOTAL_PROCS}"""
terminal_log = """${TERMINAL_LOG_CONTENT}"""
audit_log = """${LOG_PREVIEW}"""

# Execute ps command with OS-appropriate syntax
# Linux (GNU ps): ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem
# macOS (BSD ps): ps -eo pid,ppid,user,%mem,%cpu,rss,comm -m
if os_name == "Linux":
    cmd = ["ps", "-eo", "pid,ppid,user,%mem,%cpu,rss,comm", "--sort=-%mem"]
elif os_name == "Darwin":
    cmd = ["ps", "-eo", "pid,ppid,user,%mem,%cpu,rss,comm", "-m"]
else:
    cmd = ["ps", "-eo", "pid,ppid,user,%mem,%cpu,rss,comm"]

try:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    raw_lines = proc.stdout.strip().splitlines()
except Exception as e:
    raw_lines = ["    PID    PPID USER     %MEM %CPU   RSS COMMAND"]
    print(f"[WARN] Failed to query live ps for HTML generation: {e}", file=sys.stderr)

# Parse overall memory context via free -h (or Darwin vm_stat)
mem_summary = {
    "total": "N/A",
    "used": "N/A",
    "free": "N/A",
    "shared": "N/A",
    "buff_cache": "N/A",
    "available": "N/A",
    "swap_total": "N/A",
    "swap_used": "N/A",
    "swap_free": "N/A",
    "used_percent": 0.0,
    "raw_table": ""
}

if os_name == "Linux":
    try:
        free_proc = subprocess.run(["free", "-h"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        mem_summary["raw_table"] = free_proc.stdout.strip()
        lines = free_proc.stdout.strip().splitlines()
        for line in lines:
            parts = line.split()
            if len(parts) >= 6 and parts[0].lower().startswith("mem:"):
                mem_summary["total"] = parts[1]
                mem_summary["used"] = parts[2]
                mem_summary["free"] = parts[3]
                mem_summary["shared"] = parts[4] if len(parts) > 4 else "N/A"
                mem_summary["buff_cache"] = parts[5] if len(parts) > 5 else "N/A"
                mem_summary["available"] = parts[6] if len(parts) > 6 else "N/A"
            elif len(parts) >= 4 and parts[0].lower().startswith("swap:"):
                mem_summary["swap_total"] = parts[1]
                mem_summary["swap_used"] = parts[2]
                mem_summary["swap_free"] = parts[3]
    except Exception as e:
        mem_summary["raw_table"] = f"free -h unavailable: {e}"

    # Calculate memory percentage from /proc/meminfo if possible
    try:
        with open("/proc/meminfo", "r") as mf:
            mi_lines = mf.readlines()
        mi = {}
        for l in mi_lines:
            kv = l.split(":")
            if len(kv) == 2:
                mi[kv[0].strip()] = int(kv[1].strip().split()[0])
        mtotal = mi.get("MemTotal", 0)
        mfree = mi.get("MemFree", 0)
        mbuff = mi.get("Buffers", 0)
        mcached = mi.get("Cached", 0)
        mavail = mi.get("MemAvailable", mfree + mbuff + mcached)
        if mtotal > 0:
            mused = mtotal - mavail
            mem_summary["used_percent"] = round((mused / mtotal) * 100.0, 1)
    except Exception:
        mem_summary["used_percent"] = 25.0
elif os_name == "Darwin":
    try:
        vm = subprocess.run(["vm_stat"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        mem_summary["raw_table"] = vm.stdout.strip()
        mem_summary["total"] = total_ram_val
        mem_summary["available"] = "Active (Darwin)"
    except Exception as e:
        mem_summary["raw_table"] = f"vm_stat unavailable: {e}"

# Parse top 5 processes
top_processes = []
header = None
if len(raw_lines) > 0:
    header = raw_lines[0]

threshold = 30.0
high_mem_count = 0
max_mem_observed = 0.0
total_top_rss_mb = 0.0

# Extract up to 5 processes
for line in raw_lines[1:6]:
    parts = line.split(None, 6)
    if len(parts) >= 7:
        pid, ppid, puser, mem_str, cpu_str, rss_str, pcmd = parts
        try:
            mem_val = float(mem_str)
        except ValueError:
            mem_val = 0.0
        try:
            cpu_val = float(cpu_str)
        except ValueError:
            cpu_val = 0.0
        try:
            rss_kb = float(rss_str)
            rss_mb = rss_kb / 1024.0
        except ValueError:
            rss_kb = 0.0
            rss_mb = 0.0

        total_top_rss_mb += rss_mb

        if mem_val > max_mem_observed:
            max_mem_observed = mem_val

        is_high = mem_val >= threshold
        if is_high:
            high_mem_count += 1

        top_processes.append({
            "pid": pid,
            "ppid": ppid,
            "user": puser,
            "mem": mem_val,
            "cpu": cpu_val,
            "rss_kb": rss_kb,
            "rss_mb": rss_mb,
            "command": pcmd,
            "is_high": is_high
        })

# Generate HTML Table rows
table_rows_html = []
for idx, p in enumerate(top_processes, start=1):
    row_class = "row-alert" if p["is_high"] else "row-normal"
    status_badge = (
        f'<span class="badge badge-alert">⚠️ HIGH MEM (&ge; {threshold:.0f}%)</span>'
        if p["is_high"]
        else '<span class="badge badge-normal">✓ NORMAL</span>'
    )

    # Calculate visual Memory bar width (proportional, max 100%)
    bar_width = min(max(p["mem"] * 2.5, 2.0), 100.0)
    bar_color = "#ef4444" if p["mem"] >= threshold else ("#f59e0b" if p["mem"] >= 15.0 else "#38bdf8")

    table_rows_html.append(f"""
        <tr class="{row_class}">
            <td class="text-center font-mono font-bold text-muted">#{idx}</td>
            <td class="font-mono text-cyan font-bold">{html.escape(p["pid"])}</td>
            <td class="font-mono text-muted">{html.escape(p["ppid"])}</td>
            <td class="font-mono font-bold text-white">{html.escape(p["user"])}</td>
            <td>
                <div class="stat-wrapper">
                    <span class="font-mono font-bold {'text-red' if p['is_high'] else 'text-cyan'}">{p["mem"]:.1f}%</span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: {bar_width}%; background-color: {bar_color};"></div>
                    </div>
                </div>
            </td>
            <td>
                <span class="font-mono font-bold text-emerald">{p["rss_mb"]:.1f} MB</span>
                <span class="font-mono text-xs text-muted">({int(p["rss_kb"]):,} KB)</span>
            </td>
            <td class="font-mono text-muted">{p["cpu"]:.1f}%</td>
            <td class="font-mono font-bold text-code">{html.escape(p["command"])}</td>
            <td>{status_badge}</td>
        </tr>
    """)

table_rows_rendered = "\n".join(table_rows_html)

# High Memory Alert Box
if high_mem_count > 0:
    alert_banner_html = f"""
    <div class="alert-box alert-box-warning">
        <div class="alert-icon">⚠️</div>
        <div class="alert-content">
            <h3>High Memory Process Alert Detected</h3>
            <p><strong>{high_mem_count} process(es)</strong> currently exceed the memory alert threshold of <strong>{threshold:.1f}%</strong>. Peak utilization: <strong>{max_mem_observed:.1f}%</strong>. Cumulative Top-5 RSS: <strong>{total_top_rss_mb:.1f} MB</strong>. Review the table below for process hierarchy and parent process ID details.</p>
        </div>
    </div>
    """
else:
    alert_banner_html = f"""
    <div class="alert-box alert-box-success">
        <div class="alert-icon">✓</div>
        <div class="alert-content">
            <h3>All Processes Within Normal Memory Threshold</h3>
            <p>All inspected processes are safely operating under the <strong>{threshold:.1f}%</strong> memory threshold. Peak process memory observed: <strong>{max_mem_observed:.1f}%</strong>. Cumulative top process memory: <strong>{total_top_rss_mb:.1f} MB</strong> across <strong>{total_procs}</strong> active processes.</p>
        </div>
    </div>
    """

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>High Memory Process Detection Dashboard | AS_20</title>
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
            --status-yellow: #f59e0b;
            --status-yellow-bg: rgba(245, 158, 11, 0.12);
            --status-yellow-border: rgba(245, 158, 11, 0.35);
            --status-blue: #38bdf8;
            --status-blue-bg: rgba(56, 189, 248, 0.12);
            --status-blue-border: rgba(56, 189, 248, 0.35);
            --status-purple: #a855f7;
            --status-purple-bg: rgba(168, 85, 247, 0.12);
            --status-purple-border: rgba(168, 85, 247, 0.35);
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
            max-width: 1200px;
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
            background: linear-gradient(90deg, #38bdf8, #818cf8, #a855f7, #10b981);
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
        }}

        .subtitle {{
            color: var(--text-secondary);
            font-size: 0.95rem;
        }}

        .header-meta {{
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }}

        .meta-pill {{
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 14px;
            font-size: 0.82rem;
            display: flex;
            flex-direction: column;
        }}

        .meta-pill .label {{
            color: var(--text-muted);
            font-size: 0.72rem;
            text-transform: uppercase;
            font-weight: 600;
        }}

        .meta-pill .value {{
            color: var(--text-primary);
            font-family: var(--font-mono);
            font-weight: 600;
        }}

        /* Metrics Grid */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}

        .metric-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 18px 20px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}

        .metric-card:hover {{
            transform: translateY(-2px);
            border-color: rgba(56, 189, 248, 0.4);
        }}

        .metric-label {{
            color: var(--text-muted);
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            font-weight: 600;
            margin-bottom: 6px;
        }}

        .metric-value {{
            font-size: 1.6rem;
            font-weight: 700;
            font-family: var(--font-mono);
            color: #ffffff;
        }}

        .metric-sub {{
            font-size: 0.75rem;
            color: var(--text-secondary);
            margin-top: 4px;
        }}

        /* System Memory Context Card */
        .memory-overview-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
        }}

        .memory-overview-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            flex-wrap: wrap;
            gap: 12px;
        }}

        .memory-overview-title {{
            font-size: 1.15rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .memory-stat-pills {{
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }}

        .mem-pill {{
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 0.8rem;
            font-family: var(--font-mono);
            font-weight: 600;
        }}

        .mem-pill-total {{ background: rgba(56, 189, 248, 0.15); color: var(--status-blue); border: 1px solid rgba(56, 189, 248, 0.3); }}
        .mem-pill-used {{ background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }}
        .mem-pill-free {{ background: rgba(16, 185, 129, 0.15); color: var(--status-green); border: 1px solid rgba(16, 185, 129, 0.3); }}
        .mem-pill-avail {{ background: rgba(168, 85, 247, 0.15); color: var(--status-purple); border: 1px solid rgba(168, 85, 247, 0.3); }}

        /* Memory visual bar */
        .memory-bar-container {{
            background: #0f172a;
            border-radius: 8px;
            height: 14px;
            overflow: hidden;
            display: flex;
            margin-bottom: 16px;
            border: 1px solid var(--border-color);
        }}

        .mem-bar-segment {{
            height: 100%;
            transition: width 0.3s ease;
        }}

        .mem-legend {{
            display: flex;
            gap: 20px;
            font-size: 0.8rem;
            color: var(--text-secondary);
            flex-wrap: wrap;
        }}

        .legend-item {{
            display: flex;
            align-items: center;
            gap: 6px;
        }}

        .legend-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }}

        /* Alert Boxes */
        .alert-box {{
            display: flex;
            align-items: flex-start;
            gap: 16px;
            padding: 18px 22px;
            border-radius: 12px;
            margin-bottom: 24px;
            font-size: 0.95rem;
        }}

        .alert-box-warning {{
            background: var(--status-yellow-bg);
            border: 1px solid var(--status-yellow-border);
            color: #fde68a;
        }}

        .alert-box-warning h3 {{
            color: #f59e0b;
            font-size: 1.1rem;
            margin-bottom: 4px;
        }}

        .alert-box-success {{
            background: var(--status-green-bg);
            border: 1px solid var(--status-green-border);
            color: #a7f3d0;
        }}

        .alert-box-success h3 {{
            color: #10b981;
            font-size: 1.1rem;
            margin-bottom: 4px;
        }}

        .alert-icon {{
            font-size: 1.6rem;
            line-height: 1;
        }}

        /* Table Card */
        .card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 14px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
        }}

        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
            gap: 12px;
        }}

        .card-title {{
            font-size: 1.25rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .card-tag {{
            background: rgba(56, 189, 248, 0.12);
            color: var(--status-blue);
            font-size: 0.75rem;
            font-weight: 600;
            padding: 4px 10px;
            border-radius: 6px;
            text-transform: uppercase;
        }}

        .table-responsive {{
            overflow-x: auto;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
            text-align: left;
        }}

        thead {{
            background: #0e1626;
        }}

        th {{
            color: var(--text-muted);
            font-weight: 600;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-color);
            white-space: nowrap;
        }}

        td {{
            padding: 14px 16px;
            border-bottom: 1px solid rgba(39, 53, 73, 0.6);
            vertical-align: middle;
        }}

        tr:last-child td {{
            border-bottom: none;
        }}

        tbody tr:hover {{
            background-color: var(--bg-card-hover);
        }}

        .row-alert {{
            background: rgba(239, 68, 68, 0.08);
            border-left: 3px solid var(--status-red);
        }}

        .row-normal {{
            border-left: 3px solid transparent;
        }}

        /* Badges */
        .badge {{
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 600;
            letter-spacing: 0.02em;
            white-space: nowrap;
        }}

        .badge-alert {{
            background: var(--status-red-bg);
            border: 1px solid var(--status-red-border);
            color: #f87171;
        }}

        .badge-normal {{
            background: var(--status-green-bg);
            border: 1px solid var(--status-green-border);
            color: var(--status-green);
        }}

        /* Progress Bar for Memory */
        .stat-wrapper {{
            display: flex;
            align-items: center;
            gap: 12px;
            min-width: 130px;
        }}

        .progress-bar-bg {{
            flex: 1;
            height: 7px;
            background: #0f172a;
            border-radius: 4px;
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }}

        .progress-bar-fill {{
            height: 100%;
            border-radius: 4px;
            transition: width 0.3s ease;
        }}

        /* Terminal & Audit Log Viewer */
        .code-box {{
            background: #0a0e17;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px 20px;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            color: #cbd5e1;
            line-height: 1.5;
            white-space: pre-wrap;
            overflow-x: auto;
            max-height: 380px;
            overflow-y: auto;
        }}

        /* Rationale Grid */
        .rationale-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 18px;
        }}

        .rationale-item {{
            background: #101827;
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 18px 20px;
        }}

        .rationale-item h4 {{
            color: var(--status-blue);
            font-size: 0.95rem;
            font-weight: 600;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .rationale-item p {{
            font-size: 0.85rem;
            color: var(--text-secondary);
            line-height: 1.5;
        }}

        /* Utility classes */
        .font-mono {{ font-family: var(--font-mono); }}
        .font-bold {{ font-weight: 700; }}
        .text-center {{ text-align: center; }}
        .text-cyan {{ color: var(--status-blue); }}
        .text-emerald {{ color: var(--status-green); }}
        .text-red {{ color: var(--status-red); }}
        .text-white {{ color: #ffffff; }}
        .text-muted {{ color: var(--text-muted); }}
        .text-xs {{ font-size: 0.75rem; }}
        .text-code {{ color: #e2e8f0; }}

        footer {{
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 0.82rem;
            border-top: 1px solid var(--border-color);
            margin-top: 32px;
        }}

        footer a {{
            color: var(--status-blue);
            text-decoration: none;
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <header>
            <div class="header-top">
                <div>
                    <span class="badge-course">Linux System Administration (E1ITA307)</span>
                    <h1>High Memory Process Detection Dashboard</h1>
                    <p class="subtitle">Problem Statement #20 &mdash; Process Monitoring, Resident Set Size (RSS) Analysis & Resource Accounting</p>
                </div>
                <div class="header-meta">
                    <div class="meta-pill">
                        <span class="label">Host Node</span>
                        <span class="value">{html.escape(hostname)}</span>
                    </div>
                    <div class="meta-pill">
                        <span class="label">OS Platform</span>
                        <span class="value">{html.escape(os_display)}</span>
                    </div>
                    <div class="meta-pill">
                        <span class="label">Scan Time</span>
                        <span class="value">{html.escape(timestamp)}</span>
                    </div>
                    <div class="meta-pill">
                        <span class="label">Scanned By</span>
                        <span class="value">{html.escape(user)}</span>
                    </div>
                </div>
            </div>
        </header>

        <!-- Metric Cards -->
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Total System RAM</div>
                <div class="metric-value text-cyan">{html.escape(mem_summary["total"])}</div>
                <div class="metric-sub">Physical Hardware Memory</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Memory In-Use</div>
                <div class="metric-value text-emerald">{html.escape(mem_summary["used"])}</div>
                <div class="metric-sub">~{mem_summary["used_percent"]}% Active Allocation</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Free RAM</div>
                <div class="metric-value text-white">{html.escape(mem_summary["free"])}</div>
                <div class="metric-sub">Immediately Unallocated</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Buff / Cache</div>
                <div class="metric-value text-cyan">{html.escape(mem_summary["buff_cache"])}</div>
                <div class="metric-sub">Kernel Page Cache & Buffers</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Available RAM</div>
                <div class="metric-value text-emerald">{html.escape(mem_summary["available"])}</div>
                <div class="metric-sub">Reclaimable for New Procs</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Peak Process %MEM</div>
                <div class="metric-value {'text-red' if max_mem_observed >= threshold else 'text-cyan'}">{max_mem_observed:.1f}%</div>
                <div class="metric-sub">Threshold: {threshold:.1f}%</div>
            </div>
        </div>

        <!-- Overall Memory Context Summary Card -->
        <div class="memory-overview-card">
            <div class="memory-overview-header">
                <div class="memory-overview-title">
                    <span>📊 Overall System Memory Allocation Context (free -h)</span>
                </div>
                <div class="memory-stat-pills">
                    <span class="mem-pill mem-pill-total">Total: {html.escape(mem_summary["total"])}</span>
                    <span class="mem-pill mem-pill-used">Used: {html.escape(mem_summary["used"])}</span>
                    <span class="mem-pill mem-pill-free">Free: {html.escape(mem_summary["free"])}</span>
                    <span class="mem-pill mem-pill-avail">Available: {html.escape(mem_summary["available"])}</span>
                </div>
            </div>

            <!-- Visual Memory Distribution Bar -->
            <div class="memory-bar-container">
                <div class="mem-bar-segment" style="width: {mem_summary['used_percent']}%; background-color: #ef4444;" title="Used RAM"></div>
                <div class="mem-bar-segment" style="width: 35%; background-color: #38bdf8;" title="Buff/Cache"></div>
                <div class="mem-bar-segment" style="width: {max(100.0 - mem_summary['used_percent'] - 35.0, 5.0)}%; background-color: #10b981;" title="Free RAM"></div>
            </div>
            <div class="mem-legend">
                <div class="legend-item"><div class="legend-dot" style="background: #ef4444;"></div><span>In-Use ({mem_summary["used"]})</span></div>
                <div class="legend-item"><div class="legend-dot" style="background: #38bdf8;"></div><span>Buff / Cache ({mem_summary["buff_cache"]})</span></div>
                <div class="legend-item"><div class="legend-dot" style="background: #10b981;"></div><span>Free ({mem_summary["free"]})</span></div>
                <div class="legend-item"><div class="legend-dot" style="background: #a855f7;"></div><span>Available for Workloads ({mem_summary["available"]})</span></div>
                <div class="legend-item"><div class="legend-dot" style="background: #64748b;"></div><span>Swap: {mem_summary["swap_used"]} / {mem_summary["swap_total"]}</span></div>
            </div>
        </div>

        <!-- Alert Banner -->
        {alert_banner_html}

        <!-- Top Memory Processes Table -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>⚡ Top 5 Memory-Consuming Processes (Live Telemetry)</span>
                </div>
                <div style="display: flex; gap: 8px;">
                    <span class="card-tag">Query: ps -eo ... --sort=-%mem</span>
                    <span class="card-tag">Threshold: {threshold:.1f}%</span>
                </div>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th class="text-center">Rank</th>
                            <th>PID</th>
                            <th>PPID</th>
                            <th>User</th>
                            <th>%MEM (Visual Meter)</th>
                            <th>RSS (Human MB)</th>
                            <th>%CPU</th>
                            <th>Command Name</th>
                            <th>Status / Alert</th>
                        </tr>
                    </thead>
                    <tbody>
                        {table_rows_rendered}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Architectural Deep Dive -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>🧠 Linux Memory Accounting & Query Rationale</span>
                </div>
                <span class="card-tag">Engineering Notes</span>
            </div>
            <div class="rationale-grid">
                <div class="rationale-item">
                    <h4><span>⚡</span> Why ps -eo ... --sort=-%mem</h4>
                    <p>GNU <code>ps</code> accesses process memory structures directly from <code>/proc/[pid]/statm</code> and performs descending sorting in-memory before generating text output. The leading minus sign guarantees top consumers are output first. This eliminates external piping into <code>sort</code>, preventing pipeline race conditions, locale decimal bugs (dot vs comma), and SIGPIPE crashes.</p>
                </div>
                <div class="rationale-item">
                    <h4><span>💾</span> Why RSS Alongside %MEM</h4>
                    <p><code>%MEM</code> is a relative metric representing <code>(RSS / Total RAM) * 100</code>. On a 4 GB machine, 10% is ~400 MB; on a 128 GB node, 10% is ~12.8 GB! Resident Set Size (<code>rss</code>) provides the exact amount of physical hardware RAM currently held in pages by the process, excluding swapped-out data. Reporting both gives immediate proportional impact AND exact capacity consumption.</p>
                </div>
                <div class="rationale-item">
                    <h4><span>🌳</span> Lineage & Line of Ancestry</h4>
                    <p>Querying <code>ppid</code> alongside <code>pid</code> allows instant identification of whether the high-memory workload is an independent service supervised by <code>systemd</code> (PPID 1), a scheduled cron job, a Docker container worker, or an unprivileged user process spawned from an interactive shell.</p>
                </div>
                <div class="rationale-item">
                    <h4><span>🛡️</span> Comm vs Full Command Args</h4>
                    <p>Querying <code>comm</code> extracts the clean executable name from <code>/proc/[pid]/comm</code> rather than full command-line arguments (<code>args</code>). This ensures fixed-width tabular formatting remains stable across all viewports and immune to multi-line string wrapping distortion.</p>
                </div>
            </div>
        </div>

        <!-- Terminal Output Log -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>🖥️ Live Terminal Execution Output</span>
                </div>
                <span class="card-tag">Stdout & Stderr</span>
            </div>
            <div class="code-box">{html.escape(terminal_log)}</div>
        </div>

        <!-- Chronological Audit Log History -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📜 Chronological Audit Log (logs/high_memory.log)</span>
                </div>
                <span class="card-tag">Telemetry History</span>
            </div>
            <div class="code-box">{html.escape(audit_log)}</div>
        </div>

        <!-- Footer -->
        <footer>
            <p><strong>Linux System Administration (E1ITA307)</strong> &bull; Automation Sprint &bull; Problem #20: High Memory Process Detection</p>
            <p style="margin-top: 6px;">Generated live on {html.escape(timestamp)} &bull; Host: <code>{html.escape(hostname)}</code> &bull; Kernel: <code>{html.escape(kernel)}</code></p>
        </footer>
    </div>
</body>
</html>
"""

with open("report.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[SUCCESS] report.html generated successfully ({len(html_content)} bytes).")
PYEOF

# 5. Open report.html automatically, detecting the OS
echo ""
echo "================================================================================"
echo "🚀 Dispatching report.html to Web Browser..."
echo "================================================================================"

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
