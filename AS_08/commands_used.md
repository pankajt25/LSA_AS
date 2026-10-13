# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #08: Large File Detection — Commands Reference

This document catalogs all core Linux system administration and storage triage commands utilized in the design, execution, verification, and reporting of `AS_08`.

---

### 1. Storage Inspection & Large File Identification

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `find <DIR> -type f -size +<THRESHOLD> -printf "%s\t%p\n"` | Recursively traverses directory tree, filtering files strictly larger than the threshold (`-type f -size +10M`), outputting size in bytes and path delimited by tab. |
| `sort -nr` | Sorts raw find output numerically in reverse (descending order), placing largest files at the top. |
| `awk '{sum += $1} END {print sum+0}'` | Computes cumulative byte consumption across all discovered large files in linear time. |
| `stat -c "%A %U %G %y" <FILE>` | Extracts detailed file metadata: POSIX permission string (`%A`), owning user (`%U`), owning group (`%G`), and modification timestamp (`%y`). |

---

### 2. Live Verification Commands

```bash
# Execute large file detector against live system logs for files exceeding 1 MB
cd AS_08
./large_file_detector.sh /var/log 1M

# Execute large file detector with top-10 limit
./large_file_detector.sh --dir /var/log --size 5M --limit 10

# Scan synthetic sandbox environment
./large_file_detector.sh --sandbox 5M

# Output structured JSON telemetry
./large_file_detector.sh /var/log 1M --json
```

---

### 3. Triage & Storage Remediation Commands

```bash
# Query systemd journal disk consumption
journalctl --disk-usage

# Vacuum older journal logs to cap storage at 200MB
sudo journalctl --vacuum-size=200M

# Vacuum journal logs older than 7 days
sudo journalctl --vacuum-time=7d

# Check logrotate status and force rotation
sudo logrotate -d /etc/logrotate.conf  # dry-run debug
sudo logrotate -f /etc/logrotate.conf  # force execution
```
