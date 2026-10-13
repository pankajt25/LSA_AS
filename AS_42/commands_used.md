# Linux Commands Used — AS_42: Department Folder Creation

This document outlines the core Linux administration utilities and techniques applied in the department directory provisioning and group ownership automation solution.

---

### 1. `groupadd` — Dedicated Security Group Provisioning
- **Command:** `sudo groupadd "lsatest_${dept}"`
- **Purpose:** Creates a dedicated system security group for each organizational department (e.g., `lsatest_engineering`, `lsatest_finance`).
- **Isolation:** Prefixed with `lsatest_` to prevent conflict with host groups.

### 2. `getent` — Querying Name Service Switch (NSS) Database
- **Command:** `getent group "lsatest_${dept}"`
- **Purpose:** Verifies group creation idempotently and retrieves the assigned numerical Group ID (GID) without hardcoding system state.

### 3. `mkdir` — Hierarchical Directory Provisioning
- **Command:** `mkdir -p "${BASE_DIR}/${dept}"`
- **Purpose:** Creates the sandboxed organizational directory structure inside `sandbox_data/departments/`.

### 4. `chown` & `chgrp` — Granular Ownership Assignment
- **Command:** `sudo chown "${USER}:lsatest_${dept}" "${dept_folder}"`
- **Purpose:** Assigns the primary administrator as user owner while delegating group authority to the respective department group.

### 5. `chmod` — SGID Bit & Discretionary Access Control (DAC)
- **Command:** `sudo chmod 2770 "${dept_folder}"`
- **Permission Breakdown:**
  - `2` (SGID / Set Group ID): Forces all newly created files and subdirectories inside the folder to inherit the group of the parent directory (`lsatest_<dept>`) rather than the primary group of the creating user.
  - `7` (User): Read, Write, Execute (`rwx`) for the folder owner.
  - `7` (Group): Read, Write, Execute (`rwx`) for all members of the department group.
  - `0` (Others): Zero permissions (`---`) ensuring strict isolation against cross-department snooping.

### 6. `stat` — Permission and Ownership Introspection
- **Command:** `stat -c "%A|%a|%U|%G" "${dept_folder}"`
- **Purpose:** Extracts symbolic permission string (`rwxrws---`), octal mask (`2770`), user owner, and group owner to programmatically verify access controls.

### 7. `groupdel` & `rm` — Safe Teardown & De-provisioning (`cleanup.sh`)
- **Command:** `sudo groupdel "lsatest_${dept}"`
- **Command:** `sudo rm -rf "${BASE_DIR}"`
- **Purpose:** Completely cleans up test groups and sandboxed folder trees, restoring the host system to pristine state.
