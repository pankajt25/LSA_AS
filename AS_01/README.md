# Employee Account Setup — Automation Sprint (AS_01)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** User Management, Group Provisioning & Access Control  
**Problem Statement #1:** A company has a list of new employees. Write a Bash script to create Linux user accounts from a given employee list and assign them to the appropriate department group.

---

## ⚠️ MANDATORY SAFETY & SANDBOXING WARNING

> [!WARNING]
> **REAL PERSISTENT SYSTEM MODIFICATION NOTICE:**  
> Unlike read-only monitoring or synthetic log analysis scripts, **this sprint interacts directly with the live Linux user subsystem** (`/etc/passwd`, `/etc/shadow`, `/etc/group`, and physical home directories under `/home/`).
> 
> To guarantee total safety and prevent collisions with human or pre-existing system accounts:
> 1. **Strict Test Prefix:** Every provisioned username is strictly prefixed with `lsatest_` (e.g. `lsatest_jdoe`). Any username lacking this prefix is **immediately rejected** by the script.
> 2. **Pre-Creation Verification:** The script audits `getent passwd <user>` and `getent group <dept>` before making changes; it **never** overwrites existing accounts.
> 3. **Mandatory Teardown:** A dedicated teardown script (`cleanup.sh`) removes all created test accounts (`userdel -r`) and empty departmental groups (`groupdel`), cleanly restoring the host to its pristine pre-test state.
> 
> **Always run `bash cleanup.sh` after evaluating/grading this sprint!**

---

## Command to Execute

This sprint uses a **two-step lifecycle**:

```text
+-----------------------+           +-----------------------+
|      STEP 1: RUN      |           |     STEP 2: CLEANUP   |
|     (Provisioning)    |  ======>  |       (Teardown)      |
|      bash run.sh      |           |    bash cleanup.sh    |
+-----------------------+           +-----------------------+
  - Creates test users                - Deletes test users
  - Creates dept groups               - Removes /home/lsatest_*
  - Forces passwd reset               - Deletes empty groups
  - Generates report.html             - Restores pristine state
```

### 1. Provision Accounts & Generate Dashboard (Step 1)
```bash
bash run.sh
```
*Executes `employee_account_setup.sh` against `employees.csv`, provisions real test accounts and groups, logs actions to `logs/account_setup.log`, serializes telemetry to `logs/account_setup.json`, regenerates `report.html`, and automatically launches the dashboard in your default browser.*

### 2. Teardown Accounts & Restore System (Step 2)
```bash
bash cleanup.sh
```
*Reads `employees.csv`, removes each created test account and its home directory (`sudo userdel -r <user>`), removes empty departmental groups (`sudo groupdel <dept>`), and verifies that the system has been cleanly restored.*

---

## Viewing the HTML Report

If your environment is headless or the browser does not open automatically, view the generated dashboard manually:

