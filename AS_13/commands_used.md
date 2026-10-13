# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #13: Failed Login Audit — Commands Reference

This document catalogs all core Linux system administration, security auditing, log analysis, and text-processing commands utilized in the design, execution, verification, and reporting of `AS_13`.

---

### 1. Authentication Log Inspection & Text Processing

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `grep -iE "Failed (password\|publickey)\|authentication failure" <LOG>` | Filters security-critical failed authentication events across OpenSSH daemon variations. |
| `grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}'` | Extracts IPv4 addresses of source attack hosts using Perl-compatible lookbehind regex. |
| `awk '{ for (i=1; i<=NF; i++) { if ($i == "user") { print $(i+1); next } ... } }'` | Dynamically parses varied log syntax to isolate usernames targeted in invalid and valid account login attempts. |
| `sort \| uniq -c \| sort -nr` | Computes frequency aggregation, ranking offender IPs and targeted usernames by total failed attempt volume. |
| `grep -ci "invalid user" <LOG>` | Quantifies unauthorized user enumeration versus valid system credential guessing. |
| `journalctl _COMM=sshd --no-pager` | Queries systemd journald log stream for SSH daemon events when traditional file-based logs are absent. |

---

### 2. Live Verification Commands

```bash
# Execute failed login audit against live system logs (/var/log/auth.log)
cd AS_13
./failed_login_audit.sh

# Execute audit against synthetic brute-force attack drill dataset
./failed_login_audit.sh --sandbox

# Audit custom authentication log file
./failed_login_audit.sh /var/log/auth.log

# Output machine-readable JSON telemetry
./failed_login_audit.sh --json
```

---

### 3. Production Security Monitoring via Cron

```bash
# Automated hourly security audit logging and alerting
# 0 * * * * /usr/local/bin/failed_login_audit.sh >> /var/log/failed_login_audit.log 2>&1
```
