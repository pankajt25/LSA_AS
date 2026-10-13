#!/usr/bin/env bash
# ==============================================================================
# Script: run.sh
# Purpose: Driver script for AS_41 (Archive Old Project Files)
# Generates report.html and auto-opens in browser.
# ==============================================================================

set -euo pipefail
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
HTML_REPORT="${SCRIPT_DIR}/report.html"
DATA_DIR="${SCRIPT_DIR}/sandbox_data"
ARCHIVE_DIR="${DATA_DIR}/archive"
PROJECTS_DIR="${DATA_DIR}/projects"

echo "======================================================================"
echo " Running AS_41: Archive Old Project Files"
echo "======================================================================"

# Reset sandbox if previous run already moved all files
mkdir -p "${PROJECTS_DIR}" "${ARCHIVE_DIR}"
TOTAL_FILES=$(find "${PROJECTS_DIR}" -type f 2>/dev/null | wc -l || true)
if [ "${TOTAL_FILES}" -le 4 ]; then
    echo "[SETUP] Re-seeding sandbox project files for archival demonstration..."
    mkdir -p "${PROJECTS_DIR}/alpha_project/docs" \
             "${PROJECTS_DIR}/alpha_project/builds" \
             "${PROJECTS_DIR}/beta_service/logs" \
             "${PROJECTS_DIR}/gamma_analytics/reports" \
             "${PROJECTS_DIR}/legacy_core/src"

    # Stale files (>30d)
    echo "Architecture Document v0.1" > "${PROJECTS_DIR}/alpha_project/docs/arch_v0.1_old.pdf"
    touch -d "120 days ago" "${PROJECTS_DIR}/alpha_project/docs/arch_v0.1_old.pdf"

    dd if=/dev/urandom of="${PROJECTS_DIR}/alpha_project/builds/release_2023_candidate.iso" bs=1024 count=128 status=none 2>/dev/null || true
    touch -d "95 days ago" "${PROJECTS_DIR}/alpha_project/builds/release_2023_candidate.iso"

    echo "[DEBUG] 2023-01-15 Server startup log dump" > "${PROJECTS_DIR}/beta_service/logs/service_2023_debug.log"
    touch -d "65 days ago" "${PROJECTS_DIR}/beta_service/logs/service_2023_debug.log"

    echo "Quarterly Financial Analysis Q1 2024" > "${PROJECTS_DIR}/gamma_analytics/reports/q1_2024_interim.csv"
    touch -d "48 days ago" "${PROJECTS_DIR}/gamma_analytics/reports/q1_2024_interim.csv"

    echo "/* Deprecated driver stub */ int init_old() { return 0; }" > "${PROJECTS_DIR}/legacy_core/src/driver_v1.c"
    touch -d "40 days ago" "${PROJECTS_DIR}/legacy_core/src/driver_v1.c"

    # Active files (<30d)
    echo "Active project specs 2026" > "${PROJECTS_DIR}/alpha_project/docs/specs_current.md"
    touch -d "5 days ago" "${PROJECTS_DIR}/alpha_project/docs/specs_current.md"

    echo "[INFO] Current application runtime logs" > "${PROJECTS_DIR}/beta_service/logs/runtime_current.log"
    touch -d "1 days ago" "${PROJECTS_DIR}/beta_service/logs/runtime_current.log"

    echo -e "id,metric,value\n1,throughput,9420" > "${PROJECTS_DIR}/gamma_analytics/reports/current_metrics.csv"
    touch -d "10 days ago" "${PROJECTS_DIR}/gamma_analytics/reports/current_metrics.csv"

    echo "/* Production engine core */ int main() { return 0; }" > "${PROJECTS_DIR}/legacy_core/src/main.c"
    touch -d "2 days ago" "${PROJECTS_DIR}/legacy_core/src/main.c"
fi

# Run the archival script
bash ./archive_old_files.sh --days 30 --compress

# Generate dark-themed HTML report
python3 - <<'PYEOF'
import os, json, socket, platform, datetime, tarfile

report_path = "report.html"
json_path = "logs/last_run.json"

telemetry = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "days_threshold": 30,
    "total_scanned_files": 0,
    "archived_count": 0,
    "bytes_reclaimed": 0,
    "remaining_files": 0,
    "archive_artifact": "N/A",
    "log_file": "N/A"
}

if os.path.exists(json_path):
    try:
        with open(json_path) as f:
            telemetry = json.load(f)
    except Exception as e:
        print(f"Warning: could not read {json_path}: {e}")

