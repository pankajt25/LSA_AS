# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #10: Daily Backup — Commands Reference

This document catalogs all core Linux system administration and archive management commands utilized in the design, execution, verification, and reporting of `AS_10`.

---

### 1. Archiving, Compression & Integrity Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `tar -czf <ARCHIVE.tar.gz> -C <PARENT_DIR> <TARGET_DIR>` | Creates (`-c`) a gzip-compressed (`-z`) archive file (`-f`) changing directory (`-C`) to the parent to prevent absolute path security warnings during un-tarring. |
| `tar -tzf <ARCHIVE.tar.gz>` | Lists table of contents (`-t`) of gzip archive (`-z`), serving as a non-destructive read test to verify archive integrity. |
| `tar -tvf <ARCHIVE.tar.gz>` | Displays detailed verbose (`-v`) manifest including permissions, file sizes, owners, timestamps, and paths. |
| `sha256sum <ARCHIVE>` | Computes 256-bit cryptographic digest to verify data immutability and detect corruption or tampering. |
| `du -sb <DIR>` | Measures exact apparent byte size of directory tree prior to compression. |
| `stat -c "%s" <FILE>` | Returns byte size of compressed archive file. |

---

### 2. Live Verification Commands

```bash
# Execute daily backup using default sandbox project and backups folder
cd AS_10
./daily_backup.sh

# Explicit source and destination directories
./daily_backup.sh -s ./sandbox_data/project -d ./backups

# Custom bzip2 compression algorithm
./daily_backup.sh -c bzip2

# Verify checksum of created backup
sha256sum -c backups/backup_project_*.tar.gz.sha256

# Inspect archive contents without extracting
tar -tvf backups/backup_project_*.tar.gz

# Output machine-readable JSON telemetry
./daily_backup.sh --json
```

---

### 3. Production Scheduling via Cron

```bash
# Crontab schedule for automated nightly backup at 02:00 AM
# 0 2 * * * /usr/local/bin/daily_backup.sh -s /srv/app -d /var/backups >> /var/log/backup.log 2>&1
```