### Windows / WSL2 (Command Prompt / PowerShell / WSL Terminal):
```bash
# Inside WSL terminal:
explorer.exe "$(wslpath -w report.html)"
```
Or open the resolved Windows file path in any browser:
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_01\report.html
```

### Native Linux Desktop:
```bash
xdg-open report.html || sensible-browser report.html || python3 -m webbrowser report.html
```

### macOS:
```bash
open report.html
```
*(Note: As documented in `run.sh`, `useradd` and `groupadd` are Linux-specific; macOS uses `dscl`. `run.sh` displays this platform status cleanly in the report).*

---

## 1. System Architecture & Workflow

```text
                                  +-----------------------------+
                                  |        employees.csv        |
                                  |  username,fullname,dept     |
                                  +--------------+--------------+
                                                 |
                                                 v
                                  +-----------------------------+
                                  |    employee_account_setup   |
                                  |       (Defensive Bash)      |
                                  +--------------+--------------+
                                                 |
                   +-----------------------------+-----------------------------+
                   |                             |                             |
                   v                             v                             v
        +---------------------+       +---------------------+       +---------------------+
        |  Department Groups  |       |    User Provision   |       |  Security & Expiry  |
        |  getent group       |       |  useradd -m -c -g   |       |  chpasswd (initial) |
        |  groupadd <dept>    |       |  -m: /home seeded   |       |  passwd -e (force   |
        |  (if missing)       |       |  -g: primary GID    |       |  reset on 1st login)|
        +----------+----------+       +----------+----------+       +----------+----------+
                   |                             |                             |
                   +-----------------------------+-----------------------------+
                                                 |
                                                 v
                                  +-----------------------------+
                                  |   Verification & Audit      |
                                  |   id, getent, chage -l      |
                                  |   ls -ld /home/lsatest_*    |
                                  +--------------+--------------+
                                                 |
                   +-----------------------------+-----------------------------+
                   |                                                           |
                   v                                                           v
        +---------------------+                                     +---------------------+
        |     Audit Logs      |                                     | Interactive Report  |
        | logs/account_setup  |                                     |    report.html      |
        | .log & .json        |                                     | (Dark Live Dashboard|
        +---------------------+                                     +---------------------+
```

---

## 2. Input Dataset Format (`employees.csv`)

The employee list is stored in standard comma-separated value (CSV) format adhering to RFC 4180:

```csv
lsatest_jdoe,Jane Doe,engineering
lsatest_asmith,Alex Smith,engineering
lsatest_rkumar,Ravi Kumar,finance
lsatest_mwong,Mei Wong,hr
```

### Field Definitions:
1. `username`: Account login name. Must conform to `^lsatest_[a-zA-Z0-9_]+$`.
2. `fullname`: Employee's full name, assigned to the GECOS/comment field in `/etc/passwd`.
3. `department`: Departmental group, assigned as the user's primary login group (`GID`).

---

## 3. Detailed Component Breakdown

### A. `employee_account_setup.sh`
- **Prefix Safety Enforcement:** Inspects `$user` against `REQUIRED_USER_PREFIX` (`lsatest_`). Refuses to create or modify accounts failing this regex.
- **Group Audit & Provisioning:**
  ```bash
  if ! getent group "$dept" &>/dev/null; then
      sudo groupadd "$dept"
  fi
  ```
- **User Creation:**
  ```bash
  sudo useradd -m -c "$fullname" -g "$dept" "$user"
  ```
  - `-m`: Creates the home directory (`/home/<user>`) with skeleton dotfiles copied from `/etc/skel`.
  - `-c "$fullname"`: Sets the GECOS comment field in `/etc/passwd`.
  - `-g "$dept"`: Sets the primary login group to the employee's department group.
- **Temporary Password & Forced First-Login Reset:**
  ```bash
  echo "$user:$TEMP_PASS" | sudo chpasswd
  sudo passwd -e "$user"
  ```
  `passwd -e` forces password expiration. When the user logs in for the first time, Linux PAM (`pam_unix.so`) immediately intercepts the session and demands an interactive password change before granting shell access.
- **Multi-Vector Verification:**
  - `id <user>` confirms UID, primary GID, and groups.
  - `ls -ld /home/<user>` verifies directory creation, permissions (`drwxr-x---`), and ownership (`<user>:<dept>`).
  - `sudo chage -l <user>` verifies shadow database aging policy (`password must be changed`).
- **Audit Logging:** Every step is recorded with microsecond timestamps in `logs/account_setup.log` and serialized to `logs/account_setup.json`.

### B. `cleanup.sh`
- **Safe Teardown:** Ensures the system can be demonstrated without leaving persistent test artifacts behind.
- **Account Removal:**
  ```bash
  sudo userdel -r "$user"
  ```
  The `-r` flag cleans up the user's entry from `/etc/passwd`, `/etc/shadow`, `/etc/group`, while deleting the `/home/<user>` tree and `/var/mail/<user>`.
- **Empty Group Removal:**
  Inspects each department group. If no users remain (neither supplementary members nor users with that primary GID in `/etc/passwd`), it executes `sudo groupdel "$dept"`. If non-test users belong to the group, the group is preserved to avoid accidental system impact.
- **Restoration Sanity Audit:** Runs post-teardown probes on `id` and `ls -ld` to confirm complete removal.

### C. `run.sh`
- **Single-Command Execution:** Chains setup, output capture, telemetry serialization, HTML generation, and browser launch.
- **Embedded Dashboard Generator:** Employs an inline Python script to transform live `logs/account_setup.json` data into a standalone, dark-themed `report.html` with zero external dependencies.
- **Deliberate Separation:** Explicitly does **not** auto-run `cleanup.sh`, ensuring faculty/examiners can inspect the live accounts and web dashboard.

---

## 4. Live Verification Output

Captured during live execution on host `SP` (`WSL2 Ubuntu 24.04`, Kernel `6.18.40.1-microsoft-standard-WSL2`):

```text
▶ Initiating Employee Account Setup Automation (Course: E1ITA307)
[INFO] Platform: Linux | Kernel: 6.18.40.1-microsoft-standard-WSL2 | Hostname: SP
[INFO] Input CSV: employees.csv
[INFO] Log File: logs/account_setup.log
▶ Reading employee records from employees.csv...

[INFO] Processing record [Line 1]: Employee 'Jane Doe' (lsatest_jdoe) -> Department 'engineering'
[INFO] Department group 'engineering' does not exist. Creating group...
✓ [SUCCESS] Created department group 'engineering' (GID: 1009).
[INFO] Provisioning user account 'lsatest_jdoe' for 'Jane Doe' in department 'engineering'...
✓ [SUCCESS] Account 'lsatest_jdoe' created successfully.
[INFO] Temporary password assigned non-interactively for 'lsatest_jdoe'.
✓ [SUCCESS] Password expiration enforced for 'lsatest_jdoe' (change required on first login).
✓ [SUCCESS] Home directory verified: /home/lsatest_jdoe (drwxr-x--- lsatest_jdoe:engineering)
[INFO] Verification Audit: uid=1011(lsatest_jdoe) gid=1009(engineering) groups=1009(engineering) | Password Status: P | Expiry: password must be changed 7

[INFO] Processing record [Line 2]: Employee 'Alex Smith' (lsatest_asmith) -> Department 'engineering'
[INFO] Department group 'engineering' already verified in this session.
[INFO] Provisioning user account 'lsatest_asmith' for 'Alex Smith' in department 'engineering'...
✓ [SUCCESS] Account 'lsatest_asmith' created successfully.
[INFO] Temporary password assigned non-interactively for 'lsatest_asmith'.
✓ [SUCCESS] Password expiration enforced for 'lsatest_asmith' (change required on first login).
✓ [SUCCESS] Home directory verified: /home/lsatest_asmith (drwxr-x--- lsatest_asmith:engineering)
[INFO] Verification Audit: uid=1012(lsatest_asmith) gid=1009(engineering) groups=1009(engineering) | Password Status: P | Expiry: password must be changed 7

[INFO] Processing record [Line 3]: Employee 'Ravi Kumar' (lsatest_rkumar) -> Department 'finance'
[INFO] Department group 'finance' does not exist. Creating group...
✓ [SUCCESS] Created department group 'finance' (GID: 1010).
[INFO] Provisioning user account 'lsatest_rkumar' for 'Ravi Kumar' in department 'finance'...
✓ [SUCCESS] Account 'lsatest_rkumar' created successfully.
[INFO] Temporary password assigned non-interactively for 'lsatest_rkumar'.
✓ [SUCCESS] Password expiration enforced for 'lsatest_rkumar' (change required on first login).
✓ [SUCCESS] Home directory verified: /home/lsatest_rkumar (drwxr-x--- lsatest_rkumar:finance)
[INFO] Verification Audit: uid=1013(lsatest_rkumar) gid=1010(finance) groups=1010(finance) | Password Status: P | Expiry: password must be changed 7

[INFO] Processing record [Line 4]: Employee 'Mei Wong' (lsatest_mwong) -> Department 'hr'
[INFO] Department group 'hr' does not exist. Creating group...
✓ [SUCCESS] Created department group 'hr' (GID: 1011).
[INFO] Provisioning user account 'lsatest_mwong' for 'Mei Wong' in department 'hr'...
✓ [SUCCESS] Account 'lsatest_mwong' created successfully.
[INFO] Temporary password assigned non-interactively for 'lsatest_mwong'.
✓ [SUCCESS] Password expiration enforced for 'lsatest_mwong' (change required on first login).
✓ [SUCCESS] Home directory verified: /home/lsatest_mwong (drwxr-x--- lsatest_mwong:hr)
[INFO] Verification Audit: uid=1014(lsatest_mwong) gid=1011(hr) groups=1011(hr) | Password Status: P | Expiry: password must be changed 7

▶ Employee Account Setup Summary
================================================================================
Summary of Account Setup Operations:
  Total Employee Records Processed : 4
  User Accounts Created            : 4
  Accounts Skipped (Already Exists): 0
  Failed / Rejected Records        : 0
  Department Groups Created        : 3
  Department Groups Pre-existing   : 0
  Audit Trail Log                  : logs/account_setup.log
  JSON Telemetry                   : logs/account_setup.json
================================================================================
✓ [SUCCESS] All eligible employee accounts processed successfully!
```

---

## 5. Viva Voce & Technical Administration Questions

### Q1: What is the purpose of the `-m` flag in `useradd` and how does it populate the home directory?
**Answer:** The `-m` (`--create-home`) flag instructs `useradd` to create the user's home directory (`/home/<username>`) if it does not already exist. It populates this directory by copying skeleton configuration files located in `/etc/skel` (e.g. `.bashrc`, `.profile`, `.bash_logout`), setting their ownership to the new user and primary group with standard restrictive permissions (`0750` or `0700`).

### Q2: Why is `chpasswd` preferred over interactive `passwd` in automated Bash scripts?
**Answer:** The standard `passwd` utility is designed for interactive TTY use and reads password input directly from `/dev/tty`, deliberately resisting stdin redirection for security. `chpasswd` is explicitly designed for batch administrative processing; it accepts `username:password` pairs over standard input (`echo "user:pass" | sudo chpasswd`), enabling automated, secure password setting without human intervention.

### Q3: How does `passwd -e <username>` (or `chage -d 0`) enforce password reset on first login?
**Answer:** In the Linux shadow database (`/etc/shadow`), field 3 stores the date of the last password change as the number of days since the Unix Epoch (January 1, 1970). Running `passwd -e` or `chage -d 0` sets this value to `0`. Linux PAM (`pam_unix.so` / `pam_auth`) checks this field during login; detecting day 0, it recognizes the password as immediately expired and obligates the user to enter a new password before granting shell access.

### Q4: What is the difference between a primary group (`-g`) and supplementary groups (`-G`)?
**Answer:** 
- **Primary Group (`-g`):** Recorded directly in field 4 of `/etc/passwd`. Every new file, directory, or process created by the user is assigned this GID by default. Every user has exactly one primary group.
- **Supplementary Groups (`-G`):** Recorded in `/etc/group` as comma-separated lists of members. Used for granting access to additional resources, shared project folders, or administrative capabilities (e.g. `sudo`, `docker`).

### Q5: Why is `userdel -r` used instead of plain `userdel` in the cleanup script?
**Answer:** Plain `userdel <username>` only removes the user record from `/etc/passwd`, `/etc/shadow`, and `/etc/group`, leaving `/home/<username>` and `/var/mail/<username>` orphaned on the disk. The `-r` (`--remove`) flag ensures complete teardown by recursively purging the home directory and mail spool, leaving no orphaned files with obsolete UID/GID ownership.

---

## 6. Deliverables Summary

| File | Purpose |
|---|---|
| [`employee_account_setup.sh`](./employee_account_setup.sh) | Core batch employee provisioning script with error handling and logging |
| [`cleanup.sh`](./cleanup.sh) | Safe environment teardown script restoring system to pristine state |
| [`employees.csv`](./employees.csv) | Test employee dataset (`username,fullname,department`) |
| [`run.sh`](./run.sh) | Cross-platform launcher and live HTML report dashboard generator |
| [`report.html`](./report.html) | Standalone dark-themed HTML report dashboard with live metrics |
| [`commands_used.md`](./commands_used.md) | Exhaustive command log detailing all development and validation steps |
| [`logs/account_setup.log`](./logs/account_setup.log) | Chronological timestamped execution and audit trail |
| [`logs/account_setup.json`](./logs/account_setup.json) | Structured machine-readable JSON telemetry |
| [`README.md`](./README.md) | Complete sprint documentation, architecture guide, and viva preparation |
