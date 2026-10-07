# LSA_AS — Linux System Administration (Automation Sprint)

Central repository for **Linux System Administration (E1ITA307)** Automation Sprint solutions and scripts.

---

## 📁 Repository Structure

```text
LSA_AS/
├── .gitignore
├── README.md
├── AS_01/                          # Automation Sprint Problem #1
│   ├── employee_account_setup.sh   # Core batch employee provisioning script
│   ├── cleanup.sh                  # Safe environment teardown & restoration script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & viva preparation
│   ├── employees.csv               # Employee list dataset
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   └── README.md                   # Problem documentation & usage
├── AS_02/                          # Automation Sprint Problem #2
│   ├── inactive_employee_detector.sh # Core local account inactivity audit script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail directory
│   └── README.md                   # Problem documentation & usage
├── AS_03/                          # Automation Sprint Problem #3
│   ├── department_access.sh        # Core department group & shared folder permission script
│   ├── cleanup.sh                  # Safe environment teardown & group removal script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   ├── sandbox_data/               # Sandboxed shared folder data directory
│   └── README.md                   # Problem documentation & usage
├── AS_04/                          # Automation Sprint Problem #4
│   ├── permission_audit.sh         # Core world-writable security auditing script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   ├── sandbox_data/               # Multi-tier permission test dataset directory
│   └── README.md                   # Problem documentation & usage
├── AS_05/                          # Automation Sprint Problem #5
│   ├── ownership_audit.sh          # Core project administrator file ownership auditing script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   ├── sandbox_data/               # Simulated project codebase with multi-user file ownership
│   └── README.md                   # Problem documentation & usage
├── AS_06/                          # Automation Sprint Problem #6
│   ├── server_health_check.sh      # Core pre-workday server health monitoring script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   └── README.md                   # Problem documentation & usage
├── AS_07/                          # Automation Sprint Problem #7
│   ├── low_disk_space_alert.sh     # Core filesystem storage utilization & alert script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & development history
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   └── README.md                   # Problem documentation & usage
├── AS_08/                          # Automation Sprint Problem #8
│   ├── large_file_detector.sh      # Core storage inspection & large file detection script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & storage triage manual
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   ├── sandbox_data/               # Simulated large-file data environment
│   └── README.md                   # Problem documentation & usage
├── AS_09/                          # Automation Sprint Problem #9
│   ├── temp_cleaner.sh             # Core temporary file cleanup & storage hygiene script
│   ├── run.sh                      # Unified execution & HTML dashboard generator
│   ├── commands_used.md            # Command log & storage hygiene reference
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail & JSON telemetry directory
│   ├── sandbox_data/               # Aging test temporary directory tree
│   └── README.md                   # Problem documentation & usage
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
├── AS_26/                          # Automation Sprint Problem #26
│   ├── package_update_check.sh     # Cross-platform package manager update audit script
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
| **AS_01** | **Employee Account Setup** | Automated employee account provisioning (`useradd -m -c -g`), department group creation (`groupadd`), non-interactive forced first-login password expiration (`passwd -e`), sandboxed test isolation (`lsatest_`), and safe teardown (`cleanup.sh`). | ✅ Completed | [`AS_01/`](./AS_01) |
| **AS_02** | **Inactive Employee Detection** | Real local account discovery (`/etc/passwd`), human user filtering (`UID >= 1000`), multi-tier login history resolution (`lastlog` / `last` / `loginctl` fallback), configurable thresholding, and dark-themed HTML report. | ✅ Completed | [`AS_02/`](./AS_02) |
| **AS_03** | **Department Access** | Department group creation (`groupadd`), sandboxed shared directory provisioning (`chmod 2770`), SGID bit inheritance enforcement, zero non-member access (`---`), and safe teardown (`cleanup.sh`). | ✅ Completed | [`AS_03/`](./AS_03) |
| **AS_04** | **Permission Audit** | Automated world-writable file auditing (`find -type f -perm -0002`), risk severity classification, least-privilege compliance scoring, and dark-themed HTML report. | ✅ Completed | [`AS_04/`](./AS_04) |
| **AS_05** | **Ownership Audit** | Project administrator ownership verification (`find ! -user <admin>`), privilege drift classification (root/foreign/orphan), compliance ratio reporting, and dark-themed HTML report. | ✅ Completed | [`AS_05/`](./AS_05) |
| **AS_06** | **Server Health Check** | Comprehensive pre-workday system health monitoring covering CPU utilization, memory & swap allocation, storage use, system uptime, active logged-in sessions, and dark-themed HTML report. | ✅ Completed | [`AS_06/`](./AS_06) |
| **AS_07** | **Low Disk Space Alert** | Filesystem storage capacity auditing (`df -P`), dynamic threshold evaluation (&ge; 80%), critical severity classification, mitigation recommendations, and dark-themed HTML report. | ✅ Completed | [`AS_07/`](./AS_07) |
| **AS_08** | **Large File Detection** | Recursive filesystem tree inspection (`find -size +<threshold>`), numerical sorting (`sort -nr`), file ownership & timestamp extraction (`stat`), cumulative consumption tallying, and dark-themed HTML report. | ✅ Completed | [`AS_08/`](./AS_08) |
| **AS_09** | **Temporary File Cleanup** | Stale file aging evaluation (`stat` epoch / `find -mtime`), safe simulation dry-run (`--dry-run`), active unlinking (`rm -f`), empty tree pruning, and dark-themed HTML report. | ✅ Completed | [`AS_09/`](./AS_09) |
| **AS_14** | **Suspicious IP Detection** | Automated SSH brute-force monitor, real log auto-detection (`/var/log/auth.log`), regex parsing, descending ranking, and audit reporting. | ✅ Completed | [`AS_14/`](./AS_14)
| **AS_15** | **Error Log Report** | Automated error extraction, real log auto-detection (`/var/log/syslog`), severity breakdown, frequency ranking, and tail-style review. | ✅ Completed | [`AS_15/`](./AS_15)
| **AS_16** | **Service Availability Check** | Real-time service monitoring, boot persistence verification, systemd/SysV fallback, audit logging, and dark-themed HTML report dashboard. | ✅ Completed | [`AS_16/`](./AS_16)
| **AS_17** | **Automatic Service Recovery** | Automated service health probing, dead/inactive remediation with safe delays, post-restart active state verification, and dark-themed before/after report. | ✅ Completed | [`AS_17/`](./AS_17)
| **AS_18** | **Server Process Check** | Process verification via `pgrep -f`, case-sensitivity flags, regex escaping, PID & oldest uptime inspection, and dark-themed HTML report. | ✅ Completed | [`AS_18/`](./AS_18)
| **AS_19** | **High CPU Process Detection** | Real-time live process table inspection (`ps -eo ... --sort=-%cpu`), top-5 extraction, dynamic CPU alert thresholding (&ge; 50%), and dark-themed HTML report. | ✅ Completed | [`AS_19/`](./AS_19)
| **AS_20** | **High Memory Process Detection** | Real-time live process table inspection (`ps -eo ... --sort=-%mem`), RSS MB conversion, `free -h` context, dynamic memory thresholding (&ge; 30%), and dark-themed HTML report. | ✅ Completed | [`AS_20/`](./AS_20)
| **AS_21** | **Network Connectivity Check** | Automated gateway reachability test, public baseline sanity probing (`8.8.8.8`), ICMP loss/RTT grep-awk parsing, and dark-themed HTML report. | ✅ Completed | [`AS_21/`](./AS_21)
| **AS_22** | **Multiple Server Check** | Inventory-based server reachability probing, OS ping flag adaptation, parallel subshell execution (`&` + `wait`), and dark-themed HTML report. | ✅ Completed | [`AS_22/`](./AS_22)
| **AS_23** | **IP Configuration Report** | Hostname discovery (`hostname -I`), active interface auditing (`ip -br addr show up`), MAC/MTU extraction, default gateway parsing, `/etc/resolv.conf` DNS inspection, and dark-themed HTML report. | ✅ Completed | [`AS_23/`](./AS_23)
| **AS_24** | **SSH Service Check** | Dynamic distribution service discovery ('ssh' vs 'sshd'), systemd active & boot persistence inspection, independent TCP port 22 socket cross-check, and dark-themed HTML report. | ✅ Completed | [`AS_24/`](./AS_24)
| **AS_25** | **Port Availability Check** | Native Bash `/dev/tcp` network probing, resilient OpenBSD netcat fallback, active RST vs timeout differentiation, multi-port loop auditing, and dark-themed HTML report. | ✅ Completed | [`AS_25/`](./AS_25)
| **AS_26** | **Package Update Check** | Dynamic package manager detection (`apt`, `dnf`, `brew`, `pacman`, `zypper`), safe read-only index refresh, package version extraction, security vs standard classification, and dark-themed HTML report. | ✅ Completed | [`AS_26/`](./AS_26)
| *Upcoming* | *Future Sprints* | Additional automation tasks and administration solutions. | ⏳ Planned | — |

---

## ⚡ Commands to Execute (Run & View HTML Reports)

Each project can be executed with a **single command** that automatically runs the automation script and immediately redirects/opens its interactive HTML report dashboard in your default browser. These commands natively support **Linux**, **macOS**, and **Windows** (WSL / Git Bash):

### 🌐 Universal One-Line Execution Table (Cross-Platform)

| Sprint | Project Title | Single Command to Execute & Open HTML Site (From Repo Root) |
|---|---|---|
| **AS_01** | Employee Account Setup | `cd AS_01 && bash run.sh` *(Run `bash cleanup.sh` afterward to restore system)* |
| **AS_02** | Inactive Employee Detection | `cd AS_02 && bash run.sh` |
| **AS_03** | Department Access | `cd AS_03 && bash run.sh` *(Run `bash cleanup.sh` afterward to restore system)* |
| **AS_04** | Permission Audit | `cd AS_04 && bash run.sh` |
| **AS_05** | Ownership Audit | `cd AS_05 && bash run.sh` |
| **AS_06** | Server Health Check | `cd AS_06 && bash run.sh` |
| **AS_07** | Low Disk Space Alert | `cd AS_07 && bash run.sh` |
| **AS_08** | Large File Detection | `cd AS_08 && bash run.sh` |
| **AS_09** | Temporary File Cleanup | `cd AS_09 && bash run.sh` |
| **AS_14** | Suspicious IP Detection | `cd AS_14 && bash run.sh` |
| **AS_15** | Error Log Report | `cd AS_15 && bash run.sh` |
| **AS_16** | Service Availability Check | `cd AS_16 && bash run.sh` |
| **AS_17** | Automatic Service Recovery | `cd AS_17 && bash run.sh` |
| **AS_18** | Server Process Check | `cd AS_18 && bash run.sh` |
| **AS_19** | High CPU Process Detection | `cd AS_19 && bash run.sh` |
| **AS_20** | High Memory Process Detection | `cd AS_20 && bash run.sh` |
| **AS_21** | Network Connectivity Check | `cd AS_21 && bash run.sh` |
| **AS_22** | Multiple Server Check | `cd AS_22 && bash run.sh` |
| **AS_23** | IP Configuration Report | `cd AS_23 && bash run.sh` |
| **AS_24** | SSH Service Check | `cd AS_24 && bash run.sh` |
| **AS_25** | Port Availability Check | `cd AS_25 && bash run.sh` |
| **AS_26** | Package Update Check | `cd AS_26 && bash run.sh` |

### 💻 Quick Command Reference by Operating System

| Sprint | 🐧 Linux (`xdg-open`) | 🍎 macOS (`open`) | 🪟 Windows WSL (`explorer.exe`) | 🪟 Windows Git Bash (`start`) |
|---|---|---|---|---|
| **AS_01** | `cd AS_01 && bash run.sh` | `cd AS_01 && bash run.sh` | `cd AS_01 && bash run.sh` | `cd AS_01 && bash run.sh` |
| **AS_02** | `cd AS_02 && bash run.sh` | `cd AS_02 && bash run.sh` | `cd AS_02 && bash run.sh` | `cd AS_02 && bash run.sh` |
| **AS_03** | `cd AS_03 && bash run.sh` | `cd AS_03 && bash run.sh` | `cd AS_03 && bash run.sh` | `cd AS_03 && bash run.sh` |
| **AS_04** | `cd AS_04 && bash run.sh` | `cd AS_04 && bash run.sh` | `cd AS_04 && bash run.sh` | `cd AS_04 && bash run.sh` |
| **AS_05** | `cd AS_05 && bash run.sh` | `cd AS_05 && bash run.sh` | `cd AS_05 && bash run.sh` | `cd AS_05 && bash run.sh` |
| **AS_06** | `cd AS_06 && bash run.sh` | `cd AS_06 && bash run.sh` | `cd AS_06 && bash run.sh` | `cd AS_06 && bash run.sh` |
| **AS_07** | `cd AS_07 && bash run.sh` | `cd AS_07 && bash run.sh` | `cd AS_07 && bash run.sh` | `cd AS_07 && bash run.sh` |
| **AS_08** | `cd AS_08 && bash run.sh` | `cd AS_08 && bash run.sh` | `cd AS_08 && bash run.sh` | `cd AS_08 && bash run.sh` |
| **AS_09** | `cd AS_09 && bash run.sh` | `cd AS_09 && bash run.sh` | `cd AS_09 && bash run.sh` | `cd AS_09 && bash run.sh` |
| **AS_14** | `cd AS_14 && bash run.sh` | `cd AS_14 && bash run.sh` | `cd AS_14 && bash run.sh` | `cd AS_14 && bash run.sh` |
| **AS_15** | `cd AS_15 && bash run.sh` | `cd AS_15 && bash run.sh` | `cd AS_15 && bash run.sh` | `cd AS_15 && bash run.sh` |
| **AS_16** | `cd AS_16 && bash run.sh` | `cd AS_16 && bash run.sh` | `cd AS_16 && bash run.sh` | `cd AS_16 && bash run.sh` |
| **AS_17** | `cd AS_17 && bash run.sh` | `cd AS_17 && bash run.sh` | `cd AS_17 && bash run.sh` | `cd AS_17 && bash run.sh` |
| **AS_18** | `cd AS_18 && bash run.sh` | `cd AS_18 && bash run.sh` | `cd AS_18 && bash run.sh` | `cd AS_18 && bash run.sh` |
| **AS_19** | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` | `cd AS_19 && bash run.sh` |
| **AS_20** | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` | `cd AS_20 && bash run.sh` |
| **AS_21** | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` | `cd AS_21 && bash run.sh` |
| **AS_22** | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` | `cd AS_22 && bash run.sh` |
| **AS_23** | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` | `cd AS_23 && bash run.sh` |
| **AS_24** | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` | `cd AS_24 && bash run.sh` |
| **AS_25** | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` | `cd AS_25 && bash run.sh` |
| **AS_26** | `cd AS_26 && bash run.sh` | `cd AS_26 && bash run.sh` | `cd AS_26 && bash run.sh` | `cd AS_26 && bash run.sh` |

