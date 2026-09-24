# Server Process Check — Automation Sprint (AS_18)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Process Management & Process Table Inspection  
**Problem Statement #18:** An administrator wants to verify whether a particular application process is running. Create a script that reports its status.

---

## 1. Overview & Architecture

System administrators routinely need to verify whether critical application daemons (web servers, database engines, background workers) are active and healthy. Naive implementations frequently rely on piping `ps aux` to `grep`, which introduces race conditions, brittle string scraping, and false-positive self-matching.

`server_process_check.sh` is an automated, production-grade Bash utility designed to inspect the Linux process table reliably using `pgrep -f` and retrieve accurate instance counts, PID lists, and runtime duration for the oldest running instance via `ps -o etime= -p <pid>`.

### Why `pgrep` Is Preferred Over `ps aux | grep <name>`

| Dimension | `pgrep -f "<name>"` | `ps aux | grep "<name>"` |
|---|---|---|
| **Self-Matching** | **Immune:** Deliberately ignores its own process in `/proc` | **Prone:** Spawns a grep process matching its own pattern (requires `grep -v grep` hacks) |
| **Interface** | **Kernel Direct:** Reads process records directly from `/proc` | **String Scraping:** Serializes `/proc` to text, pipes across processes, parses stdout |
| **Exit Status** | **POSIX Clean:** `0` (found), `1` (none), `2` (regex error) | **Fragile:** Reflects pipeline exit status; pipefail masking can obscure failures |
| **Native Filtering** | **Comprehensive:** Built-in `-f` (full cmdline), `-i` (case-insensitive), `-o` (oldest), `-u` (user) | **Manual:** Requires manual combinations of `grep`, `awk`, `cut`, and `sort` |
| **Formatting Resilience** | **Immune:** Bypasses terminal column widths and truncation | **Vulnerable:** `ps` columns can truncate long command lines based on terminal width |

### Process Check Workflow Diagram
```
                     +-------------------------------+
                     |  Start: Parse CLI Arguments   |
                     |  (-s, -d, -h, or Process $1)  |
                     +---------------+---------------+
                                     |
                         [Any process name given?]
                                     |
                    +----------------+----------------+
                    | No                              | Yes
                    v                                 v
        +-----------------------+        +---------------------------+
        | Print Usage & Error   |        | Escape Regex Characters   |
        | Log to audit log      |        | via sed metacharacter map |
        | Exit code 2           |        +-------------+-------------+
        +-----------------------+                      |
                                                       v
                                         +---------------------------+
                                         | Execute pgrep [-i] -f     |
                                         +-------------+-------------+
                                                       |
                                                       v
                                         +---------------------------+
                                         | Filter Out $$, $PPID, and |
                                         | ephemeral script subshells|
                                         +-------------+-------------+
                                                       |
                                            [Matching PIDs > 0?]
                                                       |
                    +----------------------------------+----------------------------------+
                    | Yes                                                                 | No
                    v                                                                     v
        +-------------------------------+                                     +-----------------------+
        | Sort PIDs by etimes (seconds) |                                     | Print "NOT running"   |
        | Select oldest instance PID    |                                     | Log STOPPED to audit  |
        | Query ps -o etime= -p <pid>   |                                     | Exit code 1           |
        | Print RUNNING card & PIDs     |                                     +-----------------------+
        | Log RUNNING to audit log      |
        | Exit code 0                   |
        +-------------------------------+
```

---

## 2. Sandboxing & Safety Notice (Mandatory)

This sprint strictly adheres to the project sandboxing requirements:
- **100% Read-Only Operations:** The script and all testing procedures only inspect system processes via `pgrep` and `ps`.
- **Zero Process Modifications:** No system processes were started, stopped, killed, or signaled.
- **Filesystem Isolation:** All generated files (logs, HTML dashboard, markdown reports) reside exclusively inside `AS_18/`. No block devices, `/etc`, or external files were modified.

---

## 3. Script Features & Implementation

`server_process_check.sh` includes:
- **Positional & Flag Handling:** Accepts `<process_name>` as `$1`, with support for `-s` (`--strict`) and `-d` (`--default`).
- **Safe Demo Default:** Defaults to safe, always-present user process `bash` if `--default` is specified.
- **Case Sensitivity Control:** Case-insensitive partial matching by default (`pgrep -i -f`); toggles to strict case-sensitive matching (`pgrep -f`) via `-s` / `--strict`.
- **Regex Metacharacter Sanitization:** Employs `sanitize_regex` using `sed 's/[][\\.^$*+?(){}|]/\\&/g'` so names like `[kworker]`, `c++`, or `app(v1)` never crash `pgrep` with regex syntax errors.
- **Defensive Self-Filtering:** Dynamically strips `$$`, `$PPID`, and transient subshells containing the script name from matched results to prevent false-positive self-detection.
- **Oldest Instance Uptime:** Uses `ps -o pid=,etimes=,etime= -p <pids> | sort -k2,2rn | head -n1` to accurately identify the oldest running process and extracts its runtime via `ps -o etime= -p <pid>`.
- **Structured Audit Logging:** Appends timestamped audit entries to `logs/process_check.log` with operation mode, target, instance count, PIDs, and uptime.
- **Standardized Return Codes:**
  - `0`: Process is active and running.
  - `1`: Process is not running (0 instances found).
  - `2`: Usage error (missing argument or invalid flag).

