# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #28: Package Verification — Commands Reference

This document catalogs all core Linux system administration, package status querying, version extraction, and dependency audit commands utilized in the design, execution, verification, and reporting of `AS_28`.

---

### 1. Package Status Querying & Version Parsing

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `dpkg -s <PACKAGE>` | Queries Debian/Ubuntu package database to verify exact installation status without network round-trips. |
| `dpkg -s <PACKAGE> \| grep -i "^Version:" \| awk '{print $2}'` | Parses installed release and patch version strings for installed packages. |
| `command -v <PACKAGE>` | Identifies absolute filesystem path of package binary executable in `$PATH`. |
| `<PACKAGE> --version` | Direct binary invocation for standalone tools or packages managed outside dpkg. |
| `rpm -q --queryformat "%{VERSION}-%{RELEASE}" <PACKAGE>` | Cross-platform RPM package manager version inspection for RHEL/Fedora/openSUSE. |
| `pacman -Q <PACKAGE>` | Cross-platform Arch Linux package status and version query. |

---

### 2. Live Verification Commands

```bash
# Execute automated package verification against default manifest (packages.txt)
cd AS_28
bash run.sh

# Direct verification using default manifest
./package_verifier.sh

# Verify custom ad-hoc list of packages
./package_verifier.sh curl git python3 nginx docker cowsay

# Verify custom manifest file
./package_verifier.sh -f packages.txt

# Emit machine-readable JSON telemetry
./package_verifier.sh --json
```

---

### 3. Production Inventory Auditing via Cron

```bash
# Automated weekly system package compliance verification
# 0 6 * * 1 /usr/local/bin/package_verifier.sh -f /etc/required-packages.txt >> /var/log/package_audit.log 2>&1
```
