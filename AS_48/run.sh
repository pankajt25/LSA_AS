#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_48 (Administrator Daily Report)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_48: Administrator Daily Report"
echo "======================================================================"

# Execute main reporting script
bash ./admin_daily_report.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "hostname": socket.gethostname(),
    "kernel": platform.release(),
    "architecture": platform.machine(),
    "uptime": {"formatted": "0d 0h 0m 0s", "pretty": "up 0 mins", "boot_time": "N/A"},
    "cpu": {"usage_pct": 0.0, "load_1m": 0.1, "load_5m": 0.1, "load_15m": 0.1, "cores": 4, "top_consumer": "N/A"},
    "memory": {"total_mb": 0, "used_mb": 0, "avail_mb": 0, "usage_pct": 0, "swap_used_mb": 0, "swap_total_mb": 0, "swap_pct": 0},
    "disk": {"root_fs": "/", "total": "0", "used": "0", "avail": "0", "usage_pct": 0, "mounts": []},
    "users": {"count": 1, "sessions": []},
    "services": [],
    "report_txt": "",
    "log_file": ""
}

if os.path.exists(json_path):
    try:
        with open(json_path) as f:
            telemetry = json.load(f)
    except Exception as e:
        print(f"Warning: could not read {json_path}: {e}")

hostname = telemetry.get("hostname", socket.gethostname())
os_name = platform.platform()

uptime_obj = telemetry.get("uptime", {})
cpu_obj = telemetry.get("cpu", {})
mem_obj = telemetry.get("memory", {})
disk_obj = telemetry.get("disk", {})
user_obj = telemetry.get("users", {})

uptime_formatted = uptime_obj.get("formatted", "0d 0h 0m 0s")
uptime_pretty = uptime_obj.get("pretty", "up 0 mins")
cpu_usage = cpu_obj.get("usage_pct", 0)
cpu_load1 = cpu_obj.get("load_1m", 0)
cpu_cores = cpu_obj.get("cores", 4)
mem_pct = mem_obj.get("usage_pct", 0)
mem_used = mem_obj.get("used_mb", 0)
mem_total = mem_obj.get("total_mb", 0)
disk_pct = disk_obj.get("usage_pct", 0)
disk_avail = disk_obj.get("avail", "0G")
user_count = user_obj.get("count", 0)

# Build Disk Mounts table
mount_rows = ""
for m in telemetry.get("disk", {}).get("mounts", []):
    mount_rows += f"""
    <tr>
        <td style="font-family: monospace; color: #79c0ff;">{m.get('mount')}</td>
        <td style="color: #8b949e; font-size: 11px;">{m.get('filesystem')}</td>
        <td>{m.get('size')}</td>
        <td>{m.get('used')}</td>
        <td>{m.get('avail')}</td>
        <td><strong style="color: {'#f85149' if int(m.get('pct', '0%').replace('%','')) > 85 else '#3fb950'};">{m.get('pct')}</strong></td>
    </tr>
    """

# Build Services Grid
svc_badges = ""
for s in telemetry.get("services", []):
    svc_name = s.get("service")
    svc_st = s.get("status")
    color = "#3fb950" if svc_st == "RUNNING" else ("#d29922" if svc_st == "STOPPED" else "#8b949e")
    bg = "rgba(46, 160, 67, 0.15)" if svc_st == "RUNNING" else "rgba(110, 118, 129, 0.15)"
    svc_badges += f"""
    <div style="background: {bg}; border: 1px solid {color}; border-radius: 6px; padding: 10px 14px; display: flex; justify-content: space-between; align-items: center;">
        <span style="font-weight: 600; color: #f0f6fc;">{svc_name}</span>
        <span style="font-size: 11px; font-weight: bold; color: {color};">{svc_st}</span>
    </div>
    """

# Read Generated Plaintext Daily Report
daily_report_txt = ""
report_file = telemetry.get("report_txt", "")
if report_file and os.path.exists(report_file):
    try:
        with open(report_file, "r") as rf:
            daily_report_txt = rf.read()
    except Exception:
        daily_report_txt = "Daily report text file could not be read."

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
    <title>AS_48 - Administrator Daily Report</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --border-color: #30363d;
            --text-primary: #c9d1d9;
            --text-muted: #8b949e;
            --accent-green: #238636;
            --accent-blue: #1f6feb;
            --accent-purple: #8957e5;
            --accent-orange: #d29922;
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
        
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .card {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
        }}
        .card-label {{
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }}
        .card-val {{
            font-size: 26px;
            font-weight: bold;
            color: #f0f6fc;
        }}
        .card-sub {{
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 6px;
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
        pre.report-box {{
            background-color: #0b0e14;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            padding: 18px;
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 12px;
            color: #c9d1d9;
            overflow-x: auto;
            max-height: 420px;
            margin: 0;
            white-space: pre;
            line-height: 1.45;
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
            max-height: 240px;
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
                <h1>📋 Administrator Daily Report (AS_48)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Report Generated:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                <span class="badge badge-success">Daily Audit Completed</span>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">System Uptime</div>
                <div class="card-val" style="color: #58a6ff; font-size: 20px;">{uptime_formatted}</div>
                <div class="card-sub">{uptime_pretty}</div>
            </div>
            <div class="card">
                <div class="card-label">CPU Utilization</div>
                <div class="card-val" style="color: #3fb950;">{cpu_usage}%</div>
                <div class="card-sub">Load: {cpu_load1} ({cpu_cores} cores)</div>
            </div>
            <div class="card">
                <div class="card-label">Memory Allocation</div>
                <div class="card-val" style="color: #bc8cff;">{mem_pct}%</div>
                <div class="card-sub">{mem_used} MB / {mem_total} MB</div>
            </div>
            <div class="card">
                <div class="card-label">Root Storage</div>
                <div class="card-val" style="color: #d29922;">{disk_pct}%</div>
                <div class="card-sub">{disk_avail} Available</div>
            </div>
            <div class="card">
                <div class="card-label">Active Users</div>
                <div class="card-val" style="color: #f0f6fc;">{user_count}</div>
                <div class="card-sub">Active terminal session(s)</div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">📄 Plaintext Daily Administrator Briefing</h2>
            <pre class="report-box">{daily_report_txt}</pre>
        </div>

        <div class="section">
            <h2 class="section-title">💾 Storage Volumes & Mount Points</h2>
            <table>
                <thead>
                    <tr>
                        <th>Mount Point</th>
                        <th>Device Filesystem</th>
                        <th>Total Size</th>
                        <th>Used Space</th>
                        <th>Available</th>
                        <th>Utilization</th>
                    </tr>
                </thead>
                <tbody>
                    {mount_rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">⚙️ Essential System Daemons</h2>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px;">
                {svc_badges}
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Audit Execution Trace</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_48
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
echo " AS_48 Complete: report.html updated."
echo "======================================================================"
