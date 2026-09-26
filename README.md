# LSA_AS — Linux System Administration (Automation Sprint)

Central repository for **Linux System Administration (E1ITA307)** Automation Sprint solutions and scripts.

---

## 📁 Repository Structure

```text
LSA_AS/
├── .gitignore
├── README.md
├── AS_14/                          # Automation Sprint Problem #14
│   ├── suspicious_ip_detector.sh   # Core bash script for IP detection
│   ├── commands_used.md            # Command log & viva preparation
│   ├── test_auth.log               # Synthetic test authentication log
│   ├── empty_auth.log              # Empty log edge-case test file
│   ├── reports/                    # Audit report logs
│   └── README.md                   # Problem documentation & usage
├── AS_15/                          # Automation Sprint Problem #15
│   ├── error_log_report.sh         # Core bash script for error log analysis
│   ├── commands_used.md            # Command log & viva preparation
│   ├── sample_syslog.log           # Synthetic test syslog
│   ├── clean_syslog.log            # Clean log edge-case test file
│   ├── empty_syslog.log            # Empty log edge-case test file
│   ├── reports/                    # Timestamped error reports
│   └── README.md                   # Problem documentation & usage
├── AS_16/                          # Automation Sprint Problem #16
│   ├── service_availability_check.sh # Core service monitoring & reporting script
│   ├── commands_used.md            # Command log & viva preparation
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail directory
│   └── README.md                   # Problem documentation & usage
├── AS_17/                          # Automation Sprint Problem #17
│   ├── auto_service_recovery.sh    # Core automated service recovery & monitoring script
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report (before/after comparison)
│   ├── logs/                       # Structured recovery audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_18/                          # Automation Sprint Problem #18
│   ├── server_process_check.sh     # Core process inspection & reporting script
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
└── (Upcoming Projects)/            # Future Automation Sprint additions
```

---

## 🚀 Projects Index

| Sprint / Problem | Title | Description | Status | Folder |
|---|---|---|---|---|
| **AS_14** | **Suspicious IP Detection** | Automated SSH brute-force monitor, real log auto-detection (`/var/log/auth.log`), regex parsing, descending ranking, and audit reporting. | ✅ Completed | [`AS_14/`](./AS_14) |
| **AS_15** | **Error Log Report** | Automated error extraction, real log auto-detection (`/var/log/syslog`), severity breakdown, frequency ranking, and tail-style review. | ✅ Completed | [`AS_15/`](./AS_15) |
| **AS_16** | **Service Availability Check** | Real-time service monitoring, boot persistence verification, systemd/SysV fallback, audit logging, and dark-themed HTML report dashboard. | ✅ Completed | [`AS_16/`](./AS_16) |
| **AS_17** | **Automatic Service Recovery** | Automated service health probing, dead/inactive remediation with safe delays, post-restart active state verification, and dark-themed before/after report. | ✅ Completed | [`AS_17/`](./AS_17) |
| **AS_18** | **Server Process Check** | Process verification via `pgrep -f`, case-sensitivity flags, regex escaping, PID & oldest uptime inspection, and dark-themed HTML report. | ✅ Completed | [`AS_18/`](./AS_18) |
| *Upcoming* | *Future Sprints* | Additional automation tasks and administration solutions. | ⏳ Planned | — |

---

## 🔍 Sprint Deep Dives

<details>
<summary><strong>AS_14 — Suspicious IP Detection (Real System Data)</strong></summary>

### Problem Statement
Detect suspicious IP addresses attempting brute-force attacks from SSH authentication logs. Identify repeated failed login attempts, rank offending IPs by aggression, and generate audit reports.

### Summary of Approach
- **Dynamic Real Log Auto-Detection:** Automatically discovers and parses the active live system authentication log source in precedence order:
  1. `/var/log/auth.log` (Debian/Ubuntu PAM and SSH authentication log)
  2. `/var/log/secure` (RHEL/CentOS/Rocky/Fedora authentication log)
  3. `journalctl -u ssh --no-pager` / `journalctl _COMM=sshd --no-pager` (systemd journald stream)
  4. Fallback: `test_auth.log` (strictly labeled as *"synthetic demonstration data — no real auth log was available on this system"*).
- **Precision PCRE Extraction:** Uses `grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}'` with keep-out `\K` lookbehind discard to extract IPv4 addresses regardless of log line column shifting (e.g. `invalid user`).
- **Descending Aggression Ranking:** Deduplicates and tallies failed attempts per IP with `sort | uniq -c | sort -nr` to present top threat actors first.
- **First Seen & Last Seen Timestamps:** Extracts chronological temporal bounds for flagged attackers.
- **Real Host Scan Finding:** Auto-detected `/var/log/auth.log`; confirmed 0 failed SSH attempts on the live host, providing valid clean-state reporting: *"No suspicious IP activity found in the current system logs"*.
- **Interactive Dashboard:** Complete dark-themed HTML report displaying live clean-state audit status and verification logs.

