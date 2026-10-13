# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #11: Backup Verification — Commands Reference

This document catalogs all core Linux system administration and archive validation commands utilized in the design, execution, verification, and reporting of `AS_11`.

---

### 1. Archive Discovery, Integrity Testing & Checksumming

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `find <DIR> -maxdepth 1 -type f -name "*.tar.gz" -printf "%T@ %p\n" \| sort -nr \| head -n1` | Discovers the latest archive file in the repository by numerical modification timestamp sorting. |
| `test -s <FILE>` | Validates that the archive exists and has a size strictly greater than 0 bytes. |
| `tar -tzf <ARCHIVE.tar.gz>` | Performs non-destructive integrity check on gzip archive table of contents, catching corrupted block structures or truncated tar archives. |
| `tar -tvf <ARCHIVE.tar.gz>` | Reads and lists verbose manifest of files bundled inside the archive. |
| `sha256sum <ARCHIVE>` | Computes 256-bit SHA-256 cryptographic checksum. |
| `sha256sum -c <CHECKSUM_FILE>` | Cross-references archive against saved `.sha256` reference digest to detect data corruption or unauthorized modification. |
| `stat -c "%Y %y %s" <FILE>` | Extracts file modification epoch (`%Y`), human-readable timestamp (`%y`), and exact byte length (`%s`). |

---

### 2. Live Verification Commands

```bash
# Verify latest backup archive in default sandbox repository
cd AS_11
./backup_verifier.sh

# Explicit repository directory
./backup_verifier.sh ./sandbox_data/backups

# Verify specific candidate archive file directly
./backup_verifier.sh -f ./sandbox_data/backups/backup_prod_20261007_020000.tar.gz

# Output machine-readable JSON telemetry
./backup_verifier.sh --json
```

---

### 3. Production Disaster Recovery Verification Workflow

```bash
# Automated post-backup verification cron hook
# 30 2 * * * /usr/local/bin/backup_verifier.sh /var/backups >> /var/log/backup_verify.log 2>&1 || alert_admin.sh
```
