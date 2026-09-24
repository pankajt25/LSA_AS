# Automation Sprint #16: Service Availability Check (Service Monitoring)

**Course:** Linux System Administration (E1ITA307)  
**Problem Statement #16:** Service Availability Check — Operational service monitoring, boot persistence verification, systemd/SysV fallback handling, structured audit logging, and responsive dark-themed dashboard reporting.

---

## 📌 Overview

This project delivers a self-contained, enterprise-grade Bash monitoring utility (`service_availability_check.sh`) designed for system administrators to monitor the real-time operational availability and boot persistence of critical Linux services. It automatically senses the host init architecture (`systemd` with classic `service`/SysV init fallback), cleanly disambiguates active, inactive, failed, and missing units, logs every check to an audit history file, and generates a standalone, dark-themed HTML dashboard (`report.html`).

---

## 📂 Project Structure

```text
AS_16/
├── service_availability_check.sh   # Core service monitoring & reporting script
├── commands_used.md                # Chronological command history & viva guide
├── report.html                     # Standalone dark-themed dashboard report
├── logs/                           # Audit trail directory
│   └── service_check.log           # Timestamped check history log
└── README.md                       # Comprehensive problem documentation
```

---

## ⚙️ Key Features

1. **Init Subsystem Detection & Fallback:**
   - Detects whether PID 1 is managed by systemd and verifies `/run/systemd/system`.
   - In environments lacking full systemd (e.g. WSL 1, Docker containers, legacy SysV), automatically falls back to `/usr/sbin/service <service> status` and `/etc/init.d/` inspections.
2. **Defensive Disambiguation of Unit States:**
   - Evaluates `systemctl show -p LoadState` and `systemctl cat` to distinguish between an **inactive/stopped service** and a **completely nonexistent unit**.
   - Handles runtime active states: `active`, `inactive`, `failed`, `activating`, `deactivating`, and `reloading`.
3. **Independent Boot Persistence Verification:**
   - Checks `systemctl is-enabled <service>` separately from runtime active state to detect whether a service will start automatically on reboot (`enabled`, `disabled`, `masked`, `static`, or `n/a`).
4. **Structured Audit Logging:**
   - Logs every invocation to `logs/service_check.log` in a machine-parsable and human-readable format:
     `[TIMESTAMP] [INIT] SERVICE=<name> ACTIVE=<state> ENABLED=<state> EXIT=<code|0|1|2> MSG="<desc>"`
5. **Interactive & Responsive HTML Dashboard:**
   - Generates a standalone, dark-themed HTML report (`report.html`) with inline CSS (no external dependencies).
   - Features color-coded status cards (🟢 Green = Active, 🟡 Amber = Enabled-but-inactive, 🔴 Red = Inactive / Not Found).
   - Features a collapsible `<details>` section with a scrollable monospace raw audit log viewer.
6. **Programmatic Telemetry (JSON):**
   - Supports `--json` flag to emit structured JSON output for integration with CI/CD and monitoring pipelines.
7. **Defensive Shell Scripting:**
   - Strict execution safety (`set -uo pipefail`).
   - Modular functional decomposition.
   - Standardized exit codes (0 = Active, 1 = Inactive, 2 = Not Found, 3 = Error).

---

## 🚀 Usage

### Syntax
```bash
./service_availability_check.sh [SERVICE_NAME] [OPTIONS]
```

### Arguments & Options
- `SERVICE_NAME` *(Optional)*: Name of the system service to inspect (e.g., `cron`, `rsync`, `apparmor`). Defaults to `cron` if omitted.
- `-h`, `--help`: Display the usage manual and exit.
- `-r`, `--report`: Automatically generate/refresh the standalone HTML dashboard (`report.html`).
- `-j`, `--json`: Output check results in structured JSON format to stdout.

### Example Invocations

