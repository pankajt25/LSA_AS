# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #38: Scheduled Linux System Health Report via Cron — Commands Reference

This document catalogs all core Linux system administration, system load telemetry, memory diagnostics, filesystem audits, process metrics, and cron automation commands utilized in the design, execution, verification, and reporting of `AS_38`.

---

### 1. System Health Monitoring & Telemetry Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `uptime -p` / `cat /proc/loadavg` | Gathers human-readable system uptime duration and 1m, 5m, 15m CPU load averages. |
| `free -m` | Extracts physical RAM and swap space distribution (total, used, free, buff/cache, available). |
| `df -hP /` | Audits root filesystem storage capacity, consumed percentage, and remaining availability. |
| `ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu \| head -n 6` | Profiles top 5 CPU-intensive processes consuming processor time. |
| `ps -eo pid,user,%mem,rss,comm --sort=-%mem \| head -n 6` | Profiles top 5 memory-intensive processes consuming resident set size (RSS). |
| `ip -br addr show` | Queries active network interfaces, operational link states, and assigned IP configurations. |
| `nproc` / `grep -c ^processor /proc/cpuinfo` | Detects logical processor core count to contextualize load averages. |

---

### 2. Cron Scheduling Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `crontab -l` | Lists active crontab schedules configured for the executing user. |
| `crontab -` | Installs updated crontab file from standard input stream. |
| `crontab -l \| grep -v '# LSA_SPRINT_TEST' \| crontab -` | Safely removes test cron jobs while preserving other existing schedules. |

---

### 3. Live Verification & Execution Commands

```bash
# Execute automated health check, register cron, and launch HTML dashboard
cd AS_38
bash run.sh

# Run health report generation directly
./scheduled_health_report.sh --generate

# Configure cron schedule (e.g., every 30 minutes)
./scheduled_health_report.sh --schedule "*/30 * * * *"

# Verify active cron schedule
./scheduled_health_report.sh --verify-cron

# Unschedule health report cron job
./scheduled_health_report.sh --unschedule

# Teardown and restore system
bash cleanup.sh
```
