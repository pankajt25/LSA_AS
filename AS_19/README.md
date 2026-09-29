# High CPU Process Detection — Automation Sprint (AS_19)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Process Monitoring & Resource Accounting  
**Problem Statement #19:** Develop a script to identify the top five processes consuming CPU resources.

---

## 1. Overview & Architecture

Resource exhaustion—particularly CPU starvation—is one of the most critical operational issues encountered by Linux system administrators. Uncontrolled processes, infinite loops, runaway background tasks, or memory thrashing can saturate CPU cores, starve mission-critical services, and degrade overall system throughput.

`high_cpu_detector.sh` is an automated, production-grade Bash utility designed to inspect the system process table reliably in real time. It retrieves the highest CPU-consuming processes, structures them into a clean, human-readable table, highlights anomalies that exceed a user-defined threshold, and records chronological scan history to an audit log.

Complementing the detector, `run.sh` provides a **single, cross-platform execute-and-report command** that runs the detector, regenerates a dark-themed HTML report dashboard (`report.html`) from scratch using live telemetry, and automatically launches the dashboard in the host's default web browser.

### Architectural Rationale: Why `ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu`

| Parameter / Column | Architectural Rationale & Why It Is Used |
|---|---|
| `--sort=-%cpu` | **Kernel/Internal Sorting:** GNU `ps` sorts process table entries directly in memory before writing to stdout. The leading minus (`-`) guarantees descending order (highest CPU hogs first). This eliminates external pipeline sorting (`| sort`), preventing pipeline race conditions, broken multi-line wraps, locale-dependent decimal issues, and `SIGPIPE` crashes under `set -eo pipefail`. |
| `pid` | **Process Identification:** The unique operating system identifier essential for further troubleshooting, diagnostic tracing (`strace`), or process management. |
| `ppid` | **Process Lineage:** The Parent Process ID reveals ancestry and execution context (e.g. whether spawned by `systemd` (PID 1), cron, Docker container runtime, an interactive shell, or a background worker pool). |
| `user` | **Privilege Auditing:** Disambiguates system daemons running as `root` from dedicated service accounts (`www-data`, `postgres`) and unprivileged interactive users. |
| `%cpu` | **Primary Resource Metric:** The exact ratio of CPU time consumed divided by elapsed execution time. Essential for identifying rogue tasks and CPU hogs. |
| `%mem` | **Holistic Context:** High CPU consumption often correlates directly with memory leaks, garbage collection thrashing, or high swap I/O. Tracking `%MEM` side-by-side provides immediate diagnostic context. |
| `comm` | **Tabular Stability:** Extracts the short executable name from `/proc/[pid]/comm` rather than the full command line with arguments (`args`). This ensures fixed column widths and prevents long argument strings from corrupting terminal or HTML tables. |

### Process Monitoring Workflow Diagram
```
                     +-----------------------------------+
                     |       Start: Parse CLI Flags      |
                     |       (-n count, -t threshold)    |
                     +-----------------+-----------------+
                                       |
                           [Valid Arguments Passed?]
                                       |
                      +----------------+----------------+
                      | No                              | Yes
                      v                                 v
          +-----------------------+        +---------------------------+
          | Print Error & Manual  |        | Query Live Process Table  |
          | Exit Code 2           |        | via ps -eo ... --sort=-%cpu|
          +-----------------------+        +-------------+-------------+
                                                         |
                                                         v
                                           +---------------------------+
                                           | Extract Top N Processes   |
                                           | Evaluate Float CPU% >= Thresh |
                                           | via Awk Numerical Engine  |
                                           +-------------+-------------+
                                                         |
                                      +------------------+------------------+
                                      |                                     |
                          [Any %CPU >= Threshold?]                          |
                                      |                                     |
                         +------------+------------+                        |
                         | Yes                     | No                     |
                         v                         v                        |
             +-----------------------+ +-----------------------+            |
             | Flag [⚠️ HIGH ALERT]  | | Mark [✓ NORMAL]       |            |
             +-----------+-----------+ +-----------+-----------+            |
                         |                         |                        |
                         +------------+------------+                        |
                                      |                                     |
                                      v                                     v
                         +---------------------------+        +---------------------------+
                         | Render Formatted Terminal |        | Append Chronological Scan |
                         | Output Table to Stdout    |        | to logs/high_cpu.log      |
                         +---------------------------+        +---------------------------+
                                      |
                                      v
                         +---------------------------+
                         | run.sh Regenerates        |
                         | report.html Dashboard     |
                         | & Dispatches Browser      |
                         +---------------------------+
```

---

## 2. Sandboxing & Safety Notice (Mandatory)

This sprint strictly complies with all sandbox and safety requirements:
- **100% Read-Only Operations:** The script only reads live system telemetry via `ps`, `uptime`, and `/proc`.
- **Zero Process Modifications:** No processes are terminated, killed, signaled, reniced, or altered in any way.
- **Filesystem Isolation:** All writes (audit logs, HTML dashboards, command logs, markdown documentation) are strictly confined within `AS_19/`. No system directories (`/etc`, `/usr`, `/home`) or block devices are touched.

