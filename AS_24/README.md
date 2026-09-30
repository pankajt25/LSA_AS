# SSH Service Check — Automation Sprint (AS_24)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** SSH Administration, Service Availability & Port Socket Verification  
**Problem Statement #24:** Write a script to verify whether SSH is running and display the current service status.  

---

## Command to Execute

To audit this machine's live SSH service status, dynamically discover service naming across distributions, inspect runtime active and boot persistence states, perform an independent network socket cross-check on port 22, regenerate the dark-themed HTML report dashboard, and automatically launch it in your default web browser, run:

```bash
bash run.sh
```

### Platform-Specific One-Line Execution Notes:
- **Windows (WSL2 / Ubuntu):** `cd AS_24 && bash run.sh` — Checks live SSH service and socket binding, logs audit entries to `logs/ssh_check.log`, regenerates `report.html`, translates Linux paths via `wslpath -w`, and automatically launches the dashboard in your default Windows browser via `explorer.exe`.
- **Linux (Desktop / X11 / Wayland):** `cd AS_24 && bash run.sh` — Executes the audit workflow and dispatches `report.html` via `xdg-open`.
- **macOS (Darwin):** `cd AS_24 && bash run.sh` — Queries Remote Login status via `systemsetup -getremotelogin` and launches `report.html` via `open`.
- **Windows (Git Bash / MSYS2 / Cygwin):** `cd AS_24 && bash run.sh` — Executes the Bash workflow and dispatches `report.html` via Windows `start ""`.

> **Note on Live Data Regeneration:** `run.sh` **never** serves fabricated or static mock data. Every single execution invokes `ssh_service_check.sh`, queries this machine's actual real SSH configuration (candidate service naming, systemd/SysV active state, boot persistence state, and TCP port 22 listening sockets), records a timestamped audit entry in `logs/ssh_check.log`, emits structured JSON telemetry in `logs/ssh_check.json`, and regenerates `report.html` completely from scratch.

---

## Viewing the HTML Report

If your environment is headless or your web browser does not open automatically, view the generated report manually:

### Windows / WSL2 Fallback (Command Prompt / PowerShell / WSL):
```bash
# From within WSL terminal:
explorer.exe "$(wslpath -w report.html)"
```
Or directly open the resolved Windows file path in any web browser (Edge, Chrome, Firefox, Brave):
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_24\report.html
```

### Native Linux / macOS Fallbacks:
```bash
# Linux Desktop:
xdg-open report.html || sensible-browser report.html || python3 -m webbrowser report.html

