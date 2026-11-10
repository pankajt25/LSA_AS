# Commands Used — Server Health Check (AS_06)

The following list documents every command executed during the discovery, prototyping, development, verification, and report generation of Problem Statement #06:

1. `pwd && ls -la` — Inspected workspace structure and verified sandboxed directory.
2. `nproc` — Probed host logical CPU core count (4 cores).
3. `uptime` / `cat /proc/loadavg` — Retrieved live host uptime, session count, and 1m/5m/15m system load averages.
4. `free -m` and `free -h` — Audited physical memory and swap allocation metrics.
5. `df -h /` and `df -h -x tmpfs -x devtmpfs` — Evaluated root partition storage consumption and mounted physical filesystems.
6. `who` — Captured active interactive logged-in user sessions, pseudoterminals, and connection origins.
7. `ps -ef | wc -l` — Counted total active running system tasks.
8. `ps -eo stat | grep -c '^Z'` — Audited process table for zombie tasks.
9. `mkdir -p AS_06/logs` — Created persistent audit log directory for AS_06.
10. `chmod +x AS_06/server_health_check.sh` — Granted execute permissions to core server health monitoring script.
11. `./AS_06/server_health_check.sh` — Executed baseline health audit against live system subsystems.
12. `./AS_06/server_health_check.sh --json` — Validated structured JSON telemetry generation and schema completeness.
13. `chmod +x AS_06/run.sh` — Granted execute permissions to unified cross-platform launcher.
14. `bash AS_06/run.sh` — Executed unified workflow: polled live health telemetry, regenerated `report.html`, and launched browser.
15. `cat AS_06/logs/server_health_check.log` — Inspected persistent timestamped audit trail log.
16. `cat AS_06/logs/server_health_check.json` — Inspected machine-readable telemetry JSON file.
17. `explorer.exe "$(wslpath -w AS_06/report.html)"` — Verified automated browser dispatch in WSL environment.