---

## 🔍 Sprint Deep Dives

<details>
<summary><strong>AS_01 — Employee Account Setup (User Management & Group Provisioning)</strong></summary>

### Problem Statement
A company has a list of new employees. Write a Bash script to create Linux user accounts from a given employee list (`employees.csv`) and assign them to the appropriate department group.

### Summary of Approach
- **Strict Test Sandboxing:** Enforces mandatory `lsatest_` prefix validation on all usernames (`^lsatest_[a-zA-Z0-9_]+$`) to strictly isolate test operations and prevent collisions or modifications to real human/system user accounts.
- **Dynamic Department Group Auditing:** Inspects departmental group existence via `getent group <dept>`, provisioning missing groups dynamically with `sudo groupadd <dept>`.
- **Pre-Existing Account Check:** Checks `/etc/passwd` and `getent passwd <user>` before provisioning, skipping pre-existing accounts with `[SKIPPED]` status without terminating the batch loop.
- **Robust User Creation (`useradd`):** Executes `sudo useradd -m -c "<fullname>" -g <dept> <username>`, creating user home directories from `/etc/skel` skeleton profiles (`-m`), setting GECOS comment fields (`-c`), and configuring primary departmental groups (`-g`).
- **Non-Interactive Password & Forced First-Login Reset:** Provisions initial temporary passwords securely via `echo "<user>:<pass>" | sudo chpasswd` and enforces immediate expiration via `sudo passwd -e <username>` (or `sudo chage -d 0`), forcing Linux PAM to intercept first logins for password change.
- **Multi-Vector Verification:** Audits account creation via `id <user>`, inspects home directory existence and permissions (`drwxr-x---`), and validates shadow aging policy via `sudo chage -l <user>`.
- **Safe Teardown Script (`cleanup.sh`):** Provides a comprehensive restoration script reading `employees.csv`, purging test accounts and home directories (`sudo userdel -r <user>`), removing empty departmental groups (`sudo groupdel <dept>`), and verifying pristine environment restoration.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with executive KPI metric cards, detailed accounts table, live execution log, and automatic browser dispatch across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to provision accounts, audit system state, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `bash cleanup.sh` — Safely deletes all created test accounts (`userdel -r`), home directories, and empty departmental groups, restoring pristine system state
- `./employee_account_setup.sh` — Default batch account provisioning execution against `employees.csv`
- `./employee_account_setup.sh --dry-run` — Simulates account creation and group checks without modifying system files
- `./employee_account_setup.sh --file custom_list.csv` — Provisions accounts from a custom employee CSV file
- `./employee_account_setup.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_01/report.html`](./AS_01/report.html)
- 📖 **Sprint Documentation:** [`AS_01/README.md`](./AS_01/README.md)
- 📜 **Audit Log File:** [`AS_01/logs/account_setup.log`](./AS_01/logs/account_setup.log)
</details>

