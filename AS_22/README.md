# Multiple Server Check — Automation Sprint (AS_22)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Network Automation, Multi-Host Inventory Probing & Fleet Availability  
**Problem Statement #22:** An administrator maintains a list of servers. Develop a script that checks connectivity to every server and reports UP/DOWN status.

---

## Command to Execute

To execute the multi-server health check, capture real-time live network telemetry across all targets in `servers.txt`, regenerate the dark-themed HTML report dashboard, and automatically launch it in your default web browser, run:

```bash
bash run.sh
```

### Platform-Specific One-Line Execution Notes:
- **Linux (Desktop / X11 / Wayland):** `cd AS_22 && bash run.sh` — Probes live hosts in parallel and launches `report.html` via `xdg-open`.
- **Windows (WSL2 / Ubuntu):** `cd AS_22 && bash run.sh` — Translates Linux paths via `wslpath -w` and opens the dashboard directly in your Windows default browser via `explorer.exe`.
- **macOS (Darwin):** `cd AS_22 && bash run.sh` — Runs native BSD ping probes and opens `report.html` via `open`.
- **Windows (Git Bash / MSYS2 / Cygwin):** `cd AS_22 && bash run.sh` — Dispatches execution and launches `report.html` via Windows `start ""`.

> **Note on Live Data Regeneration:** `run.sh` **never** serves stale or static mock data. Every single invocation runs `multi_server_check.sh`, pings the live hosts in `servers.txt`, captures real-time ICMP packet loss and RTT latencies, updates `logs/multi_server_check.log`, and regenerates `report.html` completely from scratch with live system data.

---

## Viewing the HTML Report

If your terminal environment is headless or your browser does not open automatically, view the generated report manually:

### Windows / WSL2 Fallback (Command Prompt / PowerShell / WSL):
```bash
# From within WSL terminal:
explorer.exe "$(wslpath -w report.html)"
```
Or directly open the resolved Windows file path in any browser (Edge, Chrome, Firefox, Brave):
```text
D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_22\report.html
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

In modern production environments—from private datacenters and hybrid clouds to distributed microservices and Kubernetes clusters—administrators must constantly monitor fleet-wide server reachability. Network partitions, routing misconfigurations, cloud firewall alterations, and upstream carrier outages can sever communication between critical application nodes.

`multi_server_check.sh` is an automated, production-grade Bash utility designed to systematically test reachability across an arbitrary inventory of hosts defined in `servers.txt`. It executes bounded ICMP echo requests, extracts packet loss and latency metrics using grep/awk, presents clean terminal tables with status highlights, logs historical records with timestamps, and summarizes total fleet availability.

```text
                                  +-----------------------------+
                                  |    Inventory: servers.txt   |
                                  | (Hosts, IPs, Inline Labels) |
                                  +--------------+--------------+
                                                 |
                               +-----------------+-----------------+
                               |   Inventory Parser & Validator    |
                               | (Comments, Whitespace, GATEWAY)   |
                               +-----------------+-----------------+
                                                 |
                         +-----------------------+-----------------------+
                         |                                               |
                         v (Default: --parallel)                         v (Optional: --sequential)
          +-------------------------------+               +-------------------------------+
          |   Parallel Subshell Pool (&)  |               |    Serial Iterative Loop      |
          |  slot_0.dat ... slot_N.dat    |               |  Target 1 -> Target 2 -> ...  |
          |      synchronized by 'wait'   |               |   Deterministic Single-Thread |
          +---------------+---------------+               +---------------+---------------+
                          \                                               /
                           \                                             /
                            v                                           v
                             +-----------------------------------------+
                             |       Grep & Awk Extraction Pipeline    |
                             |   Loss %, Avg RTT, Min/Max RTT, Status  |
                             +--------------------+--------------------+
                                                  |
                         +------------------------+------------------------+
                         |                                                 |
                         v                                                 v
           +---------------------------+                     +---------------------------+
           |   Terminal Table Output   |                     | Chronological Audit Log   |
           | [ UP ] / [ DOWN ] Badges  |                     | logs/multi_server_check.log|
           +---------------------------+                     +---------------------------+
                         |
                         v
           +---------------------------+
           |       run.sh Launcher     |
           | Regenerates report.html   |
           | Dispatches Default Web UI |
           +---------------------------+
