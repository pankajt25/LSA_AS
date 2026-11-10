# Linux Commands Used — AS_46: Service Status Dashboard

This document details the systemd introspection utilities and cgroup accounting properties used in the service status dashboard.

---

### 1. `systemctl show -p LoadState` — Unit Definition Existence
- **Command:** `systemctl show -p LoadState --value "<unit>.service"`
- **Purpose:** Verifies whether a service unit file is loaded into the systemd state machine or missing (`not-found`), preventing false alarms for uninstalled packages.

### 2. `systemctl is-active` — High-Level Unit State
- **Command:** `systemctl is-active "<unit>.service"`
- **Return Values:**
  - `active`: Service daemon is actively running or socket listening.
  - `inactive`: Service is stopped cleanly.
  - `failed`: Service exited with error or failed during startup.

### 3. `systemctl is-enabled` — Boot Persistence Inspection
- **Command:** `systemctl is-enabled "<unit>.service"`
- **Return Values:** `enabled`, `disabled`, `static`, `masked`.
- **Purpose:** Verifies whether the daemon is configured to start automatically at system boot via multi-user target symlinks.

### 4. `systemctl show -p MainPID` & Memory Accounting
- **Main PID:** `systemctl show -p MainPID --value "<unit>.service"`
  - Queries systemd for the root daemon PID.
- **Memory Consumption:** `systemctl show -p MemoryCurrent --value "<unit>.service"`
  - Directly queries the Linux kernel control group (cgroup v2) memory controller for instantaneous resident memory bytes consumed by the unit slice.

### 5. `systemctl show -p ActiveEnterTimestamp`
- **Command:** `systemctl show -p ActiveEnterTimestamp --value "<unit>.service"`
- **Purpose:** Discovers the exact timestamp the service transitioned into the active state.
