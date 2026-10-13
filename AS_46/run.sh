#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_46 (Service Status Dashboard)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_46: Service Status Dashboard"
echo "======================================================================"

# Run main script
bash ./service_dashboard.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "total_services": 0,
    "active_count": 0,
    "inactive_count": 0,
    "failed_count": 0,
    "not_found_count": 0,
    "services": [],
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

def badge_status(status):
    if status == "ACTIVE":
        return '<span class="badge badge-success">● RUNNING</span>'
    elif status == "INACTIVE":
        return '<span class="badge badge-warning">○ STOPPED</span>'
    elif status == "FAILED":
        return '<span class="badge badge-danger">✖ FAILED</span>'
    return '<span class="badge badge-neutral">⊘ NOT INSTALLED</span>'

def badge_enable(en):
    if en == "enabled":
        return '<span class="badge badge-info">ENABLED</span>'
    elif en == "disabled":
        return '<span class="badge badge-neutral">DISABLED</span>'
    elif en == "static":
        return '<span class="badge badge-neutral">STATIC</span>'
    return f'<span class="badge badge-neutral">{en.upper()}</span>'

rows = ""
for s in telemetry.get("services", []):
    svc = s.get("service", "")
    unit = s.get("unit", "")
    st = s.get("status", "")
    en = s.get("enabled", "")
    pid = s.get("pid", "-")
    mem = s.get("memory", "-")
    desc = s.get("description", "")
    
    rows += f"""
    <tr>
        <td style="font-weight: 600; color: #58a6ff;">{svc}</td>
        <td style="color: #8b949e; font-family: monospace; font-size: 12px;">{unit}</td>
        <td>{badge_status(st)}</td>
        <td>{badge_enable(en)}</td>
        <td><code>{pid}</code></td>
        <td style="color: #bc8cff;">{mem}</td>
        <td style="color: #c9d1d9; font-size: 12px;">{desc}</td>
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
    <title>AS_46 - Service Status Dashboard</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --border-color: #30363d;
            --text-primary: #c9d1d9;
            --text-muted: #8b949e;
            --accent-green: #238636;
            --accent-blue: #1f6feb;
            --accent-orange: #d29922;
            --accent-red: #da3633;
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
        .badge-info {{ background-color: rgba(56, 139, 253, 0.2); color: #58a6ff; border: 1px solid rgba(56, 139, 253, 0.4); }}
        .badge-neutral {{ background-color: rgba(110, 118, 129, 0.2); color: #8b949e; border: 1px solid rgba(110, 118, 129, 0.4); }}
        
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
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
            font-size: 28px;
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
                <h1>🛡️ Service Status Dashboard (AS_46)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Audited:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                <span class="badge badge-info">Service Audit Live</span>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">Services Monitored</div>
                <div class="card-val" style="color: #58a6ff;">{telemetry.get("total_services")}</div>
                <div class="card-sub">Cataloged target daemons</div>
            </div>
            <div class="card">
                <div class="card-label">Active / Running</div>
                <div class="card-val" style="color: #3fb950;">{telemetry.get("active_count")}</div>
                <div class="card-sub">Operational systemd units</div>
            </div>
            <div class="card">
                <div class="card-label">Inactive / Stopped</div>
                <div class="card-val" style="color: #d29922;">{telemetry.get("inactive_count")}</div>
                <div class="card-sub">Installed but dormant</div>
            </div>
            <div class="card">
                <div class="card-label">Not Installed</div>
                <div class="card-val" style="color: #8b949e;">{telemetry.get("not_found_count")}</div>
                <div class="card-sub">No unit definition found</div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">📋 Daemon Status & Health Matrix</h2>
            <table>
                <thead>
                    <tr>
                        <th>Service</th>
                        <th>Unit File</th>
                        <th>Active Status</th>
                        <th>Boot Persistence</th>
                        <th>PID</th>
                        <th>Memory Use</th>
                        <th>Description</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Service Audit Log</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_46
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
echo " AS_46 Complete: report.html updated."
echo "======================================================================"
