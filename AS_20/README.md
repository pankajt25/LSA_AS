# High Memory Process Detection — Automation Sprint (AS_20)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Process Monitoring & Memory Resource Accounting  
**Problem Statement #20:** Develop a script to identify the top five processes consuming memory.

---

## 1. Overview & Architecture

Physical memory (RAM) is one of the most vital, finite resources managed by the Linux kernel. When applications experience memory leaks, unbounded cache growth, or sudden load surges, the system may suffer severe page thrashing, aggressive swap I/O, latency degradation, or abrupt process termination by the Out-Of-Memory (OOM) killer. Rapidly detecting and diagnosing high-memory workloads is a cornerstone competency for Linux system administrators.

`high_memory_detector.sh` is an automated, production-grade Bash utility designed to inspect the live system process table in real time. It retrieves the highest memory-consuming processes, converts raw Resident Set Size (`RSS`) into human-readable megabytes (MB), reports overall system memory context (`free -h`), highlights processes exceeding a configurable memory threshold (default: `30.0%`), and records chronological scan history to an audit log.

Complementing the detector, `run.sh` provides a **single, cross-platform execute-and-report command** that runs the detector, regenerates a dark-themed HTML report dashboard (`report.html`) from scratch using live telemetry, and automatically launches the dashboard in the host's default web browser.

---

### Architectural Rationale: Why `ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem`

| Parameter / Column | Architectural Rationale & Why It Is Used |
|---|---|
| `--sort=-%mem` | **In-Memory Kernel Sorting:** GNU `ps` parses memory statistics directly from `/proc/[pid]/statm` and sorts entries in-memory before generating stdout. The leading minus (`-`) guarantees descending order (highest memory consumers first). This eliminates external pipeline sorting (`| sort`), preventing pipeline race conditions, broken multi-line wraps, locale-dependent decimal issues (dot vs comma), and `SIGPIPE` crashes under `set -eo pipefail`. |
| `rss` (Resident Set Size) | **Absolute Physical RAM Measurement:** While `%mem` expresses a relative ratio (`RSS / Total_RAM * 100`), Resident Set Size (`rss`) measures the exact amount of physical hardware RAM (in KB) currently held in main memory by the process. It excludes swapped-out memory and unallocated virtual address space (`VSZ`). Presenting `rss` (converted to MB) alongside `%mem` provides both absolute physical footprint and proportional system impact. |
| `pid` | **Process Identification:** The unique operating system identifier essential for targeted diagnostic tracing (`strace`), memory profiling, or administrative isolation. |
| `ppid` | **Process Lineage & Ancestry:** The Parent Process ID reveals ancestry and execution hierarchy (e.g. whether spawned by `systemd` (PID 1), cron, Docker container runtime, an interactive shell, or a background worker pool). |
| `user` | **Privilege Auditing:** Disambiguates system daemons running as `root` from dedicated service accounts (`www-data`, `postgres`) and unprivileged interactive users. |
| `%mem` | **Relative Memory Utilization:** The primary ranking metric required for Problem #20, expressing the proportion of total physical memory allocated to the process. |
| `%cpu` | **Holistic Context:** High memory processes frequently exhibit high CPU utilization due to memory allocation loops, garbage collection thrashing, or high page fault rates. Monitoring `%CPU` side-by-side provides vital diagnostic insight. |
| `comm` | **Tabular Stability:** Extracts the short executable name from `/proc/[pid]/comm` rather than the full command line with arguments (`args`). This ensures fixed column widths and prevents long argument strings from corrupting terminal or HTML tables. |

---

### Why RSS is Included Alongside %MEM

A common mistake in memory monitoring is relying exclusively on `%mem`. The architectural reasons for reporting both `%mem` and `rss` side-by-side are:
1. **Relative vs. Absolute Context:** On a lightweight VM with 2 GB RAM, a process consuming 10% `%MEM` uses ~200 MB. On a production server with 256 GB RAM, 10% `%MEM` represents **25.6 GB** of memory! Percentage alone lacks scale.
2. **True Physical Footprint:** Virtual Memory Size (`VSZ`) includes shared libraries, memory-mapped files, and memory reserved but never written to. In contrast, `RSS` measures the actual physical hardware RAM pages mapped to the process.
3. **Capacity Planning & Triage:** Seeing that a process consumes `8.0%` of system RAM **and** occupies `301.4 MB` enables administrators to instantly evaluate how much headroom remains and whether memory scaling is required.

---

### Process Monitoring Workflow Diagram

