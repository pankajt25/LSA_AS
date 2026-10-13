# Commands Used During Development and Testing
**Course:** Linux System Administration (E1ITA307) — Automation Sprint  
**Problem Statement #16:** Service Availability Check — Focus: Service Monitoring  

The following log details every command executed during the discovery, development, validation, and reporting phases, strictly confined within the project sandbox:

1. `pwd && ls -la`  
   Verified the current working directory and confirmed that the project sandbox was initially clean.

2. `ps -p 1 -o comm= && which systemctl service && systemctl list-units --type=service --state=running | head -n 20`  
   Inspected PID 1 to verify the active init system (`systemd`), checked the paths of `systemctl` and `service`, and listed pre-existing active services.

3. `systemctl is-active cron; echo "exit: $?"; systemctl is-enabled cron; echo "exit: $?"; systemctl is-active not-a-real-service; echo "exit: $?"; systemctl is-enabled not-a-real-service; echo "exit: $?"`  
   Tested the standard exit codes and string outputs of `systemctl is-active` and `systemctl is-enabled` across active and nonexistent services.

4. `systemctl status not-a-real-service 2>&1; echo "exit: $?"; systemctl cat not-a-real-service 2>&1; echo "exit: $?"`  
   Investigated unit existence verification and error output patterns when querying non-existent services.

5. `systemctl list-unit-files --type=service --state=disabled | head -n 10`  
   Identified existing disabled/inactive services on the system (`rsync`) to safely test inactive states without modifying any system service.

6. `systemctl is-active rsync; echo "exit: $?"; systemctl is-enabled rsync; echo "exit: $?"`  
   Verified status output and exit codes for a known inactive and disabled service (`rsync`).

7. `systemctl show -p LoadState cron; systemctl show -p LoadState rsync; systemctl show -p LoadState not-a-real-service`  
   Tested unit property queries using `LoadState` to reliably distinguish between loaded units and nonexistent (`not-found`) units.

8. `systemctl show -p LoadState,ActiveState,SubState,UnitFileState cron; echo "---"; systemctl show -p LoadState,ActiveState,SubState,UnitFileState rsync; echo "---"; systemctl show -p LoadState,ActiveState,SubState,UnitFileState not-a-real-service`  
   Evaluated composite systemd unit properties for detailed operational diagnostics.

9. `service cron status 2>&1; echo "exit: $?"; service rsync status 2>&1; echo "exit: $?"; service not-a-real-service status 2>&1; echo "exit: $?"`  
   Tested fallback SysV init status command behavior across active, inactive, and nonexistent services for non-systemd environments.

10. `systemctl show -p LoadState,ActiveState,UnitFileState --value cron`  
    Verified raw value extraction from systemd properties without key prefixes.

11. `systemctl list-unit-files --state=masked | head -n 5`  
    Checked for masked services on the host to verify edge case handling in boot persistence detection.

12. `systemctl is-active cryptdisks 2>&1; echo "active code: $?"; systemctl is-enabled cryptdisks 2>&1; echo "enabled code: $?"`  
    Verified status query outputs and exit codes for a masked unit (`cryptdisks`).

13. `systemctl list-unit-files --type=service --state=enabled | while read -r unit state preset; do ...`  
    Scanned the system to identify a service that is enabled at boot but currently inactive (`apparmor`) to validate the amber card state.

14. `chmod +x service_availability_check.sh && bash -n service_availability_check.sh`  
    Granted execution permissions to the script and performed static bash syntax checking.

15. `./service_availability_check.sh; echo "Exit code: $?"`  
    Executed the script without arguments to verify default parameter assignment (`cron`), active state branch, and exit code 0.

16. `./service_availability_check.sh not-a-real-service; echo "Exit code: $?"`  
    Executed the script with a deliberately invalid service name to verify nonexistent unit detection, error handling, and exit code 2.

17. `./service_availability_check.sh rsync; echo "Exit code: $?"`  
    Executed the script against an inactive/disabled service to verify inactive state detection and exit code 1.

18. `./service_availability_check.sh apparmor; echo "Exit code: $?"`  
    Executed the script against an enabled-but-inactive service to test separate boot persistence reporting and amber card classification.

19. `cat logs/service_check.log`  
    Inspected the accumulated audit log file to verify structured formatting, timestamps, and audit history.

20. `./service_availability_check.sh cron --report`  
    Executed the script with the `--report` flag to generate and update the styled, dark-themed HTML dashboard (`report.html`).

21. `./service_availability_check.sh --help && ./service_availability_check.sh cron --json`  
    Verified the command-line usage manual and validated JSON output formatting for automation pipelines.

22. `ls -la`  
    Verified that all required deliverable files exist strictly inside the project directory without modifying any external files.
