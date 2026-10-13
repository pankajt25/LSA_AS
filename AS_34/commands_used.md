# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #34: File Integrity Check — Commands Reference

This document catalogs all core Linux system administration, security auditing, baseline management, cryptographic hashing, and file integrity monitoring (FIM) commands utilized in the design, execution, verification, and reporting of `AS_34`.

---

### 1. Cryptographic Checksum & File Integrity Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `sha256sum <files...> > baseline.sha256` | Generates authoritative cryptographic baseline manifest for critical target files. |
| `sha256sum -c baseline.sha256` | Standard coreutils integrity verification comparing live files against baseline records. |
| `sha256sum -c --quiet baseline.sha256` | Filters output to alert exclusively on modified or failed checksum checks. |
| `find <dir> -type f -exec sha256sum {} +` | Traverses filesystem directories to generate recursive baseline checksum manifests. |
| `md5sum` / `sha512sum` | Alternative cryptographic hashing algorithms for multi-layer validation. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute automated file integrity verification and launch HTML dashboard
cd AS_34
bash run.sh

# Run core script directly on live system critical files
./file_integrity_checker.sh

# Generate or update the live system baseline manifest
./file_integrity_checker.sh --init

# Verify integrity against custom baseline manifest
./file_integrity_checker.sh --baseline /path/to/baseline.sha256 --dir /path/to/dir

# Audit simulated security tampering scenario (demonstrating all 4 integrity states)
./file_integrity_checker.sh --sandbox

# Emit machine-readable JSON telemetry
./file_integrity_checker.sh --json

# View usage manual
./file_integrity_checker.sh --help
```

---

### 3. Production Integrity Auditing via Cron

```bash
# Automated periodic integrity audit (runs every 6 hours)
# 0 */6 * * * /usr/local/bin/file_integrity_checker.sh --json >> /var/log/fim_audit.log 2>&1
```
