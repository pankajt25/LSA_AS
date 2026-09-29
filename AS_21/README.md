# Network Connectivity Check — Automation Sprint (AS_21)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Network Monitoring & Gateway Reachability Verification  
**Problem Statement #21:** An organization wants to periodically verify connectivity to its gateway/server. Write a script using `ping` and report whether the host is reachable.

---

## 1. Overview & Architecture

In production Linux environments, network connectivity to the local default gateway and external wide area networks (WAN) is the primary prerequisite for all application workloads, database clustering, microservice communication, and remote administrative management. A silent network disruption can halt distributed systems or trigger cascaded failovers.

`connectivity_check.sh` is an automated, production-grade Bash utility designed to systematically test network reachability. It automatically detects the active default gateway across different operating systems, probes it with a bounded number of ICMP echo requests, parses the results for packet loss and round-trip time (RTT), tests a secondary public sanity baseline (`8.8.8.8`), and provides an authoritative diagnostic verdict.

Complementing the monitoring utility, `run.sh` provides a **single, cross-platform execute-and-report command** that runs the check on live network infrastructure, regenerates a self-contained dark-themed HTML report dashboard (`report.html`) from scratch using live telemetry, and automatically launches the dashboard in the host's default web browser.

---

### Architectural Rationale: Dual-Target Triangulation & Baseline Sanity

A naive network check only pings the default gateway. However, in modern enterprise networks, cloud virtualization, and containerized platforms (such as WSL2 or hardened Linux hosts), a single probe produces misleading results:

1. **Gateway Down vs. Internet Down:** If only the gateway is pinged and it succeeds, you know local LAN routing is active, but you cannot determine whether upstream ISP routing or Internet access is functioning.
2. **ICMP Filtering on Modern Firewalls:** Many corporate routers, cloud gateways, and virtual switch adapters (including the Hyper-V virtual switch in WSL2) explicitly drop or filter ICMP Echo Requests (`ping`) as a security posture, while transparently routing TCP, UDP, and application traffic. If a script only probes the gateway, it falsely flags the entire network as offline!
3. **The Solution (Dual-Target Triangulation):** By concurrently probing **both** the local default gateway **and** a resilient public Anycast reference host (`8.8.8.8` Google Public DNS or `1.1.1.1` Cloudflare DNS), the script triangulates the exact failure domain.

```text
                               +-----------------------------+
                               |     Host Interface (eth0)   |
                               +--------------+--------------+
                                              |
                        +---------------------+---------------------+
                        |                                           |
                        v                                           v
       [Probe 1: Default Gateway]                  [Probe 2: Sanity Baseline]
       (Auto-detected: 192.168.32.1)               (Public Anycast: 8.8.8.8)
                        |                                           |
                        +---------------------+---------------------+
                                              |
                                              v
                              +-------------------------------+
                              |    Triangulation Evaluator    |
                              +---------------+---------------+
                                              |
        +-------------------------+-----------+-----------+-------------------------+
        |                         |                       |                         |
        v                         v                       v                         v
 [GW OK + Base OK]         [GW OK + Base FAIL]     [GW FAIL + Base OK]       [GW FAIL + Base FAIL]
 ✅ Full Connectivity     ⚠️ Local LAN Only       🌐 Internet Accessible    ❌ Total Network Outage
  All routes operational    Upstream ISP severed    ICMP filtered at router   Physical/link failure
```

---

### Cross-Platform Gateway Auto-Detection

The script automatically detects the machine's real default gateway without requiring hardcoded configuration:

| Operating System | Detection Command | Architectural Rationale |
|---|---|---|
| **Linux (iproute2)** | `ip route \| grep default \| awk '{print $3}'` | Primary modern Linux standard; extracts next-hop gateway address from the kernel routing table. |
| **Linux (net-tools fallback)** | `route -n \| awk '/^0.0.0.0/ {print $2; exit}'` | Legacy fallback if `iproute2` package is missing. |
| **macOS (Darwin BSD)** | `route -n get default \| awk '/gateway:/ {print $2}'` | Standard macOS BSD routing table inspection. |
| **Windows (Git Bash / MSYS)** | `netstat -rn \| awk '$1 == "0.0.0.0" {print $3; exit}'` | Standard Windows routing table parsing under MSYS/Cygwin. |
| **Windows (PowerShell)** | `(Get-NetRoute -DestinationPrefix '0.0.0.0/0').NextHop` | Native Windows PowerShell network cmdlet fallback. |

