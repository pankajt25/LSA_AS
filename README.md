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
| **AS_14** | **Suspicious IP Detection** | Automated SSH brute-force monitor, regex parsing, descending frequency ranking, and timestamped audit reporting. | ✅ Completed | [`AS_14/`](./AS_14) |
| **AS_15** | **Error Log Report** | Automated error extraction with severity categorization, frequency ranking, distribution bars, and tail-style review. | ✅ Completed | [`AS_15/`](./AS_15) |
| **AS_16** | **Service Availability Check** | Real-time service monitoring, boot persistence verification, systemd/SysV fallback, audit logging, and dark-themed HTML report dashboard. | ✅ Completed | [`AS_16/`](./AS_16) |
| **AS_17** | **Automatic Service Recovery** | Automated service health probing, dead/inactive remediation with safe delays, post-restart active state verification, and dark-themed before/after report. | ✅ Completed | [`AS_17/`](./AS_17) |
| **AS_18** | **Server Process Check** | Process verification via `pgrep -f`, case-sensitivity flags, regex escaping, PID & oldest uptime inspection, and dark-themed HTML report. | ✅ Completed | [`AS_18/`](./AS_18) |
| *Upcoming* | *Future Sprints* | Additional automation tasks and administration solutions. | ⏳ Planned | — |

---

## 🔍 Sprint Deep Dives

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

