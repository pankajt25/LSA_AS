# Commands Used — Multiple Server Check (AS_22)

The following list documents every command executed during the development, testing, verification, and artifact generation of Problem Statement #22:

1. `pwd && ls -la` — Inspected initial project directory to confirm isolated sandboxed workspace inside `AS_22/`.
2. `ls -la ..` — Examined repository root hierarchy, git status, and completed sprint directories (AS_14 through AS_21).
3. `ls -la ../AS_21` — Inspected AS_21 files and project deliverable structure.
4. `git status && git remote -v` — Checked working tree status and confirmed remote origin URL (`https://github.com/pankajt25/LSA_AS.git`).
5. `git log -n 5 --oneline` — Examined commit history and commit message conventions across previous automation sprints.
6. `git show --stat f990e87` — Reviewed changes and file counts committed for AS_21.
7. `view_file ../AS_21/commands_used.md` — Inspected documentation format and command log layout in AS_21.
8. `tail -n 60 ../README.md` — Examined root README index table, quick commands table, and Sprint Deep Dives formatting.
9. `grep -n -C 5 "AS_21" ../README.md` — Located exact markdown anchor locations for AS_21 in root README.
10. `ip route` — Inspected kernel routing table to discover live default gateway (`192.168.32.1 dev eth0`) and subnet mask.
11. `ping -c 2 -W 2 192.168.32.1 && ...` — Tested ICMP behavior against local gateway, confirming Hyper-V virtual switch ICMP drop behavior in WSL2.
12. `ping -c 2 -W 2 8.8.8.8 && ping -c 2 -W 2 1.1.1.1 && ping -c 2 -W 2 google.com` — Validated public WAN reachability, latency, and packet loss metrics across Anycast DNS and cloud services.
13. `ping -c 2 -W 1 127.0.0.1` — Verified local loopback reachability, zero packet loss, and sub-millisecond round-trip time.
14. `ping -c 2 -W 1 192.0.2.1 || true` — Tested RFC 5737 TEST-NET-1 reserved unroutable IP to verify 100% loss trapping and timeout responsiveness.
15. `view_file ../AS_21/connectivity_check.sh` — Reviewed cross-platform gateway auto-detection and ping output parsing regex patterns.
16. `ping -c 2 -W 2 9.9.9.9 && ping -c 2 -W 2 github.com && ping -c 2 -W 2 wikipedia.org` — Verified candidate servers for inventory mix.
17. `bash -c 'targets=(...); for t in "${targets[@]}"; do ping -c 2 -W 2 "$t"; done'` — Executed sequential benchmark loop across candidate hosts.
18. `bash -c 'time { tmpdir=$(mktemp -d); ... wait; }'` — Benchmarked parallel subshell execution with `&` and `wait`, confirming ~3-second completion across all targets.
19. `write_to_file servers.txt` — Created server inventory configuration with gateway, loopback, public DNS, cloud hosts, and RFC 5737 benchmark target.
20. `write_to_file multi_server_check.sh` — Created core multi-server health check script with parallel/sequential probing, regex parsing, and formatted table output.
21. `chmod +x multi_server_check.sh && ./multi_server_check.sh` — Executed initial script run, detecting bash `set -e` arithmetic post-increment exit trap.
22. `bash -x ./multi_server_check.sh` — Traced subshell execution to isolate `(( LINE_NUMBER++ ))` returning exit status 1 when incrementing from zero.
23. `replace_file_content multi_server_check.sh` — Replaced post-increments with safe arithmetic assignments (`LINE_NUMBER=$((LINE_NUMBER + 1))`, `COUNT_UP`, `COUNT_DOWN`).
24. `./multi_server_check.sh` — Executed parallel check successfully, validating table rendering, column alignment, and live metrics.
25. `./multi_server_check.sh -s` — Executed sequential mode benchmark, confirming 16-second total execution time.
26. `view_file logs/multi_server_check.log` — Verified structured, timestamped audit log generation and history accumulation across runs.
27. `./multi_server_check.sh -f nonexistent_file.txt || true` — Tested missing configuration file error trapping (clean message, exit code 1).
28. `bash -c 'touch empty_test.txt; ./multi_server_check.sh -f empty_test.txt'` — Tested empty configuration file error trapping (clean message, exit code 1).
29. `bash -c 'cat << "EOF" > test_malformed.txt ...'` — Validated malformed entry skipping, command injection defense, and DNS resolution error handling.
30. `replace_file_content multi_server_check.sh` — Refined table header format string (`LOSS %`) and expanded description column width to 32 characters.
31. `replace_file_content multi_server_check.sh` — Added machine-readable `logs/.last_run.dat` generation for seamless dashboard synchronization.
32. `./multi_server_check.sh && cat logs/.last_run.dat` — Validated structured `.last_run.dat` metadata and server records.
33. `write_to_file run.sh` — Created single cross-platform launcher script with live telemetry extraction, HTML dashboard generation, and browser launch.
34. `chmod +x run.sh && bash run.sh` — Diagnosed JavaScript curly brace escaping requirement inside Python heredoc f-string.
35. `replace_file_content run.sh` — Escaped curly braces in client-side interactive table filter script block.
36. `bash run.sh` — Executed complete workflow end-to-end: parallel check, HTML dashboard regeneration, and browser dispatch.
37. `head -n 50 report.html && tail -n 50 report.html` — Verified generated dark-themed HTML report structure, metadata, and styling.
38. `write_to_file commands_used.md` — Documented all commands executed during development, verification, and artifact generation.
39. `write_to_file README.md` — Authored comprehensive project documentation with required execution commands, architecture analysis, and viva reference.
40. `git add . && git commit -m "..." && git push -u origin main` — Staged, committed, and pushed AS_22 sprint deliverables to GitHub repository.
41. `git add README.md && git commit -m "..." && git push` — Updated and pushed root README index table and Sprint Deep Dives dropdown details.
