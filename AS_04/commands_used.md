# Commands Used — Permission Audit (AS_04)

The following list documents every command executed during the discovery, prototyping, development, verification, and report generation of Problem Statement #04:

1. `pwd && ls -la` — Inspected workspace structure and verified sandboxed directory.
2. `find /var/log -type f -perm -0002` — Audited live system `/var/log` for world-writable files (confirmed 0 baseline).
3. `find / -xdev -type f -perm -0002` — Audited root filesystem for live system world-writable file patterns.
4. `mkdir -p AS_04/logs AS_04/sandbox_data/{conf,scripts,data}` — Created sandboxed data structure and audit log directories.
5. `chmod 666 AS_04/sandbox_data/conf/database.conf` — Created synthetic world-writable configuration file (HIGH risk exposure).
6. `chmod 777 AS_04/sandbox_data/scripts/deploy.sh` — Created synthetic world-writable executable script (CRITICAL risk exposure).
7. `chmod 666 AS_04/sandbox_data/data/customer_records.csv` — Created synthetic world-writable data file (HIGH risk exposure).
8. `chmod 644 ... && chmod 755 ... && chmod 600 ...` — Created compliant benchmark files with standard least-privilege permissions.
9. `chmod +x AS_04/permission_audit.sh` — Granted execute permissions to core permission audit script.
10. `./AS_04/permission_audit.sh` — Executed baseline permission audit against `sandbox_data/`, identifying 3 world-writable files.
11. `./AS_04/permission_audit.sh /var/log` — Executed permission audit against real live system directory `/var/log`, confirming 100% compliance.
12. `chmod +x AS_04/run.sh` — Granted execute permissions to unified cross-platform launcher.
13. `bash AS_04/run.sh` — Executed unified workflow: ran scanner, captured live output, regenerated `report.html`, and launched browser.
14. `cat AS_04/logs/permission_audit.log` — Inspected persistent timestamped audit trail log.
15. `cat AS_04/logs/permission_audit.json` — Inspected machine-readable telemetry JSON file.
16. `explorer.exe "$(wslpath -w AS_04/report.html)"` — Verified automated browser dispatch in WSL environment.
