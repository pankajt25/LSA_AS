# Linux System Administration (E1ITA307) — Automation Sprint
## Problem Statement #27: Application Installation — Commands Reference

This document catalogs all core Linux system administration, package management, dependency resolution, and menu-driven automation commands utilized in the design, execution, verification, and reporting of `AS_27`.

---

### 1. Package Management & Verification

| Command Pattern | Purpose & Rationale |
| :--- | :--- |
| `dpkg -s <PACKAGE>` | Verifies Debian/Ubuntu package installation status and metadata without network queries. |
| `dpkg -s <PACKAGE> \| grep "^Version:"` | Extracts exact installed upstream and distro package version strings. |
| `sudo apt-get install -y <PACKAGE>` | Installs target packages non-interactively without prompt interruption. |
| `sudo apt-get remove -y <PACKAGE>` | Safely unlinks and purges demonstration packages during system teardown. |
| `command -v <BINARY>` | Fast POSIX verification of binary path availability within system `$PATH`. |
| `cowsay "<TEXT>"` / `figlet "<TEXT>"` | Verifies live functional execution of newly deployed terminal utilities. |

---

### 2. Live Verification & Execution Commands

```bash
# Automated run (installs safe demo packages cowsay & figlet and generates dashboard)
cd AS_27
bash run.sh

# Interactive terminal menu (browse catalog, select items 1..10 or D for demo)
./package_installer.sh

# Non-interactive CLI flag mode
./package_installer.sh --demo

# Specific package installation
./package_installer.sh --install cowsay,figlet

# Dry-run simulation mode (safe trial)
./package_installer.sh --dry-run --demo

# Status inspection & JSON telemetry export
./package_installer.sh --status --json

# Safe system teardown (uninstalls demo packages)
bash cleanup.sh
```

---

### 3. Production Deployment Automation

```bash
# Unattended infrastructure provisioning hook
# /usr/local/bin/package_installer.sh --install curl,git,htop,tmux,jq,tree >> /var/log/provision.log 2>&1
```