```text
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
          | Exit Code 2           |        | via ps -eo ... --sort=-%mem|
          +-----------------------+        +-------------+-------------+
                                                         |
                                                         v
                                           +---------------------------+
                                           | Extract Top N Processes   |
                                           | Convert RSS KB -> MB      |
                                           | Evaluate Float %MEM >= Th |
                                           | via Awk Numerical Engine  |
                                           +-------------+-------------+
                                                         |
                                      +------------------+------------------+
                                      |                                     |
                          [Any %MEM >= Threshold?]                          |
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
                         | Output Table to Stdout    |        | to logs/high_memory.log   |
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
- **100% Read-Only Operations:** The script only inspects system telemetry via `ps`, `free`, and `/proc`.
- **Zero Process Modifications:** No processes are killed, terminated, signaled, reniced, or altered in any way.
- **Filesystem Isolation:** All file writes (audit logs, HTML dashboards, command logs, markdown documentation) are strictly confined within `AS_20/`. No system directories (`/etc`, `/usr`, `/home`) or block devices are touched.

---

## 3. Real-Data Requirement

All output generated by `high_memory_detector.sh` and `run.sh` reflects the **actual live memory-consuming processes and memory telemetry** of the host machine at the exact second of execution. No values are hardcoded, mocked, or replayed from previous runs. Every execution recalculates current RAM usage and process states.

---

## 4. Script Features & Implementation

`high_memory_detector.sh` includes:
- **Live Real-Data Execution:** Retrieves live, actual memory-consuming processes on whichever machine it runs. Never hardcoded or mock data.
- **Dynamic Thresholding:** Uses configurable memory percentage threshold (default `30.0%`) as a variable, not hardcoded.
- **Awk Floating-Point Evaluation:** Uses `awk` to perform floating-point numerical comparisons (`$4 >= thresh`). This prevents Bash integer truncation bugs where `29.8%` would incorrectly be compared as `29`.
- **Human-Readable RSS Conversion:** Accurately converts Resident Set Size from raw kilobytes to megabytes (`RSS_MB = RSS_KB / 1024.0`).
- **Overall System Memory Context:** Automatically executes `free -h` and reports total, used, free, shared, buff/cache, and available memory alongside the process table so numbers have proper context.
- **Flexible Argument Parsing:**
  - `-n <count>`: Changes how many top processes are displayed (default: `5`).
  - `-t <threshold>`: Sets custom memory alert threshold (default: `30.0`).
  - `-l <logfile>`: Directs audit entries to custom log path.
  - `-h` / `--help`: Displays comprehensive manual.
- **Defensive Input Validation:** Enforces strict regex validation on numeric arguments (`^[1-9][0-9]*$` for count, `^[0-9]+(\.[0-9]+)?$` for threshold), exiting with code 2 on syntax errors.
- **Persistent Chronological Logging:** Appends (`>>`) every scan with full system context (timestamp, host, kernel, user, load avg, total processes, system memory summary, peak %MEM, cumulative top RSS) to `logs/high_memory.log`.
- **Cross-Platform Compatibility:** Detects OS via `uname -s`. Automatically uses `ps -eo ... --sort=-%mem` on Linux, and adapts to `ps -eo ... -m` on macOS (Darwin BSD `ps`). Handles `free` on Linux and falls back to `vm_stat` / `sysctl` on macOS.
- **Comprehensive Error Trapping:** Validates presence and return codes of system utilities (`ps`, `awk`, `free`), failing gracefully with actionable error messages rather than crashing silently.

---

## ## Command to Execute

Run this **single command** from inside the `AS_20/` directory:

```bash
bash run.sh
```

*(From repository root, execute: `cd AS_20 && bash run.sh`)*

### 🌐 Cross-Platform Execution Notes

- **🐧 Linux & 🍎 macOS:** Run `bash run.sh` directly in any standard terminal. On Linux, the script automatically launches the report via `xdg-open`. On macOS, it invokes `open report.html`.
- **🪟 Windows (WSL):** Run `bash run.sh` inside WSL. The script translates the path using `wslpath -w` and dispatches `explorer.exe` to open the report inside your Windows default browser.
- **🪟 Windows (Git Bash / MSYS / Cygwin):** Run `bash run.sh` in Git Bash. The script detects the environment and invokes `start "" report.html`.

> [!NOTE]
> The HTML report (`report.html`) **regenerates live on every run** from scratch using real-time system metrics. It is never a static or stale document.

---

## ## Viewing the HTML Report

The `bash run.sh` script automatically opens `report.html` upon execution. If you need to open or view the report manually, use the appropriate command for your platform:

### 🪟 Windows WSL (Manual Fallback)
```bash
explorer.exe "$(wslpath -w report.html)"
```
*Windows File System Path Equivalent:*
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_20\report.html
```

### 🐧 Native Linux Desktop (X11 / Wayland)
```bash
xdg-open report.html
```

### 🍎 macOS
```bash
open report.html
```

### 🪟 Windows Git Bash / Command Prompt
```bash
start "" report.html
```

---

## 5. Command-Line Options & Syntax

`high_memory_detector.sh` supports several flags for automation pipelines and monitoring agents:

```bash
./high_memory_detector.sh [OPTIONS]
```

| Flag | Parameter | Default | Description |
|---|---|---|---|
| `-n` | `<count>` | `5` | Number of top memory-consuming processes to display |
| `-t` | `<threshold>` | `30.0` | Memory percentage threshold (&ge; triggers alert flag) |
| `-l` | `<logfile>` | `logs/high_memory.log` | Path to append scan audit log |
| `-h`, `--help` | None | N/A | Displays full usage manual and exits |

