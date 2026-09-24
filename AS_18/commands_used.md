# Commands Used — Server Process Check (AS_18)

The following list documents every command executed during the development, testing, verification, and artifact generation of Problem Statement #18:

1. `pwd && ls -la && ls -la ..` — Inspected initial project directory and repository hierarchy to confirm sandboxed workspace.
2. `ls -la ../AS_17` — Inspected existing sprint artifacts to align architectural patterns and style conventions.
3. `pgrep -l bash` — Tested baseline `pgrep` listing behavior and verified running bash instances.
4. `ps -o etime= -p 365` — Tested retrieval of elapsed execution time for a target PID.
5. `pgrep -o -f bash` — Tested retrieval of the oldest matching process PID via the `-o` flag.
6. `pgrep -f "foo[bar"` — Probed `pgrep` exit code and syntax error behavior when unescaped regex metacharacters are passed.
7. `printf '%s' "$input" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g'` — Verified robust sed-based regex metacharacter escaping to prevent regex crashes.
8. `cat /proc/$$/cmdline` — Checked process command-line inspection behavior and designed defensive filtering against script self-matching.
9. `ps -o pid=,etimes=,etime= -p "$PID_LIST" | sort -k2,2rn | head -n1` — Tested numerical sorting by elapsed seconds (`etimes`) to accurately isolate the oldest instance.
10. `mkdir -p logs` — Created the sandboxed audit log directory inside `AS_18/`.
11. `chmod +x server_process_check.sh` — Granted execute permissions to the process check Bash script.
12. `./server_process_check.sh bash` — Executed Test Case 1: verified running process detection, PID listing, and uptime reporting.
13. `./server_process_check.sh not-a-real-process-xyz` — Executed Test Case 2: verified clean detection of nonexistent processes and exit code 1.
14. `./server_process_check.sh` — Executed Test Case 3: verified usage and argument validation error trapping with exit code 2.
15. `./server_process_check.sh -s bash` — Tested strict mode with an exact lowercase match (exited 0).
16. `./server_process_check.sh -s BASH` — Tested strict mode case sensitivity where uppercase does not match lowercase (exited 1).
17. `./server_process_check.sh BASH` — Tested default case-insensitive mode where uppercase matches lowercase (exited 0).
18. `./server_process_check.sh "nonexistent[app]+test*"` — Tested regex metacharacter escaping to ensure `pgrep` handles special characters safely.
19. `./server_process_check.sh --default` — Tested `--default` flag using safe fallback process (`bash`).
20. `cat logs/process_check.log` — Verified structured, timestamped audit log generation across all test scenarios.
21. `wslpath -w report.html` — Converted the WSL report path to its Windows equivalent for browser viewing.
