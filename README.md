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
├── AS_19/                          # Automation Sprint Problem #19
│   ├── high_cpu_detector.sh        # Core process monitoring & CPU detection script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_20/                          # Automation Sprint Problem #20
│   ├── high_memory_detector.sh     # Core process monitoring & memory detection script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_21/                          # Automation Sprint Problem #21
│   ├── connectivity_check.sh       # Core network monitoring & reachability script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_22/                          # Automation Sprint Problem #22
│   ├── multi_server_check.sh       # Core multi-server monitoring & reachability script
│   ├── servers.txt                 # Target server inventory configuration
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_23/                          # Automation Sprint Problem #23
│   ├── ip_config_report.sh         # Core network configuration audit script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── reports/                    # Timestamped network reports directory
│   └── README.md                   # Problem documentation & usage
├── AS_24/                          # Automation Sprint Problem #24
│   ├── ssh_service_check.sh        # Core SSH service & socket auditing script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log directory
│   └── README.md                   # Problem documentation & usage
├── AS_25/                          # Automation Sprint Problem #25
│   ├── port_check.sh               # Core TCP socket reachability & port auditing script
│   ├── run.sh                      # Unified cross-platform execution & report launcher
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Structured audit log & JSON telemetry directory
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
| **AS_19** | **High CPU Process Detection** | Real-time live process table inspection (`ps -eo ... --sort=-%cpu`), top-5 extraction, dynamic CPU alert thresholding (&ge; 50%), and dark-themed HTML report. | ✅ Completed | [`AS_19/`](./AS_19) |
| **AS_20** | **High Memory Process Detection** | Real-time live process table inspection (`ps -eo ... --sort=-%mem`), RSS MB conversion, `free -h` context, dynamic memory thresholding (&ge; 30%), and dark-themed HTML report. | ✅ Completed | [`AS_20/`](./AS_20) |
| **AS_21** | **Network Connectivity Check** | Automated gateway reachability test, public baseline sanity probing (`8.8.8.8`), ICMP loss/RTT grep-awk parsing, and dark-themed HTML report. | ✅ Completed | [`AS_21/`](./AS_21) |
| **AS_22** | **Multiple Server Check** | Inventory-based server reachability probing, OS ping flag adaptation, parallel subshell execution (`&` + `wait`), and dark-themed HTML report. | ✅ Completed | [`AS_22/`](./AS_22) |
| **AS_23** | **IP Configuration Report** | Hostname discovery (`hostname -I`), active interface auditing (`ip -br addr show up`), MAC/MTU extraction, default gateway parsing, `/etc/resolv.conf` DNS inspection, and dark-themed HTML report. | ✅ Completed | [`AS_23/`](./AS_23) |
| **AS_24** | **SSH Service Check** | Dynamic distribution service discovery ('ssh' vs 'sshd'), systemd active & boot persistence inspection, independent TCP port 22 socket cross-check, and dark-themed HTML report. | ✅ Completed | [`AS_24/`](./AS_24) |
| **AS_25** | **Port Availability Check** | Native Bash `/dev/tcp` network probing, resilient OpenBSD netcat fallback, active RST vs timeout differentiation, multi-port loop auditing, and dark-themed HTML report. | ✅ Completed | [`AS_25/`](./AS_25) |
| *Upcoming* | *Future Sprints* | Additional automation tasks and administration solutions. | ⏳ Planned | — |

---

## ⚡ Commands to Execute (Run & View HTML Reports)

Each project can be executed with a **single command** that automatically runs the automation script and immediately redirects/opens its interactive HTML report dashboard in your default browser. These commands natively support **Linux**, **macOS**, and **Windows** (WSL / Git Bash):

### 🌐 Universal One-Line Execution Table (Cross-Platform)

