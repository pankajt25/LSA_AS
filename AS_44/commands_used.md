# Linux Commands Used — AS_44: Resource Threshold Monitor

This document details the Linux kernel pseudo-filesystems, process accounting tools, and arithmetic parsing utilities used to build the real-time resource monitor.

---

### 1. `/proc/stat` — Precise Instantaneous CPU Sampling
- **Command:** `read -r _ user nice sys idle iow irq sirq steal _ < /proc/stat`
- **Calculation Formula:**
  - Total Jiffies = $\text{user} + \text{nice} + \text{sys} + \text{idle} + \text{iowait} + \text{irq} + \text{softirq} + \text{steal}$
  - Idle Jiffies = $\text{idle} + \text{iowait}$
  - Utilization $\% = 100 \times \left(1 - \frac{\Delta \text{Idle}}{\Delta \text{Total}}\right)$
- **Advantage:** Bypasses inaccurate single-sample averages from static snapshot tools and computes true interval delta.

### 2. `/proc/meminfo` — Accurate Kernel Memory Accounting
- **Metrics Read:**
  - `MemTotal`: Total physical RAM reported by kernel.
  - `MemAvailable`: Kernel estimate of memory available for starting new applications without swapping (superior to legacy `MemFree`).
  - `SwapTotal` & `SwapFree`: Virtual memory swap reservation.
- **Formula:** $\text{Used RAM} = \text{MemTotal} - \text{MemAvailable}$

### 3. `/proc/loadavg` & `nproc` — Run Queue Load Metrics
- **Command:** `cat /proc/loadavg`
- **Command:** `nproc`
- **Purpose:** Extracts exponential 1-minute, 5-minute, and 15-minute system load averages and compares them against physical/logical core counts.

### 4. `ps` — Live Process Hierarchy Profiling
- **Top CPU Consumers:**
  `ps -eo pid,user,%cpu,%mem,comm,args --sort=-%cpu | head -n 6`
- **Top Memory Consumers:**
  `ps -eo pid,user,%mem,%cpu,rss,comm,args --sort=-%mem | head -n 6`
- **Purpose:** Identifies heavy resource consumers in real time when thresholds are approached.

### 5. `awk` — Precision Arithmetic & Threshold Logic
- **Command:** `awk -v v="${CPU_USAGE}" -v w="${CPU_WARN}" -v c="${CPU_CRIT}" 'BEGIN { if (v >= c) print "CRITICAL"; else if (v >= w) print "WARNING"; else print "OK"; }'`
- **Purpose:** Performs floating point evaluations and threshold classification without external binary dependencies.
