# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #37: Cron-Based Automated Project Backup — Commands Reference

This document catalogs all core Linux system administration, project backup packaging, checksum hashing, cron scheduling, and retention management commands utilized in the design, execution, verification, and reporting of `AS_37`.

---

### 1. Backup Packaging, Checksumming & Verification Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `tar -czf <archive>.tar.gz -C <parent> <folder>` | Generates a gzip-compressed archive using relative directory references to prevent stripping leading slashes. |
| `tar -tzf <archive>.tar.gz` | Executes non-destructive decompression dry-run testing to confirm archive integrity. |
| `sha256sum <archive> > <archive>.sha256` | Calculates cryptographic SHA-256 digest and serializes companion validation manifest. |
| `find <dest> -name "*.tar.gz" -mtime +14` | Discovers archives exceeding retention thresholds for automatic pruning. |
| `du -sb <dir>` / `stat -c %s <file>` | Measures byte footprints to calculate compression savings and ratio percentages. |

---

### 2. Cron Automation Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `crontab -l` | Inspects current user's active cron schedules. |
| `crontab -` | Ingests new crontab table from stdin. |
| `crontab -l \| grep -v '# LSA_SPRINT_TEST' \| crontab -` | Removes test cron jobs cleanly while preserving other existing schedules. |

---

### 3. Live Verification & Execution Commands

```bash
# Execute automated backup, register cron, and launch HTML dashboard
cd AS_37
bash run.sh

# Run standalone backup targeting specific directory
./scheduled_backup.sh --source /path/to/my_project --destination ./backups

# Install backup schedule in crontab (e.g., 01:00 AM nightly)
./scheduled_backup.sh --schedule "0 1 * * *"

# Verify active cron schedule
./scheduled_backup.sh --verify-cron

# Remove scheduled cron job
./scheduled_backup.sh --unschedule

# Teardown and restore system
bash cleanup.sh
```
