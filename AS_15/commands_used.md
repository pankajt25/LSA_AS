# Commands Used Log & Viva Preparation Guide

**Course:** Linux System Administration (E1ITA307) — Automation Sprint  
**Problem Statement #15:** Error Log Report — Automated Log Extraction & Summary  
**Working Directory (Sandbox):** `/mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_15`  

---

## 1. Chronological Command History

Every command executed during the development, testing, and verification of `error_log_report.sh` is logged below with a one-line plain-English explanation:

| # | Command Executed | Plain-English Explanation (Viva Reference) |
|---|------------------|--------------------------------------------|
| 1 | `pwd && ls -la` | Checked the initial working directory path and confirmed that the sandbox folder was clean. |
| 2 | `mkdir -p reports && cat > sample_syslog.log << 'EOF' ... EOF` | Created the destination `reports` folder and generated the synthetic sample syslog file for testing. |
| 3 | `cat sample_syslog.log` | Printed and verified the contents of the synthetic syslog file on screen. |
| 4 | `bash -c 'KEYWORDS=(...); KEYWORD_REGEX=...; ...'` | Prototyped and tested array-to-ERE regex generation and keyword match counting in Bash. |
| 5 | `bash -c 'set -euo pipefail; count=$(grep ...)'` | Tested defensive grep return code handling to prevent script aborts when zero matches occur under `set -e`. |
| 6 | `grep -i -E "error\|..." sample_syslog.log \| awk -F': ' ... \| sort \| uniq -c \| sort -rn` | Tested Unix pipeline chaining `grep`, `awk`, `sort`, and `uniq` to extract and rank error-reporting daemons. |
| 7 | `grep -i -E "..." sample_syslog.log \| awk '{ ... }' \| sort \| uniq -c \| sort -rn` | Tested message pattern extraction and frequency ranking for recurring errors. |
| 8 | `awk -v c=3 -v t=5 'BEGIN { ... }'` | Prototyped and verified dynamic calculation of percentages and ASCII distribution bar rendering in `awk`. |
| 9 | `chmod +x error_log_report.sh && ./error_log_report.sh` | Made the script executable and ran it against the default sandboxed `sample_syslog.log`. |
| 10 | `ls -la reports/ && cat reports/error_report_*.log` | Inspected the `reports` directory and verified the persisted timestamped report format and accuracy. |
| 11 | `./error_log_report.sh non_existent_file.log \|\| echo "Exit code: $?"` | Tested defensive error handling for missing files, confirming a clear stderr message and exit code 1. |
| 12 | `touch empty.log && ./error_log_report.sh empty.log` | Created an empty 0-byte file and confirmed the script outputs a clear warning message and empty log record. |
| 13 | `cat > clean_syslog.log << 'EOF' ... EOF && ./error_log_report.sh clean_syslog.log` | Created a clean log without errors and verified the explicit "no errors detected" status report. |
| 14 | `./error_log_report.sh --help` | Tested the command-line help manual flag (`-h` / `--help`). |
| 15 | `cat > test_multi_errors.log << 'EOF' ... EOF && ./error_log_report.sh test_multi_errors.log` | Created a 15-error log and verified that Section 4 strictly truncates output to the 10 most recent error entries. |
| 16 | `mv empty.log empty_syslog.log && rm test_multi_errors.log` | Standardized test filenames in the sandbox and removed scratch test data. |
| 17 | `rm reports/error_report_20260923_114753.log` | Cleaned up the scratch test report produced during multi-error testing. |
| 18 | `./error_log_report.sh` | Verified default execution without arguments using default `sample_syslog.log`. |
| 19 | `./error_log_report.sh ./sample_syslog.log` | Verified execution when explicitly passing the sample log path as `$1`. |
| 20 | `./error_log_report.sh ./clean_syslog.log` | Verified execution against the clean log file (0 error matches). |
| 21 | `./error_log_report.sh ./empty_syslog.log` | Verified execution against the empty log file (0 bytes). |
| 22 | `./error_log_report.sh ./nonexistent_file.log \|\| echo "Exit code: $?"` | Verified non-zero exit code (1) and error diagnostic for non-existent files. |
| 23 | `git status` | Inspected working tree status in the git repository. |
| 24 | `git add AS_15/` | Staged all AS_15 solution files, reports, logs, and documentation for commit. |
| 25 | `git commit -m "..."` | Committed AS_15 solution with descriptive message. |
| 26 | `git push origin main` | Pushed committed changes to GitHub remote repository (`origin/main`). |

---

## 2. Key Linux Commands & Viva Justifications

| Utility / Construct | Usage in Script | Why Chosen (Viva Justification) |
|---------------------|-----------------|---------------------------------|
| `grep -i -E` | Case-insensitive Extended Regular Expression search | Matches keywords regardless of case (`ERROR`, `Error`, `error`, `WARNING`, `warning`) across all keywords in a single pass without spawning multiple grep processes. |
| `grep -n` | Line numbering prefix | Attaches original file line numbers (`Line 2`, `Line 4`) so system administrators can immediately jump to the exact source line in their editor or pager. |
| `wc -l` and `wc -c` | Line and byte counting | Provides high-speed line and byte totals without loading the whole file into memory. |
| `awk` | Text formatting, floating-point math, ASCII bar rendering | Bash only supports integer arithmetic; `awk` enables floating-point division for percentages (`(c / total) * 100`) and tabular formatting (`printf`) natively. |
| `sort \| uniq -c \| sort -rn` | Frequency analysis pipeline | The canonical Unix pipeline to deduplicate recurring errors, count occurrences (`uniq -c`), and order by frequency descending (`sort -rn`). |
| `tail -n 10` | Recent lines extraction | Retrieves the last 10 matching errors in chronological order, fulfilling the requirement for quick tail-style review. |
| `tee` | Dual stream redirection | Writes report output simultaneously to stdout (for terminal viewing) and a timestamped file in `reports/` (for archival and audit trails). |
| `set -euo pipefail` | Defensive shell safety flags | Prevents bugs caused by unset variables, catches failing commands immediately, and tracks pipe failures across all pipeline stages. |

---

## 3. Sandboxing Verification

- All development, script generation, sample logs, and generated reports were strictly confined to:  
  `/mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_15`
- No system files in `/var/log`, `/etc`, `/dev`, or outside this project directory were touched, modified, or deleted.
