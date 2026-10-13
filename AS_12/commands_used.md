# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #12: Old Backup Cleanup — Commands Reference

This document catalogs all core Linux system administration and archive retention commands utilized in the design, execution, verification, and reporting of `AS_12`.

---

### 1. Archive Retention, Age Filtering & Storage Pruning

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `find <DIR> -maxdepth 1 -type f -name "*.tar.gz" -printf "%T@\t%s\t%p\n"` | Recursively surveys archive candidates, returning float epoch timestamps, raw byte sizes, and paths delimited by tab. |
| `sort -nr` | Orders archives from newest to oldest for retention policy evaluation. |
| `stat -c "%Y %y %s" <FILE>` | Obtains exact modification epoch and human timestamp for precise day-age calculation. |
| `rm -f <ARCHIVE>` | Safely unlinks expired archive files exceeding retention SLA. |
| `rm -f <ARCHIVE>.sha256` | Atomically purges companion checksum metadata when parent archive is removed, preventing orphaned metadata leaks. |
| `touch -d "<DAYS> days ago" <FILE>` | Backdates test archives to simulate historical retention lifecycles. |

---

### 2. Live Verification Commands

```bash
# Execute old backup cleanup in default active deletion mode (>7 days)
cd AS_12
./old_backup_cleaner.sh --delete

# Safe dry-run simulation mode (no files deleted)
./old_backup_cleaner.sh --dry-run

# Custom retention threshold (e.g. 14 days)
./old_backup_cleaner.sh -d 14

# Minimum guaranteed latest backups to preserve
./old_backup_cleaner.sh --keep-min 2 --delete

# Emit structured JSON telemetry
./old_backup_cleaner.sh --json
```

---

### 3. Production Lifecycle Scheduling via Cron

```bash
# Automated nightly retention pruning at 03:00 AM (following 02:00 AM backup window)
# 0 3 * * * /usr/local/bin/old_backup_cleaner.sh -d 7 --delete >> /var/log/backup_pruning.log 2>&1
```