---

### Cross-Platform Ping Flag Differences

Unbounded pings can freeze automated scripts indefinitely. `connectivity_check.sh` enforces a bounded count (`-c 4`) and handles syntactic variations across operating systems:

- **Linux (`iputils-ping`):** Uses `ping -c 4 -W 2 <host>`. `-c 4` sends 4 echo requests; `-W 2` enforces a 2-second timeout per packet so unreachable hosts do not hang.
- **macOS (`Darwin BSD`):** Uses `ping -c 4 -t 2 <host>`.
- **Windows Native (`ping.exe`):** Uses `ping -n 4 -w 2000 <host>`. The script dynamically detects whether `ping` expects `-c` or `-n`.

---

### Grep / Awk Output Extraction Pipeline

Rather than dumping raw text, the script extracts precise metrics using POSIX-compliant `grep` and `awk`:

- **Transmitted & Received Count:**
  ```bash
  transmitted=$(echo "$raw_output" | grep -oE '[0-9]+ packets transmitted' | awk '{print $1}')
  received=$(echo "$raw_output" | grep -oE '[0-9]+ (packets )?received' | awk '{print $1}')
  ```
- **Packet Loss Percentage:**
  ```bash
  loss_pct=$(echo "$raw_output" | grep -oE '[0-9]+(\.[0-9]+)?% packet loss' | awk '{print $1}')
  ```
- **Average Round-Trip Time (RTT):**
  ```bash
  stats_line=$(echo "$raw_output" | grep -E "rtt|round-trip" | head -n 1)
  rtt_values=$(echo "$stats_line" | awk -F'=' '{print $2}')
  avg_rtt=$(echo "$rtt_values" | awk -F'/' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  ```

---

## 2. Sandboxing & Safety Notice (Mandatory)

This sprint strictly complies with all sandbox and safety requirements:
- **No System Modifications:** All created scripts, logs, and reports reside exclusively within `AS_21/`.
- **Non-Destructive Operations:** The script only transmits standard ICMP Echo Requests (`ping`). It does not modify routing tables, IP addresses, `/etc/resolv.conf`, or firewall configurations.
- **Guaranteed Bounded Execution:** All ping commands enforce strict packet counts (`-c 4`) and timeouts (`-W 2`), preventing infinite loops or background execution freezes.
- **Zero Forbidden Commands:** No destructive disk operations (`rm -rf`, `dd`, `mkfs`, `parted`) are executed anywhere.

---

## 3. Key Features

- **Automated Default Gateway Discovery:** Automatically detects the live gateway IP via `ip route | grep default | awk '{print $3}'`.
- **Dual-Target Sanity Probing:** Automatically tests a well-known public baseline (`8.8.8.8`) alongside the gateway to differentiate local LAN link status from WAN access.
- **Real-Time Live Telemetry:** Captures actual live network statistics on this machine (no simulated or fabricated numbers).
- **Clear Status Messages:** Outputs standardized indicators:
  - `✅ Gateway 192.168.x.x is REACHABLE (0% loss, avg 2.1ms)`
  - `❌ Gateway 192.168.x.x is UNREACHABLE (100% loss)`
- **Persistent Chronological Audit Logging:** Appends every scan with timestamp, hostname, OS, kernel, probe results, and diagnosis to `logs/connectivity.log`.
- **Defensive Error Handling:** Validates tool availability (`ping`), handles unresolvable hostnames gracefully, and prevents script crashes.
- **Self-Contained Dark-Themed Dashboard:** Automatically regenerates `report.html` from scratch on every run with responsive status cards, routing context, triangulation reference, and scrollable log viewer.

