# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #35: Log Archival — Commands Reference

This document catalogs all core Linux system administration, log retention, archive packaging, compression algorithms, and cryptographic verification commands utilized in the design, execution, verification, and reporting of `AS_35`.

---

### 1. Log Packaging, Compression & Verification Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `tar -czf <archive>.tar.gz -C <dir> <files...>` | Creates a gzip-compressed tar archive from relative paths to avoid hardcoded root path structures. |
| `tar -tzf <archive>.tar.gz` | Non-destructive dry-run archive reading to test decompression integrity without extracting to disk. |
| `sha256sum <archive>.tar.gz > <archive>.sha256` | Generates cryptographic integrity verification hash for the completed archive. |
| `find <dir> -name "*.log" -mtime +30` | Discovers historical log files exceeding organization retention periods. |
| `tar -cjf` / `tar -cJf` | Bzip2 (`.tar.bz2`) and XZ (`.tar.xz`) compression alternatives for maximum byte reduction. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute automated log archival and launch HTML dashboard
cd AS_35
bash run.sh

# Run core script directly on default sandbox corporate logs
./log_archiver.sh

# Archive specific log directory
./log_archiver.sh --source /var/log/custom --output ./archives

# Select compression format (gz, bz2, or xz)
./log_archiver.sh --format bz2

# Filter logs older than N days (e.g. 7 days)
./log_archiver.sh --older-than 7

# Safely purge original logs after verified archival
./log_archiver.sh --purge

# Emit machine-readable JSON telemetry
./log_archiver.sh --json

# View usage manual
./log_archiver.sh --help
```

---

### 3. Production Log Archival via Cron

```bash
# Automated nightly log archival run at midnight
# 0 0 * * * /usr/local/bin/log_archiver.sh --source /var/log/apps --output /backup/log_archives --purge >> /var/log/nightly_archival.log 2>&1
```
