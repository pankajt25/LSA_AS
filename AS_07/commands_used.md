# Commands Used — Low Disk Space Alert (AS_07)

The following list documents every command executed during the discovery, prototyping, development, verification, and report generation of Problem Statement #07:

1. `pwd && ls -la` — Inspected workspace structure and verified sandboxed directory.
2. `df -h` — Evaluated host human-readable disk utilization across all mounted volumes.
3. `df -P` — Tested POSIX portable single-line filesystem output to eliminate line-wrap column errors.
4. `df -P -x tmpfs -x devtmpfs -x squashfs` — Tested filtration of virtual memory and pseudo-filesystems.
5. `mkdir -p AS_07/logs` — Created persistent audit log directory for AS_07.
6. `chmod +x AS_07/low_disk_space_alert.sh` — Granted execute permissions to core disk space alert script.
7. `./AS_07/low_disk_space_alert.sh` — Executed baseline capacity audit against live system volumes with default 80% threshold (0 alerts).
8. `./AS_07/low_disk_space_alert.sh 70` — Executed threshold stress test at 70%, successfully triggering warning alerts on `/mnt/c` and `/usr/lib/wsl/drivers` (71%).
9. `./AS_07/low_disk_space_alert.sh --json` — Validated structured JSON telemetry generation and schema completeness.
10. `chmod +x AS_07/run.sh` — Granted execute permissions to unified cross-platform launcher.
11. `bash AS_07/run.sh` — Executed unified workflow: polled storage volume metrics, regenerated `report.html`, and launched browser.
12. `cat AS_07/logs/disk_alert.log` — Inspected persistent timestamped audit trail log.
13. `cat AS_07/logs/disk_alert.json` — Inspected machine-readable telemetry JSON file.
14. `explorer.exe "$(wslpath -w AS_07/report.html)"` — Verified automated browser dispatch in WSL environment.
