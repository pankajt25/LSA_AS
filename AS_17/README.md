# Automatic Service Recovery — Automation Sprint (AS_17)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Service Automation & Automated Fault Recovery  
**Problem Statement #17:** Develop a script that checks a specified service and restarts it automatically if it is not running.

---

## 1. Overview & Architecture

In production Linux environments, service outages cause downtime if not promptly detected and mitigated. `auto_service_recovery.sh` is an automated, self-contained Bash utility designed to monitor systemd units, detect dead or inactive states, initiate remediation restarts with elevated privileges when necessary, wait for process stabilization, and log every event in a structured audit trail.

### Recovery Workflow Diagram
```
                     +---------------------------+
                     |  Start: Accept $1 or      |
                     |  default to 'dummy-test'  |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     |  systemctl is-active      |
                     +-------------+-------------+
                                   |
                  +----------------+----------------+
                  |                                 |
           [State == active]               [State != active]
                  |                                 |
                  v                                 v
     +--------------------------+     +--------------------------+
     | Log: Healthy, no action  |     | Attempt: systemctl       |
     | Exit 0                   |     | restart <service>        |
     +--------------------------+     +-------------+------------+
                                                    |
                                    +---------------+---------------+
                                    |                               |
                              [Exit Code != 0]              [Exit Code == 0]
                                    |                               |
                                    v                               v
                       +-------------------------+     +-------------------------+
                       | Log: Restart failed     |     | Wait 2s (stabilization) |
                       | (nonexistent / broken)  |     +------------+------------+
                       | Exit 1                  |                  |
                       +-------------------------+                  v
                                                       +-------------------------+
                                                       | Re-probe is-active      |
                                                       +------------+------------+
                                                                    |
                                                    +---------------+---------------+
                                                    |                               |
                                             [State == active]               [State != active]
                                                    |                               |
                                                    v                               v
                                       +-------------------------+     +-------------------------+
                                       | Log: Restart succeeded  |     | Log: Verification failed|
                                       | Exit 0                  |     | Exit 1                  |
                                       +-------------------------+     +-------------------------+
```

---

## 2. Sandboxing & Safety Notice (Important)

### Dummy Test Service: `dummy-test.service`
To strictly honor sandboxing and prevent disruption to the host or WSL environment:
- **No production or pre-existing service** (`ssh`, `cron`, networking, systemd daemons) was ever stopped, restarted, or altered.
- All testing was conducted against a harmless test unit: `/etc/systemd/system/dummy-test.service`.
- **Purpose of `dummy-test.service`:** This service simply runs `/bin/sleep infinity`. It consumes zero noticeable system resources and exists solely as a target for automated failure injection and restart verification.
- **Production Warning:** This unit was created specifically for this sprint. It is not an OS component and can safely remain in place or be removed via:
  ```bash
  sudo systemctl disable --now dummy-test.service
  sudo rm -f /etc/systemd/system/dummy-test.service
  sudo systemctl daemon-reload
  ```

---

## 3. Script Features & Implementation

`auto_service_recovery.sh` includes:
- **Safe Defaults:** Defaults target service to `dummy-test` if no argument is supplied.
- **Privilege Management:** Automatically prepends `sudo` when restarting if executed by an unprivileged user, while keeping inspection commands unprivileged.
- **Stabilization Window:** Introduces a `sleep 2` pause post-restart to allow the daemon to fork, initialize, or report immediate failure.
- **Double Verification:** Never assumes a successful return from `systemctl restart` guarantees runtime health; re-checks `systemctl is-active` before confirming resolution.
- **Structured Audit Logging:** Every check and recovery is timestamped and recorded in `logs/recovery.log` formatted as:
  ```
  [YYYY-MM-DD HH:MM:SS] Service: <name> | Prior State: <state> | Action: <action> | Result State: <state>
  ```
- **Robust Error Handling:** Missing or un-startable units are cleanly trapped with detailed diagnostic output without hanging or infinite loops.