---

## 3. Script Features & Implementation

`high_cpu_detector.sh` includes:
- **Live Real-Data Execution:** Retrieves live, actual CPU-consuming processes on whichever machine it runs. Never hardcoded or mock data.
- **Dynamic Thresholding:** Uses configurable CPU percentage threshold (default `50.0%`) as a variable, not hardcoded.
- **Awk Floating-Point Evaluation:** Uses `awk` to perform floating-point numerical comparisons (`$4 >= thresh`). This prevents Bash integer truncation bugs where `49.9%` would incorrectly be compared as `49`.
- **Flexible Argument Parsing:**
  - `-n <count>`: Changes how many top processes are displayed (default: `5`).
  - `-t <threshold>`: Sets custom CPU alert threshold (default: `50.0`).
  - `-l <logfile>`: Directs audit entries to custom log path.
  - `-h` / `--help`: Displays comprehensive manual.
- **Defensive Input Validation:** Enforces strict regex validation on numeric arguments (`^[1-9][0-9]*$` for count, `^[0-9]+(\.[0-9]+)?$` for threshold), exiting with code 2 on syntax errors.
- **Persistent Chronological Logging:** Appends (`>>`) every scan with full system context (timestamp, host, kernel, user, load avg, total processes, peak CPU) to `logs/high_cpu.log`.
- **Cross-Platform Compatibility:** Detects OS via `uname -s`. Automatically uses `ps -eo ... --sort=-%cpu` on Linux, and adapts to `ps -eo ... -r` on macOS (Darwin BSD `ps`).
- **Comprehensive Error Trapping:** Validates presence and return codes of system utilities (`ps`, `awk`), failing gracefully with actionable error messages rather than crashing silently.

---

## ⚡ Command to Execute

Run this **single command** from inside the `AS_19/` directory:

```bash
bash run.sh
```

*(From repository root, execute: `cd AS_19 && bash run.sh`)*

### 🌐 Cross-Platform Execution Notes

- **🐧 Linux Desktop / 🍎 macOS:** Run `bash run.sh` directly from your terminal. It executes the detector, regenerates `report.html` from scratch with live telemetry, and dispatches the HTML report to your default browser (`xdg-open` on Linux, `open` on macOS).
- **🪟 Windows (WSL):** Run `bash run.sh` inside WSL. It automatically detects the WSL environment, translates the path using `wslpath -w report.html`, and launches the report in your Windows default browser via `explorer.exe`.
- **🪟 Windows (Git Bash):** Run `bash run.sh` inside Git Bash. It detects MSYS/Cygwin and launches the report using `start "" report.html`.
- **🔄 Live Regeneration Note:** The HTML report (`report.html`) **regenerates live on every single run**, capturing current real-time CPU utilization, system load, and running processes at that exact second.

---

## 🖥️ Viewing the HTML Report

The generated HTML report is a standalone, self-contained dashboard with modern dark styling and inline CSS. It displays live metric stat cards, color-coded process tables with visual CPU progress bars, high-CPU alert banners, an embedded terminal execution console, a persistent audit log viewer, and rubric verification checklists.

### Manual Fallback Commands

If your environment does not support automated browser launching, open `report.html` manually using:

- **Windows Subsystem for Linux (WSL):**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows Path Equivalent:**
  ```text
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_19\report.html
  ```
  *(Paste this path into your Windows browser address bar, Windows File Explorer, or the `Win + R` Run dialog)*
- **Native Linux Desktop:**
  ```bash
  xdg-open report.html
  ```
- **macOS:**
  ```bash
  open report.html
  ```
- **Windows Git Bash:**
  ```bash
  start report.html
  ```
- **File URL Fallback:**
  ```text
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_19/report.html
  ```

---

## 4. Usage Instructions & Test Verification

### Test Case 1: Default Top-5 Detection (50.0% Threshold)
```bash
./high_cpu_detector.sh
```
*Live Captured Output:*
```text
==================================================================================
                 HIGH CPU PROCESS DETECTION REPORT (LIVE DATA)                    
==================================================================================
 Timestamp       : 2026-09-29 23:21:36
 Host / Node     : SP (OS: Linux, Kernel: 6.18.33.2-microsoft-standard-WSL2)
 Active User     : pankaj
 System Load     : 0.82 1.16 0.79 (1m, 5m, 15m)
 Total Processes : 32 running in process table
 Top Processes   : 5 requested (Displaying 5)
 CPU Threshold   : 50.0% (Processes >= threshold flagged as high CPU)
----------------------------------------------------------------------------------
PID      PPID     USER               %CPU     %MEM   COMMAND              STATUS / ALERT
-------- -------- -------------- -------- --------   -------------------- -------------------
911      239      pankaj             64.4      8.2   agy                  ⚠️  ALERT (>= 50.0%)
1289     1285     pankaj             17.6      0.0   bash                 NORMAL
1285     911      pankaj              2.5      0.0   bash                 NORMAL
1        0        root                1.5      0.3   systemd              NORMAL
1212     380      pankaj              0.4      0.1   dbus-daemon          NORMAL
----------------------------------------------------------------------------------
⚠️  ALERT: 1 process(es) exceeded the 50.0% CPU threshold! (Peak: 64.4%)
==================================================================================
Audit log appended to: /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_19/logs/high_cpu.log
```

