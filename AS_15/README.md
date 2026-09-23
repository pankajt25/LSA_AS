# Automation Sprint #15: Error Log Report (Log Analysis & Reporting)

**Course:** Linux System Administration (E1ITA307)  
**Problem Statement #15:** Error Log Report — Automated extraction, severity categorization, frequency ranking, and statistical reporting from Linux system and application log files.

---

## 📌 Overview

This project provides an automated, self-contained Bash solution (`error_log_report.sh`) designed for system administrators to rapidly inspect, filter, and summarize error events from Linux logs. It extracts events matching configurable severity keywords (`error`, `fail`, `critical`, `fatal`, `warn`), computes statistical breakdowns, ranks recurring signatures, presents a tail-style view of the 10 most recent error entries with original line numbers, and persists immutable timestamped audit reports.

---

## 📂 Project Structure

```text
AS_15/
├── error_log_report.sh     # Core production-ready Bash log analyzer & reporter
├── sample_syslog.log       # Synthetic test log with errors, warnings, fatal, and info events
├── clean_syslog.log        # Edge-case test log containing zero errors
├── empty_syslog.log        # Edge-case test log with 0 bytes (empty file)
├── commands_used.md        # Chronological command history & viva preparation guide
├── reports/                # Directory storing timestamped error audit reports
└── README.md               # Project documentation
```

---

## ⚙️ Features

1. **Configurable Keyword Array:** Monitored keywords are defined in a Bash array variable (`KEYWORDS=("error" "fail" "critical" "fatal" "warn")`), allowing quick extension (e.g., adding `panic`, `alert`) without touching parsing logic.
2. **Single-Pass ERE Pattern Matching:** Compiles keywords into an Extended Regular Expression (`error|fail|critical|fatal|warn`) evaluated via `grep -i -E`, minimizing disk I/O and process overhead.
3. **Comprehensive Executive Summary:** Computes total lines analyzed, error-matching line count, and error proportion percentage using native floating-point math in `awk`.
4. **Severity Breakdown & ASCII Visual Bars:** Categorizes matching entries per severity keyword, displays percentage shares, and renders dynamic ASCII distribution progress bars.
5. **Recurring Pattern Frequency Ranking:** Leverages a standard Unix pipeline (`grep | sort | uniq -c | sort -rn | head -n 5`) to surface repeated error messages and runaway loops.
6. **Chronological Tail Review (10 Most Recent):** Uses `grep -n` and `tail -n 10` to display the last 10 errors with original source file line numbers for immediate triage.
7. **Dual-Stream Synchronization (`tee`):** Formats output cleanly to stdout and simultaneously persists an audit report in `reports/error_report_<timestamp>.log`.
8. **Defensive Shell Scripting:**
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
- `LOG_FILE_PATH` *(Optional)*: Path to the target log file (defaults to `sample_syslog.log` in the sandbox if omitted).
- `-h`, `--help`: Display the usage manual and argument documentation.

### Example Invocations

```bash
# 1. Run using the default sandboxed sample log:
./error_log_report.sh

# 2. Run with an explicit path to the sample log:
./error_log_report.sh ./sample_syslog.log

# 3. Run against edge-case test logs:
./error_log_report.sh ./clean_syslog.log
./error_log_report.sh ./empty_syslog.log

# 4. Run against custom application or system logs:
./error_log_report.sh /path/to/custom_application.log

# 5. Display command help:
./error_log_report.sh --help
```

---

## 📊 Sample Report Preview

```text
================================================================================
                       SYSTEM LOG ERROR ANALYSIS REPORT
================================================================================
Generated On       : 2026-09-23 11:50:00 IST
Target Log File    : /mnt/d/.../AS_15/sample_syslog.log
Log File Size      : 434 bytes
Total Log Entries  : 7
Monitored Keywords : error fail critical fatal warn
================================================================================

[+] SECTION 1: EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
Status                  : [ALERT] Errors/Warnings detected!
Total Lines Analyzed    : 7
Matching Error Entries  : 5 (71.43% of total entries)

[+] SECTION 2: SEVERITY & KEYWORD BREAKDOWN
--------------------------------------------------------------------------------
KEYWORD        MATCHING LINES SHARE (%)    DISTRIBUTION            
--------------------------------------------------------------------------------
ERROR          2              40.0%        [########------------]
FAIL           3              60.0%        [############--------]
CRITICAL       1              20.0%        [####----------------]
FATAL          1              20.0%        [####----------------]
WARN           1              20.0%        [####----------------]
--------------------------------------------------------------------------------
Note: The sum of individual keyword counts may exceed total error lines because
      a single log entry can contain multiple keywords (e.g. 'ERROR: failed...').

[+] SECTION 3: FREQUENCY OF RECURRING ERROR PATTERNS
--------------------------------------------------------------------------------
COUNT        | ERROR ENTRY PATTERN
--------------------------------------------------------------------------------
1            | Sep 23 10:06:20 host app: FATAL: service crashed unexpectedly
1            | Sep 23 10:05:59 host app: ERROR: authentication failed for user admin
1            | Sep 23 10:03:44 host app: CRITICAL: disk write failure on /dev/sdb1
1            | Sep 23 10:02:03 host app: WARNING: low memory detected
1            | Sep 23 10:01:15 host app: ERROR: failed to connect to database

[+] SECTION 4: 10 MOST RECENT MATCHING LINES (CHRONOLOGICAL)
--------------------------------------------------------------------------------
ORIG LINE  | LOG ENTRY CONTENT
--------------------------------------------------------------------------------
Line 2     | Sep 23 10:01:15 host app: ERROR: failed to connect to database
Line 3     | Sep 23 10:02:03 host app: WARNING: low memory detected
Line 4     | Sep 23 10:03:44 host app: CRITICAL: disk write failure on /dev/sdb1
Line 6     | Sep 23 10:05:59 host app: ERROR: authentication failed for user admin
Line 7     | Sep 23 10:06:20 host app: FATAL: service crashed unexpectedly
================================================================================
                          END OF ERROR LOG REPORT
================================================================================
```

---

## 📝 Viva / Evaluation Reference

See [`commands_used.md`](./commands_used.md) for the complete chronological command execution log with plain-English explanations and viva justification notes for all Linux utilities (`grep`, `awk`, `sort`, `uniq`, `wc`, `tee`).
