# Commands Used — High Memory Process Detection (AS_20)

The following list documents every command executed during the development, testing, verification, and artifact generation of Problem Statement #20:

1. `pwd && ls -la && ls -la ..` — Inspected initial project directory and repository hierarchy to confirm sandboxed workspace.
2. `git remote -v && git status` — Verified git remote repository URL (`https://github.com/pankajt25/LSA_AS.git`) and checked working tree status.
3. `ls -la AS_19/` — Inspected sibling sprint artifacts to align architectural patterns and style conventions.
4. `view_file AS_19/high_cpu_detector.sh` — Reviewed previous detector implementation for coding standards and defensive design.
5. `view_file AS_19/run.sh` — Reviewed unified cross-platform launcher patterns and browser dispatch logic.
6. `view_file README.md` — Inspected root repository README for index table formatting and deep dive dropdowns.
7. `uname -a && cat /proc/version && free -h && ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem | head -n 10` — Tested live system telemetry, kernel version, memory statistics (`free -h`), and GNU `ps` sorting by `%mem`.
8. `ps -eo pid,ppid,user,%mem,%cpu,rss,comm --sort=-%mem | head -n 6 | awk '...'` — Validated field extraction, floating-point parsing, and RSS conversion from KB to MB via `awk`.
9. `free -h` — Checked exact memory and swap output formats for terminal summary and HTML metric card parsing.
10. `write_to_file high_memory_detector.sh` — Created the core high memory detection script with full comments, RSS conversion, threshold checking, and audit logging.
11. `chmod +x high_memory_detector.sh && ./high_memory_detector.sh` — Executed baseline detection test with default parameters (top 5, 30.0% threshold).
12. `./high_memory_detector.sh -n 3 -t 5.0` — Tested CLI argument parsing for custom display count and sensitive alert threshold triggering.
13. `./high_memory_detector.sh -n invalid` — Verified defensive input validation and argument error trapping (exit code 2).
14. `./high_memory_detector.sh --help` — Tested CLI manual and usage documentation banner.
15. `view_file logs/high_memory.log` — Verified structured, timestamped audit log generation and history accumulation across runs.
16. `python3 --version` — Verified Python 3 environment for robust HTML dashboard generation and HTML entity escaping.
17. `python3 - << 'EOF' ...` — Tested Python subprocess querying of `ps` and `free` commands.
18. `write_to_file run.sh` — Created the single cross-platform execute + report launcher script.
19. `chmod +x run.sh && bash run.sh` — Executed end-to-end workflow: runs detector, captures live output, regenerates `report.html`, and launches browser.
20. `bash run.sh -n 3 -t 5.0` — Verified passing of CLI flags through `run.sh` into `high_memory_detector.sh` and HTML regeneration.
21. `bash run.sh` — Generated fresh default baseline live dashboard report (`report.html`).
22. `view_file report.html` — Inspected generated dark-themed HTML report dashboard for data accuracy, CSS styling, and live metrics.
23. `git add AS_20` — Staged all AS_20 sprint deliverables to git tracking.
24. `git commit -m "AS_20: High Memory Process Detection - script, run.sh, live HTML report, docs"` — Committed AS_20 deliverables.
25. `git push -u origin main` — Pushed AS_20 deliverables to remote GitHub repository.
26. `git add README.md` — Staged updated root README with AS_20 index entry, cross-platform commands, and deep-dive dropdown.
27. `git commit -m "Update README: add AS_20 to index and dropdown details"` — Committed root README updates.
28. `git push` — Pushed root documentation updates to remote GitHub repository.

