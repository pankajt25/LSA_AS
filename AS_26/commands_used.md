# Development Commands Log — AS_26 (Package Update Check)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Package Management & System Update Status Auditing  
**Author:** Individual Timed Sprint  

Every command executed during the discovery, testing, implementation, validation, error handling, and verification of **AS_26** is recorded below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment
- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint hierarchy.
- `git status && git remote -v` — Checked git working tree status and confirmed remote origin URL (`https://github.com/pankajt25/LSA_AS.git`).
- `ls -la ../AS_25 && head -n 30 ../AS_25/README.md` — Inspected previous sprint folder structure, documentation, and reporting deliverables.
- `grep -n "AS_25" ../README.md` — Verified index table and dropdown details structure in root README.
- `uname -a && cat /etc/os-release && which apt dnf yum brew pacman zypper` — Identified host Linux distribution (`Ubuntu 26.04.1 LTS`), kernel (`6.18.40.1-microsoft-standard-WSL2`), and detected package managers.
- `which explorer.exe && which wslpath` — Verified Windows host browser launcher and WSL path translation binaries.
- `python3 --version` — Confirmed Python 3.14.4 availability for standalone HTML dashboard generation.
- `which rpm dpkg` — Checked low-level package manager helper binaries.

---

## 2. Package Management Probing & Parsing Prototyping
- `sudo -n true; apt list --upgradable` — Tested passwordless sudo capability and probed live upgradable packages via APT.
- `sudo apt update` — Synchronized live repository package index metadata from official Ubuntu package mirrors.
- `apt list --upgradable 2>/dev/null` — Queried raw list of packages requiring updates on the live machine.
- `apt list --upgradable 2>/dev/null | grep -v '^Listing'` — Tested filtering header lines from APT upgradable output.
- `apt list --upgradable 2>/dev/null | grep -E '\[upgradable from:'` — Prototyped line extraction pattern for package records.
- `apt-get -s upgrade` — Tested simulated safe dry-run upgrade to inspect phased updates and packages kept back.
- `python3 - << 'EOF' ...` — Prototyped structured regex parsing for package name, repository, current version, available version, architecture, and security classification.
- `apt list --upgradable 2>/dev/null | awk ...` — Tested pure awk parsing for terminal table display and classification.
- `grep -qi microsoft /proc/version` — Verified WSL environment detection logic.

---

## 3. Script Development, Verification & Error Handling
- `mkdir -p logs` — Created local project logs directory for audit trails and JSON telemetry.
- `chmod +x package_update_check.sh && ./package_update_check.sh --skip-refresh` — Verified initial script execution and option handling.
- `tail -n 35 logs/package_check.log && head -n 30 logs/package_check.json` — Verified persistent audit log records and JSON telemetry schema.
- `./package_update_check.sh` — Executed full live check with live index synchronization (`sudo apt-get update -qq`).
- `./package_update_check.sh --help` — Verified CLI manual display, ANSI escapes, and options documentation.
- `./package_update_check.sh -s --json` — Validated structured JSON stdout output streaming.
- `chmod +x run.sh && bash run.sh` — Ran full end-to-end execution, live index refresh, report regeneration, and automated browser launch.

---

## 4. Git Version Control & Main Repository Integration
- `git add . && git commit -m "AS_26: Package Update Check - script, run.sh, live HTML report, docs"` — Staged and committed AS_26 sprint deliverables.
- `git push -u origin main` — Pushed AS_26 sprint commit to remote repository.
- `git add README.md && git commit -m "Update README: add AS_26 to index and dropdown details"` — Staged and committed root README updates.
- `git push` — Pushed final root README documentation updates to GitHub.
