# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #30: Logged-in User Report — Commands Reference

This document catalogs all core Linux system administration, user session auditing, terminal inspection, and idle monitoring commands utilized in the design, execution, verification, and reporting of `AS_30`.

---

### 1. User Session Auditing & Terminal Inspection

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `w -h` | Queries active utmp/wtmp records without headers, returning username, tty, remote IP, login time, idle duration, and foreground process. |
| `who -u` | Alternative session query displaying line status, terminal device, and process ID. |
| `loginctl list-sessions` | Systemd PAM session manager query displaying systemd session IDs, user UIDs, and seat associations. |
| `last` / `lastb` | Historical successful and bad login records from `/var/log/wtmp` and `/var/log/btmp`. |
| `uptime -p` | Returns human-friendly system uptime since previous kernel bootstrap. |

---

### 2. Live Verification Commands

```bash
# Execute automated user session monitoring and dashboard generation
cd AS_30
bash run.sh

# Run core script directly on live host sessions
./logged_in_users.sh

# Run audit on simulated enterprise multi-user scenario
./logged_in_users.sh --sandbox

# Emit machine-readable JSON telemetry
./logged_in_users.sh --json

# View usage manual
./logged_in_users.sh --help
```

---

### 3. Production Security Auditing via Cron

```bash
# Automated periodic user session snapshot logging
# */15 * * * * /usr/local/bin/logged_in_users.sh --json >> /var/log/user_sessions_history.log 2>&1
```
