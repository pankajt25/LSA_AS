# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #36: Routine Server Maintenance & Cron Scheduling — Commands Reference

This document catalogs all core Linux system administration, routine maintenance, cron scheduling, buffer synchronization, and process audit commands utilized in the design, execution, verification, and reporting of `AS_36`.

---

### 1. Routine Server Maintenance Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `sync` | Flushes dirty filesystem buffers from RAM cache to underlying non-volatile storage blocks. |
| `find /tmp -maxdepth 2 -type f` | Audits stale temporary files and session caches across the temporary filesystem hierarchy. |
| `du -sh /tmp` / `du -sh /var/log` | Computes human-readable disk consumption for transient file directories. |
| `dpkg --audit` / `apt-get check` | Audits Debian/Ubuntu package management state for broken dependencies or unconfigured packages. |
| `journalctl --disk-usage` | Queries systemd journal storage footprint across active and archived service logs. |
| `free -m` | Inspects real-time physical memory allocation (total, used, free, buff/cache). |
| `ps -eo stat \| grep -c '^Z'` | Checks the Linux kernel process table for defunct/zombie processes awaiting reaping. |
| `df -hP /` | Audits root filesystem storage capacity, consumed percentage, and available space. |

---

### 2. Cron Automation & Management Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `crontab -l` | Lists the current user's active cron schedule table. |
| `crontab -` | Installs an updated crontab stream via standard input. |
| `crontab -r` | Removes the current user's entire crontab table. |
| `crontab -l \| grep -v '# LSA_SPRINT_TEST' \| crontab -` | Non-destructive teardown filter to remove test cron entries while preserving existing user jobs. |

---

### 3. Live Verification & Execution Commands

```bash
# Execute automated routine maintenance and launch HTML dashboard
cd AS_36
bash run.sh

# Run maintenance script directly on real host data
./routine_maintenance.sh --run

# Install cron schedule with custom frequency (e.g., 2:00 AM daily)
./routine_maintenance.sh --schedule "0 2 * * *"

# Verify active cron installation
./routine_maintenance.sh --verify-cron

# Safely unschedule cron job
./routine_maintenance.sh --unschedule

# Full cleanup and system restoration
bash cleanup.sh
```
