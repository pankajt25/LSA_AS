# Commands Used — Network Connectivity Check (AS_21)

The following list documents every command executed during the development, testing, verification, and artifact generation of Problem Statement #21:

1. `pwd && ls -la && ls -la ..` — Inspected initial project directory and repository hierarchy to confirm sandboxed workspace.
2. `git remote -v && git status` — Verified git remote repository URL (`https://github.com/pankajt25/LSA_AS.git`) and checked working tree status.
3. `git log -n 5` — Checked recent commit history across previous automation sprint deliverables (AS_14 through AS_20).
4. `ls -la ../AS_20` — Inspected AS_20 folder structure and deliverables.
5. `git show --stat 4dc677ff` — Examined commit statistics and formatting standards of AS_20.
6. `view_file ../AS_20/commands_used.md` — Reviewed command log structure and viva prep reference format.
7. `view_file ../AS_20/README.md` — Reviewed markdown structure, architectural tables, and section headings.
8. `view_file ../README.md` — Inspected root README index table and Sprint Deep Dives formatting.
9. `uname -a && cat /proc/version && which ping` — Queried system kernel version, OS release, and verified ping executable path.
10. `ip route` — Inspected live routing table to discover default route and egress network interface (`eth0`).
11. `ping -c 4 192.168.32.1` — Tested live ICMP echo behavior against the machine's real default gateway (`192.168.32.1`).
12. `ping -c 4 -W 2 8.8.8.8` — Tested ICMP echo response against sanity baseline host (`8.8.8.8`) to verify external WAN connectivity.
13. `ping -V` — Verified `iputils` version and compiled feature set (`iputils 20250605`).
14. `ping -c 4 -W 1 192.168.32.1` — Tested timeout responsiveness with `-W 1` to prevent unbounded hanging.
15. `bash -c '...'` — Validated grep and awk parsing pipelines for packet loss percentage and average RTT extraction.
16. `ping -c 4 invalid.hostname.xyz.noway 2>&1 || true` — Tested unresolvable hostname edge case to verify DNS error detection.
17. `bash -c 'detect_gateway() ...'` — Tested cross-platform gateway auto-detection functions across Linux, macOS, and Windows.
18. `ip addr && cat /etc/resolv.conf` — Queried local IP assignments, loopback aliases, and active DNS nameservers.
19. `ping -c 2 -W 1 10.255.255.254` — Tested ICMP reachability to the local WSL2 DNS resolver.
20. `write_to_file connectivity_check.sh` — Created the core network monitoring and gateway reachability script with full comments.
21. `chmod +x connectivity_check.sh && ./connectivity_check.sh` — Tested baseline execution with default gateway auto-detection.
22. `./connectivity_check.sh 1.1.1.1` — Tested custom target argument passing and dual-reachable status handling.
23. `./connectivity_check.sh fake.domain.test.invalid.nonexistent` — Tested defensive DNS resolution error trapping and reporting.
24. `view_file logs/connectivity.log` — Verified structured, timestamped audit log generation and history accumulation across runs.
25. `replace_file_content connectivity_check.sh` — Refined diagnostic triangulation logic to specifically identify DNS resolution errors.
26. `./connectivity_check.sh fake.domain.test.invalid.nonexistent` — Verified updated DNS diagnostic message.
27. `write_to_file run.sh` — Created the single cross-platform execute + report launcher script.
28. `chmod +x run.sh && bash run.sh` — Tested automated script execution, HTML report regeneration, and browser dispatch.
29. `bash run.sh 1.1.1.1` — Tested argument passthrough through `run.sh` into `connectivity_check.sh`.
30. `bash run.sh` — Generated final baseline live dashboard report (`report.html`).
31. `view_file report.html` — Inspected generated dark-themed HTML report dashboard for data accuracy, CSS styling, and live metrics.
32. `git add AS_21` — Staged all AS_21 sprint deliverables to git tracking.
33. `git commit -m "AS_21: Network Connectivity Check - script, run.sh, live HTML report, docs"` — Committed AS_21 deliverables.
34. `git push -u origin main` — Pushed AS_21 deliverables to remote GitHub repository.
35. `git add README.md` — Staged updated root README with AS_21 index entry, cross-platform commands, and deep-dive dropdown.
36. `git commit -m "Update README: add AS_21 to index and dropdown details"` — Committed root README updates.
37. `git push` — Pushed root documentation updates to remote GitHub repository.
