# Commands Used — Ownership Audit (AS_05)

The following list documents every command executed during the discovery, prototyping, development, verification, and report generation of Problem Statement #05:

1. `pwd && ls -la` — Inspected workspace structure and verified sandboxed directory.
2. `id -un && id -u` — Identified current user (`pankaj`) and primary UID (`1000`) for baseline administrator designation.
3. `mkdir -p AS_05/logs AS_05/sandbox_data/project_alpha/{src,docs,tests,config,assets,build}` — Created sandboxed project directory structure and audit log directories.
4. `chown pankaj:pankaj ...` — Seeded compliant project source files owned by designated administrator.
5. `sudo chown root:root ...` — Simulated privilege drift anomalies by assigning root ownership to test and configuration files.
6. `sudo chown nobody:nogroup ...` — Simulated contractor / unprivileged foreign ownership anomaly on asset files.
7. `chmod +x AS_05/ownership_audit.sh` — Granted execute permissions to core ownership audit script.
8. `./AS_05/ownership_audit.sh` — Executed baseline file ownership audit against project directory with designated admin `pankaj`, detecting 3 violations.
9. `./AS_05/ownership_audit.sh /etc/cron.d root` — Executed live system ownership audit against `/etc/cron.d` with designated admin `root`, confirming 100% compliance.
10. `chmod +x AS_05/run.sh` — Granted execute permissions to unified cross-platform launcher.
11. `bash AS_05/run.sh` — Executed unified workflow: ran scanner, captured live output, regenerated `report.html`, and launched browser.
12. `cat AS_05/logs/ownership_audit.log` — Inspected persistent timestamped audit trail log.
13. `cat AS_05/logs/ownership_audit.json` — Inspected machine-readable telemetry JSON file.
14. `explorer.exe "$(wslpath -w AS_05/report.html)"` — Verified automated browser dispatch in WSL environment.
