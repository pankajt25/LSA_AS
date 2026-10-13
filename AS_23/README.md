# IP Configuration Report — Automation Sprint (AS_23)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Network Administration & Live System Interface Audit  
**Problem Statement #23:** Create a script that displays the hostname, IP address, active interfaces, and default gateway of a Linux system.  

---

## Command to Execute

To audit this machine's live network configuration, query all active interfaces and routes, regenerate the dark-themed HTML report dashboard, and automatically launch it in your default web browser, run:

```bash
bash run.sh
```

### Platform-Specific One-Line Execution Notes:
- **Windows (WSL2 / Ubuntu):** `cd AS_23 && bash run.sh` — Queries live kernel network configuration via `iproute2`, generates `report.html`, translates Linux paths via `wslpath -w`, and opens the dashboard directly in your Windows default browser via `explorer.exe`.
- **Linux (Desktop / X11 / Wayland):** `cd AS_23 && bash run.sh` — Gathers live interface data and launches `report.html` via `xdg-open`.
- **macOS (Darwin):** `cd AS_23 && bash run.sh` — Gathers network parameters via BSD `ifconfig` + `route -n get default` and opens `report.html` via `open`.
- **Windows (Git Bash / MSYS2 / Cygwin):** `cd AS_23 && bash run.sh` — Executes the Bash workflow and dispatches `report.html` via Windows `start ""`.

> **Note on Live Data Regeneration:** `run.sh` **never** serves stale or static mock data. Every single execution runs `ip_config_report.sh`, queries this machine's actual real network configuration (hostname, assigned IPs, default gateway, MAC addresses, MTU, and DNS nameservers), records a timestamped plain-text report in `reports/`, and regenerates `report.html` completely from scratch.

---

## Viewing the HTML Report

If your environment is headless or your web browser does not open automatically, view the generated report manually:

### Windows / WSL2 Fallback (Command Prompt / PowerShell / WSL):
```bash
# From within WSL terminal:
explorer.exe "$(wslpath -w report.html)"
```
Or directly open the resolved Windows file path in any web browser (Edge, Chrome, Firefox, Brave):
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_23\report.html
```

### Native Linux / macOS Fallbacks:
```bash
# Linux Desktop:
xdg-open report.html || sensible-browser report.html || python3 -m webbrowser report.html

# macOS:
open report.html
```

---

## 1. Overview & System Architecture

In modern Linux administration, auditing network configuration is fundamental for server provisioning, container clustering, troubleshooting reachability, and network segmentation. Understanding which interfaces are operational, what IP and MAC bindings they carry, which gateway routes outgoing traffic, and how DNS resolution is routed is essential for system reliability.

`ip_config_report.sh` is an automated, production-grade network administration tool designed to inspect, parse, and present live network configuration metrics. It queries the Linux kernel networking subsystem using modern `iproute2` utilities, formats a clean terminal report with ANSI status badges, logs timestamped audit records, and feeds structured JSON telemetry into the self-contained `report.html` dashboard.

```text
                                  +-----------------------------+
                                  |    run.sh Cross-Platform    |
                                  |          Launcher           |
                                  +--------------+--------------+
                                                 |
                                +----------------+----------------+
                                |      ip_config_report.sh        |
                                |     (Core Audit Engine)         |
                                +----------------+----------------+
                                                 |
                       +-------------------------+-------------------------+
                       |                         |                         |
                       v                         v                         v
          +-------------------------+ +-------------------------+ +-------------------------+
          |   Host Identification   | |   Routing & Gateway     | |   Active Interfaces     |
          |  'hostname', 'hostname -I'| | 'ip route show default' | | 'ip -br addr show up'   |
          |  System Distro & Kernel | | Gateway IP, Dev, Metric | | MAC ('ip link'), MTU    |
          +------------+------------+ +------------+------------+ +------------+------------+
                       |                           |                           |
                       +---------------------------+---------------------------+
                                                 |
                                +----------------+----------------+
                                |  DNS & Resolver Discovery       |
                                |   /etc/resolv.conf nameservers  |
                                |   systemd-resolved fallback     |
                                +----------------+----------------+
                                                 |
                       +-------------------------+-------------------------+
                       |                         |                         |
                       v                         v                         v
          +-------------------------+ +-------------------------+ +-------------------------+
          |  Clean Terminal Report  | | Timestamped Audit Files | | Structured Telemetry    |
          |  ANSI Aligned Tables    | | reports/ip_report_*.txt | | reports/.last_report.json|
          +-------------------------+ +-------------------------+ +------------+------------+
                                                                               |
                                                                               v
                                                                  +-------------------------+
                                                                  | Regenerate report.html  |
                                                                  |  Dark Theme Dashboard   |
                                                                  +------------+------------+
                                                                               |
                                                                               v
                                                                  +-------------------------+
                                                                  | Launch Browser via OS   |
                                                                  | explorer.exe / xdg-open |
                                                                  +-------------------------+
