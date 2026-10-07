# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #32: File Modification Monitor — Commands Reference

This document catalogs all core Linux system administration, filesystem inspection, file modification tracking, and timestamp analysis commands utilized in the design, execution, verification, and reporting of `AS_32`.

---

### 1. Filesystem Timestamp & Modification Inspection Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `find <dir> -type f -mmin -1440` | Discovers regular files modified within the last 1440 minutes (exact 24-hour cutoff). |
| `find <dir> -type f -mtime -1` | Standard POSIX-compatible find evaluation by 24-hour interval periods. |
| `stat -c "%y %s %U %a %n" <file>` | Inspects file inode metadata: modification timestamp (%y), size in bytes (%s), owner (%U), octal permissions (%a), and filename (%n). |
| `find <dir> -printf "%TY-%Tm-%Td %TH:%TM:%TS %s %p\n"` | Formats timestamped tabular directory inspection directly via GNU find. |
| `touch -d "2 hours ago" <file>` | Adjusts file modification timestamp to simulate past change windows for rigorous regression verification. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute automated file modification monitoring and launch HTML dashboard
cd AS_32
bash run.sh

# Run core script directly on live project workspace
./file_modification_monitor.sh

# Audit custom target directory
./file_modification_monitor.sh --dir /path/to/project

# Modify time window threshold (e.g. last 12 hours or 48 hours)
./file_modification_monitor.sh --hours 12

# Filter by file extension
./file_modification_monitor.sh --ext .py

# Audit simulated project repository
./file_modification_monitor.sh --sandbox

# Emit machine-readable JSON telemetry
./file_modification_monitor.sh --json

# View usage manual
./file_modification_monitor.sh --help
```

---

### 3. Production Monitoring via Cron

```bash
# Automated daily report of modified project assets
# 0 18 * * * /usr/local/bin/file_modification_monitor.sh --dir /srv/project --json >> /var/log/daily_file_mods.log 2>&1
```
