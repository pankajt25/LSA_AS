#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_50 (Mini Linux Administration Dashboard)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"

echo "======================================================================"
echo " Running AS_50: Mini Linux Administration Dashboard"
echo "======================================================================"

# Execute mini administration dashboard script
bash ./mini_dashboard.sh

# Generate HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "system": {
        "hostname": socket.gethostname(),
        "os_name": platform.platform(),
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "uptime": {"seconds": 0, "formatted": "0s", "boot_epoch": 0, "boot_time": "Unknown"}
    },
    "cpu": {
        "usage_pct": 0.0,
        "cores": 1,
        "load_avg": {"1m": 0.0, "5m": 0.0, "15m": 0.0},
        "top_processes": []
    },
    "memory": {
        "total_mb": 0, "used_mb": 0, "avail_mb": 0, "usage_pct": 0.0,
        "swap_total_mb": 0, "swap_used_mb": 0, "swap_usage_pct": 0.0,
        "top_processes": []
    },
    "disk": {
        "root": {"filesystem": "/", "size": "0G", "used": "0G", "avail": "0G", "usage_pct": 0.0, "inode_pct": 0.0},
        "mounts": []
    },
    "users": {
        "session_count": 0, "unique_count": 0, "sessions": []
    },
    "services": {
        "total_running": 0, "total_failed": 0, "monitored": []
    },
    "log_file": ""
}

if os.path.exists(json_path):
    try:
        with open(json_path) as f:
            telemetry = json.load(f)
    except Exception as e:
        print(f"Warning: could not read {json_path}: {e}")

# Precompute all variables before f-string
sys_info = telemetry.get("system", {})
hostname = sys_info.get("hostname", socket.gethostname())
os_name = sys_info.get("os_name", platform.platform())
kernel = sys_info.get("kernel", platform.release())
arch = sys_info.get("architecture", platform.machine())

uptime_info = sys_info.get("uptime", {})
uptime_formatted = uptime_info.get("formatted", "N/A")
boot_time = uptime_info.get("boot_time", "N/A")

cpu_info = telemetry.get("cpu", {})
cpu_pct = float(cpu_info.get("usage_pct", 0.0))
cores = cpu_info.get("cores", 1)
load_avg = cpu_info.get("load_avg", {})
load1 = load_avg.get("1m", 0.0)
load5 = load_avg.get("5m", 0.0)
load15 = load_avg.get("15m", 0.0)

mem_info = telemetry.get("memory", {})
mem_pct = float(mem_info.get("usage_pct", 0.0))
mem_total = mem_info.get("total_mb", 0)
mem_used = mem_info.get("used_mb", 0)
mem_avail = mem_info.get("avail_mb", 0)
swap_pct = float(mem_info.get("swap_usage_pct", 0.0))
swap_used = mem_info.get("swap_used_mb", 0)
swap_total = mem_info.get("swap_total_mb", 0)

disk_info = telemetry.get("disk", {})
root_disk = disk_info.get("root", {})
disk_pct = float(root_disk.get("usage_pct", 0.0))
disk_size = root_disk.get("size", "N/A")
disk_used = root_disk.get("used", "N/A")
disk_avail = root_disk.get("avail", "N/A")
inode_pct = float(root_disk.get("inode_pct", 0.0))

users_info = telemetry.get("users", {})
session_count = users_info.get("session_count", 0)
unique_users = users_info.get("unique_count", 0)

svc_info = telemetry.get("services", {})
running_svcs = svc_info.get("total_running", 0)
failed_svcs = svc_info.get("total_failed", 0)

# Colors helper
def get_meter_color(pct):
    if pct < 60:
        return "#3fb950"
    elif pct < 85:
        return "#d29922"
    else:
        return "#f85149"

cpu_color = get_meter_color(cpu_pct)
mem_color = get_meter_color(mem_pct)
disk_color = get_meter_color(disk_pct)