---

## 4. Usage Instructions

### Run the Default Health Check (Safe Mode)
```bash
./auto_service_recovery.sh
```
If `dummy-test` is active, the script outputs:
```
=== Automatic Service Recovery Monitor ===
Target Service : dummy-test
Log Destination: /path/to/AS_17/logs/recovery.log
--------------------------------------------------------
[OK] Service 'dummy-test' is healthy, no action needed.
```

### Test Service Recovery
1. Simulate a service outage by stopping the dummy unit:
   ```bash
   sudo systemctl stop dummy-test
   ```
2. Execute the recovery script:
   ```bash
   ./auto_service_recovery.sh
   ```
   Output:
   ```
   === Automatic Service Recovery Monitor ===
   Target Service : dummy-test
   Log Destination: /path/to/AS_17/logs/recovery.log
   --------------------------------------------------------
   [WARN] Service 'dummy-test' is currently 'inactive'. Initiating recovery...
   [INFO] Restart signal sent. Waiting 2 seconds for service stabilization...
   [SUCCESS] Service 'dummy-test' successfully recovered and is now active.
   ```
3. Confirm status:
   ```bash
   systemctl status dummy-test
   ```

### Test Error Handling (Nonexistent Service)
```bash
./auto_service_recovery.sh nonexistent-service
```
Output:
```
=== Automatic Service Recovery Monitor ===
Target Service : nonexistent-service
Log Destination: /path/to/AS_17/logs/recovery.log
--------------------------------------------------------
[WARN] Service 'nonexistent-service' is currently 'inactive'. Initiating recovery...
[ERROR] Restart attempt failed (Exit Code 5): Failed to restart nonexistent-service.service: Unit nonexistent-service.service not found.
```

---

## 5. Viewing the HTML Report

The sprint output includes a styled, dark-themed dashboard: `report.html`. It presents real captured terminal outputs for the "Before" (inactive) and "After" (active) service states, interactive metric badges, execution session replay, and the full scrollable recovery log.

### Option A: From inside WSL (Recommended)
Launch the report directly in your default Windows browser:
```bash
explorer.exe $(wslpath -w report.html)
```

### Option B: Direct Windows Path
Open your browser and navigate directly to:
```
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_17\report.html
```
*(Or paste this path into Windows File Explorer address bar / Run dialog `Win + R`)*

> **Self-Contained Note:** `report.html` is completely standalone. It uses inline CSS and native typography. No web server, Node.js, Python server, or external internet access is required.

---

## 6. Project Artifacts

| File | Description |
|---|---|
| [`auto_service_recovery.sh`](auto_service_recovery.sh) | The primary bash script with complete recovery logic and why-focused comments |
| [`logs/recovery.log`](logs/recovery.log) | Structured log recording check/recovery timestamped history |
| [`report.html`](report.html) | Standalone dark-themed HTML report comparing before & after states |
| [`commands_used.md`](commands_used.md) | Exhaustive log of every command run during development with one-line descriptions |
| [`README.md`](README.md) | Project documentation, setup guide, and rubric checklist |

---

## 7. Rubric Self-Check

- [x] **Strict Sandboxing:** Only `dummy-test.service` was ever stopped/restarted; no real services (`ssh`, `cron`, etc.) were touched.
- [x] **Filesystem Isolation:** Nothing modified outside `AS_17/` except the one test unit `/etc/systemd/system/dummy-test.service`.
- [x] **Dual Detection:** Script correctly detects both "already healthy" and "needs recovery" states.
- [x] **Graceful Error Handling:** Restart failure case (nonexistent service) handled gracefully with exit code 1 and logged diagnostic.
- [x] **Real Data in Report:** `report.html` contains actual captured `systemctl status` output before and after recovery.
- [x] **Accessible Report:** README explains both WSL command and Windows file path for viewing `report.html`.
- [x] **Quality Documentation:** Comments throughout the script explain *why* each decision was made, not just *what*.
