# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #33: Duplicate File Detection — Commands Reference

This document catalogs all core Linux system administration, cryptographic hashing, collision indexing, and storage recovery analysis commands utilized in the design, execution, verification, and reporting of `AS_33`.

---

### 1. Checksum Hashing & Duplicate Discovery Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `sha256sum <file>` | Computes 256-bit cryptographic digest ensuring collision-resistant file verification. |
| `md5sum <file>` | Fast legacy cryptographic checksumming suitable for rapid non-adversarial de-duplication. |
| `find <dir> -type f -exec sha256sum {} +` | Batch hashing invocation minimizing process fork overhead. |
| `find <dir> -type f -printf "%s %p\n" | sort -n` | Pre-groups filesystem items by byte length to prevent redundant hashing. |
| `sha256sum <files...> | sort | uniq -w64 -D` | Native coreutils pipeline isolating duplicates based on SHA-256 collision blocks. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute automated duplicate detection and launch HTML dashboard
cd AS_33
bash run.sh

# Run core script directly on live workspace repository
./duplicate_file_detector.sh

# Target custom directory path
./duplicate_file_detector.sh --dir /path/to/directory

# Use MD5 algorithm instead of SHA-256
./duplicate_file_detector.sh --algo md5

# Filter out small files below byte threshold (e.g., ignore < 1024 bytes)
./duplicate_file_detector.sh --min-size 1024

# Audit simulated multi-folder sandbox dataset
./duplicate_file_detector.sh --sandbox

# Emit machine-readable JSON telemetry
./duplicate_file_detector.sh --json

# View usage manual
./duplicate_file_detector.sh --help
```

---

### 3. Production Deduplication via Cron

```bash
# Automated weekly storage hygiene scan
# 0 2 * * 0 /usr/local/bin/duplicate_file_detector.sh --dir /var/data --json >> /var/log/dup_storage_audit.log 2>&1
```
