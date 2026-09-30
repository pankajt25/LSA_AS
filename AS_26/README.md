# Package Update Check — Automation Sprint (AS_26)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Package Management & System Update Status Auditing  
**Problem Statement #26:** Create a script to check whether system packages require updates and display the update status.  

---

## Command to Execute

To audit live package update availability across the system, synchronize package repository index metadata, classify pending updates (security vs standard), regenerate the interactive dark-themed HTML report dashboard, and automatically launch it in your default web browser, execute:

```bash
bash run.sh
```

### Platform-Specific One-Line Execution Notes:
- **Windows (WSL2 / Ubuntu):** `cd AS_26 && bash run.sh` — Refreshes repository metadata via `sudo apt-get update -qq`, audits live packages via `apt list --upgradable`, writes timestamped chronological traces to `logs/package_check.log`, serializes structured telemetry to `logs/package_check.json`, regenerates `report.html`, translates Linux paths via `wslpath -w`, and automatically launches the dashboard in your default Windows browser via `explorer.exe`.
- **Linux (Desktop / X11 / Wayland):** `cd AS_26 && bash run.sh` — Executes the package audit workflow and dispatches `report.html` via `xdg-open`.
- **macOS (Darwin):** `cd AS_26 && bash run.sh` — Synchronizes Homebrew formulas via `brew update`, inspects outdated packages via `brew outdated --verbose`, and launches `report.html` via `open`.
- **Windows (Git Bash / MSYS2 / Cygwin):** `cd AS_26 && bash run.sh` — Executes the Bash workflow and dispatches `report.html` via Windows `start ""`.

> **Note on Live Data Regeneration:** `run.sh` **never** serves fabricated or static mock data. Every single execution invokes `package_update_check.sh`, queries this machine's actual package manager index, extracts live package candidate versions, categorizes security fixes, appends to `logs/package_check.log`, exports `logs/package_check.json`, and regenerates `report.html` completely from scratch.

---

## Viewing the HTML Report

If your environment is headless, over SSH, or your web browser does not open automatically, view the generated report manually:

### 1. Windows Subsystem for Linux (WSL2):
```bash
explorer.exe "$(wslpath -w report.html)"
```
**Windows Direct Path Equivalent:**
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_26\report.html
```

### 2. Native Linux Desktop:
```bash
xdg-open report.html
# Or with Python's built-in browser launcher:
python3 -m webbrowser "file://$(pwd)/report.html"
```

### 3. macOS (Darwin):
```bash
open report.html
```

### 4. Windows Git Bash:
```bash
start "" report.html
```

---

## Architectural Overview & Technical Implementation

```
               ┌────────────────────────────────────────────────────────┐
               │         run.sh (Cross-Platform Orchestrator)           │
               └───────────────────────────┬────────────────────────────┘
                                           │
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │    package_update_check.sh (Core Audit Engine)         │
               └───────────────────────────┬────────────────────────────┘
                                           │
         ┌─────────────────────────────────┼────────────────────────────────┐
         ▼                                 ▼                                ▼
┌─────────────────┐               ┌─────────────────┐              ┌─────────────────┐
│ Package Manager │               │ Read-Only Index │              │ Parsing Engine  │
│ Auto-Detection  │               │ Metadata Sync   │              │ & Security Tag  │
│ (apt, dnf, brew,│               │ (sudo apt update│              │ (Regex / Awk /  │
│  pacman, zypper)│               │  read-only sync)│              │  Version Diff)  │
└────────┬────────┘               └────────┬────────┘              └────────┬────────┘
         │                                 │                                │
         └─────────────────────────────────┼────────────────────────────────┘
                                           │
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │               Telemetry & Storage Pipeline             │
               │  • logs/package_check.log  (Chronological Audit Trace) │
               │  • logs/package_check.json (Structured Data Schema)    │
               └───────────────────────────┬────────────────────────────┘
                                           │
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │         report.html (Dark-Themed Dashboard)            │
               │  • Safety Banner (Zero Packages Installed Guarantee)   │
               │  • Executive KPI Cards (Total, Security, Standard)     │
               │  • Scrollable Package Inventory Table + Live Filter    │
               │  • Captured Console Execution Transcript               │
               │  • SysAdmin Manual Remediation Guide                   │
               └───────────────────────────┬────────────────────────────┘
                                           │
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │         Automated Browser Dispatcher                   │
               │  WSL (explorer.exe) | Linux (xdg-open) | macOS (open)  │
               └────────────────────────────────────────────────────────┘