---

## ## Command to Execute

Run this **single command** from inside the `AS_21/` directory:

```bash
bash run.sh
```

*(From repository root, execute: `cd AS_21 && bash run.sh`)*

### 🌐 Cross-Platform Execution Notes

- **🐧 Linux & 🍎 macOS:** Run `bash run.sh` directly in any standard terminal. On Linux, the script automatically launches the report via `xdg-open`. On macOS, it invokes `open report.html`.
- **🪟 Windows (WSL):** Run `bash run.sh` inside WSL. The script translates the path using `wslpath -w` and dispatches `explorer.exe` to open the report inside your Windows default browser.
- **🪟 Windows (Git Bash / MSYS / Cygwin):** Run `bash run.sh` in Git Bash. The script detects the environment and invokes `start "" report.html`.

> [!NOTE]
> The HTML report (`report.html`) **regenerates live on every run** from scratch using real-time network metrics. It is never a static or stale document.

---

## ## Viewing the HTML Report

The `bash run.sh` script automatically opens `report.html` upon execution. If you need to open or view the report manually, use the appropriate command for your platform:

### 🪟 Windows WSL (Manual Fallback)
```bash
explorer.exe "$(wslpath -w report.html)"
```
*Windows File System Path Equivalent:*
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_21\report.html
```

### 🐧 Native Linux Desktop (X11 / Wayland)
```bash
xdg-open report.html
```

### 🍎 macOS
```bash
open report.html
```

### 🪟 Windows Git Bash / Command Prompt
```bash
start "" report.html
```

---

## 4. Command-Line Options & Syntax

`connectivity_check.sh` supports positional target arguments as well as standard CLI options:

```bash
./connectivity_check.sh [TARGET] [OPTIONS]
```

| Argument / Option | Default | Description |
|---|---|---|
| `TARGET` (positional `$1`) | Auto-detected Gateway | IP address or hostname to probe. |
| `-t, --target <host>` | Auto-detected Gateway | Explicitly sets the target host. |
| `-b, --baseline <host>` | `8.8.8.8` | Sanity baseline host for Internet reference. |
| `-c, --count <num>` | `4` | Number of ping packets to transmit per probe. |
| `-l, --log <file>` | `logs/connectivity.log` | Destination path for audit logging. |
| `-h, --help` | None | Displays comprehensive manual and exits. |

### Usage Examples

```bash
# 1. Baseline scan: automatically detects real gateway and tests against 8.8.8.8
./connectivity_check.sh

# 2. Test specific target (e.g. Cloudflare DNS)
./connectivity_check.sh 1.1.1.1

# 3. Test with custom packet count and custom sanity baseline
./connectivity_check.sh -c 2 -b 1.0.0.1

# 4. Test unresolvable domain to verify graceful DNS error handling
./connectivity_check.sh fake.domain.test.invalid

# 5. Run full execute + report workflow through the unified launcher
bash run.sh 1.1.1.1
```

---

## 5. Sample Live Terminal Output

The following live output was captured during execution on this system:

```text
================================================================================
        AUTOMATION SPRINT (AS_21) — NETWORK CONNECTIVITY CHECK                  
================================================================================
[INFO] Running connectivity_check.sh on live network...
--------------------------------------------------------------------------------
================================================================================
     NETWORK CONNECTIVITY CHECK — AUTOMATION SPRINT (AS_21)                    
================================================================================
Timestamp : 2026-09-29 23:45:10 | Host: SP | OS: Linux (6.18.33.2-microsoft-standard-WSL2)
User      : pankaj
Target    : 192.168.32.1 (Gateway)
Baseline  : 8.8.8.8 (Sanity Host / Public Internet Reference)
Pings     : 4 packets per target (Timeout: 2s)
--------------------------------------------------------------------------------
[1/2] Probing Gateway: 192.168.32.1...
[2/2] Probing Sanity Baseline Host: 8.8.8.8...
--------------------------------------------------------------------------------
PROBE RESULTS:
  ❌ Gateway 192.168.32.1 is UNREACHABLE (100% loss)
  ✅ Baseline Host 8.8.8.8 is REACHABLE (0% loss, avg 56.527ms)
