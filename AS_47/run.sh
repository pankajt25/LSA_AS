#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_47 (Security Audit Report)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_47: Security Audit Report"
echo "======================================================================"

# Run main security audit script
bash ./security_audit.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "compliance_score": 100,
    "severity_label": "NOMINAL",
    "severity_class": "SUCCESS",
    "summary": {
        "passwordless_accounts": 0,
        "world_writable_files": 0,
        "failed_logins": 0,
        "active_users": 0
    },
    "passwordless_details": [],
    "world_writable_details": [],
    "failed_login_details": [],
    "active_user_details": [],
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
score = telemetry.get("compliance_score", 100)
summary = telemetry.get("summary", {})

score_color = "#3fb950"
if score < 60:
    score_color = "#f85149"
elif score < 85:
    score_color = "#d29922"

# Passwordless Rows
pw_rows = ""
for u in telemetry.get("passwordless_details", []):
    pw_rows += f"""
    <tr>
        <td style="font-weight: 600; color: #f85149;">{u.get('user')}</td>
        <td><code>UID: {u.get('uid')}</code></td>
        <td style="font-family: monospace;">{u.get('shell')}</td>
        <td><span class="badge badge-danger">CRITICAL RISK</span></td>
        <td style="color: #8b949e;">Lock account (<code>passwd -l</code>) or set password (<code>passwd</code>)</td>
    </tr>
    """
if not pw_rows:
    pw_rows = "<tr><td colspan='5' style='text-align: center; color: #3fb950;'>✓ No password-less accounts detected. All shadow credentials secure.</td></tr>"

# World-Writable Rows
ww_rows = ""
for w in telemetry.get("world_writable_details", []):
    ww_rows += f"""
    <tr>
        <td style="color: #79c0ff; font-family: monospace;">{w.get('path')}</td>
        <td><code>{w.get('permissions')} ({w.get('octal')})</code></td>
        <td>{w.get('owner')}:{w.get('group')}</td>
        <td>{w.get('size')} B</td>
        <td><span class="badge badge-warning">WORLD-WRITABLE</span></td>
    </tr>
    """
if not ww_rows:
    ww_rows = "<tr><td colspan='5' style='text-align: center; color: #3fb950;'>✓ No insecure world-writable files found.</td></tr>"

# Failed Login Rows
fl_rows = ""
for fl in telemetry.get("failed_login_details", []):
    fl_rows += f"""
    <tr>
        <td>{fl.get('timestamp')}</td>
        <td style="font-weight: 600; color: #d29922;">{fl.get('user')}</td>
        <td><code>{fl.get('source_ip')}</code></td>
        <td style="font-size: 11px; color: #8b949e; font-family: monospace;">{fl.get('raw')}</td>
    </tr>
    """
if not fl_rows:
    fl_rows = "<tr><td colspan='4' style='text-align: center; color: #8b949e;'>No recent failed authentication log entries discovered.</td></tr>"

# Active User Rows
au_rows = ""
for au in telemetry.get("active_user_details", []):
    au_rows += f"""
    <tr>
        <td style="font-weight: 600; color: #58a6ff;">{au.get('user')}</td>
        <td><code>{au.get('tty')}</code></td>
        <td>{au.get('login_time')}</td>
        <td><code>{au.get('remote_host')}</code></td>
        <td><span class="badge badge-success">ACTIVE SESSION</span></td>
    </tr>
    """
if not au_rows:
    au_rows = "<tr><td colspan='5' style='text-align: center; color: #8b949e;'>No active sessions found.</td></tr>"

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
    <title>AS_47 - Security Audit Report</title>
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
                <h1>🛡️ System Security Audit Report (AS_47)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Audited:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                <span class="badge" style="background: rgba(210, 153, 34, 0.2); color: {score_color}; border: 1px solid {score_color};">
                    {telemetry.get("severity_label")}
                </span>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">Security Score</div>
                <div class="card-val" style="color: {score_color};">{score}%</div>
                <div class="card-sub">Least-privilege posture rating</div>
            </div>
            <div class="card">
                <div class="card-label">Password-less Accounts</div>
                <div class="card-val" style="color: {'#f85149' if summary.get('passwordless_accounts') > 0 else '#3fb950'};">{summary.get('passwordless_accounts', 0)}</div>
                <div class="card-sub">Accounts lacking shadow hash</div>
            </div>
            <div class="card">
                <div class="card-label">World-Writable Files</div>
                <div class="card-val" style="color: {'#d29922' if summary.get('world_writable_files') > 0 else '#3fb950'};">{summary.get('world_writable_files', 0)}</div>
                <div class="card-sub">Files with write mask for others</div>
            </div>
            <div class="card">
                <div class="card-label">Active User Sessions</div>
                <div class="card-val" style="color: #58a6ff;">{summary.get('active_users', 0)}</div>
                <div class="card-sub">Live terminal sessions active</div>
            </div>
        </div>

        <!-- Vector 1 -->
        <div class="section">
            <h2 class="section-title">🔑 Vector 1: Password-less User Accounts (/etc/shadow)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Username</th>
                        <th>User ID</th>
                        <th>Login Shell</th>
                        <th>Risk Assessment</th>
                        <th>Recommended Remediation</th>
                    </tr>
                </thead>
                <tbody>
                    {pw_rows}
                </tbody>
            </table>
        </div>

        <!-- Vector 2 -->
        <div class="section">
            <h2 class="section-title">📝 Vector 2: World-Writable Files Audit</h2>
            <table>
                <thead>
                    <tr>
                        <th>File Location</th>
                        <th>Permissions Mode</th>
                        <th>Ownership</th>
                        <th>File Size</th>
                        <th>Risk Tag</th>
                    </tr>
                </thead>
                <tbody>
                    {ww_rows}
                </tbody>
            </table>
        </div>

        <!-- Vector 3 -->
        <div class="section">
            <h2 class="section-title">🚨 Vector 3: Failed Authentication Attempts (/var/log/auth.log)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Timestamp</th>
                        <th>Targeted User</th>
                        <th>Source IP</th>
                        <th>Log Excerpt</th>
                    </tr>
                </thead>
                <tbody>
                    {fl_rows}
                </tbody>
            </table>
        </div>

        <!-- Vector 4 -->
        <div class="section">
            <h2 class="section-title">👥 Vector 4: Active Interactive Sessions (who)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Logged-In User</th>
                        <th>TTY / Terminal</th>
                        <th>Login Time</th>
                        <th>Remote Host / Origin</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    {au_rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Security Audit Log</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_47
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
echo " AS_47 Complete: report.html updated."
echo " Note: Run 'bash cleanup.sh' to remove test accounts and restore system."
echo "======================================================================"
