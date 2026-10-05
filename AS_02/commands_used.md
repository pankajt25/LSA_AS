# Development Commands Log — AS_02 (Inactive Employee Detection)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** User Administration, Authentication Auditing & Login History  
**Author:** Individual Timed Sprint  

Every command executed during the environment discovery, system authentication analysis, prototyping, implementation, debugging, verification, and release of **AS_02** is documented below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment

- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint repository hierarchy.
- `git status && git remote -v && ls -la ../AS_01` — Verified git status, branch state, and confirmed remote origin URL (`https://github.com/pankajt25/LSA_AS.git`).
- `ls -la AS_01` — Inspected deliverables in completed sibling sprint AS_01 to align architecture and dashboard standards.
- `cat /etc/os-release && uname -a && cat /etc/passwd` — Discovered OS version (`Ubuntu 26.04.1 LTS Resolute Raccoon`), kernel (`6.18.40.1-microsoft-standard-WSL2`), and enumerated local accounts.
- `which lastlog last && lastlog && last -n 10` — Probed presence of standard legacy login history utilities `lastlog` and `last`.
- `which lastlog || echo "no lastlog"; which last || echo "no last"; ls -la /var/log/lastlog /var/log/wtmp` — Checked binary presence and inspected `/var/log/lastlog` (0 bytes) and `/var/log/wtmp` (48KB binary log).
- `echo "PATH: $PATH"; ls -la /usr/bin/last* /usr/sbin/last* /bin/last* /sbin/last*` — Checked system PATH and searched standard binary directories for login history tools.
- `dpkg -l | grep -E "last|wtmp|util-linux|shadow|systemd"` — Audited installed packages related to session tracking, discovering `liblastlog2-2`, `util-linux`, and `systemd`.
- `dpkg -L util-linux-extra login passwd | grep -E "bin/"` — Audited binaries shipped by login utilities, confirming `lslogins`, `login`, and `chage`.
- `apt-cache search '^lastlog' || true; apt-cache search '^wtmpdb' || true` — Discovered modern 64-bit Y2038 replacements (`wtmpdb` and `lastlog2`) in package repositories.
- `which who w loginctl` — Verified availability of active session inspection tools (`/usr/bin/who`, `/usr/bin/w`, `/usr/bin/loginctl`).

---

## 2. Session & Authentication Data Analysis

- `python3 -c "import struct, os, time; ..."` — Read and decoded binary `/var/log/wtmp` records using Python `struct` to inspect raw session records.
- `who && w && loginctl list-sessions && loginctl list-users` — Audited active user sessions and verified `pankaj` on `pts/1` with state `active`.
- `loginctl show-user pankaj` — Inspected systemd user properties, extracting live session timestamp (`Timestamp=Mon 2026-10-05 09:20:36 IST`).
- `awk -F: '$3 >= 1000 {print $1, "UID:"$3, "Shell:"$7, "Home:"$6}' /etc/passwd` — Filtered `/etc/passwd` to identify all human/login-capable accounts (`UID >= 1000`).
- `cat /etc/shells` — Inspected system list of valid login shells (`/bin/bash`, `/bin/sh`, etc.) to exclude service daemons.
- `grep -E "Accepted|session opened" /var/log/auth.log | tail -n 20` — Inspected PAM session authentication logs in `/var/log/auth.log` to track login timestamps.
- `date -d "Mon Oct 5 09:20:32 +0530 2026" +%s` — Validated GNU `date -d` epoch conversion for lastlog and PAM timestamp formats.
- `bash -c 'start_t=$(date +%s%N); declare -A who_map; ...'` — Prototyped and benchmarked O(1) in-memory session cache yielding sub-300ms query performance.

---

## 3. Script Implementation & Debugging

- `chmod +x inactive_employee_detector.sh && ./inactive_employee_detector.sh` — Executed initial script implementation.
- `bash -x ./inactive_employee_detector.sh` — Traced execution and diagnosed bash `set -e` post-increment trap (`(( TOTAL_ACCOUNTS++ ))` returning non-zero when 0).
- `./inactive_employee_detector.sh` — Successfully executed script with default 30-day threshold, verifying clean CLI table output.
- `./inactive_employee_detector.sh --json | head -n 35` — Validated machine-readable JSON telemetry schema for dashboard ingestion.
- `./inactive_employee_detector.sh 15` — Validated dynamic threshold override with custom 15-day inactivity window.
- `./inactive_employee_detector.sh -h` — Validated command-line manual, option documentation, and examples.
- `cat logs/inactive_check.log` — Verified persistent audit log generation with timestamps, machine context, and account summaries.

---

## 4. Unified Execution & HTML Dashboard Generation

- `chmod +x run.sh && bash run.sh` — Tested automated cross-platform wrapper, generating `report.html` and launching browser.
- `ls -lh report.html logs/inactive_check.log` — Verified live report file generation (35KB) and audit log persistence.
- `view_file report.html` — Inspected generated HTML markup, verifying dark theme CSS variables, live user table, and security deep dive.

---

## 5. Version Control & Git Release

- `git status` — Audited modified and untracked sprint files across the project workspace.
- `git add .` — Staged all `AS_02/` deliverables (`inactive_employee_detector.sh`, `run.sh`, `report.html`, `commands_used.md`, `README.md`, logs).
- `git commit -m "AS_02: Inactive Employee Detection - script, run.sh, live HTML report, docs"` — Committed AS_02 sprint package.
- `git push -u origin main` — Pushed AS_02 branch to GitHub repository.
- `git add README.md && git commit -m "Update README: add AS_02 to index and dropdown details" && git push` — Updated and synchronized parent README.md index and deep dive.