# Build Mounts Table
mount_rows = ""
for m in disk_info.get("mounts", []):
    m_pct_val = 0
    try:
        m_pct_val = int(m.get("pct", "0%").replace("%", ""))
    except Exception:
        pass
    badge_cls = "badge-success" if m_pct_val < 70 else ("badge-warning" if m_pct_val < 85 else "badge-danger")
    mount_rows += f"""
    <tr>
        <td style="font-family: monospace; color: #79c0ff;">{m.get('filesystem')}</td>
        <td><strong>{m.get('mount')}</strong></td>
        <td>{m.get('size')}</td>
        <td>{m.get('used')}</td>
        <td>{m.get('avail')}</td>
        <td>
            <div style="display: flex; align-items: center; gap: 8px;">
                <div class="meter-bar" style="flex: 1;"><div class="meter-fill" style="width: {m_pct_val}%; background-color: {get_meter_color(m_pct_val)};"></div></div>
                <span class="badge {badge_cls}">{m.get('pct')}</span>
            </div>
        </td>
    </tr>
    """

# Build Monitored Services Table
service_rows = ""
for s in svc_info.get("monitored", []):
    st = s.get("status", "INACTIVE")
    badge_cls = "badge-success" if st == "ACTIVE" else "badge-danger"
    service_rows += f"""
    <tr>
        <td style="font-family: monospace; color: #58a6ff; font-weight: bold;">{s.get('unit')}</td>
        <td><span class="badge {badge_cls}">● {st}</span></td>
        <td><span class="badge badge-info">{s.get('enabled')}</span></td>
        <td><code>{s.get('pid')}</code></td>
        <td>{s.get('memory')}</td>
    </tr>
    """

# Build User Sessions Table
user_rows = ""
for u in users_info.get("sessions", []):
    user_rows += f"""
    <tr>
        <td style="font-weight: bold; color: #58a6ff;">{u.get('user')}</td>
        <td><code>{u.get('terminal')}</code></td>
        <td>{u.get('time')}</td>
        <td><code>{u.get('host')}</code></td>
        <td><span class="badge badge-success">Active Session</span></td>
    </tr>
    """

if not user_rows:
    user_rows = "<tr><td colspan='5' style='text-align: center; color: #8b949e;'>No active sessions detected.</td></tr>"

# Build Top CPU processes
cpu_proc_rows = ""
for p in cpu_info.get("top_processes", []):
    cpu_proc_rows += f"""
    <tr>
        <td><code>{p.get('pid')}</code></td>
        <td>{p.get('user')}</td>
        <td><strong>{p.get('cpu')}%</strong></td>
        <td>{p.get('mem')}%</td>
        <td style="font-family: monospace; color: #79c0ff;">{p.get('command')}</td>
    </tr>
    """

# Build Top Mem processes
mem_proc_rows = ""
for p in mem_info.get("top_processes", []):
    mem_proc_rows += f"""
    <tr>
        <td><code>{p.get('pid')}</code></td>
        <td>{p.get('user')}</td>
        <td><strong>{p.get('mem')}%</strong></td>
        <td>{p.get('cpu')}%</td>
        <td style="font-family: monospace; color: #79c0ff;">{p.get('command')}</td>
    </tr>
    """

# Read execution log
log_content = ""
log_file = telemetry.get("log_file", "")
if log_file and os.path.exists(log_file):
    try:
        with open(log_file, "r") as lf:
            lines = lf.readlines()[-40:]
            log_content = "".join(lines)
    except Exception:
        log_content = "Log file could not be read."

