# Linux Commands Used — AS_48: Administrator Daily Report

This document outlines the system inspection tools, performance telemetry interfaces, and report generation routines used to produce the administrator daily briefing.

---

### 1. `/proc/uptime` & `uptime` — System Uptime & Boot Telemetry
- **Command:** `read -r UPTIME_RAW _ < /proc/uptime`
- **Command:** `uptime -p && uptime -s`
- **Purpose:** Extracts monotonic uptime seconds and humanized duration strings alongside the kernel boot timestamp.

### 2. `/proc/stat` & `/proc/loadavg` — Processor Load & Utilization
- **CPU Delta Calculation:** Samples `/proc/stat` twice over a 0.5-second interval to compute exact instantaneous CPU busy percentage.
- **Run Queue Load:** `cat /proc/loadavg` extracts exponential 1-minute, 5-minute, and 15-minute load averages compared against `nproc`.
- **Top CPU Process:** `ps -eo comm,%cpu --sort=-%cpu | sed -n '2p'` captures the leading CPU consuming process.

### 3. `/proc/meminfo` — Physical & Virtual Memory Breakdown
- **Metrics Read:** `MemTotal`, `MemAvailable`, `SwapTotal`, `SwapFree`.
- **Formulas:**
  - $\text{Used RAM} = \text{MemTotal} - \text{MemAvailable}$
  - $\text{Used Swap} = \text{SwapTotal} - \text{SwapFree}$

### 4. `df -hP` — Storage Capacity & Volume Utilization
- **Command:** `df -hP /`
- **Options:**
  - `-h`: Human-readable size units (GB, MB).
  - `-P`: POSIX standard one-line tabular formatting preventing wrapped lines.
- **Volume Inspection:** `df -hP -x tmpfs -x devtmpfs` filters in-memory virtual mounts to report physical/network storage.

### 5. `who` — Active User Sessions
- **Command:** `who`
- **Purpose:** Profiles current active interactive login sessions, terminals (`pts/X`), and login timestamps.

### 6. `systemctl is-active` — Core Services Health
- **Command:** `systemctl is-active "<unit>.service"`
- **Purpose:** Checks the operational status (`active`, `inactive`, `failed`) of mission-critical daemons.