| Sprint | Project Title | Single Command to Execute & Open HTML Site (From Repo Root) |
|---|---|---|
| **AS_14** | Suspicious IP Detection | `cd AS_14 && ./suspicious_ip_detector.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } \|\| { command -v open >/dev/null && open report.html; } \|\| explorer.exe $(wslpath -w report.html 2>/dev/null \|\| echo report.html) 2>/dev/null \|\| python3 -m webbrowser report.html` |
| **AS_15** | Error Log Report | `cd AS_15 && ./error_log_report.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } \|\| { command -v open >/dev/null && open report.html; } \|\| explorer.exe $(wslpath -w report.html 2>/dev/null \|\| echo report.html) 2>/dev/null \|\| python3 -m webbrowser report.html` |
| **AS_16** | Service Availability Check | `cd AS_16 && ./service_availability_check.sh --report; { command -v xdg-open >/dev/null && xdg-open report.html; } \|\| { command -v open >/dev/null && open report.html; } \|\| explorer.exe $(wslpath -w report.html 2>/dev/null \|\| echo report.html) 2>/dev/null \|\| python3 -m webbrowser report.html` |
| **AS_17** | Automatic Service Recovery | `cd AS_17 && ./auto_service_recovery.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } \|\| { command -v open >/dev/null && open report.html; } \|\| explorer.exe $(wslpath -w report.html 2>/dev/null \|\| echo report.html) 2>/dev/null \|\| python3 -m webbrowser report.html` |
| **AS_18** | Server Process Check | `cd AS_18 && ./server_process_check.sh --default; { command -v xdg-open >/dev/null && xdg-open report.html; } \|\| { command -v open >/dev/null && open report.html; } \|\| explorer.exe $(wslpath -w report.html 2>/dev/null \|\| echo report.html) 2>/dev/null \|\| python3 -m webbrowser report.html` |
| **AS_19** | High CPU Process Detection | `cd AS_19 && bash run.sh` |
| **AS_20** | High Memory Process Detection | `cd AS_20 && bash run.sh` |
| **AS_21** | Network Connectivity Check | `cd AS_21 && bash run.sh` |
| **AS_22** | Multiple Server Check | `cd AS_22 && bash run.sh` |
| **AS_23** | IP Configuration Report | `cd AS_23 && bash run.sh` |
| **AS_24** | SSH Service Check | `cd AS_24 && bash run.sh` |
| **AS_25** | Port Availability Check | `cd AS_25 && bash run.sh` |

### 💻 Quick Command Reference by Operating System