<details>
<summary><strong>AS_02 — Inactive Employee Detection (User Administration & Login History)</strong></summary>

### Problem Statement
The system administrator wants to identify users who have not logged in recently. Write a Bash script to display inactive user accounts.

### Summary of Approach
- **Local Account Discovery & Human User Filtering:** Parses `/etc/passwd` directly, applying standard Linux conventions (`UID >= 1000`, `UID != 65534 nobody`) and verifying valid interactive shells against `/etc/shells` while excluding non-login service daemons (`/usr/sbin/nologin`, `/bin/false`). Optional `--include-system` audits service daemons and `root`.
- **Multi-Tier Login History Engine:**
  - *Tier 1 (Preferred):* `lastlog -u <user>` reading `/var/log/lastlog` (fixed-size direct-indexed UID table).
  - *Tier 2 (Fallback):* `last -F <user> | head -1` reading `/var/log/wtmp` (sequential append circular log).
  - *Tier 3 (Modern Linux / WSL2 Fallback):* For modern minimal distributions (Ubuntu 24.04/26.04) and WSL2 lacking legacy 32-bit utmp binaries, queries active sessions (`who`, `w`), systemd user session timestamps (`loginctl show-user`), and PAM authentication records (`/var/log/auth.log`).
- **Resilient Zero-Record Handling:** Treats accounts with no login history gracefully as "Never logged in" / `INACTIVE` without failing or crashing.
- **Dynamic Inactivity Threshold:** Configurable threshold (default: 30 days) via argument or environment variable. Evaluates days since last login using GNU `date -d` epoch arithmetic: `days = (current_epoch - login_epoch) / 86400`.
- **Strict Read-Only Sandboxing:** Performs zero account modifications, locking, or deletions. All logs and reports are isolated inside `AS_02/`.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with executive KPI metric cards, interactive search/filter table, dark theme, and automated browser dispatch across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to audit accounts, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `bash run.sh 15` — Single command with custom 15-day inactivity threshold
- `./inactive_employee_detector.sh` — Default CLI table audit report with 30-day threshold
- `./inactive_employee_detector.sh 60` — CLI table report with custom 60-day threshold
- `./inactive_employee_detector.sh --include-system` — Audits all local accounts including system daemons and root
- `./inactive_employee_detector.sh --json` — Emits structured JSON telemetry for programmatic consumption
- `./inactive_employee_detector.sh --help` — Displays CLI manual, options, and examples

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_02/report.html`](./AS_02/report.html)
- 📖 **Sprint Documentation:** [`AS_02/README.md`](./AS_02/README.md)
- 📜 **Audit Log File:** [`AS_02/logs/inactive_check.log`](./AS_02/logs/inactive_check.log)
- 📋 **Command Log:** [`AS_02/commands_used.md`](./AS_02/commands_used.md)

</details>

<details>
<summary><strong>AS_03 — Department Access (Groups & Permissions)</strong></summary>

### Problem Statement
Create a department group and configure a shared directory so that only members of that group can access it.

### Summary of Approach
- **Department Group Provisioning:** Automatically inspects and provisions test group `lsatest_dept_shared` using `sudo groupadd` if not already present.
- **Sandboxed Directory Setup:** Establishes `AS_03/sandbox_data/shared/` without altering system-level root directories.
- **Restrictive Ownership & SGID Bit Enforcement:** Configures directory ownership to `${USER}:lsatest_dept_shared` and applies octal mode `2770` (`drwxrws---`).
- **Group Inheritance Validation:** The SetGID bit (`2xxx`) ensures that all newly created files and subdirectories automatically inherit the department group (`lsatest_dept_shared`).
- **Kernel-Enforced Non-Member Lockdown:** Zero permissions (`---` / `0`) for Others ensures that non-members (probed via `sudo -u nobody`) are strictly denied read, write, and execute permissions (`EACCES`).
- **Safe Teardown Script (`cleanup.sh`):** Restores pristine system state by removing the group (`sudo groupdel lsatest_dept_shared`) and resetting folder permissions.
- **Cross-Platform HTML Dashboard (`run.sh`):** Automatically executes the configuration, verifies permissions, regenerates `report.html` from scratch, and dispatches the dashboard across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to configure access, audit permissions, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `bash cleanup.sh` — Safely deletes test group `lsatest_dept_shared` and restores pristine host state
- `./department_access.sh` — Default configuration and audit run
- `./department_access.sh --check` — Audits current group and directory permissions without making modifications
- `./department_access.sh --dry-run` — Simulates execution steps
- `./department_access.sh --json` — Emits structured JSON telemetry

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_03/report.html`](./AS_03/report.html)
- 📖 **Sprint Documentation:** [`AS_03/README.md`](./AS_03/README.md)
- 📜 **Audit Log File:** [`AS_03/logs/department_access.log`](./AS_03/logs/department_access.log)
- 📋 **Command Log:** [`AS_03/commands_used.md`](./AS_03/commands_used.md)