### Usage Examples

```bash
# Baseline scan: display top 5 processes with default 30.0% threshold
./high_memory_detector.sh

# Display top 10 processes
./high_memory_detector.sh -n 10

# Flag any process consuming >= 15.0% of system memory
./high_memory_detector.sh -n 5 -t 15.0

# Pass arguments directly through the unified launcher
bash run.sh -n 5 -t 10.0
```

---

## 6. Sample Live Terminal Output

```text
==================================================================================
                HIGH MEMORY PROCESS DETECTION REPORT (LIVE DATA)                  
==================================================================================
 Timestamp       : 2026-09-29 23:31:00
 Host / Node     : SP (OS: Linux, Kernel: 6.18.33.2-microsoft-standard-WSL2)
 Active User     : pankaj
 System Load     : 1.06 0.78 0.73 (1m, 5m, 15m)
 Total Processes : 32 running in process table
 Top Processes   : 5 requested (Displaying 5)
 Memory Threshold: 30.0% (Processes >= threshold flagged as high memory)
----------------------------------------------------------------------------------
OVERALL SYSTEM MEMORY CONTEXT (free -h):
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       682Mi       1.8Gi       4.2Mi       1.5Gi       3.1Gi
Swap:          1.0Gi          0B       1.0Gi
----------------------------------------------------------------------------------
PID      PPID     USER              %MEM    RSS (MB)    %CPU   COMMAND              STATUS / ALERT
-------- -------- -------------- ------- ----------- -------   -------------------- -------------------
1531     239      pankaj            7.7%     300.9 MB   80.3%   agy                  ✓ NORMAL
232      1        root              0.9%      37.9 MB    0.2%   containerd           ✓ NORMAL
237      1        root              0.8%      32.0 MB    0.0%   unattended-upgr      ✓ NORMAL
177      1        root              0.7%      29.2 MB    0.0%   networkd-dispat      ✓ NORMAL
62       1        root              0.4%      16.4 MB    0.1%   systemd-journal      ✓ NORMAL
----------------------------------------------------------------------------------
✓ All top 5 processes are operating within normal memory limits (< 30.0%).
   Top 5 processes consume a cumulative 416.4 MB of physical RAM (Peak: 7.7%).
==================================================================================
Audit log appended to: logs/high_memory.log
```

---

## 7. Audit Logging Format (`logs/high_memory.log`)

Every run appends a structured entry to `logs/high_memory.log`:

```text
================================================================================
[2026-09-29 23:31:00] HIGH MEMORY AUDIT SCAN
Host: SP | OS: Linux | Kernel: 6.18.33.2-microsoft-standard-WSL2 | Scanned by: pankaj
Parameters: Top Count = 5 | Memory Threshold = 30.0%
System State: Total Processes = 32 | Load Avg = 1.06 0.78 0.73
--------------------------------------------------------------------------------
System Memory Summary:
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       682Mi       1.8Gi       4.2Mi       1.5Gi       3.1Gi
Swap:          1.0Gi          0B       1.0Gi
--------------------------------------------------------------------------------
PID      PPID     USER              %MEM    RSS (MB)    %CPU   COMMAND              STATUS
-------- -------- -------------- ------- ----------- -------   -------------------- ------
1531     239      pankaj            7.7%     300.9 MB   80.3%   agy                  ✓ NORMAL
232      1        root              0.9%      37.9 MB    0.2%   containerd           ✓ NORMAL
237      1        root              0.8%      32.0 MB    0.0%   unattended-upgr      ✓ NORMAL
177      1        root              0.7%      29.2 MB    0.0%   networkd-dispat      ✓ NORMAL
62       1        root              0.4%      16.4 MB    0.1%   systemd-journal      ✓ NORMAL
--------------------------------------------------------------------------------
Result: 0 process(es) >= 30.0% threshold. Peak %MEM: 7.7%. Cumulative Top RSS: 416.4 MB.
================================================================================
```

---

## 8. Exit Codes & Error Trapping

The detector adheres to POSIX error-handling standards:

| Exit Code | Meaning | Cause |
|---|---|---|
| `0` | Success | Normal execution and live process table inspection. |
| `1` | System Environment Error | `ps` or `awk` not installed or query failed. |
| `2` | Syntax / Input Error | Invalid CLI flag or non-numeric argument passed. |

---

## 9. Deliverables Summary

| File | Purpose |
|---|---|
| `high_memory_detector.sh` | Core process memory monitoring, RSS MB conversion, and audit logging script. |
| `run.sh` | Unified cross-platform runner and HTML dashboard generator. |
| `report.html` | Self-contained dark-themed live dashboard with inline CSS. |
| `logs/high_memory.log` | Persistent append-only chronological scan audit log. |
| `commands_used.md` | Log of all commands executed during development and testing. |
| `README.md` | Complete project documentation, usage guide, and architectural notes. |
