#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_44 (Resource Threshold Monitor)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_44: Resource Threshold Monitor"
echo "======================================================================"

# Execute monitoring script
bash ./resource_monitor.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "overall_status": "OK",
    "cpu": {"usage_pct": 0, "status": "OK", "cores": 4, "load_1m": 0, "load_5m": 0, "load_15m": 0, "warn_threshold": 70, "crit_threshold": 85},
    "memory": {"usage_pct": 0, "status": "OK", "total_mb": 0, "used_mb": 0, "available_mb": 0, "warn_threshold": 75, "crit_threshold": 90},
    "swap": {"usage_pct": 0, "status": "OK", "total_mb": 0, "used_mb": 0, "warn_threshold": 50, "crit_threshold": 75},
    "top_cpu_processes": [],
    "top_mem_processes": [],
    "log_file": ""
}

if os.path.exists(json_path):
    try:
        with open(json_path) as f:
            telemetry = json.load(f)
    except Exception as e:
        print(f"Warning: could not read {json_path}: {e}")

hostname = socket.gethostname()
os_name = platform.platform()

def status_badge(status):
    if status == "CRITICAL":
        return '<span class="badge badge-danger">CRITICAL</span>'
    elif status == "WARNING":
        return '<span class="badge badge-warning">WARNING</span>'
    return '<span class="badge badge-success">HEALTHY</span>'

overall_badge = status_badge(telemetry.get("overall_status", "OK"))

cpu_data = telemetry.get("cpu", {})
mem_data = telemetry.get("memory", {})
swap_data = telemetry.get("swap", {})

cpu_usage = cpu_data.get("usage_pct", 0)
cpu_status = cpu_data.get("status", "OK")
cpu_cores = cpu_data.get("cores", 4)
cpu_load1 = cpu_data.get("load_1m", 0)
cpu_warn = cpu_data.get("warn_threshold", 70)
cpu_badge = status_badge(cpu_status)
cpu_bar_color = "#f85149" if cpu_status == "CRITICAL" else ("#d29922" if cpu_status == "WARNING" else "#58a6ff")

mem_usage = mem_data.get("usage_pct", 0)
mem_status = mem_data.get("status", "OK")
mem_used = mem_data.get("used_mb", 0)
mem_total = mem_data.get("total_mb", 0)
mem_warn = mem_data.get("warn_threshold", 75)
mem_badge = status_badge(mem_status)
mem_bar_color = "#f85149" if mem_status == "CRITICAL" else ("#d29922" if mem_status == "WARNING" else "#bc8cff")

swap_usage = swap_data.get("usage_pct", 0)
swap_status = swap_data.get("status", "OK")
swap_used = swap_data.get("used_mb", 0)
swap_total = swap_data.get("total_mb", 0)
swap_warn = swap_data.get("warn_threshold", 50)
swap_badge = status_badge(swap_status)
swap_bar_color = "#f85149" if swap_status == "CRITICAL" else ("#d29922" if swap_status == "WARNING" else "#3fb950")

# Build Top CPU rows
cpu_rows = ""
for p in telemetry.get("top_cpu_processes", []):
    cpu_rows += f"""
    <tr>
        <td><code>{p.get('pid')}</code></td>
        <td>{p.get('user')}</td>
        <td style="font-weight: 600; color: #58a6ff;">{p.get('cpu_pct')}%</td>
        <td>{p.get('mem_pct')}%</td>
        <td><strong style="color: #f0f6fc;">{p.get('comm')}</strong></td>
        <td style="color: #8b949e; font-size: 11px; font-family: monospace;">{p.get('args')}</td>
    </tr>
    """

# Build Top Memory rows
mem_rows = ""
for p in telemetry.get("top_mem_processes", []):
    mem_rows += f"""
    <tr>
        <td><code>{p.get('pid')}</code></td>
        <td>{p.get('user')}</td>
        <td style="font-weight: 600; color: #bc8cff;">{p.get('mem_pct')}%</td>
        <td>{p.get('rss_mb')} MB</td>
        <td>{p.get('cpu_pct')}%</td>
        <td><strong style="color: #f0f6fc;">{p.get('comm')}</strong></td>
        <td style="color: #8b949e; font-size: 11px; font-family: monospace;">{p.get('args')}</td>
    </tr>
    """

# Read log
log_content = ""
log_file = telemetry.get("log_file", "")
if log_file and os.path.exists(log_file):
    try:
        with open(log_file, "r") as lf:
            lines = lf.readlines()[-30:]
            log_content = "".join(lines)
    except Exception:
        log_content = "Log file could not be read."

