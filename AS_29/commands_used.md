# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #29: System Inventory — Commands Reference

This document catalogs all core Linux system administration, hardware discovery, kernel introspection, storage inspection, and network enumeration commands utilized in the design, execution, verification, and reporting of `AS_29`.

---

### 1. Hardware, OS, Storage & Network Enumeration

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `source /etc/os-release` | Reads vendor-standard OS release metadata (`PRETTY_NAME`, `NAME`, `VERSION_ID`). |
| `uname -r` / `uname -m` | Retrieves Linux kernel release version and CPU instruction set architecture (`x86_64`). |
| `grep -m1 "model name" /proc/cpuinfo` | Extracts processor model, vendor string, and hardware frequency without external tools. |
| `nproc` | Returns active processing units / hardware thread count available to the OS. |
| `free -m` | Queries physical RAM and virtual swap memory allocations, used vs available bytes. |
| `df -hP -x tmpfs -x devtmpfs -x squashfs` | Queries non-virtual filesystem partition storage, mount points, and consumption ratios. |
| `ip -br addr show` | Formats network interface names, operational states (`UP`/`DOWN`), and CIDR IP addresses. |
| `cat /sys/class/net/<iface>/address` | Directly extracts interface hardware MAC addresses from sysfs. |

---

### 2. Live Verification Commands

```bash
# Execute automated system inventory collection and dashboard generation
cd AS_29
bash run.sh

# Run core script directly for detailed terminal output
./system_inventory.sh

# Emit machine-readable JSON telemetry
./system_inventory.sh --json

# View usage manual
./system_inventory.sh --help
```

---

### 3. Production Inventory Auditing via Cron

```bash
# Automated periodic hardware/system audit snapshot
# 0 0 * * * /usr/local/bin/system_inventory.sh --json > /var/log/system_spec_daily.json 2>&1
```