```

---

## 2. Key Requirements & Implementation Details

| Requirement | Implementation in `multi_server_check.sh` & `run.sh` | Architectural Justification |
|---|---|---|
| **1. Config Inventory** | Reads targets from `servers.txt` (`#` comments, blank lines skipped, inline labels parsed, `GATEWAY` dynamically substituted). | Decouples target inventory from script logic; enables dynamic host fleet expansion. |
| **2. OS-Adapted Probes** | Detects OS via `uname -s`. Uses `-c 2 -W 2` (Linux), `-c 2 -t 2` (macOS), `-n 2 -w 2000` (Windows). | Prevents syntax errors across BSD, GNU, and Windows native ping implementations. |
| **3. Clean Status Table** | Formats aligned ASCII table with Target, Status (`[ UP ]` / `[ DOWN ]`), Loss %, Avg RTT, Packets, Role. | Provides instant human-readable status for console operators. |
| **4. Executive Summary** | Calculates Total Targets, Reachable Count, Down Count, and Overall Availability Percentage (`awk`). | Gives management-level health ratio in one glance. |
| **5. Parallel Execution** | Spawns background subshells (`&`) with numbered slot files, synchronized via `wait`. Includes `-s` sequential flag. | Drops wall-clock execution time from `O(N * timeout)` (~16s) to `O(timeout)` (~3s). |
| **6. Audit Logging** | Appends structured timestamped runs to `logs/multi_server_check.log`. | Preserves historical audit records for compliance, SLA tracking, and trend analysis. |
| **7. Robust Error Trapping** | Traps missing file (exit 1), empty config (exit 1), skips malformed tokens with warnings, handles DNS failure gracefully. | Guarantees the script never crashes midway or enters infinite loops. |
| **8. Automated HTML Report** | `run.sh` regenerates a self-contained dark dashboard `report.html` from live data and dispatches the browser. | Zero-dependency, portable stakeholder dashboard with interactive filters. |

---

## 3. Deep Dive: Parallel vs. Sequential Concurrency

A core design requirement of network automation is managing latency and timeout accumulation. In this project, both **Parallel** and **Sequential** modes are fully implemented and can be toggled via `--parallel` (default) or `--sequential` (`-s`).

### Concurrency Benchmark Comparison (Live Test Results on 9 Targets):

| Metric | Sequential Mode (`-s`) | Parallel Mode (`--parallel` / Default) |
|---|---|---|
| **Execution Pattern** | Linear: Target 1 &rarr; Target 2 &rarr; Target 3... | Concurrent: Spawns subshells in background (`&`) |
| **Synchronization** | Blocking loop | Non-blocking background jobs + bash `wait` |
| **Total Wall-Clock Time** | **16 seconds** | **3 to 4 seconds** (Bounded by max probe timeout) |
| **Display Order** | Direct | Guaranteed order via numbered slot files (`slot_N.dat`) |
| **Failure Isolation** | One slow/hanging host delays all subsequent checks | Slow or down hosts finish independently without blocking others |
| **IPC Mechanism** | None (in-process variables) | Numbered temporary files in secure `mktemp -d` directory |
| **Cleanup Guarantee** | None required | Guaranteed by `trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM` |
| **Resource Footprint** | Minimal (1 process at a time) | $N$ lightweight subshells (bounded by fleet size) |

### Tradeoff Analysis (Viva Defense):
- **Why Parallel is Superior for Fleets:** As server inventories scale from 10 to 100 or 500 hosts, sequential execution becomes completely unviable ($100 \times 2\text{s} = 200\text{s} \approx 3.3\text{ minutes}$). Parallel execution runs in $O(\text{timeout})$, completing 100 targets in the same ~2–3 seconds as 5 targets.
- **When Sequential is Appropriate:** On resource-constrained edge devices (e.g. low-memory embedded routers, Raspberry Pis, or cellular IoT modems) where spawning 50 concurrent subshells might exhaust file descriptors, saturate ICMP socket buffers, or trigger packet queue dropping on a shared physical adapter.

---

## 4. Real Target Inventory Configuration (`servers.txt`)

`servers.txt` contains a balanced mix of real, reachable network endpoints and intentional benchmark targets:

```text
# Local Network Infrastructure & Gateway
192.168.32.1        # Local Default Gateway (Hyper-V / Virtual Switch)
127.0.0.1           # Localhost Loopback Interface

# Tier-1 Public Anycast DNS Resolvers
8.8.8.8             # Google Primary Public DNS
1.1.1.1             # Cloudflare Primary Public DNS
9.9.9.9             # Quad9 Threat-Blocking Secure DNS

# Major Global Web & Cloud Infrastructure
google.com          # Google Global Search Infrastructure
github.com          # GitHub Version Control & Developer Platform
wikipedia.org       # Wikimedia Foundation Global CDN

# Reserved Benchmark Blackhole Target (RFC 5737 TEST-NET-1)
192.0.2.1           # RFC 5737 Test IP (Intentionally Unroutable Benchmark)
```