</details>

<details>
<summary><strong>AS_04 — Permission Audit (Security)</strong></summary>

### Problem Statement
A company security administrator wants to identify all world-writable files in a specified directory. Develop a script to generate an audit report.

### Summary of Approach
- **Least-Privilege Auditing Engine:** Probes target directory tree for regular files with the 'others' write bit enabled (`find -type f -perm -0002` / `-perm -o+w`), eliminating false positives from directories with sticky bits.
- **Risk Severity Categorization:** Evaluates flagged files by classification — CRITICAL for world-writable executables/scripts (`.sh`, `.py`, binaries), HIGH for config files (`.conf`, `.key`, `.csv`, `.json`), and MEDIUM for general files.
- **Target Flexibility & Live Auditing:** Defaults to sandboxed multi-tier test environment (`AS_04/sandbox_data/`), but seamlessly audits live system paths (e.g. `./permission_audit.sh /var/log` or `--system`).
- **Remediation Suggestions:** Automatically generates precision hardening commands (`chmod o-w <file>`) for every identified threat.
- **Compliance Scoring:** Calculates system compliance percentage (`(compliant / total) * 100`) and serializes JSON telemetry.
- **Cross-Platform HTML Dashboard (`run.sh`):** Executes scan, regenerates dark-themed `report.html` with interactive findings tables and metrics, and dispatches the default browser across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to audit permissions, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./permission_audit.sh` — Default scan of sandboxed company directory tree
- `./permission_audit.sh /var/log` — Real-world audit of live host log directory
- `./permission_audit.sh --system` — Audits host temporary directories (`/var/tmp`)
- `./permission_audit.sh --json` — Emits structured JSON telemetry
- `./permission_audit.sh --help` — Displays CLI manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_04/report.html`](./AS_04/report.html)
- 📖 **Sprint Documentation:** [`AS_04/README.md`](./AS_04/README.md)
- 📜 **Audit Log File:** [`AS_04/logs/permission_audit.log`](./AS_04/logs/permission_audit.log)
- 📋 **Command Log:** [`AS_04/commands_used.md`](./AS_04/commands_used.md)

