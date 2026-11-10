# Linux Commands Used — AS_47: Security Audit Report

This document outlines the security auditing utilities, privilege checks, and log analysis commands implemented in the multi-vector security report.

---

### 1. `/etc/shadow` Parsing — Password-less Account Discovery
- **Command:** `sudo awk -F: '($2 == "") { print $1 }' /etc/shadow`
- **Purpose:** Parses field 2 of the shadow database. A blank string indicates an account that can authenticate without credentials, representing a severe security risk.
- **Verification:** `sudo passwd -S <user>` returns `NP` (No Password).

### 2. `find -perm -0002` — World-Writable File Discovery
- **Command:** `find "${TARGET_DIR}" -type f -perm -0002`
- **Purpose:** Recursively discovers regular files where the other/world write bit is enabled (octal `o+w`).
- **Inspection:** `stat -c "%A|%a|%U|%G"` extracts exact permission masks and file ownership.

### 3. Log Analysis — Failed Authentication Monitoring
- **Command:** `sudo grep -iE "(Failed password|authentication failure|Failed publickey)" /var/log/auth.log`
- **Purpose:** Extracts failed login events, identifying targeted account names, timestamp frequencies, and originating IP addresses.

### 4. `who` — Active Session Profiling
- **Command:** `who`
- **Purpose:** Discovers current interactive terminal sessions, active pseudoterminals (`pts/X`), login timestamps, and remote host addresses.

### 5. `useradd` & `userdel` — Sandboxed Test Lifecycle (`cleanup.sh`)
- **Provisioning:** `sudo useradd -M -s /usr/sbin/nologin lsatest_audit_nopass && sudo passwd -d lsatest_audit_nopass`
- **Teardown:** `sudo userdel -r lsatest_audit_nopass`
- **Purpose:** Provides verifiable demonstration artifacts without endangering existing administrative accounts, restored immediately via `cleanup.sh`.