### Why Specific Hosts Behave as Observed:
1. **`192.168.32.1` (WSL2 Hyper-V Gateway) &rarr; `[ DOWN ]` (100% loss):**
   In WSL2, the default gateway points to the Windows Hyper-V virtual network adapter. Windows Defender Firewall drops incoming ICMP Echo Requests by default, while allowing TCP/UDP WAN forwarding. This represents a real-world scenario where a server route is active but drops ICMP.
2. **`192.0.2.1` (RFC 5737 TEST-NET-1) &rarr; `[ DOWN ]` (100% loss):**
   The `192.0.2.0/24` block is reserved by the IETF for documentation and testing. Public routers drop traffic to this block without response, serving as an authoritative test to verify 100% loss detection and timeout bounding.
3. **Public Hosts & Loopback &rarr; `[ UP ]` (0% loss, live RTT):**
   `127.0.0.1` (~0.03ms), `9.9.9.9` (~5ms), `1.1.1.1` (~12ms), `google.com` (~24ms), `github.com` (~22ms), `8.8.8.8` (~28ms), `wikipedia.org` (~44ms).

---

## 5. Command-Line Usage & Options

`multi_server_check.sh` provides a comprehensive command-line interface:

```text
Usage: ./multi_server_check.sh [OPTIONS]

Multiple Server Health Check — Network Automation & Inventory Probing

OPTIONS:
  -f, --file <path>       Specify custom server inventory config (default: servers.txt)
  -c, --count <num>       Number of ICMP echo packets per target (default: 2)
  -w, -W, --timeout <sec> Probe timeout in seconds (default: 2s)
  -p, --parallel          Execute server probes concurrently in parallel (default)
  -s, --sequential        Execute server probes sequentially in serial order
  -l, --log <path>        Custom audit log destination (default: logs/multi_server_check.log)
  -q, --quiet             Quiet mode (suppress informative headers)
  -h, --help              Display this command manual and exit
```

### Common Command Examples:
```bash
# 1. Default parallel check across all servers
./multi_server_check.sh

# 2. Run in sequential serial mode
./multi_server_check.sh -s

# 3. Transmit 3 packets per target with 1-second timeout
./multi_server_check.sh -c 3 -w 1

# 4. Probe custom server inventory file
./multi_server_check.sh -f custom_inventory.txt

# 5. Display command-line manual
./multi_server_check.sh --help
```

---

## 6. Live Execution Verification

Below is an authentic sample run captured from the terminal during testing:

```text
================================================================================
           MULTIPLE SERVER HEALTH CHECK — NETWORK AUTOMATION MONITOR            
================================================================================
  Timestamp:     2026-09-29 23:57:17 IST
  Host System:   SP (Linux 6.18.33.2-microsoft-standard-WSL2)
  Config File:   /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_22/servers.txt (9 targets loaded)
  Parameters:    2 packets/host | 2s timeout | Mode: Parallel Concurrent (&)
--------------------------------------------------------------------------------

+---------------------------------------------------------------------------------------------------------+
| TARGET / HOST        | STATUS   | LOSS %   | AVG RTT    | PACKETS   | ROLE / DESCRIPTION               |
+---------------------------------------------------------------------------------------------------------+
| 192.168.32.1         | [ DOWN ] | 100%     | N/A        | 0/2       | Local Default Gateway (Hyper-V / |
| 127.0.0.1            | [  UP  ] | 0%       | 0.03ms     | 2/2       | Localhost Loopback Interface     |
| 8.8.8.8              | [  UP  ] | 0%       | 28.63ms    | 2/2       | Google Primary Public DNS        |
| 1.1.1.1              | [  UP  ] | 0%       | 12.31ms    | 2/2       | Cloudflare Primary Public DNS    |
| 9.9.9.9              | [  UP  ] | 0%       | 8.36ms     | 2/2       | Quad9 Threat-Blocking Secure DNS |
| google.com           | [  UP  ] | 0%       | 27.31ms    | 2/2       | Google Global Search Infrastruct |
| github.com           | [  UP  ] | 0%       | 24.84ms    | 2/2       | GitHub Version Control & Develop |
| wikipedia.org        | [  UP  ] | 0%       | 44.39ms    | 2/2       | Wikimedia Foundation Global CDN  |
| 192.0.2.1            | [ DOWN ] | 100%     | N/A        | 0/2       | RFC 5737 Test IP (Intentionally  |
+---------------------------------------------------------------------------------------------------------+

================================================================================
                             EXECUTION SUMMARY                                  
================================================================================
  Total Servers Checked   : 9
  Servers Reachable (UP)  : 7
  Servers Down (UNREACHABLE): 2
  Overall Availability    : 77.8%
  Total Probe Wall-Time   : 4 seconds
  Audit Log Target        : /mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_22/logs/multi_server_check.log
================================================================================
```

