# Development Commands Log — AS_01 (Employee Account Setup)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** User Management, Group Provisioning & Access Control  
**Author:** Individual Timed Sprint  

Every command executed during the discovery, prototyping, implementation, execution, verification, idempotency testing, cleanup validation, and documentation of **AS_01** is recorded below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment
- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint repository hierarchy.
- `git status && git remote -v` — Checked git working tree status and confirmed remote origin URL (`https://github.com/pankajt25/LSA_AS.git`).
- `git log -n 5 --oneline && ls -la AS_14` — Checked commit history conventions and file layouts of prior completed automation sprints.
- `git show 033ca77 --stat` — Inspected file structure and commit conventions from sprint AS_26.
- `sudo -n true && echo "Sudo is passwordless"` — Verified passwordless sudo availability for non-interactive `useradd`, `groupadd`, and `chpasswd` operations.
- `uname -a && cat /proc/version` — Identified host Linux kernel version (`6.18.40.1-microsoft-standard-WSL2`), architecture (`x86_64`), and WSL2 platform.
- `which chpasswd passwd id getent useradd groupadd userdel groupdel chage` — Confirmed availability and full path of core Linux user and shadow management binaries.
- `passwd --help 2>&1 | grep -E -- "-e|expire"` — Verified the `-e` (`--expire`) parameter of the `passwd` binary to force password change on next login.

---

## 2. Safety Audit & Pre-Existing Account Verification
- `for u in lsatest_jdoe lsatest_asmith lsatest_rkumar lsatest_mwong; do id "$u" 2>&1 || true; done` — Verified that none of the target test usernames existed on the system prior to execution.
- `for g in engineering finance hr; do getent group "$g" 2>&1 || true; done` — Verified that none of the target department groups existed in `/etc/group` prior to execution.
- `getent passwd | grep lsatest_ || echo "No lsatest_ users exist"` — Confirmed that no other accounts with the `lsatest_` prefix existed on the machine.

---

## 3. User Lifecycle & Passwd Prototyping
- `sudo groupadd lsatest_grp && echo "groupadd ok"` — Tested standalone group creation using `groupadd`.
- `sudo useradd -m -c "Test Sandbox" -g lsatest_grp lsatest_tmpuser && echo "useradd ok"` — Tested account creation with home directory skeleton seeding (`-m`), GECOS full name (`-c`), and primary group (`-g`).
- `echo "lsatest_tmpuser:InitPass#2026!" | sudo chpasswd && echo "chpasswd ok"` — Validated non-interactive password injection via `chpasswd`.
- `sudo passwd -e lsatest_tmpuser && echo "passwd -e ok"` — Tested forcing password expiration on the test user.
- `id lsatest_tmpuser` — Inspected assigned UID, GID, and primary group membership for the test user.
- `sudo chage -l lsatest_tmpuser` — Verified shadow password aging policy, confirming `password must be changed` status.
- `ls -ld /home/lsatest_tmpuser` — Inspected home directory permissions (`drwxr-x---`) and ownership (`lsatest_tmpuser:lsatest_grp`).
- `sudo userdel -r lsatest_tmpuser && echo "userdel ok"` — Tested clean account removal including home directory deletion via `userdel -r`.
- `sudo groupdel lsatest_grp && echo "groupdel ok"` — Tested removal of the empty test group via `groupdel`.

---

## 4. Script Implementation & CLI Validation
- `chmod +x employee_account_setup.sh && ./employee_account_setup.sh --help` — Tested command-line interface help flag output and argument parser.
- `bash -x ./employee_account_setup.sh --dry-run` — Diagnosed and resolved `set -e` arithmetic evaluation (`(( LINE_NUM++ ))` returning non-zero when 0).
- `./employee_account_setup.sh --dry-run` — Verified simulation mode without executing real system changes, confirming safe group auditing.
- `chmod +x cleanup.sh && ./cleanup.sh --help && ./cleanup.sh --dry-run` — Tested cleanup script CLI parser and simulation of account removal.
- `chmod +x run.sh && ./run.sh` — Executed full automated provisioning workflow, creating accounts, capturing logs, and generating live `report.html`.

---

## 5. Live System State Verification
- `for u in lsatest_jdoe lsatest_asmith lsatest_rkumar lsatest_mwong; do id "$u"; ls -ld "/home/$u"; sudo chage -l "$u" | grep -E "Password expires|Last password change"; done` — Audited all 4 live test accounts, verifying UID/GID, home directory existence and permissions, and forced password expiration.
- `for g in engineering finance hr; do getent group "$g"; done` — Verified presence and GID assignment of `engineering` (GID: 1009), `finance` (GID: 1010), and `hr` (GID: 1011).
- `cat logs/account_setup.log` — Inspected persistent timestamped audit log file.
- `cat logs/account_setup.json` — Verified machine-readable JSON telemetry schema for dashboard rendering.

---

## 6. Idempotency & Teardown Verification
- `./employee_account_setup.sh` — Tested idempotency by running setup against existing accounts; verified that all 4 accounts were safely skipped with `[SKIPPED]` status.
- `./cleanup.sh` — Executed teardown script to remove all test users (`userdel -r`) and empty departmental groups (`groupdel`).
- `for u in lsatest_jdoe lsatest_asmith lsatest_rkumar lsatest_mwong; do id "$u" 2>&1 || true; ls -ld "/home/$u" 2>&1 || true; done` — Verified post-cleanup state, confirming complete removal of test accounts and home directories.
- `for g in engineering finance hr; do getent group "$g" 2>&1 || true; done` — Confirmed deletion of test departmental groups.
- `./run.sh` — Re-executed complete creation workflow to capture fresh live audit data and regenerate the production `report.html` dashboard.

---

## 7. Version Control & Git Release
- `git add .` — Staged all sprint files in `AS_01/`.
- `git commit -m "AS_01: Employee Account Setup - script, cleanup, live HTML report, docs"` — Committed AS_01 deliverables.
- `git push -u origin main` — Pushed AS_01 to GitHub remote repository.
- `git add README.md && git commit -m "Update README: add AS_01 to index and dropdown details" && git push` — Updated and synchronized root repository index.
