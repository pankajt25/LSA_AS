# Commands Used — High CPU Process Detection (AS_19)

The following list documents every command executed during the development, testing, verification, and artifact generation of Problem Statement #19:

1. `pwd && ls -la && ls -la ..` — Inspected initial project directory and repository hierarchy to confirm sandboxed workspace.
2. `ls -la ../AS_18` — Inspected existing sprint artifacts to align architectural patterns and style conventions.
3. `ls -la ../AS_14 ../AS_15 ../AS_16 ../AS_17` — Inspected sibling sprint directories to verify overall repo conventions.
4. `git remote -v` — Verified git remote repository URL (`https://github.com/pankajt25/LSA_AS.git`).
5. `git log -n 5 --oneline` — Checked recent commit history and branching structure.
6. `ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | head -n 10` — Tested live Linux `ps` query syntax, column formatting, and descending CPU sort.
7. `grep -qi microsoft /proc/version` — Verified runtime host OS environment (confirmed WSL2 Linux kernel).
8. `wslpath -w "$PWD/report.html"` — Validated WSL-to-Windows path translation for automated browser dispatch.
9. `mkdir -p logs` — Created the sandboxed audit log directory inside `AS_19/`.
10. `chmod +x high_cpu_detector.sh` — Granted execute permissions to the core CPU detection script.
11. `./high_cpu_detector.sh` — Executed baseline detection test with default parameters (top 5, 50.0% threshold).
12. `cat logs/high_cpu.log` — Verified structured, timestamped audit log generation across runs.
13. `./high_cpu_detector.sh -n 3 -t 20.0` — Tested CLI argument parsing for custom display count and alert threshold.
14. `./high_cpu_detector.sh -n invalid` — Verified defensive input validation and argument error trapping (exit code 2).
15. `./high_cpu_detector.sh --help` — Tested CLI manual and usage documentation banner.
16. `python3 --version` — Verified Python 3 environment for robust HTML dashboard generation.
17. `chmod +x run.sh` — Granted execute permissions to the unified cross-platform launcher.
18. `bash run.sh` — Executed end-to-end workflow: runs detector, captures live output, regenerates `report.html`, and launches browser.
19. `explorer.exe "$(wslpath -w "$PWD/report.html")"` — Probed Windows Explorer invocation and browser dispatch behavior.
20. `view_file report.html` — Inspected generated dark-themed HTML report dashboard for data accuracy and styling.