| Sprint | 🐧 Linux (`xdg-open`) | 🍎 macOS (`open`) | 🪟 Windows WSL (`explorer.exe`) | 🪟 Windows Git Bash (`start`) |
|---|---|---|---|---|
| **AS_14** | `cd AS_14 && ./suspicious_ip_detector.sh; xdg-open report.html` | `cd AS_14 && ./suspicious_ip_detector.sh; open report.html` | `cd AS_14 && ./suspicious_ip_detector.sh; explorer.exe $(wslpath -w report.html)` | `cd AS_14 && ./suspicious_ip_detector.sh; start report.html` |
| **AS_15** | `cd AS_15 && ./error_log_report.sh; xdg-open report.html` | `cd AS_15 && ./error_log_report.sh; open report.html` | `cd AS_15 && ./error_log_report.sh; explorer.exe $(wslpath -w report.html)` | `cd AS_15 && ./error_log_report.sh; start report.html` |
| **AS_16** | `cd AS_16 && ./service_availability_check.sh --report; xdg-open report.html` | `cd AS_16 && ./service_availability_check.sh --report; open report.html` | `cd AS_16 && ./service_availability_check.sh --report; explorer.exe $(wslpath -w report.html)` | `cd AS_16 && ./service_availability_check.sh --report; start report.html` |
| **AS_17** | `cd AS_17 && ./auto_service_recovery.sh; xdg-open report.html` | `cd AS_17 && ./auto_service_recovery.sh; open report.html` | `cd AS_17 && ./auto_service_recovery.sh; explorer.exe $(wslpath -w report.html)` | `cd AS_17 && ./auto_service_recovery.sh; start report.html` |
| **AS_18** | `cd AS_18 && ./server_process_check.sh --default; xdg-open report.html` | `cd AS_18 && ./server_process_check.sh --default; open report.html` | `cd AS_18 && ./server_process_check.sh --default; explorer.exe $(wslpath -w report.html)` | `cd AS_18 && ./server_process_check.sh --default; start report.html` |
| **AS_19** | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` |
| **AS_20** | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` |
| **AS_21** | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` |
| **AS_22** | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` |
| **AS_23** | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` |
| **AS_24** | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` |
| **AS_25** | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` |

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
- `./suspicious_ip_detector.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || explorer.exe $(wslpath -w report.html)` — Single command to execute script and open HTML report (Linux / macOS / Windows)
- `./suspicious_ip_detector.sh` — Auto-detects real auth log (`/var/log/auth.log`) with default threshold (&ge; 5)
- `./suspicious_ip_detector.sh 3` — Auto-detects real auth log with custom threshold (&ge; 3)
- `./suspicious_ip_detector.sh ./test_auth.log 5` — Explicit override against synthetic test data labeled as demonstration fallback
- `./suspicious_ip_detector.sh --help` — Displays command-line manual and option syntax

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
- `./error_log_report.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || explorer.exe $(wslpath -w report.html)` — Single command to execute analysis and open HTML report (Linux / macOS / Windows)
- `./error_log_report.sh` — Auto-detects and analyzes live `/var/log/syslog`
- `./error_log_report.sh /var/log/syslog` — Explicit override for system log inspection
- `./error_log_report.sh ./sample_syslog.log` — Fallback run on labeled synthetic demonstration data
- `./error_log_report.sh --help` — Displays command-line help manual

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
- `./service_availability_check.sh --report; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || explorer.exe $(wslpath -w report.html)` — Single command to inspect service, update dashboard, and open HTML report (Linux / macOS / Windows)
- `./service_availability_check.sh` — Inspect default active service (`cron`)
- `./service_availability_check.sh rsync` — Inspect inactive/disabled service (exit code 1)
- `./service_availability_check.sh apparmor` — Inspect enabled-but-inactive service (amber status card)
- `./service_availability_check.sh not-a-real-service` — Detect nonexistent service (exit code 2)
- `./service_availability_check.sh cron --report` — Generate and refresh standalone HTML dashboard (`report.html`)

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
- `./auto_service_recovery.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || explorer.exe $(wslpath -w report.html)` — Single command to execute recovery monitor and open HTML report (Linux / macOS / Windows)
- `./auto_service_recovery.sh` — Checks default target (`dummy-test`), confirms healthy state if active
- `sudo systemctl stop dummy-test` — Simulates service outage for failure injection testing
- `./auto_service_recovery.sh` — Detects inactive state, triggers restart, waits 2s, and verifies recovery
- `./auto_service_recovery.sh nonexistent-service` — Tests error handling against invalid unit (exit code 1)

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
- `./server_process_check.sh --default; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || explorer.exe $(wslpath -w report.html)` — Single command to inspect process and open HTML report (Linux / macOS / Windows)
- `./server_process_check.sh bash` — Check running process (reports PIDs, instance count, and oldest uptime)
- `./server_process_check.sh not-a-real-proc-xyz` — Check nonexistent process (reports stopped state, exit code 1)
- `./server_process_check.sh` — Traps missing arguments with usage error (exit code 2)
- `./server_process_check.sh -s BASH` — Strict case-sensitive match verification

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_18/report.html`](./AS_18/report.html)
- 📖 **Sprint Documentation:** [`AS_18/README.md`](./AS_18/README.md)

</details>

<details>
<summary><strong>AS_19 — High CPU Process Detection (Live System Data)</strong></summary>

### Problem Statement
Develop a script to identify the top five processes consuming CPU resources.