### Key Commands Used
- `./suspicious_ip_detector.sh` — Auto-detects real auth log (`/var/log/auth.log`) with default threshold (&ge; 5)
- `./suspicious_ip_detector.sh 3` — Auto-detects real auth log with custom threshold (&ge; 3)
- `./suspicious_ip_detector.sh ./test_auth.log 5` — Explicit override against synthetic test data labeled as demonstration fallback
- `./suspicious_ip_detector.sh --help` — Displays command-line manual and option syntax
- `explorer.exe $(wslpath -w report.html)` — View standalone HTML dashboard in browser

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_14/report.html`](./AS_14/report.html)
- 📖 **Sprint Documentation:** [`AS_14/README.md`](./AS_14/README.md)
- 📜 **Audit Report Output:** [`AS_14/reports/`](./AS_14/reports/)

</details>

<details>
<summary><strong>AS_15 — Error Log Report (Real System Data)</strong></summary>

### Problem Statement
Automate extraction, severity categorization, frequency ranking, and statistical reporting of error-relevant events from Linux system logs.

### Summary of Approach
- **Dynamic Real System Log Auto-Detection:** Automatically discovers and analyzes accessible live system logs in priority order:
  1. `/var/log/syslog` (Standard system log on Debian/Ubuntu)
  2. `/var/log/dpkg.log` (Package management log on Debian/Ubuntu)
  3. `/var/log/apt/history.log` (APT transaction history log)
  4. `journalctl --no-pager` (Systemd journald system log stream)
  5. Fallback: `sample_syslog.log` (strictly labeled as *"synthetic demonstration data — no real log was available on this system"*).
- **Single-Pass ERE Pattern Matching:** Compiles configurable keyword array (`error`, `fail`, `critical`, `fatal`, `warn`) into an Extended Regular Expression (`error|fail|critical|fatal|warn`) evaluated via `grep -i -E`.
- **Severity Breakdown & ASCII Visual Bars:** Computes individual keyword match counts, percentage share of errors, and renders dynamic ASCII distribution progress bars.
- **Robust Pipeline (SIGPIPE Fix):** Uses `sort | uniq -c | sort -rn | awk 'NR<=5'` instead of `head -n 5`, consuming input cleanly and preventing `SIGPIPE` (exit code 141) under `set -o pipefail` on large logs.
- **Real Host Scan Finding:** Auto-detected `/var/log/syslog` (937 KB, 7,611 lines); extracted 474 matching error/warning entries (6.23% error density) categorized across WARN (224), ERROR (171), FAIL (158), and FATAL (7).
- **Interactive Dashboard:** Complete dark-themed HTML report displaying real executive metrics, severity distribution, recurring patterns, and execution output.

### Key Commands Used
- `./error_log_report.sh` — Auto-detects and analyzes live `/var/log/syslog`
- `./error_log_report.sh /var/log/syslog` — Explicit override for system log inspection
- `./error_log_report.sh ./sample_syslog.log` — Fallback run on labeled synthetic demonstration data
- `./error_log_report.sh --help` — Displays command-line help manual
- `explorer.exe $(wslpath -w report.html)` — View standalone HTML dashboard in browser

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_15/report.html`](./AS_15/report.html)
- 📖 **Sprint Documentation:** [`AS_15/README.md`](./AS_15/README.md)
- 📜 **Audit Report Output:** [`AS_15/reports/`](./AS_15/reports/)

</details>

<details>
<summary><strong>AS_16 — Service Availability Check</strong></summary>

### Problem Statement
Monitor the operational availability and boot persistence of critical Linux services. Disambiguate active, inactive, failed, and missing units across init systems, and generate structured audit reports.

### Summary of Approach
- **Init Subsystem Detection & Fallback:** Senses whether PID 1 is managed by systemd (`/run/systemd/system`), gracefully falling back to `/usr/sbin/service <service> status` and `/etc/init.d/` inspections in non-systemd environments (WSL 1, containers, legacy SysV).
- **Defensive Unit State Disambiguation:** Evaluates `systemctl show -p LoadState` and `systemctl cat` to reliably distinguish between an inactive/stopped service and a completely nonexistent unit file.
- **Independent Boot Persistence Verification:** Queries `systemctl is-enabled` separately from runtime active state to determine if a service will launch on boot (`enabled`, `disabled`, `masked`, or `static`).
- **Structured Audit Logging:** Records every check invocation to `logs/service_check.log` with timestamp, init system, active status, boot persistence state, and exit code.
- **Telemetry & Standards:** Supports `--json` flag for automated CI/CD and monitoring pipelines with standardized exit codes (0 = Active, 1 = Inactive, 2 = Not Found, 3 = Error).
- **Interactive Dashboard:** Complete dark-themed HTML report (`report.html`) featuring color-coded status cards and an embedded toggleable audit log viewer.

