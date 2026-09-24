# Automation Sprint #15: Error Log Report (Log Analysis & Reporting)

**Course:** Linux System Administration (E1ITA307)  
**Problem Statement #15:** Error Log Report — Automated extraction, severity categorization, frequency ranking, and statistical reporting from Linux system and application log files.

---

## 📌 Overview

This project provides an automated, production-grade Bash utility (`error_log_report.sh`) designed for system administrators to rapidly inspect, filter, and summarize error events from Linux system logs. It auto-detects live system log sources, extracts events matching configurable severity keywords (`error`, `fail`, `critical`, `fatal`, `warn`), computes statistical breakdowns, ranks recurring signatures, presents a tail-style view of the 10 most recent error entries with line numbers, and persists immutable timestamped audit reports.

### 🛡️ Live System Data Source Auto-Detection
The analyzer automatically inspects available real system log sources in the following priority order:
1. `/var/log/syslog` (Standard system log on Debian/Ubuntu)
2. `/var/log/dpkg.log` (Package manager log on Debian/Ubuntu)
3. `/var/log/apt/history.log` (APT package manager history)
4. `journalctl --no-pager` (Systemd journald system log stream)
5. Fallback: `sample_syslog.log` (Explicitly labeled as: *"synthetic demonstration data — no real log was available on this system"*)

**Actual Source Used on this Host:**
- Detected Source: `/var/log/syslog` (Real Live System Syslog)
- File Size: `937,950 bytes`
- Total Lines Analyzed: `7,611` entries
- Status: **[ALERT] Errors/Warnings detected**
- Matching Error Entries: `474` (6.23% error density)
- Severity Distribution: `WARN` (224), `ERROR` (171), `FAIL` (158), `FATAL` (7), `CRITICAL` (0)

---

## 📂 Project Structure

```text
AS_15/
├── error_log_report.sh     # Core production-ready Bash log analyzer & reporter (auto-detecting)
├── sample_syslog.log       # Synthetic demonstration fallback log (errors, warnings, fatal)
├── clean_syslog.log        # Edge-case test log containing zero errors
├── empty_syslog.log        # Edge-case test log with 0 bytes (empty file)
├── commands_used.md        # Chronological command history & viva preparation guide
├── report.html             # Standalone dark-themed dashboard report (real system data)
├── reports/                # Directory storing timestamped error audit reports
└── README.md               # Project documentation
```

---

## ⚙️ Features

1. **Intelligent Source Auto-Detection:** Automatically discovers and analyzes live system logs (`/var/log/syslog`, `/var/log/dpkg.log`, `/var/log/apt/history.log`, or `journalctl`), falling back to labeled synthetic demonstration data only if no system log is accessible.
2. **Configurable Keyword Array:** Monitored keywords are defined in a Bash array variable (`KEYWORDS=("error" "fail" "critical" "fatal" "warn")`), allowing instant extension during viva (e.g. adding `panic`, `alert`) without modifying downstream code.
3. **Single-Pass ERE Pattern Matching:** Compiles keywords into an Extended Regular Expression (`error|fail|critical|fatal|warn`) evaluated via `grep -i -E`, minimizing disk I/O and process overhead.
4. **Comprehensive Executive Summary:** Computes total lines analyzed, error-matching line count, and error proportion percentage using native floating-point math in `awk`.
5. **Severity Breakdown & ASCII Visual Bars:** Categorizes matching entries per severity keyword, displays percentage shares, and renders dynamic ASCII distribution progress bars.
6. **Robust Recurring Pattern Frequency Ranking:** Leverages `sort | uniq -c | sort -rn | awk 'NR<=5'` to surface repeated error messages without triggering `SIGPIPE` (exit code 141) under `set -o pipefail` on large logs.
7. **Chronological Tail Review (10 Most Recent):** Uses `grep -n` and `tail -n 10` to display the last 10 errors with original source file line numbers for immediate triage.
8. **Dual-Stream Synchronization (`tee`):** Formats output cleanly to stdout and simultaneously persists an audit report in `reports/error_report_<timestamp>.log`.
9. **Defensive Shell Scripting:**
   - Strict execution safety (`set -euo pipefail`).
   - File existence, regular file, and permission checks with clear diagnostics and exit code `1`.
   - Explicit warnings and reports for empty logs (0 bytes).
   - Explicit `[OK] No error-relevant keywords detected` notice when logs are clean.

---

## 🚀 Usage

### Syntax
```bash
./error_log_report.sh [LOG_FILE_PATH]
```

### Arguments & Options
- `LOG_FILE_PATH` *(Optional)*: Path to the target log file. If omitted, auto-detects `/var/log/syslog`.
- `-h`, `--help`: Display the usage manual and argument documentation.

### Example Invocations

```bash
# 1. Run using auto-detected live system log (/var/log/syslog):
./error_log_report.sh

# 2. Run with explicit override for system log:
./error_log_report.sh /var/log/syslog

# 3. Run with synthetic demonstration fallback log:
./error_log_report.sh ./sample_syslog.log

# 4. Run against edge-case test logs:
./error_log_report.sh ./clean_syslog.log
./error_log_report.sh ./empty_syslog.log

# 5. Display command help:
./error_log_report.sh --help
```

---

## 📊 Live Report Preview (/var/log/syslog)

```text
================================================================================
                       SYSTEM LOG ERROR ANALYSIS REPORT
================================================================================
Generated On       : 2026-09-24 12:46:57 IST
Target Log File    : /var/log/syslog
Log Source Type    : real system log (/var/log/syslog)
Log File Size      : 937950 bytes
Total Log Entries  : 7611
Monitored Keywords : error fail critical fatal warn
================================================================================

[+] SECTION 1: EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
Status                  : [ALERT] Errors/Warnings detected!
Total Lines Analyzed    : 7611
Matching Error Entries  : 474 (6.23% of total entries)

[+] SECTION 2: SEVERITY & KEYWORD BREAKDOWN
--------------------------------------------------------------------------------
KEYWORD        MATCHING LINES SHARE (%)    DISTRIBUTION            
--------------------------------------------------------------------------------
ERROR          171            36.1%        [#######-------------]
FAIL           158            33.3%        [######--------------]
CRITICAL       0              0.0%         [--------------------]
FATAL          7              1.5%         [--------------------]
WARN           224            47.3%        [#########-----------]
--------------------------------------------------------------------------------
```

---

## 📝 Viva / Evaluation Reference

See [`commands_used.md`](./commands_used.md) for the complete chronological command execution log with plain-English explanations and viva justification notes for all Linux utilities (`grep`, `awk`, `sort`, `uniq`, `wc`, `tee`).

---

## 🖥️ Viewing the HTML Report

1. Command to open `report.html` in the default Windows browser from inside WSL:
   ```bash
   explorer.exe $(wslpath -w report.html)
   ```

2. Direct Windows Explorer path:
   - `D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_15\report.html`

3. *Note:* `report.html` is self-contained — no server needed, just open the file directly.