### Summary of Approach
- **Direct Live Process Query:** Retrieves real system CPU data using `ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu` (Linux GNU ps) and `ps -eo ... -r` (macOS BSD ps), ensuring instantaneous kernel-level sorting without external pipe race conditions or broken column formatting.
- **Why This Column Set:** Queries `pid` for unique process identification, `ppid` to trace process tree lineage (systemd, cron, container, interactive shell), `user` to distinguish daemon vs unprivileged workloads, `%cpu` for utilization ranking, `%mem` to correlate memory thrashing or leaks, and `comm` for uniform fixed-width column alignment.
- **Awk Floating-Point Threshold Evaluation:** Avoids Bash integer arithmetic truncation bugs by delegating numerical checks to `awk`, accurately detecting and flagging processes exceeding a configurable threshold (`THRESHOLD=50.0%`).
- **Flexible Argument Parsing:** Supports `-n <count>` (custom display count), `-t <threshold>` (custom alert trigger), `-l <logfile>`, and `-h` (`--help`), backed by strict regex validation.
- **Persistent Chronological Audit Logging:** Appends every scan with timestamp, hostname, OS, kernel, system load averages, total process counts, and peak CPU to `logs/high_cpu.log`.
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the detector, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to execute detector, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./high_cpu_detector.sh` — Inspect top 5 CPU processes with default 50.0% threshold
- `./high_cpu_detector.sh -n 3 -t 20.0` — Inspect top 3 processes with sensitive 20.0% alert threshold
- `./high_cpu_detector.sh -n invalid` — Validates defensive argument error trapping (exit code 2)
- `./high_cpu_detector.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_19/report.html`](./AS_19/report.html)
- 📖 **Sprint Documentation:** [`AS_19/README.md`](./AS_19/README.md)
- 📜 **Audit Report Output:** [`AS_19/logs/high_cpu.log`](./AS_19/logs/high_cpu.log)

</details>

<details>
<summary><strong>AS_20 — High Memory Process Detection (Live System Data)</strong></summary>

### Problem Statement
Develop a script to identify the top five processes consuming memory.

### Summary of Approach
- **Direct Live Memory Process Query:** Retrieves real system memory data using `ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem` (Linux GNU ps) and `ps -eo ... -m` (macOS BSD ps), ensuring instantaneous in-memory descending sort without external pipe race conditions or broken column formatting.
- **Why This Column Set:** Queries `pid` for unique process identification, `ppid` to trace process tree lineage (systemd, cron, container, interactive shell), `user` to distinguish daemon vs unprivileged workloads, `%mem` for relative memory ranking, `%cpu` to detect runaway execution or memory thrashing loops, `rss` for exact physical RAM footprint, and `comm` for uniform fixed-width column alignment.
- **Why RSS is Included Alongside %MEM:** `%mem` is relative (`RSS / Total_RAM * 100`) and fails to convey real physical scale across diverse machine capacities (e.g. 10% on a 2 GB machine is 200 MB, while 10% on 256 GB is 25.6 GB). Resident Set Size (`rss`) measures the exact amount of hardware RAM (in KB) held in physical pages, excluding swap and virtual allocations. Converting `rss` to human-readable MB alongside `%mem` gives complete diagnostic context.
- **Overall System Memory Context (`free -h`):** Displays overall total, used, free, shared, buff/cache, and available memory alongside the top-5 table so process numbers have immediate system-wide context.
- **Awk Floating-Point Threshold Evaluation:** Avoids Bash integer arithmetic truncation bugs by delegating numerical checks to `awk`, accurately detecting and flagging processes exceeding a configurable threshold (`MEM_THRESHOLD=30.0%`).
- **Flexible Argument Parsing:** Supports `-n <count>` (custom display count), `-t <threshold>` (custom alert trigger), `-l <logfile>`, and `-h` (`--help`), backed by strict regex validation.
- **Persistent Chronological Audit Logging:** Appends every scan with timestamp, hostname, OS, kernel, system load averages, memory context (`free -h`), top processes, and peak %MEM to `logs/high_memory.log`.
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the detector, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to execute detector, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./high_memory_detector.sh` — Inspect top 5 memory processes with default 30.0% threshold
- `./high_memory_detector.sh -n 3 -t 5.0` — Inspect top 3 processes with sensitive 5.0% alert threshold
- `./high_memory_detector.sh -n invalid` — Validates defensive argument error trapping (exit code 2)
- `./high_memory_detector.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_20/report.html`](./AS_20/report.html)
- 📖 **Sprint Documentation:** [`AS_20/README.md`](./AS_20/README.md)
- 📜 **Audit Report Output:** [`AS_20/logs/high_memory.log`](./AS_20/logs/high_memory.log)

</details>

<details>
<summary><strong>AS_21 — Network Connectivity Check (Live System Data)</strong></summary>

### Problem Statement
An organization wants to periodically verify connectivity to its gateway/server. Write a script using `ping` and report whether the host is reachable.