### Key Commands Used
- `./service_availability_check.sh` — Inspect default active service (`cron`)
- `./service_availability_check.sh rsync` — Inspect inactive/disabled service (exit code 1)
- `./service_availability_check.sh apparmor` — Inspect enabled-but-inactive service (amber status card)
- `./service_availability_check.sh not-a-real-service` — Detect nonexistent service (exit code 2)
- `./service_availability_check.sh cron --report` — Generate and refresh standalone HTML dashboard (`report.html`)
- `explorer.exe $(wslpath -w report.html)` — View standalone HTML dashboard in browser

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_16/report.html`](./AS_16/report.html)
- 📖 **Sprint Documentation:** [`AS_16/README.md`](./AS_16/README.md)

</details>

<details>
<summary><strong>AS_17 — Automatic Service Recovery</strong></summary>

### Problem Statement
Develop a script that checks a specified service and restarts it automatically if it is not running.

### Summary of Approach
- **Automated Health Probing:** Inspects target unit status via `systemctl is-active`, immediately exiting cleanly (exit code 0) if the service is already healthy.
- **Automated Fault Remediation:** Intercepts dead, inactive, or failed services and triggers remediation restarts via `systemctl restart`, automatically elevating with `sudo` if run by an unprivileged user.
- **Post-Restart Stabilization Window:** Enforces a 2-second stabilization delay (`sleep 2`) post-restart to allow background processes to initialize or report immediate startup failure.
- **Post-Restart Verification:** Performs double verification by re-probing `systemctl is-active` post-restart rather than naively assuming command return codes indicate operational health.
- **Graceful Error Handling:** Cleanly catches unrecoverable errors (e.g., nonexistent or broken unit files) with exit code 1 and diagnostic stderr reporting.
- **Structured Audit Logging:** Logs every check and recovery event with timestamps, prior state, remedial action, and final state to `logs/recovery.log`.
- **Safe Sandboxing & Before/After Dashboard:** Conducted strictly against a non-destructive unit (`dummy-test.service`), generating a standalone dark-themed HTML report comparing real before-and-after terminal states.

### Key Commands Used
- `./auto_service_recovery.sh` — Checks default target (`dummy-test`), confirms healthy state if active
- `sudo systemctl stop dummy-test` — Simulates service outage for failure injection testing
- `./auto_service_recovery.sh` — Detects inactive state, triggers restart, waits 2s, and verifies recovery
- `./auto_service_recovery.sh nonexistent-service` — Tests error handling against invalid unit (exit code 1)
- `explorer.exe $(wslpath -w report.html)` — View standalone HTML dashboard in browser

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_17/report.html`](./AS_17/report.html)
- 📖 **Sprint Documentation:** [`AS_17/README.md`](./AS_17/README.md)

</details>

<details>
<summary><strong>AS_18 — Server Process Check</strong></summary>

### Problem Statement
An administrator wants to verify whether a particular application process is running. Create a script that reports its status.

### Summary of Approach
- **Direct `/proc` Query via `pgrep`:** Replaces brittle `ps aux | grep` pipelines with direct, self-match immune `pgrep -f` and `-i` filtering.
- **Defensive Regex Sanitization:** Escapes POSIX Extended Regular Expression (ERE) metacharacters using `sed` to safeguard against syntax crashes when querying names like `[kworker]` or `app(v1)`.
- **Accurate Oldest Instance & Uptime Inspection:** Evaluates all matching PIDs by elapsed runtime in seconds (`ps -o pid=,etimes=,etime=`), numerically sorting to isolate the oldest process and querying formatted runtime via `ps -o etime= -p <pid>`.
- **Configurable Matching Modes:** Defaults to case-insensitive partial match; enforces strict case-sensitivity via `-s` / `--strict`.
- **Structured Audit Logging:** Records every run (active, stopped, or error) to `logs/process_check.log`.
- **Interactive Dashboard:** Complete dark-themed HTML report with color-coded test cards and log viewer.

### Key Commands Used
- `./server_process_check.sh bash` — Check running process (reports PIDs, instance count, and oldest uptime)
- `./server_process_check.sh not-a-real-proc-xyz` — Check nonexistent process (reports stopped state, exit code 1)
- `./server_process_check.sh` — Traps missing arguments with usage error (exit code 2)
- `./server_process_check.sh -s BASH` — Strict case-sensitive match verification
- `explorer.exe $(wslpath -w report.html)` — View standalone HTML dashboard in browser

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_18/report.html`](./AS_18/report.html)
- 📖 **Sprint Documentation:** [`AS_18/README.md`](./AS_18/README.md)

</details>

---

## 🛠️ General Guidelines

- All scripts are self-contained within their respective project directories (`AS_XX/`).
- Scripts adhere to defensive bash standards (`set -euo pipefail`), proper validation, and clear exit codes.
- Refer to individual project folders for setup instructions, command logs, and sample outputs.