</details>

<details>
<summary><strong>AS_05 — Ownership Audit (File Ownership)</strong></summary>

### Problem Statement
Write a script to find files in a project directory that are not owned by the designated project administrator.

### Summary of Approach
- **Single-Admin Ownership Verification:** Enforces designated administrative ownership by identifying all non-matching file objects via `find "$TARGET_DIR" -type f ! -user "$ADMIN_USER"`.
- **Privilege Drift Categorization:** Evaluates flagged files into actionable threat classes: ROOT_PRIVILEGE (accidental `sudo` runs leaving root-owned files), FOREIGN_USER (unauthorized user or contractor accounts), and ORPHAN_UID (`-nouser`, unmapped legacy UIDs).
- **Dual-Mode Target Flexibility:** Validated against a multi-tier sandboxed project tree (`AS_05/sandbox_data/project_alpha`) simulating multi-user development, and equally capable of auditing host system directories (e.g. `/etc/cron.d root`).
- **Targeted Remediation Recommendations:** Generates specific remediation commands (`sudo chown <ADMIN_USER> <file>`) with an optional `--remediate` correction engine.
- **Cross-Platform HTML Dashboard (`run.sh`):** Dispatches scanner, records audit trail, regenerates dark-themed `report.html` with KPI compliance cards and inventory table, and opens the default web browser across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to audit ownership, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./ownership_audit.sh` — Default scan of sandboxed project directory with current user as admin
- `./ownership_audit.sh /etc/cron.d root` — Real-world audit of live system cron directory enforcing root ownership
- `./ownership_audit.sh --dir ./sandbox_data --admin pankaj` — Explicit directory and administrator targeting
- `./ownership_audit.sh --json` — Emits structured JSON telemetry
- `./ownership_audit.sh --help` — Displays CLI manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_05/report.html`](./AS_05/report.html)
- 📖 **Sprint Documentation:** [`AS_05/README.md`](./AS_05/README.md)
- 📜 **Audit Log File:** [`AS_05/logs/ownership_audit.log`](./AS_05/logs/ownership_audit.log)
- 📋 **Command Log:** [`AS_05/commands_used.md`](./AS_05/commands_used.md)

