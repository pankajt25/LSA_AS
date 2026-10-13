# Development Commands Log — AS_24 (SSH Service Check)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** SSH Administration, Service Availability & Port Socket Verification  
**Author:** Individual Timed Sprint  

Every command executed during the discovery, development, validation, error handling, and testing of **AS_24** is recorded below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment
- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint hierarchy.
- `git status && ls -la ../AS_23` — Checked git branch status and inspected previous sprint structure and conventions.
- `git remote -v` — Verified remote git repository URL configuration (`https://github.com/pankajt25/LSA_AS.git`).
- `uname -a && cat /etc/os-release && which systemctl service ss netstat || true` — Identified host OS (Ubuntu 26.04.1 LTS on WSL2), kernel release, and inspected availability of init and socket management utilities.
- `python3 --version` — Verified Python 3 runtime version (Python 3.14.4) for standalone HTML report generation.
- `echo "Testing date, uname, hostname"; date '+%Y-%m-%d %H:%M:%S %Z'; uname -s; uname -r; hostname` — Tested system information and timestamp extraction commands.
- `wslpath -w "$(pwd)/report.html"` — Validated WSL-to-Windows path translation syntax for browser auto-launch.

---

## 2. Live SSH Service & Socket Inspection
- `systemctl is-active ssh 2>&1; echo "exit: $?"; systemctl is-active sshd 2>&1; echo "exit: $?"; systemctl is-enabled ssh 2>&1; echo "exit: $?"; systemctl is-enabled sshd 2>&1; echo "exit: $?"` — Probed live systemctl active and enabled states for candidate unit names `ssh` and `sshd`.
- `systemctl list-unit-files | grep -iE 'ssh' || true; dpkg -l | grep -iE 'openssh|ssh' || true` — Audited installed packages and systemd unit files, confirming `openssh-server` is not installed on the host.
- `ss -tlnp 2>&1; echo "---"; ss -tln | grep :22 || true` — Checked active listening TCP sockets, confirming port 22 is not currently bound.
- `service ssh status 2>&1; echo "exit: $?"; service sshd status 2>&1; echo "exit: $?"` — Tested SysV init fallback behavior on non-existent service candidates.
- `which sshd || true; ls -l /usr/sbin/sshd || true` — Checked disk filesystem for standalone OpenSSH daemon executable binaries.
- `systemctl cat ssh 2>&1; echo "cat ssh exit: $?"; systemctl cat sshd 2>&1; echo "cat sshd exit: $?"` — Verified `systemctl cat` exit code and error message when unit files do not exist.
- `systemctl is-active cron 2>&1; echo "cron is-active: $?"; systemctl is-enabled cron 2>&1; echo "cron is-enabled: $?"` — Tested systemctl behavior against an active, enabled control service (`cron`).
- `systemctl show -p LoadState --value cron; systemctl show -p LoadState --value ssh; systemctl show -p LoadState --value sshd` — Evaluated programmatic unit `LoadState` property inspection (`loaded` vs `not-found`).
- `systemctl show -p ActiveState -p SubState -p UnitFileState --value cron` — Tested systemctl property query for active, sub, and unit file states.
- `systemctl list-unit-files ssh.service sshd.service 2>&1; echo "exit: $?"` — Tested unit file query on candidate services.
- `systemctl list-unit-files cron.service 2>&1; echo "exit: $?"` — Confirmed unit file query return codes on valid active services.
- `systemctl is-system-running 2>&1; echo "exit: $?"` — Confirmed systemd init manager bus responsiveness and runtime state (`running`).
- `which netstat || true` — Checked for legacy `netstat` binary availability.
- `ss -tln | grep -E ':(22)\b' || true; ss -tlnp 2>/dev/null | grep -E ':(22)\b' || true; netstat -tlnp 2>/dev/null | grep -E ':(22)\b' || true` — Tested port 22 listening regex match across multiple socket inspection tools.
- `echo "0.0.0.0:22" | grep -E ':(22)\b' && echo "matched 22" || echo "failed"; echo "0.0.0.0:2222" | grep -E ':(22)\b' && echo "matched 2222" || echo "correctly ignored 2222"` — Verified word-boundary regex precision to ensure `:22` matches while `:2222` is properly excluded.

---

## 3. Script Development, Execution & Verification
- `chmod +x ssh_service_check.sh && ./ssh_service_check.sh` — Granted execution permissions and ran the core SSH service checking script to verify live host detection.
- `cat logs/ssh_check.log && echo "---" && cat logs/ssh_check.json` — Verified chronological audit log file generation and structured JSON telemetry structure.
- `./ssh_service_check.sh -s cron` — Tested service override flag against active `cron` service to verify partial-state handling (active/enabled but port 22 down).
- `./ssh_service_check.sh -s cron -p 53` — Tested service override and port override against active `cron` and listening port 53 to verify optimal state handling.
- `./ssh_service_check.sh && cat logs/ssh_check.json` — Verified socket command logging refinement and live JSON serialization.
- `cat logs/ssh_check.json` — Inspected final live telemetry schema and field integrity.
- `chmod +x run.sh && bash run.sh` — Granted execution permissions and executed the single cross-platform launcher end-to-end.
- `bash run.sh -s cron -p 53` — Executed full launcher workflow against test service to verify dynamic HTML regeneration under optimal health status.
- `bash run.sh` — Executed final end-to-end verification, ensuring live system data capture, `report.html` regeneration from scratch, and browser launch dispatch via `explorer.exe`.

---

## 4. Version Control & Upstream Deployment
- `git add .` — Staged all AS_24 deliverables (`ssh_service_check.sh`, `run.sh`, `report.html`, `logs/`, `commands_used.md`, `README.md`).
- `git commit -m "AS_24: SSH Service Check - script, run.sh, live HTML report, docs"` — Committed AS_24 project deliverables with descriptive conventional commit.
- `git push -u origin main` — Pushed AS_24 commit to GitHub remote repository.
- `git add README.md` — Staged root `README.md` containing updated Projects Index table and AS_24 deep dive dropdown.
- `git commit -m "Update README: add AS_24 to index and dropdown details"` — Committed root README updates.
- `git push` — Pushed final root README documentation updates to remote repository.