```

---

## 2. Architectural Rationale: Why `iproute2` (`ip`) Over Legacy `net-tools` (`ifconfig` / `route`)

A core requirement of this sprint is demonstrating the technical rationale behind modern networking tools. While legacy courses and tutorials often reference `ifconfig` and `route`, modern enterprise Linux environments exclusively utilize the `iproute2` suite.

| Feature / Metric | Modern `iproute2` (`ip` suite) | Legacy `net-tools` (`ifconfig` / `route`) | Architectural Impact |
|:---|:---|:---|:---|
| **Kernel IPC Subsystem** | **Netlink Sockets (`AF_NETLINK`)** | **Synchronous `ioctl()` Syscalls** | Netlink is asynchronous, event-driven, and high-throughput. `ioctl()` is slow, single-threaded, and cannot represent complex link attributes. |
| **Address Binding Model** | **Discrete First-Class Objects** | **Virtual Sub-Interface Aliases** | `ip addr` binds multiple IPv4/IPv6 addresses directly to a device. `ifconfig` required artificial aliases (`eth0:0`, `eth0:1`) and completely hides secondary addresses added without alias labels. |
| **Subnet Representation** | **Native CIDR Notation (`/24`, `/20`, `/64`)** | **Dotted Decimal Netmasks** | CIDR prefix lengths are concise, unambiguous, and universal across IPv4 and IPv6. |
| **Containers & Namespaces** | **Full `ip netns` Support** | **Zero Namespace Awareness** | Critical for Docker, Podman, and Kubernetes container isolation. `ifconfig` cannot see or cross network namespaces. |
| **Policy Routing & FIB** | **Multiple Routing Tables (`ip rule`)** | **Single Kernel Destination Table** | Supports policy-based routing, traffic shaping, multipath routing, and route metrics. |
| **Maintenance & Packaging** | **Actively Maintained in Kernel Tree** | **Deprecated since ~2009** | Modern enterprise distributions (Ubuntu, Debian, RHEL, Fedora, Arch) no longer include `net-tools` by default. |

---

## 3. Real System Live Telemetry Captured

The following live system parameters were queried and verified on this machine during test execution:

- **Hostname:** `SP`
- **Summary of All Assigned IPs:** `192.168.42.183`
- **Primary IPv4 Address:** `192.168.42.183/20` (bound to `eth0`)
- **Default Gateway IP:** `192.168.32.1` (egress dev: `eth0`, protocol: `kernel`)
- **DNS Nameserver(s):** `10.255.255.254` (Search domain: `ALLIANCEBLR.COM`)
- **Active Network Interfaces:**
  - `lo` — State: `UNKNOWN` (Loopback), MTU: `65536` bytes, MAC: `00:00:00:00:00:00`, IPv4: `127.0.0.1/8`, `10.255.255.254/32`, IPv6: `::1/128`
  - `eth0` — State: `UP` (Physical Ethernet), MTU: `1500` bytes, MAC: `00:15:5d:bb:c0:36`, IPv4: `192.168.42.183/20`, IPv6: `fe80::215:5dff:febb:c036/64`
- **Operating System:** Ubuntu 26.04.1 LTS (`6.18.33.2-microsoft-standard-WSL2`, `x86_64`)

---

## 4. Key Script Features & Defensive Engineering

1. **Non-Privileged Read-Only Execution:** All networking queries (`ip addr`, `ip link`, `ip route`, `cat /etc/resolv.conf`) are read-only. No system configuration or interface state is modified.
2. **Graceful Fallbacks:** If `ip -br` is unavailable, the script parses standard `ip addr show`. If `ip` is absent, it cascades to `ifconfig` and `route -n`. If networking utilities are stripped, it queries `/sys/class/net/` directly.
3. **Structured Telemetry Pipeline:** The script exports machine-readable telemetry to `reports/.last_report.json`, ensuring `run.sh` renders `report.html` deterministically without fragile regex re-parsing.
4. **Dual Output Target:** Clean, colored tables are rendered to the console, while unadorned plain text is simultaneously archived in timestamped audit logs.
5. **Cross-Platform Browser Launcher:** Automatically adapts browser opening across WSL2, native Linux desktops, macOS, and Windows Git Bash environments.

---

## 5. File Inventory

```text
AS_23/
├── ip_config_report.sh     # Core Bash network configuration audit engine
├── run.sh                  # Single cross-platform execute + report command
├── report.html             # Self-contained dark-themed dashboard (regenerated live)
├── commands_used.md        # Comprehensive development command execution log
├── README.md               # Sprint documentation and operational guide
└── reports/                # Timestamped plain-text audit reports
    ├── .last_report.json   # Structured JSON telemetry for dashboard generation
    ├── latest_ip_report.txt# Fast reference pointer to latest run
    └── ip_report_*.txt     # Historical timestamped audit logs
```