hostname = socket.gethostname()
os_name = platform.platform()
reclaimed_kb = round(telemetry.get("bytes_reclaimed", 0) / 1024, 2)

# Inspect archive artifact if tarball
manifest_rows = ""
archive_artifact = telemetry.get("archive_artifact", "")
if archive_artifact and os.path.exists(archive_artifact) and archive_artifact.endswith(".tar.gz"):
    try:
        with tarfile.open(archive_artifact, "r:gz") as tar:
            members = tar.getmembers()
            for m in members:
                m_type = "Directory" if m.isdir() else "File"
                m_size = f"{m.size:,} B" if not m.isdir() else "-"
                m_mtime = datetime.datetime.fromtimestamp(m.mtime).strftime("%Y-%m-%d %H:%M:%S")
                manifest_rows += f"""
                <tr>
                    <td style="font-family: monospace; color: #79c0ff;">{m.name}</td>
                    <td><span class="badge {'badge-info' if m.isdir() else 'badge-success'}">{m_type}</span></td>
                    <td>{m_size}</td>
                    <td>{m_mtime}</td>
                </tr>
                """
    except Exception as err:
        manifest_rows = f"<tr><td colspan='4'>Error reading tar archive: {err}</td></tr>"

if not manifest_rows:
    manifest_rows = "<tr><td colspan='4' style='text-align: center; color: #8b949e;'>No archive bundle inspection available.</td></tr>"

# Read recent log entries
log_content = ""
log_file = telemetry.get("log_file", "")
if log_file and os.path.exists(log_file):
    try:
        with open(log_file, "r") as lf:
            lines = lf.readlines()[-25:]
            log_content = "".join(lines)
    except Exception:
        log_content = "Log file could not be read."

html_code = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AS_41 - Archive Old Project Files</title>
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
        .badge-info {{ background-color: rgba(56, 139, 253, 0.2); color: #58a6ff; border: 1px solid rgba(56, 139, 253, 0.4); }}
        .badge-warning {{ background-color: rgba(210, 153, 34, 0.2); color: #d29922; border: 1px solid rgba(210, 153, 34, 0.4); }}
        
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
            display: flex;
            align-items: center;
            gap: 8px;
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
                <h1>📦 Old Project Files Archival Dashboard (AS_41)</h1>
                <div class="meta">
                    <strong>Host:</strong> {hostname} &bull; 
                    <strong>OS:</strong> {os_name} &bull; 
                    <strong>Executed:</strong> {telemetry.get("timestamp")}
                </div>
            </div>
            <div>
                <span class="badge badge-success">Archival Completed</span>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">Retention Threshold</div>
                <div class="card-val" style="color: #58a6ff;">&gt; {telemetry.get("days_threshold")} Days</div>
                <div class="card-sub">Files older than rule relocated</div>
            </div>
            <div class="card">
                <div class="card-label">Files Archived</div>
                <div class="card-val" style="color: #3fb950;">{telemetry.get("archived_count")}</div>
                <div class="card-sub">Identified & moved from project tree</div>
            </div>
            <div class="card">
                <div class="card-label">Reclaimed Space</div>
                <div class="card-val" style="color: #d29922;">{reclaimed_kb} KB</div>
                <div class="card-sub">{telemetry.get("bytes_reclaimed", 0):,} bytes total</div>
            </div>
            <div class="card">
                <div class="card-label">Active Files Remaining</div>
                <div class="card-val" style="color: #f0f6fc;">{telemetry.get("remaining_files")}</div>
                <div class="card-sub">Untouched & active files retained</div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">🗂️ Archive Bundle Manifest & Inspection</h2>
            <p style="font-size: 13px; color: var(--text-muted); margin-top: 0;">
                Artifact: <code style="color: #79c0ff; background: #0b0e14; padding: 2px 6px; border-radius: 4px;">{os.path.basename(archive_artifact)}</code>
            </p>
            <table>
                <thead>
                    <tr>
                        <th>Path in Bundle</th>
                        <th>Type</th>
                        <th>Size</th>
                        <th>Original Modification Time</th>
                    </tr>
                </thead>
                <tbody>
                    {manifest_rows}
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2 class="section-title">📜 Execution & Telemetry Log</h2>
            <pre class="log-box">{log_content}</pre>
        </div>

        <div class="footer">
            Linux System Administration (E1ITA307) &bull; Automation Sprint &bull; AS_41
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
echo " AS_41 Complete: report.html updated."
echo "======================================================================"
