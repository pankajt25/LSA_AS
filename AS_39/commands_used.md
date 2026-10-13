# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #39: Disk Space and Inode Utilization Audit — Commands Reference

This document catalogs all core Linux system administration, storage capacity inspection, inode exhaustion monitoring, and threshold alerting commands utilized in the design, execution, verification, and reporting of `AS_39`.

---

### 1. Storage & Inode Monitoring Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `df -hP` | Displays filesystem storage capacity, used space, free space, and percentage utilization in human-readable units adhering to POSIX standard output. |
| `df -iP` | Displays inode consumption (total inodes, allocated inodes, free inodes, and percentage utilization) adhering to POSIX standard output. |
| `df -kP` | Displays filesystem block consumption in 1024-byte blocks for exact integer math. |
| `find <mount> -xdev -size +100M` | Locates unusually large files on a specific filesystem without crossing mount boundaries. |
| `find <mount> -xdev -type f \| wc -l` | Counts physical files on a filesystem to troubleshoot inode exhaustion scenarios. |
| `stat -f <path>` | Queries filesystem status information including block sizes and free inode counts directly from the kernel VFS. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute storage and inode audit and open HTML dashboard
cd AS_39
bash run.sh

# Run audit directly with default thresholds (80% Disk, 80% Inode)
./disk_inode_check.sh

# Run audit with custom thresholds (e.g. 70% Disk critical threshold)
./disk_inode_check.sh --disk-threshold 70 --inode-threshold 75

# Run audit including virtual and credential mounts
./disk_inode_check.sh --all

# View command help dialog
./disk_inode_check.sh --help
```