# macOS:
open report.html
```

---

## 1. Overview & System Architecture

Secure Shell (`SSH`) is the foundational protocol for remote Linux system administration, encrypted shell sessions, automated deployments (`Ansible`, `CI/CD`), and secure file transfers (`SFTP`/`SCP`). Verifying that the SSH daemon is functioning correctly requires more than a superficial process check:
1. **Distribution Name Discrepancies:** Debian/Ubuntu systems name the OpenSSH unit `ssh.service`, while RHEL/CentOS/Fedora/Arch systems name it `sshd.service`. Hardcoding one fails immediately on the other.
2. **Init Architecture Diversity:** Modern hosts run `systemd`, while legacy systems, minimal Docker containers, and WSL1 instances run `SysV init` or direct wrappers.
3. **Socket Binding Disconnects:** A service can report `active` in `systemd` (due to a stale PID or hanging fork), yet fail to bind to port 22 due to socket errors, port conflicts, or IP binding issues. Conversely, containerized or standalone daemons may listen on port 22 without a systemd service wrapper.

`ssh_service_check.sh` is an automated, production-grade system administration audit tool designed to solve these challenges defensively, without modifying system state or disrupting active terminal sessions.

```text
                                  +-----------------------------+
                                  |    run.sh Cross-Platform    |
                                  |          Launcher           |
                                  +--------------+--------------+
                                                 |
                                 +----------------+----------------+
                                 |     ssh_service_check.sh        |
                                 |     (Core Audit Engine)         |
                                 +----------------+----------------+
                                                 |
                        +------------------------+------------------------+
                        |                        |                        |
                        v                        v                        v
           +-------------------------+ +------------------------+ +-------------------------+
           |  1. Service Discovery   | |   2. Runtime Active    | |  3. Boot Persistence    |
           | Candidate 1: 'ssh'      | | 'systemctl is-active'  | | 'systemctl is-enabled'  |
           | Candidate 2: 'sshd'     | | SysV 'service' fallback| | SysV rc.d link fallback |
           +------------+------------+ +-----------+------------+ +------------+------------+
                        |                          |                           |
                        +--------------------------+---------------------------+
                                                 |
                                 +---------------+---------------+
                                 |  4. Independent Socket Check  |
                                 |   'ss -tlnp | grep :22'       |
                                 |   'netstat -tlnp' fallback    |
                                 |   Detects bound PID & process |
                                 +---------------+---------------+
                                                 |
                                 +---------------+---------------+
                                 |  5. Multi-State Synthesis     |
                                 |   Optimal (Active+Enabled+22) |
                                 |   Degraded (Partial states)   |
                                 |   Not Installed (Safe exit)   |
                                 +---------------+---------------+
                                                 |
                        +------------------------+------------------------+
                        |                        |                        |
                        v                        v                        v
           +-------------------------+ +------------------------+ +-------------------------+
           | Clean Terminal Report   | | Chronological Audit Log| | Structured Telemetry    |
           | ANSI Badges & Headers   | | logs/ssh_check.log     | | logs/ssh_check.json     |
           +-------------------------+ +------------------------+ +------------+------------+
                                                                               |
                                                                               v
                                                                  +-------------------------+
                                                                  | Regenerate report.html  |
                                                                  | Dark Theme Dashboard    |
                                                                  +------------+------------+
                                                                               |
                                                                               v
                                                                  +-------------------------+
                                                                  | Launch Browser via OS   |
                                                                  | WSL/Linux/macOS/GitBash |
                                                                  +-------------------------+
```

---

## 2. Requirements & Implementation Breakdown

| Requirement | Implementation Detail in `ssh_service_check.sh` |
|---|---|
| **1. Dynamic Service Detection** | Checks `ssh` first (Debian/Ubuntu), then `sshd` (RHEL/CentOS). Uses `systemctl cat`, `systemctl list-unit-files`, unit `LoadState`, and `/etc/init.d/` checks. Never hardcodes a single name. |
| **2. Active Status Check** | Queries `systemctl is-active <service>`. If systemd is unavailable, seamlessly falls back to `service <service> status` and logs the fallback reason. |
| **3. Boot Persistence Check** | Queries `systemctl is-enabled <service>`. Distinguishes between `enabled`, `disabled`, `static`, `masked`, and `not-found`. SysV fallback inspects `/etc/rc*.d/S*`. |
| **4. Port 22 Socket Cross-Check** | Executes `ss -tlnp` (fallback `ss -tln`, `netstat -tlnp`, `lsof`). Matches `:22\b` with word boundary regex to prevent false matches on ports like `:2222`. Extracts listening socket details and bound process PID. |
| **5. Combined Status Banner** | Formats an unambiguous human-readable message: `✅ SSH ('<svc>') is ACTIVE, ENABLED at boot, and LISTENING on port 22` or accurate partial-state explanations if degraded. |
| **6. Persistent Audit Logging** | Appends every check step, command, return code, and evaluation with microsecond/second timestamps to `logs/ssh_check.log`. |
| **7. Defensive Error Handling** | If neither `ssh` nor `sshd` exists, clearly announces `SSH is NOT INSTALLED`, provides distribution-specific installation remediation commands, and exits cleanly without crashing. |
| **8. Commented Codebase** | Extensively documented with architectural comments explaining *why* each check is conducted and the rationale behind every fallback mechanism. |

---

## 3. Real Machine Audit Results

When executed on this host (`Ubuntu 26.04.1 LTS on WSL2`), the live output accurately identifies the machine's real state:

```text
================================================================================
       SSH SERVICE AUDIT REPORT — AUTOMATION SPRINT #24 (E1ITA307)       
================================================================================
 Timestamp : 2026-09-30 11:46:46 IST
 Hostname  : SP | OS: Ubuntu 26.04.1 LTS | Kernel: 6.18.33.2-microsoft-standard-WSL2
 Init System: systemd init manager (PID 1 active, status: running)