---

## 4. Usage Instructions & Test Verification

### Test Case 1: Running Process (`bash`)
Verify a process known to be active:
```bash
./server_process_check.sh bash
```
Output:
```text
================================================================
              LINUX SERVER PROCESS STATUS CHECK                 
================================================================
 Target Process       : bash
 Matching Mode        : Case-Insensitive
 Audit Log File       : /mnt/d/.../AS_18/logs/process_check.log
----------------------------------------------------------------
 Operational Status   : ACTIVE [RUNNING]
 Instance Count       : 3 instance(s)
 Active PID(s)        : 365 569 3955
 Oldest Instance      : PID 365
 Oldest Uptime        : 01:06:53 (ps -o etime= -p 365)
================================================================
✓ Process 'bash' is RUNNING with 3 active instance(s).
```

### Test Case 2: Nonexistent Process (`not-a-real-process-xyz`)
Verify an inactive/absent process:
```bash
./server_process_check.sh not-a-real-process-xyz
```
Output:
```text
================================================================
              LINUX SERVER PROCESS STATUS CHECK                 
================================================================
 Target Process       : not-a-real-process-xyz
 Matching Mode        : Case-Insensitive
 Audit Log File       : /mnt/d/.../AS_18/logs/process_check.log
----------------------------------------------------------------
 Operational Status   : INACTIVE [NOT RUNNING]
 Instance Count       : 0 instances found
================================================================
✗ Process 'not-a-real-process-xyz' is NOT running on this server.
```
*(Exit code: 1)*

### Test Case 3: Missing Argument / Usage Error
Verify that invoking without parameters displays usage and exits cleanly:
```bash
./server_process_check.sh
```
Output:
```text
[ERROR] No process name specified.
Please provide a process name as an argument, or use --default to test 'bash'.

Usage: server_process_check.sh [OPTIONS] <PROCESS_NAME>
... (manual details) ...
```
*(Exit code: 2)*

### Test Case 4: Strict / Case-Sensitive Matching (`-s`)
Demonstrates flag handling and case sensitivity:
```bash
# Strict mode: lowercase 'bash' matches
./server_process_check.sh -s bash    # Exit 0: RUNNING

# Strict mode: uppercase 'BASH' does NOT match lowercase processes
./server_process_check.sh -s BASH    # Exit 1: NOT RUNNING

# Default mode: case-insensitive matches regardless of case
./server_process_check.sh BASH       # Exit 0: RUNNING
```

### Test Case 5: Safe Regex Character Handling
Verify that special regex characters do not crash `pgrep`:
```bash
./server_process_check.sh "nonexistent[app]+test*"
```
*(Exit code: 1 without regex syntax error)*

---

## 5. Viewing the HTML Report

A single, self-contained, dark-themed HTML report dashboard is available at [`report.html`](report.html). It features color-coded status cards for each test run, operational metric tiles, terminal execution session transcripts, a scrollable view of `logs/process_check.log`, and rubric compliance verification.

### Option A: From Inside WSL (Recommended)
Launch the report directly in your default Windows browser:
```bash
explorer.exe $(wslpath -w report.html)
```

### Option B: Direct Windows Path
Open your web browser and navigate directly to:
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_18\report.html
```
*(Or paste this path into Windows File Explorer address bar or Run dialog `Win + R`)*

> **Self-Contained Note:** `report.html` is completely standalone with inline CSS styling. It does not require any local web server (Node/Python/Apache) or external internet connection.

---

## 6. Project Artifacts

| File | Description |
|---|---|
| [`server_process_check.sh`](server_process_check.sh) | The primary bash script with complete process inspection logic and why-focused comments |
| [`logs/process_check.log`](logs/process_check.log) | Structured audit log recording check timestamps, modes, instance counts, and PIDs |
| [`report.html`](report.html) | Standalone dark-themed HTML report dashboard with status cards and log viewer |
| [`commands_used.md`](commands_used.md) | Exhaustive log of every command run during development with one-line descriptions |
| [`README.md`](README.md) | Local project documentation, architecture diagram, usage guide, and rubric checklist |

---

## 7. Rubric Self-Check

- [x] **Strict Sandboxing:** Nothing modified outside `AS_18/`; no real process killed, started, or altered (read-only inspection).
- [x] **All 3 Mandated Tests Run:** Tested and confirmed (1) running `bash`, (2) nonexistent process, (3) no argument usage error.
- [x] **pgrep Safety:** Escaped user-supplied regex metacharacters via `sed`; zero injection/syntax crash risk.
- [x] **Real Data in Report:** `report.html` reflects actual captured command runs, PIDs, uptimes, and real log entries.
- [x] **Report Viewing Documented:** README provides both WSL `explorer.exe` command and direct Windows path.
- [x] **Code Commentary Quality:** Comments thoroughly explain *why* `pgrep` is preferred over `ps aux | grep`, why defensive filtering is necessary, and how oldest instance uptime is computed.