### Summary of Approach
- **Automated Default Gateway Discovery:** Automatically identifies the system's live next-hop gateway using `ip route | grep default | awk '{print $3}'` (Linux), with cross-platform fallback logic for macOS (`route -n get default`) and Windows (`netstat -rn` / PowerShell).
- **Dual-Target Sanity Triangulation:** Pings both the local gateway and a resilient public Anycast reference (`8.8.8.8`) to distinguish between "Gateway down", "Local LAN only / ISP outage", "ICMP-filtered gateway (common on WSL2 virtual switch and enterprise firewalls)", and "Full connectivity".
- **Strictly Bounded Probes:** Executes a bounded number of ICMP echo requests (`ping -c 4 -W 2` on Linux/macOS, `-n 4` on Windows), preventing unbounded hangs or runaway background processes.
- **Precision Grep/Awk Extraction:** Extracts transmitted packets, received packets, packet loss percentage, and round-trip time (Min, Avg, Max RTT) from raw ping output rather than dumping unparsed text.
- **Clear Status Messages:** Outputs standardized status lines: `✅ Gateway 192.168.x.x is REACHABLE (0% loss, avg 2.1ms)` or `❌ Gateway 192.168.x.x is UNREACHABLE (100% loss)`.
- **Persistent Chronological Audit Logging:** Appends every scan with timestamp, hostname, OS, kernel, target metrics, baseline metrics, and diagnostic evaluation to `logs/connectivity.log`.
- **Single Cross-Platform Launcher (`run.sh`):** Executes `connectivity_check.sh`, captures live output, regenerates `report.html` from scratch using live system telemetry, and auto-launches the dark-themed dashboard in the default browser across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to execute connectivity check, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./connectivity_check.sh` — Default scan: auto-detects gateway and tests against baseline 8.8.8.8
- `./connectivity_check.sh 1.1.1.1` — Probes custom target 1.1.1.1 alongside sanity baseline 8.8.8.8
- `./connectivity_check.sh -c 2 -b 1.0.0.1` — Sends 2 pings and uses 1.0.0.1 as sanity baseline
- `./connectivity_check.sh fake.domain.test.invalid` — Validates defensive DNS resolution error trapping
- `./connectivity_check.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_21/report.html`](./AS_21/report.html)
- 📖 **Sprint Documentation:** [`AS_21/README.md`](./AS_21/README.md)
- 📜 **Audit Report Output:** [`AS_21/logs/connectivity.log`](./AS_21/logs/connectivity.log)

</details>

<details>
<summary><strong>AS_22 — Multiple Server Check (Live System Data)</strong></summary>

### Problem Statement
An administrator maintains a list of servers. Develop a script that checks connectivity to every server and reports UP/DOWN status.

### Summary of Approach
- **Config-Driven Target Inventory:** Reads server targets from `servers.txt` with support for full-line comments (`#`), inline role descriptions, blank lines, and dynamic `GATEWAY` keyword resolution to the live default gateway.
- **High-Concurrency Parallel Probing:** Executes ICMP echo requests concurrently by backgrounding subshells (`&`) into numbered slot files and synchronizing via Bash `wait`. Drastically reduces wall-clock execution time from $O(N \times \text{timeout})$ (~16s) down to $O(\text{timeout})$ (~3–4s).
- **Sequential Fallback Mode:** Provides `--sequential` (`-s`) execution flag for resource-constrained or embedded environments where ICMP socket contention or file descriptor limits are a concern.
- **Cross-Platform OS Synthesis:** Automatically adapts ping count and timeout parameters across Linux (`ping -c 2 -W 2`), macOS (`ping -c 2 -t 2`), and Windows native (`ping -n 2 -w 2000`).
- **Precision Grep/Awk Extraction:** Robustly parses raw ping output for packet loss %, average RTT, min/max latency, and transmitted/received packet counts.
- **Formatted Terminal Table & Badges:** Outputs clean ASCII-aligned table with colorized status badges (`[  UP  ]` in green, `[ DOWN ]` in red).
- **Persistent Chronological Audit Logging:** Appends every scan run with timestamps, metadata, and per-server telemetry to `logs/multi_server_check.log`.
- **Single Cross-Platform Launcher (`run.sh`):** Executes `multi_server_check.sh`, captures live terminal output, regenerates `report.html` from scratch using live system telemetry, and auto-launches the dark-themed dashboard across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to execute multi-server check, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./multi_server_check.sh` — Default parallel scan across all targets in `servers.txt`
- `./multi_server_check.sh -s` — Executes sequential serial scan across inventory
- `./multi_server_check.sh -c 3 -w 1` — Sends 3 packets per target with 1-second timeout
- `./multi_server_check.sh -f custom_hosts.txt` — Probes a custom server inventory configuration file
- `./multi_server_check.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_22/report.html`](./AS_22/report.html)
- 📖 **Sprint Documentation:** [`AS_22/README.md`](./AS_22/README.md)
</details>

<details>
<summary><strong>AS_23 — IP Configuration Report (Live System Data)</strong></summary>

### Problem Statement
Create a script that displays the hostname, IP address, active interfaces, and default gateway of a Linux system.

### Summary of Approach
- **Modern `iproute2` Subsystem Architecture:** Interacts directly with the Linux kernel networking stack via Netlink sockets (`AF_NETLINK`), avoiding legacy synchronous `ioctl()` syscall overhead and outdated `net-tools` (`ifconfig`/`route`) deprecation issues.
- **Precision Host Identification:** Queries system hostname and all assigned IPv4 addresses in a concise one-line summary via `hostname -I` with robust fallback parsing.
- **Active Interface Auditing:** Extracts active network adapters using `ip -br addr show up` (or tokenized `ip addr show` fallback), isolating operational status, loopback devices, and physical/virtual adapters.
- **Per-Interface Hardware & MTU Metrics:** Queries MAC hardware addresses (`ip link show <iface>`) and Maximum Transmission Unit (MTU) boundaries with sysfs fallback paths (`/sys/class/net/<iface>/address` and `mtu`).
- **Default Gateway & Routing Telemetry:** Inspects kernel routing tables via `ip route show default`, extracting gateway IP, egress interface, protocol, and route metrics.
- **DNS Resolver Discovery:** Parses active nameservers and domain search lists from `/etc/resolv.conf` with supplemental fallback to `resolvectl dns`.
- **Clean Formatted Terminal Report:** Displays aligned ASCII tables with ANSI status badges and exports unadorned text reports to `reports/ip_report_<timestamp>.txt` and pointer `latest_ip_report.txt`.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with live dark-themed metric cards, interactive interface tables, and auto-dispatches browser across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to audit live network config, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./ip_config_report.sh` — Default execution generating terminal table and timestamped report
- `./ip_config_report.sh --no-color` — Generates monochrome output for loggers or non-ANSI environments
- `./ip_config_report.sh --json` — Emits structured JSON telemetry to stdout
- `./ip_config_report.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_23/report.html`](./AS_23/report.html)
- 📖 **Sprint Documentation:** [`AS_23/README.md`](./AS_23/README.md)
- 📜 **Audit Report Output:** [`AS_23/reports/latest_ip_report.txt`](./AS_23/reports/latest_ip_report.txt)

