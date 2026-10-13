# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #09: Temporary File Cleanup — Commands Reference

This document catalogs all core Linux system administration and storage hygiene commands utilized in the design, execution, verification, and reporting of `AS_09`.

---

### 1. Storage Inspection & Age Filtering

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `find <DIR> -type f -mtime +<DAYS>` | Finds files whose data was last modified strictly greater than `DAYS*24` hours ago. |
| `stat -c "%Y %y %s" <FILE>` | Extracts file metadata: epoch timestamp (`%Y`), human-readable timestamp (`%y`), and file size in bytes (`%s`). |
| `touch -d "<OFFSET>" <FILE>` | Adjusts file modification and access times backdated into the past (e.g. `touch -d "14 days ago" file.tmp`) for reproducible aging tests. |
| `rm -f <FILE>` | Safely unlinks candidate stale temporary files without prompting for confirmation. |
| `find <DIR> -type d -empty -delete` | Traverses and removes empty directories left behind after stale temporary files have been purged. |

---

### 2. Live Verification Commands

```bash
# Execute temporary cleaner in default active deletion mode (>7 days)
cd AS_09
./temp_cleaner.sh --delete

# Execute safe dry-run simulation mode (no files deleted)
./temp_cleaner.sh --dry-run

# Custom age threshold (e.g. 10 days)
./temp_cleaner.sh -d 10

# Emit structured JSON telemetry
./temp_cleaner.sh --json
```

---

### 3. Production Temporary File Automation Patterns

```bash
# systemd-tmpfiles configuration entry (/etc/tmpfiles.d/custom-tmp.conf)
# Type  Path     Mode  UID   GID   Age  Argument
# d     /tmp     1777  root  root  10d  -

# Run systemd-tmpfiles manual cleanup
sudo systemd-tmpfiles --clean

# Cron job entry for daily cleanup at 02:00 AM
# 0 2 * * * /usr/local/bin/temp_cleaner.sh -d 7 --delete >> /var/log/temp_cleaner.log 2>&1
```
