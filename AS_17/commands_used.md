# Commands Used — Automatic Service Recovery Sprint

The following list documents every command executed during the development, testing, and verification of Problem Statement #17:

1. `ls -la` — Inspected initial project directory contents to ensure a clean workspace.
2. `systemctl is-system-running` — Verified that systemd is active and operating as the system init process in WSL.
3. `sudo -n true` — Confirmed passwordless sudo privileges for non-interactive service control commands.
4. `sudo bash -c 'cat << "EOF" > /etc/systemd/system/dummy-test.service ...'` — Created the isolated dummy unit file `/etc/systemd/system/dummy-test.service` running `/bin/sleep infinity`.
5. `sudo systemctl daemon-reload` — Reloaded systemd unit configurations to recognize `dummy-test.service`.
6. `sudo systemctl enable --now dummy-test.service` — Enabled and immediately started `dummy-test.service`.
7. `sudo systemctl status dummy-test.service` — Verified that `dummy-test.service` was active and running.
8. `systemctl is-active nonexistent-service` — Tested systemctl return code and output behavior when evaluating an absent service.
9. `sudo systemctl restart nonexistent-service` — Tested error messages and exit codes when restarting a non-existent unit.
10. `systemctl is-active dummy-test` — Tested standard output and exit code for a healthy active unit.
11. `sudo systemctl stop dummy-test && systemctl is-active dummy-test` — Deliberately stopped the test service to verify inactive state detection.
12. `sudo systemctl start dummy-test && systemctl is-active dummy-test` — Restored the test service to active state for initial script baseline test.
13. `chmod +x auto_service_recovery.sh` — Granted execute permissions to the automated service recovery script.
14. `./auto_service_recovery.sh` — Executed the recovery script against active `dummy-test` to test the healthy, no-action path.
15. `cat logs/recovery.log` — Verified structured log file creation and the initial health check log line.
16. `sudo systemctl stop dummy-test && systemctl status dummy-test` — Stopped the dummy service and recorded its inactive/dead status for the "Before" test state.
17. `./auto_service_recovery.sh` — Ran the script to automatically detect the stopped service, restart it, wait for stabilization, and verify recovery.
18. `systemctl status dummy-test` — Captured the recovered active service status for the "After" test state.
19. `./auto_service_recovery.sh nonexistent-service` — Tested the script against an invalid service name to verify graceful failure handling.
20. `./auto_service_recovery.sh dummy-test` — Ran an additional health check on the recovered dummy service to confirm continued normal operation.
21. `wslpath -w report.html` — Converted the WSL path to the Windows path for local browser viewing.