html_code = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_50 - Mini Linux Administration Dashboard</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --border-color: #30363d;
            --text-primary: #c9d1d9;
            --text-muted: #8b949e;
            --accent-blue: #58a6ff;
            --accent-green: #3fb950;
            --accent-yellow: #d29922;
            --accent-red: #f85149;
            --accent-purple: #bc8cff;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            background-color: var(--bg-primary);
            color: var(--text-primary);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            padding: 24px;
            line-height: 1.5;
        }}

        .container {{
            max-width: 1300px;
            margin: 0 auto;
        }}

        .header {{
            background: linear-gradient(135deg, #161b22 0%, #1f242c 100%);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
        }}

        .header-top {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }}

        .header-title h1 {{
            font-size: 26px;
            color: #ffffff;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .header-title p {{
            color: var(--text-muted);
            font-size: 14px;
            margin-top: 4px;
        }}

        .meta-badges {{
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }}

        .meta-badge {{
            background-color: #21262d;
            border: 1px solid var(--border-color);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-primary);
        }}

        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}

        .kpi-card {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 18px;
            position: relative;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
            transition: transform 0.2s ease, border-color 0.2s ease;
        }}

        .kpi-card:hover {{
            transform: translateY(-2px);
            border-color: var(--accent-blue);
        }}

        .kpi-label {{
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}

        .kpi-value {{
            font-size: 26px;
            font-weight: 800;
            color: #ffffff;
            margin-bottom: 6px;
        }}

        .kpi-subtext {{
            font-size: 12px;
            color: var(--text-muted);
        }}

        .meter-bar {{
            width: 100%;
            height: 8px;
            background-color: #21262d;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 8px;
            border: 1px solid #30363d;
        }}

        .meter-fill {{
            height: 100%;
            border-radius: 4px;
            transition: width 0.4s ease;
        }}

        .section {{
            background-color: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 24px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
        }}

        .section-title {{
            font-size: 17px;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 10px;
        }}

        .two-col {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }}

        @media (max-width: 900px) {{
            .two-col {{
                grid-template-columns: 1fr;
            }}
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}

        th {{
            background-color: #21262d;
            color: var(--text-muted);
            text-align: left;
            padding: 10px 12px;
            font-weight: 600;
            border-bottom: 1px solid var(--border-color);
        }}

        td {{
            padding: 10px 12px;
            border-bottom: 1px solid #21262d;
            color: var(--text-primary);
        }}

        tr:hover td {{
            background-color: #1c2128;
        }}

        .badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
        }}

        .badge-success {{ background-color: rgba(63, 185, 80, 0.15); color: #3fb950; border: 1px solid #3fb950; }}
        .badge-warning {{ background-color: rgba(210, 153, 34, 0.15); color: #d29922; border: 1px solid #d29922; }}
        .badge-danger {{ background-color: rgba(248, 81, 73, 0.15); color: #f85149; border: 1px solid #f85149; }}
        .badge-info {{ background-color: rgba(88, 166, 255, 0.15); color: #58a6ff; border: 1px solid #58a6ff; }}

        code {{
            background-color: #21262d;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 12px;
            color: #79c0ff;
        }}

        .log-box {{
            background-color: #05080c;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 12px;
            line-height: 1.6;
            color: #8b949e;
            white-space: pre-wrap;
            max-height: 350px;
            overflow-y: auto;
        }}

        .footer {{
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 30px;
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-top">
                <div class="header-title">
                    <h1>📊 Mini Linux Administration Dashboard</h1>
                    <p>Live Multi-Subsystem Health & Telemetry Introspection Engine</p>
                </div>
                <div class="meta-badges">
                    <span class="meta-badge">🖥️ Host: <span style="color: #58a6ff;">{hostname}</span></span>
                    <span class="meta-badge">🐧 {os_name}</span>
                    <span class="meta-badge">⚙️ Kernel: {kernel} ({arch})</span>
                    <span class="meta-badge">🕒 {telemetry.get('timestamp')}</span>
                </div>
            </div>
        </div>

        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-label">System Uptime <span>⏱️</span></div>
                <div class="kpi-value" style="color: #3fb950; font-size: 20px;">{uptime_formatted}</div>
                <div class="kpi-subtext">Boot: {boot_time}</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-label">CPU Utilization <span>⚡</span></div>
                <div class="kpi-value" style="color: {cpu_color};">{cpu_pct}%</div>
                <div class="meter-bar"><div class="meter-fill" style="width: {min(cpu_pct, 100.0)}%; background-color: {cpu_color};"></div></div>
                <div class="kpi-subtext" style="margin-top: 6px;">Load: {load1}, {load5}, {load15} ({cores}C)</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-label">Memory Allocation <span>🧠</span></div>
                <div class="kpi-value" style="color: {mem_color};">{mem_pct}%</div>
                <div class="meter-bar"><div class="meter-fill" style="width: {min(mem_pct, 100.0)}%; background-color: {mem_color};"></div></div>
                <div class="kpi-subtext" style="margin-top: 6px;">Used: {mem_used}M / {mem_total}M (Avail: {mem_avail}M)</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-label">Root Storage <span>💾</span></div>
                <div class="kpi-value" style="color: {disk_color};">{disk_pct}%</div>
                <div class="meter-bar"><div class="meter-fill" style="width: {min(disk_pct, 100.0)}%; background-color: {disk_color};"></div></div>
                <div class="kpi-subtext" style="margin-top: 6px;">Used: {disk_used} / {disk_size} (Inodes: {inode_pct}%)</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-label">Active Users <span>👥</span></div>
                <div class="kpi-value" style="color: #58a6ff;">{session_count}</div>
                <div class="kpi-subtext">{unique_users} unique user session(s)</div>
            </div>

            <div class="kpi-card">
                <div class="kpi-label">Systemd Daemons <span>⚙️</span></div>
                <div class="kpi-value" style="color: #bc8cff;">{running_svcs} Active</div>
                <div class="kpi-subtext">{failed_svcs} failed unit(s)</div>
            </div>
        </div>

        <div class="two-col">
            <div class="section">
                <h2 class="section-title">🛡️ Key Monitored Daemons</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Service Unit</th>
                            <th>Status</th>
                            <th>Boot Enable</th>
                            <th>Main PID</th>
                            <th>Memory</th>
                        </tr>
                    </thead>
                    <tbody>
                        {service_rows}
                    </tbody>
                </table>
            </div>

            <div class="section">
                <h2 class="section-title">👤 Active Terminal Logins</h2>
                <table>
                    <thead>
                        <tr>
                            <th>User</th>
                            <th>TTY</th>
                            <th>Login Time</th>
                            <th>Origin</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {user_rows}
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">💽 Filesystem Mount Points & Storage Utilization</h2>
            <table>
                <thead>
                    <tr>
                        <th>Filesystem Device</th>
                        <th>Mount Path</th>
                        <th>Total Size</th>
                        <th>Used</th>
                        <th>Available</th>
                        <th>Capacity Gauge</th>
                    </tr>
                </thead>
                <tbody>
                    {mount_rows}
                </tbody>
            </table>
        </div>

        <div class="two-col">
            <div class="section">
                <h2 class="section-title">⚡ Top CPU Consuming Processes</h2>
                <table>
                    <thead>
                        <tr>
                            <th>PID</th>
                            <th>User</th>
                            <th>%CPU</th>
                            <th>%MEM</th>
                            <th>Command</th>
                        </tr>
                    </thead>
                    <tbody>
                        {cpu_proc_rows}
                    </tbody>
                </table>
            </div>

            <div class="section">
                <h2 class="section-title">🧠 Top Memory Consuming Processes</h2>
                <table>
                    <thead>
                        <tr>
                            <th>PID</th>
                            <th>User</th>
                            <th>%MEM</th>
                            <th>%CPU</th>
                            <th>Command</th>
                        </tr>
                    </thead>
                    <tbody>
                        {mem_proc_rows}
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Console Audit & Execution Trace</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_50
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
echo " AS_50 Complete: report.html updated."
echo "======================================================================"