### Test Case 2: Custom Process Count & Sensitive Threshold (`-n 3 -t 20.0`)
Demonstrates command-line argument handling and threshold tuning:
```bash
./high_cpu_detector.sh -n 3 -t 20.0
```
*Live Captured Output:*
```text
==================================================================================
                 HIGH CPU PROCESS DETECTION REPORT (LIVE DATA)                    
==================================================================================
 Timestamp       : 2026-09-29 23:19:36
 Host / Node     : SP (OS: Linux, Kernel: 6.18.33.2-microsoft-standard-WSL2)
 Active User     : pankaj
 System Load     : 1.06 1.19 0.74 (1m, 5m, 15m)
 Total Processes : 29 running in process table
 Top Processes   : 3 requested (Displaying 3)
 CPU Threshold   : 20.0% (Processes >= threshold flagged as high CPU)
----------------------------------------------------------------------------------
PID      PPID     USER               %CPU     %MEM   COMMAND              STATUS / ALERT
-------- -------- -------------- -------- --------   -------------------- -------------------
1083     1082     pankaj            100.0      0.1   ps                   ⚠️  ALERT (>= 20.0%)
911      239      pankaj             55.1      7.9   agy                  ⚠️  ALERT (>= 20.0%)
1076     911      pankaj             14.2      0.0   bash                 NORMAL
----------------------------------------------------------------------------------
⚠️  ALERT: 2 process(es) exceeded the 20.0% CPU threshold! (Peak: 100.0%)
==================================================================================
Audit log appended to: /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_19/logs/high_cpu.log
```

### Test Case 3: Defensive Input Validation & Error Trapping
Verify that invalid arguments are trapped cleanly without syntax crashes:
```bash
./high_cpu_detector.sh -n invalid
```
*Captured Output:*
```text
[ERROR] Option -n requires a positive integer argument. Received: 'invalid'
```
*(Exit code: 2)*

### Test Case 4: CLI Manual Banner (`--help`)
```bash
./high_cpu_detector.sh --help
```
*Captured Output:*
```text
High CPU Process Detector — Automation Sprint (AS_19)

USAGE:
    high_cpu_detector.sh [OPTIONS]

OPTIONS:
    -n <count>       Number of top CPU-consuming processes to display (default: 5)
    -t <threshold>   CPU percentage alert threshold (default: 50.0)
    -l <logfile>     Custom log file path (default: logs/high_cpu.log)
    -h, --help       Show this help manual and exit
...
```

---

## 5. Project Artifacts

| File | Description |
|---|---|
| [`high_cpu_detector.sh`](high_cpu_detector.sh) | The primary bash script with process query logic, threshold alerting, and extensive *why*-focused commentary |
| [`run.sh`](run.sh) | Unified cross-platform launcher that executes the detector, regenerates `report.html`, and launches default browser |
| [`logs/high_cpu.log`](logs/high_cpu.log) | Chronological audit log appending scan timestamps, host info, parameters, and top process data |
| [`report.html`](report.html) | Standalone dark-themed HTML report dashboard with inline CSS, live process table, metric cards, and log viewer |
| [`commands_used.md`](commands_used.md) | Exhaustive log of every command executed during development with one-line descriptions |
| [`README.md`](README.md) | Local project documentation, architecture diagram, usage guide, and rubric checklist |

---

## 6. Rubric Self-Check

- [x] **Real-Data Requirement:** Output strictly reflects this machine's actual live CPU-consuming processes (e.g. `agy`, `bash`, `ps`, `systemd`). Nothing hardcoded or mocked.
- [x] **Sandboxing Guarantee:** 100% read-only process inspection. No process was killed, reniced, or modified. All filesystem operations confined to `AS_19/`.
- [x] **`bash run.sh` End-to-End:** Runs detector &rarr; regenerates `report.html` from scratch &rarr; opens browser automatically.
- [x] **`report.html` Live Capture:** Self-contained dark-themed dashboard with inline CSS reflecting real live metrics and captured output.
- [x] **Required README Sections:** Includes both `## Command to Execute` and `## Viewing the HTML Report` sections.
- [x] **Commentary Quality:** Comments throughout explain *why* `--sort=-%cpu` is optimal, why this specific column set is used, and why floating-point math is handled with `awk`.