</details>

<details>
<summary><strong>AS_06 — Server Health Check (System Monitoring)</strong></summary>

### Problem Statement
Before starting the workday, an administrator wants a quick report showing CPU, memory, disk usage, uptime, and logged-in users. Create a Bash health-check script.

### Summary of Approach
- **Comprehensive Subsystem Auditing:** Polls live host telemetry across all 5 vital subsystem metrics — CPU utilization & core load, physical RAM & swap allocation, root storage utilization, system uptime & boot chronology, and active logged-in user sessions.
- **Kernel-Level Parsing & Delta Calculation:** Queries `/proc/stat` across high-resolution intervals to calculate live CPU utilization %, parses `/proc/loadavg` for 1m/5m/15m system load averages and load-per-core normalization, and audits `/proc/meminfo` via `free -m`.
- **Session & Process Diagnostics:** Analyzes active interactive terminal sessions via `who`, counts total active tasks, and audits `/proc` for zombie (`Z`) state processes.
- **Dynamic Operational Health Verdict:** Evaluates subsystem values against configurable operational safety thresholds (CPU, RAM, Disk < 85%, load/core < 1.5, zero zombies) to produce an executive status rating (OPTIMAL, DEGRADED, CRITICAL).
- **Cross-Platform HTML Dashboard (`run.sh`):** Executes health probe, logs telemetry, regenerates dark-themed `report.html` featuring visual progress bars, system metric stat boxes, and active session tables, and opens the default browser across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to poll health telemetry, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./server_health_check.sh` — Standard terminal health report displaying CPU, memory, disk, uptime, and user sessions
- `./server_health_check.sh --json` — Emits structured JSON telemetry for programmatic observability pipelines
- `./server_health_check.sh --quiet` — Displays concise operational health status badge
- `./server_health_check.sh --help` — Displays CLI manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_06/report.html`](./AS_06/report.html)
- 📖 **Sprint Documentation:** [`AS_06/README.md`](./AS_06/README.md)
- 📜 **Audit Log File:** [`AS_06/logs/server_health_check.log`](./AS_06/logs/server_health_check.log)
- 📋 **Command Log:** [`AS_06/commands_used.md`](./AS_06/commands_used.md)

</details>

<details>
<summary><strong>AS_07 — Low Disk Space Alert (Disk Monitoring)</strong></summary>

### Problem Statement
A server administrator wants to know if any file system has crossed 80% utilization. Write a script that displays the affected file systems and an appropriate warning.

