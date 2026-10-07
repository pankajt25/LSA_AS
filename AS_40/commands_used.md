# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #40: Mounted File System Space Report — Commands Reference

This document catalogs all core Linux system administration, virtual file system (VFS) inspection, storage capacity metrics, and mount point auditing commands utilized in the design, execution, verification, and reporting of `AS_40`.

---

### 1. File System & Mount Inspection Commands

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `df -hT` | Displays all mounted filesystems with filesystem types, human-readable total sizes, consumed space, available free space, and mount paths. |
| `findmnt -lo TARGET,SOURCE,FSTYPE,OPTIONS` | Queries the kernel mount table via `libmount` to extract target paths, sources, filesystem types, and mount flags. |
| `cat /proc/mounts` | Inspects the kernel's real-time list of all mounted filesystems directly from the `/proc` virtual interface. |
| `mount -v` | Queries currently mounted filesystems with verbose descriptive details. |
| `stat -f <mount_point>` | Inspects VFS superblock metadata, fundamental filesystem block size, and available free blocks directly. |

---

### 2. Live Verification & Execution Commands

```bash
# Execute mounted filesystem report and launch HTML dashboard
cd AS_40
bash run.sh

# Run report directly sorted by utilization percentage (default)
./mounted_fs_report.sh

# Sort mounted filesystems by total storage capacity size
./mounted_fs_report.sh --sort size

# Filter mounted filesystems by filesystem type (e.g. ext4)
./mounted_fs_report.sh --filter ext4

# Include micro-mounts like systemd service credential directories
./mounted_fs_report.sh --all

# View command usage manual
./mounted_fs_report.sh --help
```