--------------------------------------------------------------------------------
DIAGNOSTIC ASSESSMENT:
  🌐 Internet Accessible: Gateway Unreachable / ICMP Echo Filtered
  The public baseline (8.8.8.8) responded normally, confirming WAN routing is active. However, Gateway (192.168.32.1) dropped ICMP packets. In virtualized environments (such as WSL2 virtual switch) or enterprise firewalls, host routers routinely block ICMP echo requests while continuing to route forwarded traffic.
================================================================================
Audit log appended to: logs/connectivity.log
--------------------------------------------------------------------------------
[INFO] Regenerating report.html dashboard with live data...
[SUCCESS] report.html regenerated successfully (30667 bytes).

================================================================================
🚀 Dispatching report.html to Web Browser...
================================================================================
[INFO] Detected WSL environment.
[INFO] Windows Path: D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_21\report.html
[LAUNCH] Invoking explorer.exe to launch report in Windows default browser...
[SUCCESS] Dashboard launch command dispatched successfully.
================================================================================
```

---

## 6. Audit Logging Format (`logs/connectivity.log`)

Every run appends a structured entry to `logs/connectivity.log`:

```text
================================================================================
[2026-09-29 23:45:10] NETWORK CONNECTIVITY AUDIT CHECK
Host: SP | OS: Linux | Kernel: 6.18.33.2-microsoft-standard-WSL2 | User: pankaj
Scan Configuration: Count=4 packets | Timeout=2s
--------------------------------------------------------------------------------
PROBE 1: Gateway (192.168.32.1)
  Status        : UNREACHABLE
  Packets       : Transmitted = 4, Received = 0, Packet Loss = 100%
  Round-Trip    : Min = N/A, Avg = N/A, Max = N/A
  Summary Line  : ❌ Gateway 192.168.32.1 is UNREACHABLE (100% loss)
--------------------------------------------------------------------------------
PROBE 2: Sanity Baseline (8.8.8.8)
  Status        : REACHABLE
  Packets       : Transmitted = 4, Received = 4, Packet Loss = 0%
  Round-Trip    : Min = 30.291ms, Avg = 56.527ms, Max = 111.458ms
  Summary Line  : ✅ Baseline Host 8.8.8.8 is REACHABLE (0% loss, avg 56.527ms)
--------------------------------------------------------------------------------
DIAGNOSTIC ASSESSMENT: [ICMP_FILTERED]
  🌐 Internet Accessible: Gateway Unreachable / ICMP Echo Filtered
  The public baseline (8.8.8.8) responded normally, confirming WAN routing is active. However, Gateway (192.168.32.1) dropped ICMP packets. In virtualized environments (such as WSL2 virtual switch) or enterprise firewalls, host routers routinely block ICMP echo requests while continuing to route forwarded traffic.
================================================================================
```

---

## 7. Exit Codes & Error Trapping

The script adheres to POSIX error-handling standards:

| Exit Code | Meaning | Cause |
|---|---|---|
| `0` | Success | Probing completed normally and results were logged. |
| `1` | Tooling / Environment Error | `ping` command is not available in system `PATH`. |
| `2` | Syntax / Input Error | Invalid option or non-numeric packet count supplied. |

---

## 8. Deliverables Summary

| File | Purpose |
|---|---|
| `connectivity_check.sh` | Core network reachability, gateway detection, and audit logging script. |
| `run.sh` | Unified cross-platform runner, HTML dashboard regenerator, and browser launcher. |
| `report.html` | Self-contained dark-themed live dashboard with inline CSS and live telemetry. |
| `logs/connectivity.log` | Persistent append-only chronological audit log. |
| `commands_used.md` | Log of all commands executed during development and testing. |
| `README.md` | Complete project documentation, usage guide, and architectural notes. |
