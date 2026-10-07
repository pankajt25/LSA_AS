# Linux Commands Used — AS_43: Employee Offboarding

This document provides a technical breakdown of all Linux administrative utilities, PAM flags, and archival routines implemented in the employee offboarding workflow.

---

### 1. `useradd` & `chpasswd` — Test Subject Provisioning
- **Command:** `sudo useradd -m -s /bin/bash -c "Offboarding Demo" "lsatest_offboard_demo"`
- **Command:** `echo "lsatest_offboard_demo:password" | sudo chpasswd`
- **Purpose:** Sets up an active user account with a valid home directory and bash shell to simulate a departing employee.

### 2. `pkill` — Session and Process Termination
- **Command:** `sudo pkill -u "${TARGET_USER}"`
- **Purpose:** Sends `SIGTERM` to all running processes owned by the departing user, terminating active SSH, background daemon, or terminal sessions immediately.

### 3. `usermod` — Account Locking & Shell Disabling
- **Password Locking:** `sudo usermod -L "${TARGET_USER}"`
  - Prepends an exclamation mark (`!`) to the encrypted password string in `/etc/shadow`, invalidating password-based authentication.
- **Login Shell Revocation:** `sudo usermod -s /usr/sbin/nologin "${TARGET_USER}"`
  - Replaces the default interactive shell with `/usr/sbin/nologin` (or `/bin/false`), rejecting interactive shell logins, SFTP, and SSH commands.
- **Account Expiration:** `sudo usermod -e 1 "${TARGET_USER}"`
  - Sets the account expiration epoch to 1 (1970-01-02), causing PAM modules (`pam_unix.so`) to reject login attempts even if alternate auth mechanisms exist.

### 4. `passwd` & `chage` — Shadow Database Auditing
- **Password Status:** `sudo passwd -S "${TARGET_USER}"`
  - Queries shadow database to verify password lock flag (`L`).
- **Aging & Expiry Inspection:** `sudo chage -l "${TARGET_USER}"`
  - Inspects account expiry date, password inactive thresholds, and last change timestamp.

### 5. `tar` — Home Directory Archival & Integrity Verification
- **Packaging:** `sudo tar -czf "${ARCHIVE_FILE}" -C "$(dirname "${HOME_DIR}")" "$(basename "${HOME_DIR}")"`
  - Packages and compresses the entire home directory tree into a timestamped `.tar.gz` bundle.
- **Decompression Test:** `tar -tzf "${ARCHIVE_FILE}"`
  - Reads tar headers across the compressed stream to verify that data blocks are intact and recoverable without unlinking or overwriting existing files.

### 6. `sha256sum` — Forensic Manifest Generation
- **Command:** `sha256sum "${ARCHIVE_FILE}" > "${ARCHIVE_FILE}.sha256"`
- **Purpose:** Generates a cryptographic SHA-256 fingerprint of the archived home directory for archival record-keeping.

### 7. `userdel` & `groupdel` — Safe Teardown (`cleanup.sh`)
- **Command:** `sudo userdel -r "${TARGET_USER}"`
- **Purpose:** Completely removes user credentials from `/etc/passwd` and `/etc/shadow`, deletes the mail spool, and cleans up residual files.
