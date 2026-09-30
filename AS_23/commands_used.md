# Development Commands Log — AS_23 (IP Configuration Report)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Network Administration & Live Host IP Configuration Audit  
**Author:** Individual Timed Sprint  

Every command executed during the development, debugging, validation, and testing of **AS_23** is recorded below with a concise one-line explanation.

---

## 1. Environment Discovery & Workspace Assessment
- `pwd && ls -la && ls -la ..` — Inspected workspace structure, working directory location, and parent automation sprint hierarchy.
- `git -C .. status && git -C .. remote -v` — Checked git working tree status, branch state, and remote repository URLs in parent directory.
- `ls -la ../AS_22/.git 2>/dev/null || echo "No .git in AS_22"` — Verified repository architecture and confirmed subfolders do not contain isolated `.git` repositories.
- `git -C .. log -n 5 --oneline` — Reviewed git commit history and formatting conventions from prior automation sprints.
- `uname -a && cat /etc/os-release` — Identified host operating system (Ubuntu 26.04.1 LTS on WSL2), Linux kernel release (6.18.33.2), and CPU architecture (x86_64).
- `which ip hostname ifconfig route awk sed grep python3` — Audited availability of modern `iproute2` tools vs legacy `net-tools` and scripting runtimes.

---

## 2. Host Network Configuration Probing & Validation
- `hostname && hostname -I && ip -br addr show up && ip addr show && ip route && cat /etc/resolv.conf` — Queried raw live network parameters: hostname, all assigned IPs, active interfaces, routing table, and DNS nameservers.
- `ip -br addr show up && echo "---" && ip -br link show && echo "---" && ip route | grep default` — Tested modern `iproute2` brief output syntax (`-br`) for active interfaces and default gateway routing rules.
- `cat /sys/class/net/eth0/mtu && cat /sys/class/net/eth0/address` — Validated kernel sysfs fallback paths for MTU and MAC hardware address extraction.
- `ip -br link show eth0 && ip -br link show lo` — Tested brief link information extraction on physical and loopback network adapters.
- `ip link show eth0 && ip link show lo` — Inspected detailed link layer flags (`UP`, `LOWER_UP`), MTU, and queue disciplines across interfaces.
- `ip link show eth0 | awk '/link\// {print $2}' && ip link show lo | awk '/link\// {print $2}'` — Validated awk parsing for MAC hardware address extraction across link types.
- `ip link show eth0 | awk '{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}'` — Verified token-based POSIX awk parsing for payload MTU extraction on Ethernet adapter.
- `ip link show lo | awk '{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}'` — Verified MTU token extraction on loopback interface (65536 bytes).
- `ip route | awk '/^default / {for(i=1;i<=NF;i++) if($i=="via") gw=$(i+1); for(i=1;i<=NF;i++) if($i=="dev") dev=$(i+1); print "GW=" gw " DEV=" dev}'` — Tested token parsing to isolate default gateway IP and egress interface from kernel routing table.
- `grep -E '^\s*nameserver\b' /etc/resolv.conf | awk '{print $2}'` — Extracted active DNS nameservers from `/etc/resolv.conf`.
- `command -v resolvectl 2>/dev/null || echo "No resolvectl"` — Checked for systemd-resolved CLI utility presence.
- `resolvectl dns 2>/dev/null || true` — Tested resolvectl DNS output for supplemental resolver discovery.
- `ip -j addr show up && ip -j route show default` — Verified JSON serialization capabilities of modern `iproute2` on Linux.

---

## 3. Script Development, Execution & Verification
- `mkdir -p reports` — Created the dedicated reports output directory for timestamped run logs.
- `chmod +x ip_config_report.sh && ./ip_config_report.sh` — Granted execution permissions and executed the core IP configuration reporting utility.
- `python3 -c "import json; d = json.load(open('reports/.last_report.json')); print('Parsed successfully! Interfaces count:', len(d['interfaces']))"` — Validated syntax and field structure of generated JSON telemetry file.
- `ls -la reports/` — Inspected generated timestamped plain-text report files and validated pointer file `latest_ip_report.txt`.
- `chmod +x run.sh && bash run.sh` — Granted execution permissions and ran the single cross-platform workflow to regenerate `report.html` and launch browser.
- `bash run.sh` — Ran full end-to-end verification, confirming live telemetry capture, clean table formatting, and dashboard dispatch via `explorer.exe`.

---

## 4. Version Control & Upstream Deployment
- `git add AS_23/` — Staged all automation scripts, telemetry generators, HTML report, and documentation.
- `git commit -m "AS_23: IP Configuration Report - script, run.sh, live HTML report, docs"` — Committed AS_23 deliverables with structured conventional message.
- `git push origin main` — Pushed AS_23 deliverable commit to GitHub remote repository.
- `git add README.md` — Staged updated root navigation index and AS_23 sprint deep dive.
- `git commit -m "Update README: add AS_23 to index and dropdown details"` — Committed root README updates.
- `git push` — Pushed final root README index update to remote repository.