</details>

<details>
<summary><strong>AS_24 — SSH Service Check (Live System Data)</strong></summary>

### Problem Statement
Write a script to verify whether SSH is running and display the current service status.

### Summary of Approach
- **Dynamic Cross-Distribution Service Discovery:** Intelligently discovers whether the target system uses Debian/Ubuntu convention (`ssh.service`) or RHEL/CentOS/Fedora convention (`sshd.service`) using `systemctl cat`, `systemctl list-unit-files`, unit `LoadState`, and `/etc/init.d/` checks. Never hardcodes a single name.
- **Runtime Active State Inspection:** Probes live running state via `systemctl is-active <service>`, differentiating between `active`, `inactive`, and `not-found`. Automatically engages `service <service> status` fallback when systemd is unavailable (WSL1, legacy, minimal containers).
- **Boot Persistence Verification:** Queries `systemctl is-enabled <service>` to verify if the daemon is registered to start on multi-user boot targets, with fallback SysV runlevel symlink inspection (`/etc/rc*.d/S*`).
- **Independent Network Socket Cross-Check:** Executes `ss -tlnp | grep :22` (with `ss -tln`, `netstat -tlnp`, and `lsof` fallbacks) with strict word-boundary regex (`:22\b`) to independently verify that a listening TCP socket is bound to port 22, catching edge cases where service reports active but socket is unbound.
- **Multi-State Status Synthesis:** Categorizes system health into `OPTIMAL`, `WARNING`, and `CRITICAL` tiers with clear, unambiguous human-readable banners and administrative remediation recommendations.
- **Persistent Chronological Audit Trail:** Appends timestamped audit traces for every check step and command to `logs/ssh_check.log` and structured telemetry to `logs/ssh_check.json`.
- **Defensive Error Handling:** Gracefully handles hosts where OpenSSH server is not installed, outputting a clear uninstalled message without crashing, and providing OS-specific installation commands.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with live dark-themed metric cards, inspection tables, and terminal execution log, automatically launching across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to audit SSH status, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./ssh_service_check.sh` — Default live SSH service audit on the current host
- `./ssh_service_check.sh --json` — Emits structured JSON telemetry to stdout
- `./ssh_service_check.sh -p 2222` — Probes a custom TCP port for hardened SSH configurations
- `./ssh_service_check.sh -s cron` — Tests diagnostic service override against active system daemon
- `./ssh_service_check.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_24/report.html`](./AS_24/report.html)
- 📖 **Sprint Documentation:** [`AS_24/README.md`](./AS_24/README.md)
- 📜 **Audit Log File:** [`AS_24/logs/ssh_check.log`](./AS_24/logs/ssh_check.log)

</details>

<details>
<summary><strong>AS_25 — Port Availability Check (Live Network Data)</strong></summary>

### Problem Statement
A system administrator wants to verify whether a specified server port is accessible. Develop a simple port-checking utility.

### Summary of Approach
- **Native Bash `/dev/tcp` Network Probing:** Leverages GNU Bash's built-in `/dev/tcp/$host/$port` virtual device redirection (`timeout 3 bash -c "echo > /dev/tcp/$host/$port"`), invoking kernel `socket()` and `connect()` system calls without external scanner overhead.
- **Portability Awareness & Netcat Fallback:** Documents the compile-time nature of `/dev/tcp` and its absence in POSIX `sh`/`dash`, seamlessly providing an automated fallback to OpenBSD netcat (`nc -zv -w3 <host> <port>`) in zero-I/O mode.
- **TCP Diagnostic State Classification:** Distinguishes between open sockets (`SYN-ACK` received, exit code 0), active connection resets (`RST` received, exit code 1), and packet-filtering firewall timeouts (exit code 124 from `timeout`), avoiding ambiguous closed states.
- **Multi-Port Sequential Auditing:** Supports auditing individual ports, comma-separated lists (`80,443,8080`), and space-separated argument vectors across a single target host via an internal verification loop.
- **Safe Out-of-the-Box Demo Mode:** Automatically runs a live demonstration suite against `localhost:22` (local closed/refused), `google.com:443` (remote open/reachable), and `google.com:12345` (remote filtered/timed-out) when invoked without arguments.
- **Persistent Chronological Audit Trail:** Appends timestamped audit traces for every probe event to `logs/port_check.log` and exports structured telemetry to `logs/port_check.json`.
- **Defensive Input Validation:** Validates port numbers strictly within integer bounds (1-65535) and verifies hostname resolvability through glibc resolver queries before network dispatch.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with live dark-themed metric cards, per-port status cards, diagnostic tables, and terminal execution log, automatically launching across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to audit live port reachability, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./port_check.sh` — Executes the default safe demonstration suite on live endpoints
- `./port_check.sh google.com 443` — Probes a single remote HTTPS port
- `./port_check.sh google.com 80,443,12345` — Audits a list of ports across one host via internal loop
- `./port_check.sh --nc google.com 443` — Forces probe execution via the Netcat fallback engine
- `./port_check.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_25/report.html`](./AS_25/report.html)
- 📖 **Sprint Documentation:** [`AS_25/README.md`](./AS_25/README.md)
- 📜 **Audit Log File:** [`AS_25/logs/port_check.log`](./AS_25/logs/port_check.log)

</details>

---

## 🛠️ General Guidelines

- All scripts are self-contained within their respective project directories (`AS_XX/`).
- Scripts adhere to defensive bash standards (`set -euo pipefail`), proper validation, and clear exit codes.
- Refer to individual project folders for setup instructions, command logs, and sample outputs.