html_code = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_44 - Resource Threshold Monitor</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --border-color: #30363d;
            --text-primary: #c9d1d9;
            --text-muted: #8b949e;
            --accent-green: #238636;
            --accent-red: #da3633;
            --accent-orange: #d29922;
            --accent-blue: #1f6feb;
            --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        }}
        body {{
            background-color: var(--bg-primary);
            color: var(--text-primary);
            font-family: var(--font-family);
            margin: 0;
            padding: 24px;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px 24px;
            margin-bottom: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }}
        .header h1 {{
            margin: 0 0 6px 0;
            font-size: 24px;
            color: #58a6ff;
        }}
        .header .meta {{
            font-size: 13px;
            color: var(--text-muted);
        }}
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }}
        .badge-success {{ background-color: rgba(46, 160, 67, 0.2); color: #3fb950; border: 1px solid rgba(46, 160, 67, 0.4); }}
        .badge-warning {{ background-color: rgba(210, 153, 34, 0.2); color: #d29922; border: 1px solid rgba(210, 153, 34, 0.4); }}
        .badge-danger {{ background-color: rgba(248, 81, 73, 0.2); color: #f85149; border: 1px solid rgba(248, 81, 73, 0.4); }}
        
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .card {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
        }}
        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }}
        .card-label {{
            font-size: 13px;
            font-weight: 600;
            color: var(--text-primary);
        }}
        .card-val {{
            font-size: 32px;
            font-weight: bold;
            color: #f0f6fc;
            margin-bottom: 10px;
        }}
        .meter {{
            height: 8px;
            background-color: #21262d;
            border-radius: 4px;
            overflow: hidden;
            margin-bottom: 10px;
        }}
        .meter-fill {{
            height: 100%;
            border-radius: 4px;
            transition: width 0.3s ease;
        }}
        .card-sub {{
            font-size: 12px;
            color: var(--text-muted);
            display: flex;
            justify-content: space-between;
        }}

        .section {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 24px;
        }}
        .section-title {{
            font-size: 16px;
            font-weight: 600;
            margin-top: 0;
            margin-bottom: 16px;
            color: #f0f6fc;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}
        th, td {{
            text-align: left;
            padding: 10px 14px;
            border-bottom: 1px solid var(--border-color);
        }}
        th {{
            background-color: #1c2128;
            color: var(--text-muted);
            font-weight: 600;
        }}
        tr:hover td {{
            background-color: rgba(110, 118, 129, 0.05);
        }}
        pre.log-box {{
            background-color: #0b0e14;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            padding: 14px;
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 12px;
            color: #7ee787;
            overflow-x: auto;
            max-height: 280px;
            margin: 0;
        }}
        .footer {{
            text-align: center;
            color: var(--text-muted);
            font-size: 12px;
            margin-top: 24px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>📊 Resource Threshold Monitor (AS_44)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Executed:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                {overall_badge}
            </div>
        </div>

        <div class="grid">
            <!-- CPU Card -->
            <div class="card">
                <div class="card-header">
                    <span class="card-label">⚡ CPU Utilization</span>
                    {cpu_badge}
                </div>
                <div class="card-val" style="color: #58a6ff;">{cpu_usage}%</div>
                <div class="meter">
                    <div class="meter-fill" style="width: {min(100, cpu_usage)}%; background-color: {cpu_bar_color};"></div>
                </div>
                <div class="card-sub">
                    <span>Cores: {cpu_cores} &bull; Load: {cpu_load1}</span>
                    <span>Warn: &ge;{cpu_warn}%</span>
                </div>
            </div>

            <!-- Memory Card -->
            <div class="card">
                <div class="card-header">
                    <span class="card-label">🧠 RAM Allocation</span>
                    {mem_badge}
                </div>
                <div class="card-val" style="color: #bc8cff;">{mem_usage}%</div>
                <div class="meter">
                    <div class="meter-fill" style="width: {min(100, mem_usage)}%; background-color: {mem_bar_color};"></div>
                </div>
                <div class="card-sub">
                    <span>{mem_used} MB / {mem_total} MB</span>
                    <span>Warn: &ge;{mem_warn}%</span>
                </div>
            </div>

            <!-- Swap Card -->
            <div class="card">
                <div class="card-header">
                    <span class="card-label">💾 Swap Space</span>
                    {swap_badge}
                </div>
                <div class="card-val" style="color: #3fb950;">{swap_usage}%</div>
                <div class="meter">
                    <div class="meter-fill" style="width: {min(100, swap_usage)}%; background-color: {swap_bar_color};"></div>
                </div>
                <div class="card-sub">
                    <span>{swap_used} MB / {swap_total} MB</span>
                    <span>Warn: &ge;{swap_warn}%</span>
                </div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">🔥 Top 5 CPU Consuming Processes</h2>
            <table>
                <thead>
                    <tr>
                        <th>PID</th>
                        <th>User</th>
                        <th>% CPU</th>
                        <th>% MEM</th>
                        <th>Executable</th>
                        <th>Command Line Preview</th>
                    </tr>
                </thead>
                <tbody>
                    {cpu_rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">💾 Top 5 Memory Consuming Processes</h2>
            <table>
                <thead>
                    <tr>
                        <th>PID</th>
                        <th>User</th>
                        <th>% MEM</th>
                        <th>Resident Set (RSS)</th>
                        <th>% CPU</th>
                        <th>Executable</th>
                        <th>Command Line Preview</th>
                    </tr>
                </thead>
                <tbody>
                    {mem_rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Resource Monitor Log</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_44
        </div>
    </div>
</body>
</html>
"""

with open(report_path, "w") as f:
    f.write(html_code)

print("HTML report successfully generated -> report.html")
PYEOF

# Auto-open browser with OS detection
echo "[INFO] Opening report.html in browser..."
if grep -qi microsoft /proc/version 2>/dev/null; then
    explorer.exe "$(wslpath -w "${HTML_REPORT}")" 2>/dev/null || true
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${HTML_REPORT}" 2>/dev/null || true
elif command -v open >/dev/null 2>&1; then
    open "${HTML_REPORT}" 2>/dev/null || true
elif command -v start >/dev/null 2>&1; then
    start "" "${HTML_REPORT}" 2>/dev/null || true
else
    echo "Report generated at: ${HTML_REPORT}"
fi

echo "======================================================================"
echo " AS_44 Complete: report.html updated."
echo "======================================================================"