---

## 7. Deliverables & Project File Inventory

All artifacts are completely contained inside `AS_22/`:

```text
AS_22/
├── multi_server_check.sh     # Core network automation monitoring script
├── servers.txt               # Config inventory of real server targets and descriptions
├── run.sh                    # Unified cross-platform execution & report launcher
├── report.html               # Standalone dark-themed dashboard report (live data)
├── commands_used.md          # Chronological log of development commands
├── logs/
│   ├── multi_server_check.log # Append-only chronological audit log
│   └── .last_run.dat         # Machine-readable telemetry cache for report generation
└── README.md                 # Complete problem documentation & viva reference
```

---

## 8. Examination & Viva Voce Preparation

### Q1: How does `multi_server_check.sh` achieve parallel execution in pure Bash without external tools like GNU parallel?
**Answer:** The script leverages native Bash subshell backgrounding with the ampersand operator (`&`). In a loop over the target array, each call to `ping_single_host` is wrapped in parentheses `(...) &` and redirects its pipe-delimited output to a numbered slot file (`${TMP_DIR}/slot_${index}.dat`). After launching all background jobs, the script executes `wait`, which pauses parent execution until every subshell has completed. Finally, the parent iterates through the slot files from $0$ to $N-1$, ensuring that the table output is assembled in the exact order specified in `servers.txt`. A `trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM` guarantees that temporary files are purged even if interrupted.

### Q2: Why is `set -e` dangerous when using arithmetic evaluation like `(( COUNT++ ))`?
**Answer:** In Bash, post-increment arithmetic expressions evaluate to the *original* value of the variable before the increment. If `COUNT` starts at `0`, `(( COUNT++ ))` evaluates to `0`. In Bash arithmetic commands `(( expr ))`, an evaluation resulting in `0` returns an exit status of `1` (interpreted as "false" in arithmetic logic). When `set -e` (`errexit`) is enabled, any command returning a non-zero exit status immediately terminates the script! To prevent this subtle trap, safe assignment syntax should be used: `COUNT=$((COUNT + 1))`.

### Q3: How do `ping` timeout flags differ across Linux, macOS, and native Windows?
**Answer:**
- **Linux (`iputils`):** `ping -c <count> -W <timeout_seconds> <host>`. The `-W` flag specifies the deadline to wait for a response in integer seconds.
- **macOS (BSD `ping`):** `ping -c <count> -t <timeout_seconds> <host>`. The `-t` flag controls socket timeout; `-W` does not exist or behaves differently in BSD ping.
- **Windows Native (`cmd.exe` / Git Bash):** `ping -n <count> -w <timeout_milliseconds> <host>`. Windows ping uses `-n` for packet count and `-w` for timeout expressed in milliseconds ($2\text{s} = 2000\text{ms}$).

### Q4: How are comments and inline descriptions parsed in `servers.txt`?
**Answer:** The script processes `servers.txt` line by line using `while IFS= read -r raw_line || [ -n "${raw_line}" ]`. It trims carriage returns (`\r`), leading/trailing whitespace, and ignores lines starting with `#` or empty lines. If an inline comment delimiter `#` exists, `awk -F'#'` separates the first field as the target hostname/IP and subsequent text as the human-readable role/label. Furthermore, defensive regex checking ensures targets only contain valid hostname/IP characters (`[a-zA-Z0-9.:_-]`), rejecting malformed lines or shell metacharacters without crashing.

### Q5: Why does the WSL2 default gateway report 100% packet loss while Internet hosts report 0% loss?
**Answer:** In WSL2, the default gateway (`192.168.32.1`) is the virtual switch interface hosted on Windows. By default, Windows Defender Firewall blocks unsolicited incoming ICMP Echo Requests on virtual adapters to protect the host OS. However, the virtual switch forwards outbound TCP/UDP/ICMP packets from WSL2 to the physical network adapter. As a result, WAN hosts (`8.8.8.8`, `google.com`) respond normally, while the virtual gateway drops ICMP packets.
