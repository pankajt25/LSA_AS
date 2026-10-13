# Commands Used — Department Access (AS_03)

The following list documents every command executed during the discovery, implementation, testing, verification, cleanup validation, and report generation of Problem Statement #03:

1. `pwd && ls -la` — Inspected workspace structure and verified sandboxed directory.
2. `sudo -n true` — Confirmed passwordless sudo access for group provisioning operations.
3. `getent group lsatest_dept_shared` — Audited system group database to verify absence of pre-existing test groups.
4. `mkdir -p AS_03/logs AS_03/sandbox_data/shared` — Created sandboxed data and audit log directories.
5. `chmod +x AS_03/department_access.sh` — Granted execute permissions to core department access configuration script.
6. `./AS_03/department_access.sh --dry-run` — Verified simulation mode without making system modifications.
7. `chmod +x AS_03/cleanup.sh` — Granted execute permissions to teardown and cleanup script.
8. `chmod +x AS_03/run.sh` — Granted execute permissions to unified cross-platform launcher.
9. `bash AS_03/run.sh` — Executed full provisioning workflow: created group `lsatest_dept_shared`, configured `sandbox_data/shared/` permissions (`2770`), performed live access audits, and regenerated `report.html`.
10. `getent group lsatest_dept_shared` — Verified department group creation in `/etc/group` (GID 1009).
11. `stat -c "%a %A %U %G" AS_03/sandbox_data/shared` — Audited directory octal mode (`2770`), symbolic mode (`drwxrws---`), owner (`pankaj`), and group (`lsatest_dept_shared`).
12. `touch AS_03/sandbox_data/shared/.inheritance_test.tmp && stat -c "%G" AS_03/sandbox_data/shared/.inheritance_test.tmp` — Verified SGID inheritance behavior (newly created files automatically inherit group `lsatest_dept_shared`).
13. `sudo -u nobody test -r AS_03/sandbox_data/shared` — Verified access denial for non-members (EACCES Permission Denied).
14. `cat AS_03/logs/department_access.log` — Inspected timestamped audit trail log.
15. `cat AS_03/logs/department_access.json` — Inspected machine-readable telemetry data.
16. `explorer.exe "$(wslpath -w AS_03/report.html)"` — Verified automated browser dispatch in WSL environment.
17. `bash AS_03/cleanup.sh` — Verified clean teardown and removal of `lsatest_dept_shared` group.