```bash
# 1. Inspect default service (cron):
./service_availability_check.sh

# 2. Inspect a running service:
./service_availability_check.sh cron

# 3. Inspect an inactive/disabled service:
./service_availability_check.sh rsync

# 4. Inspect an enabled-but-inactive service:
./service_availability_check.sh apparmor

# 5. Inspect a deliberately nonexistent service (demonstrates error handling):
./service_availability_check.sh not-a-real-service

# 6. Generate/update the HTML dashboard:
./service_availability_check.sh cron --report

# 7. Output in JSON format for automated pipelines:
./service_availability_check.sh cron --json
```

---

## 📊 Exit Codes

| Exit Code | Meaning | Description |
|:---:|---|---|
| `0` | **ACTIVE** | The target service is loaded and actively running. |
| `1` | **INACTIVE / FAILED** | The service exists on the system but is stopped, dead, or failed. |
| `2` | **NOT FOUND** | The unit file does not exist in the system service registry. |
| `3` | **ERROR** | Invalid CLI invocation, unknown flag, or unsupported environment. |

---

## 🧪 Validation & Safe Testing

All test cases were executed strictly in **read-only** mode without modifying, starting, stopping, enabling, or disabling any real system service:

| Test Case | Service Tested | Active State | Boot Persistence | Exit Code | Card Color |
|---|---|---|---|:---:|:---:|
| **Active Service** | `cron` | `active` | `enabled` | `0` | 🟢 Green |
| **Enabled-but-Inactive** | `apparmor` | `inactive` | `enabled` | `1` | 🟡 Amber |
| **Inactive & Disabled** | `rsync` | `inactive` | `disabled` | `1` | 🔴 Red |
| **Missing Service** | `not-a-real-service` | `not-found` | `n/a` | `2` | 🔴 Red |

---

## 📜 Audit Log Sample (`logs/service_check.log`)

```text
[2026-09-24 09:35:24 IST] [systemd] SERVICE=cron ACTIVE=active ENABLED=enabled EXIT=0 MSG="✅ Service 'cron' is ACTIVE and running"
[2026-09-24 09:35:30 IST] [systemd] SERVICE=not-a-real-service ACTIVE=not-found ENABLED=n/a EXIT=2 MSG="⚠️ Service 'not-a-real-service' not found on this system"
[2026-09-24 09:35:40 IST] [systemd] SERVICE=rsync ACTIVE=inactive ENABLED=disabled EXIT=1 MSG="❌ Service 'rsync' is INACTIVE / NOT running"
[2026-09-24 09:35:40 IST] [systemd] SERVICE=apparmor ACTIVE=inactive ENABLED=enabled EXIT=1 MSG="❌ Service 'apparmor' is INACTIVE / NOT running"
[2026-09-24 09:42:59 IST] [systemd] SERVICE=cron ACTIVE=active ENABLED=enabled EXIT=0 MSG="✅ Service 'cron' is ACTIVE and running"
```

---

## 🖥️ HTML Dashboard (`report.html`)

The dashboard is generated with zero external dependencies and renders an executive status view:
- **System Telemetry**: Init architecture (`systemd`), Linux kernel release, hostname, and timestamp.
- **Service Cards**: Prominently highlights service name, operational status, boot persistence, and exit codes with distinct color-coding.
- **Collapsible Audit History**: Embeds a toggleable `<details>` viewer containing the raw log lines for rapid inspection.

---

## Viewing the HTML Report

1. The exact command to open `report.html` in the default Windows browser, run from inside WSL:
   ```bash
   explorer.exe $(wslpath -w report.html)
   ```

2. The alternative manual path via Windows Explorer:
   - If working from `/mnt/d/...` (Windows-mounted): the direct Windows path, e.g. `D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_16\report.html` — double-click it
   - If working from the WSL home directory instead: `\\wsl$\Ubuntu\home\pankaj\sprint-sandbox\report.html` (or `\\wsl.localhost\Ubuntu\home\pankaj\sprint-sandbox\report.html` on newer Windows builds)

3. *Note:* report.html is self-contained — no server needed, just open the file directly.
