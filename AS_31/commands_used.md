# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #31: User Login Audit — Commands Reference

This document catalogs all core Linux system administration, security auditing, PAM session inspection, utmp/wtmp queries, and log extraction commands utilized in the design, execution, verification, and reporting of `AS_31`.

---

### 1. User Session & Login Auditing Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `last -F -n 100` | Queries `/var/log/wtmp` binary records with full timestamps for chronological login/logout events. |
| `lastlog` | Inspects `/var/log/lastlog` returning the most recent login timestamp for all system accounts. |
| `who -a` / `who -u` | Queries active utmp sessions displaying line names, process IDs, and idle states. |
| `loginctl list-sessions` | Systemd PAM session manager query displaying live session IDs, user UIDs, and seat associations. |
| `grep "session opened" /var/log/auth.log` | Extracts PAM authentication session boundaries from system security logs. |
| `journalctl _COMM=sshd _COMM=login` | Systemd journal query extracting authentication events directly from journal storage. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute automated login audit and launch HTML dashboard
cd AS_31
bash run.sh

# Run core script directly on live host sessions and PAM logs
./user_login_audit.sh

# Filter audit by specific username
./user_login_audit.sh --user pankaj

# Show only remote network logins (e.g., SSH)
./user_login_audit.sh --remote

# Audit simulated enterprise multi-user scenario
./user_login_audit.sh --sandbox

# Emit machine-readable JSON telemetry
./user_login_audit.sh --json

# View usage manual
./user_login_audit.sh --help
```

---

### 3. Production Security Auditing via Cron

```bash
# Automated periodic user login security audit snapshot
# */30 * * * * /usr/local/bin/user_login_audit.sh --json >> /var/log/login_audit_history.log 2>&1
```
