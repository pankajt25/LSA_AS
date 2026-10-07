# Linux Commands Used — AS_45: Server Uptime Report

This document outlines the core Linux kernel files, shell built-ins, and auditing utilities implemented to measure and evaluate system uptime and continuous operation thresholds.

---

### 1. `/proc/uptime` — Monotonic Kernel Clock Interrogation
- **Command:** `read -r UPTIME_RAW IDLE_RAW < /proc/uptime`
- **Fields:**
  - Field 1: Total seconds since system boot (monotonic, uninterrupted by wall-clock changes).
  - Field 2: Total idle seconds spent by all CPU cores combined.
- **Conversion Formula:**
  - $\text{Days} = \lfloor\text{Seconds} / 86400\rfloor$
  - $\text{Hours} = \lfloor(\text{Seconds} \pmod{86400}) / 3600\rfloor$
  - $\text{Minutes} = \lfloor(\text{Seconds} \pmod{3600}) / 60\rfloor$
  - $\text{Seconds} = \text{Seconds} \pmod{60}$

### 2. `uptime` — User-Facing Uptime Formatting
- **Pretty Duration:** `uptime -p` returns humanized strings (e.g., `up 1 hour, 45 minutes`).
- **Boot Timestamp:** `uptime -s` retrieves the exact boot timestamp in `YYYY-MM-DD HH:MM:SS` format.

### 3. `/proc/stat` — Boot Epoch Discovery
- **Command:** `grep -m1 "^btime" /proc/stat | awk '{print $2}'`
- **Purpose:** Extracts the raw Unix epoch timestamp when the Linux kernel initialized.

### 4. `nproc` & Idle Time Percentage
- **Command:** `nproc`
- **Formula:** $\text{Idle } \% = \frac{\text{Idle Seconds}}{\text{Uptime Seconds} \times \text{Cores}} \times 100$
- **Purpose:** Normalizes raw idle seconds across multi-core symmetric multiprocessing (SMP) configurations.

### 5. System Health Context Tools
- **Load Averages:** `cat /proc/loadavg` for 1m, 5m, and 15m run queue metrics.
- **Active Sessions:** `who | wc -l` for logged-in user counts.
- **Kernel & Architecture:** `uname -r` and `uname -m` for OS kernel and hardware specification.
