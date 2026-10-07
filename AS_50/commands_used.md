# Commands Used — AS_50: Mini Linux Administration Dashboard

This document details all system commands, virtual filesystem queries, parameters, and utilities used to build the integrated Linux administration dashboard.

---

### 1. System Identity & Monotonic Uptime Accounting

- **`cat /proc/uptime`**
  - Reads the Linux kernel's high-resolution system uptime and idle counters (in seconds).
  - Derived values: Formatted days, hours, minutes, and seconds.
- **`awk '/btime/ {print $2}' /proc/stat`**
  - Extracts the boot epoch timestamp (`btime`) from `/proc/stat`.
- **`date -d "@<epoch>" +"%Y-%m-%d %H:%M:%S"`**
  - Formats the Unix boot epoch into a human-readable local timestamp.
- **`hostname` / `uname -r` / `uname -m`**
  - Queries system node name, active kernel release, and CPU architecture.

---

### 2. Dual-Sample CPU Utilization & Load Accounting

- **`read -r _ u n s i w q sq st _ < /proc/stat`**
  - Reads total ticks across user (`u`), nice (`n`), system (`s`), idle (`i`), iowait (`w`), irq (`q`), softirq (`sq`), and steal (`st`).
  - Employs dual-sample delta measurement separated by a precision sleep interval (`sleep 0.5`) to compute instantaneous CPU busy percentage:
    $$\text{Usage \%} = \left(1.0 - \frac{\Delta \text{idle}}{\Delta \text{total}}\right) \times 100$$
- **`cat /proc/loadavg`**
  - Extracts 1-minute, 5-minute, and 15-minute kernel run-queue load averages.
- **`nproc`**
  - Returns the number of active processing units (CPU cores) available to the OS.
- **`ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu --no-headers | head -n 5`**
  - Enumerates all processes, sorts descending by CPU consumption (`--sort=-%cpu`), and captures top 5 consuming processes.

---

### 3. Memory & Swap Accounting

- **`grep 'MemTotal\|MemAvailable\|MemFree\|Buffers\|^Cached' /proc/meminfo`**
  - Reads accurate physical memory metrics directly from the kernel memory manager.
  - Computes true used memory as `MemTotal - MemAvailable`.
- **`grep 'SwapTotal\|SwapFree' /proc/meminfo`**
  - Derives swap allocation and percentage utilization.
- **`ps -eo pid,user,%mem,%cpu,comm --sort=-%mem --no-headers | head -n 5`**
  - Extracts top 5 memory-consuming processes.

---

### 4. Filesystem & Inode Capacity Auditing

- **`df -hP /`**
  - Queries storage capacity on root filesystem in POSIX-compliant single-line format (`-P`), preventing newline breaks on long device paths.
- **`df -iP /`**
  - Audits inode allocation and usage percentage.
- **`df -hP | grep -vE '^Filesystem'`**
  - Gathers all mounted filesystems across the host, escaping Windows DrvFs backslashes (`C:\`, `D:\`) for safe JSON/Python serialization.

---

### 5. Interactive Session & User Discovery

- **`who`**
  - Lists interactive users currently logged in, associated terminal device lines (TTY/PTS), login timestamps, and remote originating hosts.
- **`who | awk '{print $1}' | sort -u | wc -l`**
  - Computes count of unique logged-in accounts.

---

### 6. Systemd Service Matrix & Daemon Health

- **`systemctl list-units --type=service --state=running --no-legend | wc -l`**
  - Counts all currently active running systemd services.
- **`systemctl list-units --type=service --state=failed --no-legend | wc -l`**
  - Detects degraded or failed systemd service units.
- **`systemctl is-active <unit>.service`**
  - Returns `active` or `inactive` for individual target daemons.
- **`systemctl is-enabled <unit>.service`**
  - Checks if the service is configured to launch at boot (`enabled`, `disabled`, or `static`).
- **`systemctl show -p MainPID --value <unit>.service`**
  - Extracts the primary process PID assigned to the systemd service unit.
- **`systemctl show -p MemoryCurrent --value <unit>.service`**
  - Reads real-time cgroup memory consumption in bytes.

---

### 7. Dashboard Rendering & Host Browser Dispatch

- **`python3 -`**
  - Ingests `last_run.json` telemetry, maps gauges and badges, and compiles the standalone responsive dark-themed `report.html`.
- **`wslpath -w <path>` / `explorer.exe <path>`**
  - Resolves WSL2 Linux path to Windows format and launches default Windows host browser.
