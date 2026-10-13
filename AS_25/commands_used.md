# Development Commands Log — AS_25 (Port Availability Check)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Network Testing & TCP Socket Reachability Probing  
**Author:** Individual Timed Sprint  

Every command executed during the discovery, testing, implementation, validation, error handling, and verification of **AS_25** is recorded below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment
- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint hierarchy.
- `git status && git remote -v` — Checked git working tree status and confirmed remote origin URL (`https://github.com/pankajt25/LSA_AS.git`).
- `ls -la ../AS_24` — Inspected previous sprint folder structure, documentation, and reporting deliverables.
- `tail -n 60 ../README.md` — Inspected main repository README format and documentation conventions for sprint deep dives.
- `grep -n -C 5 "AS_24" ../README.md` — Verified index table and dropdown details structure in root README.
- `uname -a && cat /proc/version` — Identified host Linux kernel (`6.18.33.2-microsoft-standard-WSL2`), architecture (`x86_64`), and WSL2 platform.
- `which wslpath && which explorer.exe` — Verified availability of WSL path translation and Windows host browser launcher binaries.
- `python3 --version` — Confirmed Python 3.14.4 availability for standalone HTML dashboard generation.

---

## 2. Network Probing Capabilities & Protocol Prototyping
- `bash -c 'echo > /dev/tcp/google.com/443' && echo "google.com:443 SUCCESS"` — Validated GNU Bash `/dev/tcp` virtual network redirection capability against remote live HTTPS service.
- `timeout 2 bash -c 'echo > /dev/tcp/localhost/22' 2>&1 || echo "Exit code: $?"` — Tested local closed port behavior with `/dev/tcp`, observing exit code 1 (`Connection refused`).
- `timeout 3 bash -c 'echo > /dev/tcp/google.com/12345' 2>&1 || echo "Exit code: $?"` — Verified timeout behavior on unassigned/filtered remote port, observing exit code 124 from `timeout`.
- `timeout 3 bash -c 'echo > /dev/tcp/invalid-nonexistent-domain-xyz123.test/80' 2>&1 || echo "Exit code: $?"` — Evaluated `/dev/tcp` error output on unresolvable DNS hostnames (`Name or service not known`).
- `getent hosts google.com && getent hosts localhost && (getent hosts nonexistent-host-xyz.test || echo "getent failed")` — Evaluated glibc resolver query behavior across valid hosts and unresolvable domains.
- `which nc netcat` — Verified OpenBSD netcat binary availability for resilient probe fallback.
- `nc -h 2>&1 | head -n 5` — Checked netcat version, syntax, and supported flags (`-z` zero-I/O, `-v` verbose, `-w` timeout).
- `nc -zv -w3 google.com 443 2>&1` — Tested live reachability probing using Netcat zero-I/O mode.
- `ss -tln || netstat -tln` — Inspected local listening TCP sockets to confirm local open vs closed ports on localhost.
- `date +%s%N` — Tested nanosecond timestamp resolution for sub-millisecond round-trip network latency measurement.
- `bash -c '...'` — Prototyped `/dev/tcp` probe latency measurement, exit code classification, and error parsing.
- `getent services 22/tcp && getent services 443/tcp && getent services 80/tcp` — Tested IANA service name resolution from `/etc/services` via `getent services`.
- `head -n 50 ../AS_24/report.html` — Inspected dark-themed CSS variables, layout, and visual styling.
- `head -n 60 ../AS_24/run.sh && tail -n 80 ../AS_24/run.sh` — Inspected cross-platform browser launch logic and report generation workflow.

---

## 3. Script Development, Verification & Error Handling
- `chmod +x port_check.sh && ./port_check.sh --help` — Granted execution permissions and verified CLI manual display and option parsing.
- `./port_check.sh google.com` — Tested missing port argument error handling, confirming clear error message and usage display.
- `./port_check.sh localhost 99999` — Tested out-of-range port validation, confirming clean rejection with exit code 1.
- `./port_check.sh localhost abc` — Tested non-numeric port validation, confirming clean rejection with exit code 1.
- `./port_check.sh unresolvable-fake-host-999.invalid 80` — Tested unresolvable hostname rejection, confirming clear DNS error message and exit code 2.
- `./port_check.sh localhost 22` — Tested live local closed/refused port detection, confirming active TCP RST detection.
- `./port_check.sh google.com 443` — Tested live remote open port reachability, confirming TCP 3-way handshake completion.
- `./port_check.sh google.com 12345` — Tested live remote filtered/timed-out port detection, confirming 3-second timeout classification.
- `./port_check.sh google.com 80,443,12345` — Tested multi-port comma-separated loop auditing across mixed states (open and timed-out).
- `./port_check.sh --nc google.com 443` — Tested explicit Netcat fallback probe pathway.
- `./port_check.sh` — Executed default safe demo suite covering all demo cases (localhost:22, google.com:443, google.com:12345, and multi-port loop).
- `tail -n 10 logs/port_check.log && cat logs/port_check.json` — Inspected chronological audit log file and structured JSON telemetry schema.
- `chmod +x run.sh && ./run.sh` — Ran full end-to-end launcher to audit ports, regenerate `report.html`, and dispatch browser via `explorer.exe`.
- `head -n 40 report.html && tail -n 40 report.html` — Inspected regenerated HTML structure, inline CSS, and live metadata.
- `grep -A 25 '<div class="port-card"' report.html | head -n 30` — Verified color-coded status cards markup and live telemetry values.
