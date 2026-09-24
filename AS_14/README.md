# Automation Sprint #14: Suspicious IP Detection (Security Monitoring)

**Course:** Linux System Administration (E1ITA307)  
**Problem Statement:** Automated SSH Log Security Monitor — Detect suspicious IP addresses attempting brute-force attacks from authentication logs.

---

## 📌 Overview

This project provides an automated bash solution (`suspicious_ip_detector.sh`) that parses SSH authentication logs (`/var/log/auth.log` or sandbox test logs), identifies repeated failed password attempts, ranks offending IP addresses in descending order of aggression, and logs detailed audit reports.

---

## 📂 Project Structure

```text
AS_14/
├── suspicious_ip_detector.sh   # Core production-ready bash detector script
├── test_auth.log               # Synthetic auth log with brute-force & legitimate patterns
├── empty_auth.log              # Empty log edge-case test file
├── commands_used.md            # Viva preparation log & explanation table
├── report.html                 # Standalone dark-themed dashboard report
├── reports/                    # Output directory for timestamped security audit reports
└── README.md                   # Project documentation
```

---

## ⚙️ Features

1. **Precision Regex Extraction:** Uses Perl-compatible regular expressions (`grep -oP 'from \K...'`) to isolate IPv4 addresses without column-shifting fragility.
2. **Descending Aggression Ranking:** Groups and tallies failed attempts per IP, sorting them numerically with highest offenders first (`sort | uniq -c | sort -nr`).
3. **Temporal Tracking:** Extracts and displays the `First Seen` and `Last Seen` timestamps for each suspicious IP.
4. **Audit Reporting:** Automatically generates timestamped, human-readable audit reports inside `reports/`.
5. **Defensive Shell Scripting:**
   - Strict mode (`set -euo pipefail`).
   - File existence, readability, and non-emptiness validation.
   - Non-integer threshold rejection.
   - Informative ANSI colored terminal feedback with automatic TTY detection.
   - Clean handling for cases where no threats exceed the threshold.

---

## 🚀 Usage

### Syntax
```bash
./suspicious_ip_detector.sh [LOG_FILE] [THRESHOLD]
```

### Options & Arguments
- `LOG_FILE` *(Optional)*: Path to auth log (default: `~/sprint-sandbox/test_auth.log` or `./test_auth.log`).
- `THRESHOLD` *(Optional)*: Minimum failed login attempts to trigger an alert (default: `5`).
- `-h`, `--help`: Display usage and help message.

### Examples

```bash
# 1. Run with default settings (threshold: 5)
./suspicious_ip_detector.sh

# 2. Run on specific log file with default threshold
./suspicious_ip_detector.sh test_auth.log

# 3. Run with custom threshold (e.g. 2 attempts)
./suspicious_ip_detector.sh test_auth.log 2

# 4. View help
./suspicious_ip_detector.sh --help
```

---

## 📝 Viva / Evaluation Reference

See [`commands_used.md`](./commands_used.md) for a comprehensive table of all commands executed during development and testing, along with plain-English explanations.

---

## Viewing the HTML Report

1. The exact command to open `report.html` in the default Windows browser, run from inside WSL:
   ```bash
   explorer.exe $(wslpath -w report.html)
   ```

2. The alternative manual path via Windows Explorer:
   - If working from `/mnt/d/...` (Windows-mounted): the direct Windows path, e.g. `D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_14\report.html` — double-click it
   - If working from the WSL home directory instead: `\\wsl$\Ubuntu\home\pankaj\sprint-sandbox\report.html` (or `\\wsl.localhost\Ubuntu\home\pankaj\sprint-sandbox\report.html` on newer Windows builds)

3. *Note:* report.html is self-contained — no server needed, just open the file directly.
