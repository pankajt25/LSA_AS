#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_45 (Server Uptime Report)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_45: Server Uptime Report"
echo "======================================================================"

# Execute main reporting script
bash ./server_uptime_report.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "boot_time": "N/A",
    "boot_epoch": 0,
    "uptime_seconds": 0,
    "days": 0,
    "hours": 0,
    "minutes": 0,
    "seconds": 0,
    "formatted_uptime": "0d 0h 0m 0s",
    "pretty_uptime": "up 0 minutes",
    "target_threshold_days": 30,
    "threshold_met": False,
    "operational_status": "NOMINAL OPERATION",
    "status_class": "SUCCESS",
    "advisory_note": "Server running normally.",
    "cpu_idle_percent": 95.0,
    "cores": 4,
    "load_1m": 0.2,
    "load_5m": 0.2,
    "load_15m": 0.2,
    "user_count": 1,
    "kernel_release": platform.release(),
    "architecture": platform.machine(),
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

days = telemetry.get("days", 0)
target_days = telemetry.get("target_threshold_days", 30)
progress_pct = min(100, round((days / target_days) * 100, 1)) if target_days > 0 else 100
status_class = telemetry.get("status_class", "INFO")

badge_color = "#3fb950"
if status_class == "CRITICAL":
    badge_color = "#f85149"
elif status_class == "WARNING":
    badge_color = "#d29922"
elif status_class == "INFO":
    badge_color = "#58a6ff"

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
    <title>AS_45 - Server Uptime Report</title>
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
            padding: 6px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
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
            font-size: 12px;
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
        .meter {{
            height: 8px;
            background-color: #21262d;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 8px;
            margin-bottom: 6px;
        }}
        .meter-fill {{
            height: 100%;
            background-color: #58a6ff;
            border-radius: 4px;
        }}
        .advisory-box {{
            background-color: rgba(31, 111, 235, 0.1);
            border: 1px solid rgba(56, 139, 253, 0.3);
            border-radius: 8px;
            padding: 18px 20px;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            gap: 16px;
        }}
        .advisory-icon {{
            font-size: 28px;
        }}
        .advisory-title {{
            font-size: 15px;
            font-weight: 600;
            color: #f0f6fc;
            margin-bottom: 4px;
        }}
        .advisory-text {{
            font-size: 13px;
            color: var(--text-primary);
            margin: 0;
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
                <h1>⏱️ Server Uptime & Availability Report (AS_45)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Report Generated:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                <span class="badge" style="background: rgba({int(badge_color[1:3], 16)}, {int(badge_color[3:5], 16)}, {int(badge_color[5:7], 16)}, 0.2); color: {badge_color}; border: 1px solid {badge_color};">
                    {telemetry.get("operational_status")}
                </span>
            </div>
        </div>

        <div class="advisory-box">
            <div class="advisory-icon">💡</div>
            <div>
                <div class="advisory-title">Operational Status Assessment</div>
                <p class="advisory-text">{telemetry.get("advisory_note")}</p>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">Current Uptime</div>
                <div class="card-val" style="color: #58a6ff;">{telemetry.get("formatted_uptime")}</div>
                <div class="card-sub">{telemetry.get("pretty_uptime")}</div>
            </div>
            <div class="card">
                <div class="card-label">System Boot Timestamp</div>
                <div class="card-val" style="font-size: 20px; color: #3fb950;">{telemetry.get("boot_time")}</div>
                <div class="card-sub">Epoch: {telemetry.get("boot_epoch")}</div>
            </div>
            <div class="card">
                <div class="card-label">Continuous SLA Target ({target_days}d)</div>
                <div class="card-val" style="color: #d29922;">{days} / {target_days} Days</div>
                <div class="meter">
                    <div class="meter-fill" style="width: {progress_pct}%;"></div>
                </div>
                <div class="card-sub">{progress_pct}% of Target SLA Window</div>
            </div>
            <div class="card">
                <div class="card-label">CPU Idle Ratio</div>
                <div class="card-val" style="color: #bc8cff;">{telemetry.get("cpu_idle_percent")}%</div>
                <div class="card-sub">Measured across {telemetry.get("cores")} processor cores</div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">🖥️ Kernel & Operating Environment Parameters</h2>
            <table>
                <thead>
                    <tr>
                        <th>Metric Parameter</th>
                        <th>Harvested Value</th>
                        <th>Kernel / Subsystem Source</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Kernel Release</strong></td>
                        <td><code>{telemetry.get("kernel_release")}</code></td>
                        <td><code>uname -r</code></td>
                    </tr>
                    <tr>
                        <td><strong>CPU Architecture</strong></td>
                        <td><code>{telemetry.get("architecture")}</code></td>
                        <td><code>uname -m</code></td>
                    </tr>
                    <tr>
                        <td><strong>System Load Averages</strong></td>
                        <td><code>1m: {telemetry.get("load_1m")} &bull; 5m: {telemetry.get("load_5m")} &bull; 15m: {telemetry.get("load_15m")}</code></td>
                        <td><code>/proc/loadavg</code></td>
                    </tr>
                    <tr>
                        <td><strong>Logged-In User Sessions</strong></td>
                        <td><code>{telemetry.get("user_count")} session(s) active</code></td>
                        <td><code>who</code></td>
                    </tr>
                    <tr>
                        <td><strong>Raw Kernel Uptime Counter</strong></td>
                        <td><code>{telemetry.get("uptime_seconds")} seconds</code></td>
                        <td><code>/proc/uptime</code></td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Uptime Evaluation Log</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_45
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
echo " AS_45 Complete: report.html updated."
echo "======================================================================"
