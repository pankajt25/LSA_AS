# Automation Sprint #14: Suspicious IP Detection (Security Monitoring)

**Course:** Linux System Administration (E1ITA307)  
**Problem Statement:** Automated SSH Log Security Monitor — Detect suspicious IP addresses attempting brute-force attacks from authentication logs.

---

## 📌 Overview

This project provides an automated bash solution (`suspicious_ip_detector.sh`) that monitors SSH authentication logs, identifies repeated failed password attempts, ranks offending IP addresses in descending order of aggression, and logs detailed audit reports.

### 🛡️ Live System Data Source Detection
The detector dynamically checks for real system log sources in the following precedence order:
1. `/var/log/auth.log` (Standard Debian/Ubuntu authentication log)
2. `/var/log/secure` (Standard RHEL/CentOS/Fedora authentication log)
3. `journalctl -u ssh --no-pager` / `journalctl _COMM=sshd --no-pager` (Systemd journald logs)
4. Fallback: `test_auth.log` (Explicitly labeled as: *"synthetic demonstration data — no real auth log was available on this system"*)

**Actual Source Used on this Host:**
- Detected Source: `/var/log/auth.log` (Real Live System PAM/Auth Log)
- Scan Finding: **0 failed SSH login attempts detected**
- Audit Status: **"No suspicious IP activity found in the current system logs"** (Clean status verified)

---

## 📂 Project Structure

```text
AS_14/
├── suspicious_ip_detector.sh   # Core production-ready bash detector script (with auto-detection)
├── test_auth.log               # Synthetic demonstration data fallback (brute-force test patterns)
├── empty_auth.log              # Empty log edge-case test file
├── commands_used.md            # Viva preparation log & explanation table
├── report.html                 # Standalone dark-themed dashboard report (real system data)
├── reports/                    # Output directory for timestamped security audit reports
└── README.md                   # Project documentation
```

---

## ⚙️ Features

1. **Intelligent Source Auto-Detection:** Automatically locates and reads the system's live authentication source (`/var/log/auth.log`, `/var/log/secure`, or `journalctl`), falling back to synthetic test data only when no system log is accessible.
2. **Precision Regex Extraction:** Uses Perl-compatible regular expressions (`grep -oP 'from \K...'`) to isolate IPv4 addresses without column-shifting fragility.
3. **Descending Aggression Ranking:** Groups and tallies failed attempts per IP, sorting them numerically with highest offenders first (`sort | uniq -c | sort -nr`).
4. **Temporal Tracking:** Extracts and displays the `First Seen` and `Last Seen` timestamps for each suspicious IP.
5. **Clean State Handling:** When zero threats are detected in live logs, reports an explicit positive clean state (`"No suspicious IP activity found in the current system logs"`).
6. **Audit Reporting:** Automatically generates timestamped, human-readable audit reports inside `reports/`.
7. **Defensive Shell Scripting:**
   - Strict mode (`set -euo pipefail`).
   - File existence, readability, and non-emptiness validation.
   - Non-integer threshold rejection.
   - Informative ANSI colored terminal feedback with automatic TTY detection.

---

## ⚡ Command to Execute

Run this **single write command** in your terminal to execute the project and automatically redirect/open the HTML report dashboard in your default browser. It supports **Windows**, **Linux**, and **macOS**:

### 🌐 Universal One-Line Command (Cross-Platform)
```bash
./suspicious_ip_detector.sh; { command -v xdg-open >/dev/null && xdg-open report.html; } || { command -v open >/dev/null && open report.html; } || { command -v explorer.exe >/dev/null && explorer.exe $(wslpath -w report.html 2>/dev/null || echo report.html); } || python3 -m webbrowser report.html
```

> **How it works across platforms:**
> - Executes `./suspicious_ip_detector.sh` (auto-detects real auth log or test fallback).
> - Immediately launches and redirects to `report.html` in your default browser.
> - Works automatically across **Linux** (`xdg-open`), **macOS** (`open`), **Windows WSL** (`explorer.exe`), **Git Bash**, and Python environments.

### 💻 Single Command by Operating System

| Operating System / Environment | Single Command to Execute & Open HTML Site |
|---|---|
| **🐧 Linux** (Ubuntu / Debian / Fedora / Arch) | `./suspicious_ip_detector.sh; xdg-open report.html` |
| **🍎 macOS** | `./suspicious_ip_detector.sh; open report.html` |
| **🪟 Windows (WSL)** | `./suspicious_ip_detector.sh; explorer.exe $(wslpath -w report.html)` |
| **🪟 Windows (Git Bash)** | `./suspicious_ip_detector.sh; start report.html` |
| **🪟 Windows (PowerShell)** | `bash ./suspicious_ip_detector.sh; Start-Process .\report.html` |
| **🪟 Windows (CMD)** | `bash ./suspicious_ip_detector.sh && start report.html` |

*(Note: If running from the repository root, prefix with `cd AS_14 && `)*

---

## 🚀 Usage

### Syntax
```bash
./suspicious_ip_detector.sh [LOG_FILE] [THRESHOLD]
./suspicious_ip_detector.sh [THRESHOLD]
```

### Options & Arguments
- `LOG_FILE` *(Optional)*: Path to auth log. If omitted, auto-detects real system log `/var/log/auth.log`.
- `THRESHOLD` *(Optional)*: Minimum failed login attempts to trigger an alert (default: `5`).
- `-h`, `--help`: Display usage and help message.

### Examples

```bash
# 1. Run with auto-detected live system log (/var/log/auth.log) and default threshold (5)
./suspicious_ip_detector.sh

# 2. Run with auto-detected live log and custom threshold (e.g. 3 attempts)
./suspicious_ip_detector.sh 3

# 3. Explicitly override with synthetic test log for demonstration
./suspicious_ip_detector.sh ./test_auth.log 5

# 4. View help documentation
./suspicious_ip_detector.sh --help
```

---

## 📝 Viva / Evaluation Reference

See [`commands_used.md`](./commands_used.md) for a comprehensive table of all commands executed during development and testing, along with plain-English explanations.

---

## 🖥️ Viewing the HTML Report

The report dashboard `report.html` is completely self-contained (inline CSS, zero server dependencies). You can open it across platforms using:

1. **Quick CLI Command by OS:**
   - **Linux:** `xdg-open report.html`
   - **macOS:** `open report.html`
   - **Windows (WSL):** `explorer.exe $(wslpath -w report.html)`
   - **Windows (Git Bash):** `start report.html`

2. **Direct Windows Explorer Path:**
   - `D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_14\report.html`

3. *See [⚡ Command to Execute](#-command-to-execute) above to run the script and launch this report in a single step.*