### Summary of Approach
- **POSIX Portable Filesystem Auditing:** Queries active storage partitions via `df -P`, preventing multi-column line-wrap anomalies and cleanly isolating device, mount point, blocks, used, and capacity percentage.
- **Dynamic Capacity Thresholding:** Defaults to 80% utilization detection threshold with configurable CLI argument overrides (`-t <percent>`) and virtual volume filtering.
- **Graduated Severity Alert Classification:** Categorizes exceeding filesystems by risk severity — WARNING (80%–89%), HIGH (90%–94%), and CRITICAL (&ge; 95%) — with color-coded terminal alerts.
- **Storage Remediation Playbook:** Generates immediate administrator mitigation playbooks covering directory isolation (`du -sh`), systemd journal vacuuming (`journalctl --vacuum-time`), package cache purges (`apt clean`), and container cleanup (`docker system prune`).
- **Cross-Platform HTML Dashboard (`run.sh`):** Executes probe, serializes JSON telemetry, regenerates dark-themed `report.html` with capacity alert cards, full volume inventory table, and visual progress meters, and opens the default browser across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to audit disk capacity, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./low_disk_space_alert.sh` — Default scan of mounted filesystems with 80% alert threshold
- `./low_disk_space_alert.sh 70` — Stress test with custom 70% threshold (triggers warnings on live WSL/host volumes)
- `./low_disk_space_alert.sh --json` — Emits structured JSON telemetry
- `./low_disk_space_alert.sh --help` — Displays CLI manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_07/report.html`](./AS_07/report.html)
- 📖 **Sprint Documentation:** [`AS_07/README.md`](./AS_07/README.md)
- 📜 **Audit Log File:** [`AS_07/logs/disk_alert.log`](./AS_07/logs/disk_alert.log)
- 📋 **Command Log:** [`AS_07/commands_used.md`](./AS_07/commands_used.md)

</details>

<details>
<summary><strong>AS_08 — Large File Detection (Storage Management)</strong></summary>

### Problem Statement
An administrator wants to locate all files in a directory that exceed a certain size to manage disk space. Write a script to identify such files and display their locations.

### Summary of Approach
- **Recursive Filesystem Traversal:** Leverages GNU `find <DIR> -type f -size +<THRESHOLD>` with `-printf "%s\t%p\n"` for raw precision extraction of file byte counts and absolute paths without regex or whitespace issues.
- **Descending Numerical Sort:** Pipes output to `sort -nr` to surface the largest storage-consuming files at the top of the triage queue.
- **Granular File Attribute Extraction:** Employs `stat -c` to extract permissions (`%A`), user owner (`%U`), owning group (`%G`), and modification timestamp (`%y`) for each discovered candidate.
- **Dynamic Sizing & Formatting:** Parses user-specified suffixes (`k`, `M`, `G`) and renders human-readable file and cumulative totals (`B`, `KB`, `MB`, `GB`).
- **Real Live Data & Sandbox Support:** Scans live `/var/log` system journals and syslog archives by default, while providing `--sandbox` support for testing isolated synthetic test trees.
- **Cross-Platform HTML Dashboard (`run.sh`):** Emits structured JSON telemetry, recreates a responsive dark dashboard `report.html` from scratch, and triggers native browser launch on WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to detect large files, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./large_file_detector.sh /var/log 1M` — Scans live `/var/log` for files exceeding 1 MB
- `./large_file_detector.sh --sandbox 5M` — Scans synthetic sandbox environment for files exceeding 5 MB
- `./large_file_detector.sh --dir /var/log --size 10M --limit 10` — Limits display to top 10 results
- `./large_file_detector.sh --json` — Emits machine-readable JSON telemetry

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_08/report.html`](./AS_08/report.html)
- 📖 **Sprint Documentation:** [`AS_08/README.md`](./AS_08/README.md)
- 📜 **Audit Log File:** [`AS_08/logs/large_files.log`](./AS_08/logs/large_files.log)
- 📋 **Command Log:** [`AS_08/commands_used.md`](./AS_08/commands_used.md)

</details>

<details>
<summary><strong>AS_09 — Temporary File Cleanup (System Maintenance)</strong></summary>

### Problem Statement
Temporary files can consume a large amount of disk space over time. Write a script that identifies and deletes temporary files in a specified directory that have not been modified for more than N days.

### Summary of Approach
- **Deterministic File Aging & Epoch Comparison:** Evaluates file modification epoch stamps (`stat -c %Y`) against current wall-clock epoch (`date +%s`), calculating exact age in days rather than coarse heuristic estimates.
- **Fail-Safe Dry-Run by Default:** Ships with simulation safety enabled by default; only deletes files when `--delete` or `--force` is explicitly provided.
- **Root Directory Guard:** Contains safety blocks protecting system paths (`/`, `/etc`, `/usr`, `/home`, etc.) from destructive traversal.
- **Storage Hygiene Metrics:** Automatically aggregates reclaimed bytes, human-readable totals (`KB`, `MB`), and differentiates unlinked stale files from active files preserved within the retention window.
- **Optional Empty Tree Pruning:** Supports `--empty-dirs` to remove orphaned nested directory trees after stale payload eviction.
- **Cross-Platform HTML Dashboard (`run.sh`):** Seeds reproducible test files with `touch -d` backdated timestamps, executes cleanup, serializes JSON telemetry, regenerates a responsive dark dashboard `report.html`, and auto-opens in the host's default web browser across WSL, Linux, macOS, and Git Bash.