--------------------------------------------------------------------------------
 SERVICE INSPECTION MATRIX:
--------------------------------------------------------------------------------
  Detected Service Name    : none (not-found)
  Active Status            : NOT-INSTALLED (Neither 'ssh' nor 'sshd' service is installed or registered)
  Boot Persistence         : NOT-INSTALLED (Cannot inspect boot persistence for non-existent service)
  TCP Port 22 Socket       : NOT LISTENING (No active TCP listening sockets bound to port 22)
--------------------------------------------------------------------------------
 OVERALL STATUS EVALUATION:
--------------------------------------------------------------------------------
  ❌ SSH is NOT INSTALLED (neither 'ssh' nor 'sshd' service found on this system, and port 22 is not listening)

  Remediation / Admin Note:
  To install OpenSSH server on Debian/Ubuntu: sudo apt-get update && sudo apt-get install openssh-server
================================================================================
 Audit Log File  : /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_24/logs/ssh_check.log
 JSON Telemetry  : /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_24/logs/ssh_check.json
================================================================================
```

---

## 4. Script Usage & Command-Line Options

The core script `ssh_service_check.sh` supports several command-line arguments:

```bash
# Standard live SSH check
./ssh_service_check.sh

# Emit structured JSON telemetry to stdout
./ssh_service_check.sh --json

# Inspect a custom port (e.g., hardened SSH listening on port 2222)
./ssh_service_check.sh -p 2222

# Diagnostic / testing override against another service (e.g. cron)
./ssh_service_check.sh -s cron

# Diagnostic test against cron and DNS listening port 53 (demonstrates optimal state)
./ssh_service_check.sh -s cron -p 53

# Suppress terminal banner and colors for automated scripting
./ssh_service_check.sh --quiet --no-color

# Display help manual
./ssh_service_check.sh --help
```

---

## 5. Sandboxing & Read-Only Safety Compliance

- **Read-Only Inspection:** In strict compliance with the problem constraints, this script **never** invokes `systemctl start`, `stop`, `restart`, `enable`, or `disable`. Modifying live SSH services on a remote or WSL session risks session disconnection and data loss.
- **Path Isolation:** All generated files (`logs/ssh_check.log`, `logs/ssh_check.json`, `report.html`) are confined entirely within `AS_24/`.
- **System Integrity:** No modifications are made to `/etc/ssh/`, `/etc/systemd/`, `/var/log/`, or real block devices.

---

## 6. Viva Preparation & System Administration FAQ

### Q1: Why check both service active status and network port listening?
> **Answer:** Systemd monitors process lifecycle (e.g., whether the PID tracked by systemd is running). However, an SSH daemon may hang, get stuck in a chroot jail, experience socket permission errors, or bind to a different port than expected. Conversely, an SSH daemon may run inside a Docker container or standalone without a systemd service wrapper. Checking both `systemctl is-active` and `ss -tlnp | grep :22` provides true end-to-end verification.

### Q2: Why does Debian use `ssh` while RHEL uses `sshd`?
> **Answer:** Debian packaging historically standardized on `ssh` for the package and system service name (wrapping both the daemon and client utilities under `/etc/init.d/ssh`). Red Hat / Fedora packaging named the service explicitly after the daemon executable `sshd.service` to differentiate it from the SSH client. Automated tools must query both candidates to be cross-platform.

### Q3: What is the difference between `inactive` and `not-found` in systemctl?
> **Answer:** `inactive` means the unit file exists and is registered with the systemd manager, but the daemon process is currently stopped. `not-found` means systemd searched `/etc/systemd/system/`, `/lib/systemd/system/`, and `/usr/lib/systemd/system/` and found no unit matching that name (the package is not installed).

### Q4: Why prefer `ss` over `netstat` in modern Linux?
> **Answer:** `netstat` (from legacy `net-tools`) parses `/proc/net/tcp` synchronously, which creates noticeable kernel latency and high CPU usage on busy servers with thousands of sockets. `ss` (from `iproute2`) queries the kernel directly via Netlink sockets (`AF_NETLINK`), delivering orders of magnitude faster execution and richer socket telemetry.