```

### 1. Cross-Platform Package Manager Detection (Requirement 1)
The script avoids hardcoding Debian/Ubuntu's `apt`. It performs dynamic capability probing:
- **macOS:** Inspects `uname -s` for `Darwin` and verifies `brew` in `$PATH`.
- **Debian / Ubuntu / Linux Mint:** Probes for `apt` or `apt-get`.
- **RHEL / Rocky Linux / AlmaLinux / Fedora:** Probes for `dnf` or `yum`.
- **Arch Linux / Manjaro:** Probes for `pacman` or `checkupdates`.
- **openSUSE / SLES:** Probes for `zypper`.
- **Error Handling (Requirement 7):** If no recognized package manager binary is discovered, it exits with status code 1 and a detailed diagnostic explanation.

### 2. Resilient Index Refresh (Requirement 2 & 7)
Updating repository index metadata (e.g. `apt-get update`) synchronizes package release lists and cryptographic hashes without altering installed files. The script defends against environmental edge-cases:
- **Privilege Awareness:** Automatically detects root (`id -u == 0`), passwordless sudo (`sudo -n true`), or non-interactive execution.
- **Graceful Fault Tolerance:** If repository index refresh fails (e.g. temporary network outage, proxy failure, or repository lock held by an unattended background process), the script reports a descriptive warning and falls back to querying the cached local package index without crashing.

### 3. Upgradable Package Parsing & Classification (Requirement 3 & 4)
The script queries upgradable packages using the native toolchain (`apt list --upgradable 2>/dev/null`):
- **Version Extraction:** Parses package name, current installed version, candidate target version, repository suite, and target architecture.
- **Security Classification:** Differentiates critical CVE security updates (originating from `*-security` suites, e.g. `resolute-security`) from regular functional updates (`*-updates`), alerting administrators to urgent vulnerabilities.

### 4. Mandatory Read-Only Safety Guarantee (Requirement 5)
- **Zero Package Modification:** The script is strictly read-only. It explicitly avoids invoking `apt upgrade`, `apt install`, `dnf upgrade`, or `brew upgrade`.
- **Safety Notices:** Reinforced across the script header comments, terminal output banner, JSON telemetry (`"safety_disclaimer"`), and the HTML dashboard safety card.
- **Manual Command Guidance:** Clearly prints the exact manual commands administrators should run to apply updates (`sudo apt update && sudo apt upgrade`).

### 5. Persistent Audit Logging (Requirement 6)
Every check appends a timestamped audit record to `logs/package_check.log` including:
- Hostname, distribution name, kernel version, and hardware architecture
- Package manager in use and repository index synchronization status
- Upgradable package counts and complete tabular package inventory

---

## Live Audit Output Sample

Executed directly on the host system (`Ubuntu 26.04.1 LTS on WSL2`):

```text
================================================================================
    AUTOMATION SPRINT (AS_26) — PACKAGE UPDATE CHECK EXECUTION & REPORTING     
================================================================================
[INFO] Audit Directory : /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_26
[INFO] Host Platform   : Linux (6.18.40.1-microsoft-standard-WSL2)
[INFO] Target Hostname : SP
--------------------------------------------------------------------------------
[INFO] Executing live package update check via ./package_update_check.sh...
--------------------------------------------------------------------------------
🔄 [INFO] Synchronizing package repository index metadata (apt)...
✅ [SUCCESS] Package repository index refreshed successfully.
🔍 [INFO] Querying live upgradable packages from Debian/Ubuntu (APT)...
================================================================================
         AUTOMATION SPRINT (AS_26) — PACKAGE UPDATE CHECK REPORT         
================================================================================
Target Host      : SP
Operating System : Ubuntu 26.04.1 LTS
Kernel Release   : Linux 6.18.40.1-microsoft-standard-WSL2 (x86_64)
Package Manager  : Debian/Ubuntu (APT) [/usr/bin/apt]
Audit Timestamp  : 2026-09-30 16:10:51
Index Status     : SUCCESS (Repository metadata successfully synchronized via 'sudo apt-get update -qq'.)
--------------------------------------------------------------------------------
UPDATE SUMMARY METRICS:
  • Total Upgradable Packages : 25
  • Critical Security Updates : 7 ⚠️  (Action Recommended)
  • Standard Feature Updates  : 18