### Key Commands Used
- `bash run.sh` — Single command to seed test environment, execute cleanup, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./temp_cleaner.sh --delete` — Executes actual deletion of files older than 7 days in sandbox
- `./temp_cleaner.sh --dry-run` — Safe simulation listing items that would be unlinked
- `./temp_cleaner.sh -d 10 --delete` — Cleans files older than 10 days
- `./temp_cleaner.sh --json` — Emits structured JSON telemetry

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_09/report.html`](./AS_09/report.html)
- 📖 **Sprint Documentation:** [`AS_09/README.md`](./AS_09/README.md)
- 📜 **Audit Log File:** [`AS_09/logs/temp_cleaner.log`](./AS_09/logs/temp_cleaner.log)
- 📋 **Command Log:** [`AS_09/commands_used.md`](./AS_09/commands_used.md)

</details>

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
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the detector, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to execute detector, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
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
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the analyzer, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to execute analysis, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
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
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the service check, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to inspect service, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
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
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the recovery monitor, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to execute recovery monitor, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
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
- **Single Cross-Platform Launcher (`run.sh`):** Dispatches the process check, captures live output, regenerates `report.html` from scratch, and auto-detects host OS to launch the HTML report (WSL `explorer.exe`, macOS `open`, Linux `xdg-open`, Git Bash `start`).

### Key Commands Used
- `bash run.sh` — Single command to inspect process, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
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

<details>
<summary><strong>AS_26 — Package Update Check (Live System Data)</strong></summary>

### Problem Statement
Create a script to check whether system packages require updates and display the update status.

### Summary of Approach
- **Dynamic Cross-Platform Package Manager Detection:** Avoids hardcoding `apt` only. Dynamically detects package managers across distributions: `apt`/`apt-get` (Debian/Ubuntu), `dnf`/`yum` (RHEL/Rocky/AlmaLinux/Fedora), `brew` (macOS/Darwin), `pacman` (Arch Linux), and `zypper` (openSUSE).
- **Safe Read-Only Index Metadata Refresh:** Safely synchronizes repository metadata (e.g. `sudo apt-get update -qq`) without altering any installed binaries. Gracefully falls back to querying the cached local package index without crashing if offline or unprivileged.
- **Upgradable Package Parsing & Differential Extraction:** Extracts package names, current installed versions, candidate available versions, repository suites, and CPU architecture.
- **Security Vulnerability vs Standard Update Classification:** Identifies critical CVE security patches originating from `*-security` repositories versus standard functional/phased updates.
- **Strict Read-Only Guarantee:** Guarantees zero packages are installed, removed, or upgraded. Confirms check-only policy in terminal output, structured JSON, logs, and HTML dashboard.
- **Persistent Chronological Audit Trail:** Appends timestamped audit traces to `logs/package_check.log` and exports structured machine-readable JSON telemetry to `logs/package_check.json`.
- **Cross-Platform HTML Dashboard (`run.sh`):** Regenerates `report.html` from scratch on every run with executive KPI metric cards, scrollable table with live client-side search/filter, captured terminal execution transcript, and sysadmin remediation guide, automatically launching across WSL (`explorer.exe`), Linux (`xdg-open`), macOS (`open`), and Windows Git Bash (`start`).

### Key Commands Used
- `bash run.sh` — Single command to audit live package updates, regenerate dashboard, and open HTML report (Linux / macOS / Windows)
- `./package_update_check.sh` — Executes the full package update check with repository index metadata synchronization
- `./package_update_check.sh --skip-refresh` — Queries cached package metadata without index refresh (fast/offline mode)
- `./package_update_check.sh --json` — Streams raw structured JSON telemetry directly to standard output
- `./package_update_check.sh --help` — Displays command-line manual and option syntax

### Dashboard Report & Documentation
- 📊 **Interactive Dashboard:** [`AS_26/report.html`](./AS_26/report.html)
- 📖 **Sprint Documentation:** [`AS_26/README.md`](./AS_26/README.md)
- 📜 **Audit Log File:** [`AS_26/logs/package_check.log`](./AS_26/logs/package_check.log)

</details>

---

## 🛠️ General Guidelines

- All scripts are self-contained within their respective project directories (`AS_XX/`).
- Scripts adhere to defensive bash standards (`set -euo pipefail`), proper validation, and clear exit codes.
- Refer to individual project folders for setup instructions, command logs, and sample outputs.