--------------------------------------------------------------------------------
DETAILED UPGRADABLE PACKAGES LIST:
NO.  | PACKAGE NAME                 | CURRENT VERSION      -> AVAILABLE VERSION    | SUITE/REPO       | CLASSIFICATION
-----+------------------------------+---------------------------------------------+------------------+----------------
001  | dmidecode                    | 3.6-2build1          -> 3.6-2ubuntu1         | resolute-updates | [STANDARD]
002  | gh                           | 2.100.0              -> 2.102.0              | unknown          | [STANDARD]
003  | glycin-loaders               | 2.1.1+ds-0ubuntu1    -> 2.1.5+ds-0ubuntu0.2  | resolute-updates | [STANDARD]
004  | glycin-thumbnailers          | 2.1.1+ds-0ubuntu1    -> 2.1.5+ds-0ubuntu0.2  | resolute-updates | [STANDARD]
005  | libaudit-common              | 1:4.1.2-1build1      -> 1:4.1.2-1ubuntu0.1   | resolute-updates | [STANDARD]
006  | libaudit1                    | 1:4.1.2-1build1      -> 1:4.1.2-1ubuntu0.1   | resolute-updates | [STANDARD]
007  | libcares2                    | 1.34.6-1             -> 1.34.6-1ubuntu0.1    | resolute-updates,resolute-security | [SECURITY]
008  | libglycin-2-0                | 2.1.1+ds-0ubuntu1    -> 2.1.5+ds-0ubuntu0.2  | resolute-updates | [STANDARD]
009  | libheif-plugin-aomdec        | 1.21.2-3ubuntu0.5    -> 1.21.2-3ubuntu0.6    | resolute-updates,resolute-security | [SECURITY]
010  | libheif-plugin-aomenc        | 1.21.2-3ubuntu0.5    -> 1.21.2-3ubuntu0.6    | resolute-updates,resolute-security | [SECURITY]
011  | libheif1                     | 1.21.2-3ubuntu0.5    -> 1.21.2-3ubuntu0.6    | resolute-updates,resolute-security | [SECURITY]
012  | libnetplan1                  | 1.2-1ubuntu5         -> 1.2-1ubuntu5.1       | resolute-updates | [STANDARD]
013  | libssl3t64                   | 3.5.5-1ubuntu3.5     -> 3.5.5-1ubuntu3.6     | resolute-updates,resolute-security | [SECURITY]
014  | netplan-generator            | 1.2-1ubuntu5         -> 1.2-1ubuntu5.1       | resolute-updates | [STANDARD]
015  | netplan.io                   | 1.2-1ubuntu5         -> 1.2-1ubuntu5.1       | resolute-updates | [STANDARD]
016  | openssl-provider-legacy      | 3.5.5-1ubuntu3.5     -> 3.5.5-1ubuntu3.6     | resolute-updates,resolute-security | [SECURITY]
017  | openssl                      | 3.5.5-1ubuntu3.5     -> 3.5.5-1ubuntu3.6     | resolute-updates,resolute-security | [SECURITY]
018  | python3-distupgrade          | 1:26.04.23           -> 1:26.04.25           | resolute-updates | [STANDARD]
019  | python3-netplan              | 1.2-1ubuntu5         -> 1.2-1ubuntu5.1       | resolute-updates | [STANDARD]
020  | python3-software-properties  | 0.120                -> 0.120.1              | resolute-updates | [STANDARD]
021  | rust-coreutils               | 0.8.0-0ubuntu3       -> 0.10.0-1ubuntu2~26.04.1 | resolute-updates | [STANDARD]
022  | software-properties-common   | 0.120                -> 0.120.1              | resolute-updates | [STANDARD]
023  | ubuntu-minimal               | 1.570.3              -> 1.570.4              | resolute-updates | [STANDARD]
024  | ubuntu-release-upgrader-core | 1:26.04.23           -> 1:26.04.25           | resolute-updates | [STANDARD]
025  | ubuntu-wsl                   | 1.570.3              -> 1.570.4              | resolute-updates | [STANDARD]
================================================================================
⚠️  SAFETY CONFIRMATION & ADMINISTRATIVE GUIDANCE:
   1. ZERO PACKAGES WERE MODIFIED OR INSTALLED. This script is strictly a check utility.
   2. To review or apply available updates manually, run:
      sudo apt update && sudo apt upgrade   (to apply standard & security updates)
      apt-get -s upgrade                    (to simulate upgrade safely)
================================================================================
📝 Audit record appended to: /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_26/logs/package_check.log
📊 Structured JSON saved to: /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_26/logs/package_check.json
--------------------------------------------------------------------------------
[INFO] Audit execution finished with status code: 0
[INFO] Regenerating report.html dashboard from live audit telemetry...
[SUCCESS] report.html successfully generated (47349 bytes).
================================================================================
🚀 Dispatching report.html to Web Browser...
================================================================================
[INFO] Detected Windows Subsystem for Linux (WSL) environment.
[INFO] Resolved Windows Path: D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_26\report.html
[LAUNCH] Invoking explorer.exe...
[INFO] Universal File Path to View Report:
       Windows Path : D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_26\report.html
       Linux Path   : /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_26/report.html
       File URL     : file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_26/report.html
[SUCCESS] Dashboard launch command dispatched successfully.
================================================================================
```

---

## Deliverables Summary

All required deliverables are strictly located within `AS_26/`:

1. `package_update_check.sh` — Fully commented bash utility with dynamic package manager auto-detection (`apt`, `dnf`, `brew`, `pacman`, `zypper`), safe read-only index refresh, version differential extraction, security update tagging, structured JSON serialization, and zero-install policy.
2. `run.sh` — Cross-platform execution script (`cd "$(dirname "$0")"`), triggers live package check, regenerates dark-themed `report.html` from scratch, and auto-dispatches to default browser.
3. `logs/package_check.log` — Chronological timestamped audit log of all package update checks.
4. `logs/package_check.json` — Machine-readable structured schema storing live audit telemetry.
5. `report.html` — Self-contained, dark-themed responsive HTML dashboard with executive KPI cards, searchable package table, live console log, and administrator remediation guide.
6. `commands_used.md` — Complete chronological log of every shell and testing command executed during sprint development with one-line descriptions.
7. `README.md` — Sprint documentation containing required execution and manual report viewing instructions.
