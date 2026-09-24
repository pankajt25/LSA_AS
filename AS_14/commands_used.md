# Commands Used During Development & Testing (Viva Prep Log)
**Course:** Linux System Administration (E1ITA307) — Automation Sprint  
**Problem #14:** Suspicious IP Detection (Security Monitoring)  
**Deliverable:** Viva preparation command log with plain-English explanations.

---

| # | Command Executed | Plain-English Explanation |
|---|---|---|
| 1 | `mkdir -p ~/sprint-sandbox/reports` | Creates the sandboxed project workspace and subfolder for persistent security reports. |
| 2 | `cat << 'EOF' > ~/sprint-sandbox/test_auth.log ... EOF` | Generates synthetic authentication log entries simulating brute-force attacks and legitimate SSH sessions without touching real system logs. |
| 3 | `grep -E "sshd.*Failed password" ~/sprint-sandbox/test_auth.log` | Verifies regular expression filtering to isolate only failed SSH password attempts while ignoring cron and accepted sessions. |
| 4 | `grep -oP 'from \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'` | Uses Perl-Compatible Regular Expressions (PCRE) with `\K` lookbehind discard to accurately extract IP addresses without hardcoding column numbers. |
| 5 | `sort | uniq -c | sort -nr` | Sorts IP addresses to group duplicates, counts occurrences per IP, and sorts results numerically in descending order (highest offenders first). |
| 6 | `grep -F "203.0.113.45" ~/sprint-sandbox/test_auth.log \| grep "Failed password" \| head -n1` | Filters log entries for a specific IP and grabs the first failed line to determine the first-seen timestamp. |
| 7 | `grep -F "203.0.113.45" ~/sprint-sandbox/test_auth.log \| grep "Failed password" \| tail -n1` | Filters log entries for a specific IP and grabs the final failed line to determine the last-seen timestamp. |
| 8 | `chmod +x ~/sprint-sandbox/suspicious_ip_detector.sh` | Grants execute permissions to the script so it can be run directly from the command line. |
| 9 | `~/sprint-sandbox/suspicious_ip_detector.sh` | Runs the detector script with default arguments (`~/sprint-sandbox/test_auth.log`, threshold 5). |
| 10 | `cat ~/sprint-sandbox/reports/suspicious_ip_report_<timestamp>.log` | Inspects the structured report file generated inside the sandbox to verify output formatting and audit trail. |
| 11 | `~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/test_auth.log 2` | Runs the detector with a custom lower threshold (2) to verify that both aggressive and low-volume attacker IPs are flagged. |
| 12 | `~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/test_auth.log 10` | Runs the detector with a high threshold (10) to verify graceful fallback handling when no IP exceeds the threshold ("No threats detected"). |
| 13 | `~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/non_existent.log` | Validates that non-existent log paths trigger an informative error message and a non-zero exit code. |
| 14 | `touch ~/sprint-sandbox/empty_auth.log && ~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/empty_auth.log` | Validates that empty log files are handled gracefully with a warning rather than failing silently or crashing. |
| 15 | `~/sprint-sandbox/suspicious_ip_detector.sh ~/sprint-sandbox/test_auth.log abc` | Validates threshold input sanitization, rejecting non-integer values with an error message and exit code 1. |
| 16 | `~/sprint-sandbox/suspicious_ip_detector.sh --help` | Tests the help flag (`-h` / `--help`) to verify clear usage instructions and syntax display. |
| 17 | `ls -la /var/log/auth.log /var/log/secure` | Inspects real system authentication logs on the host to determine the active auth log source. |
| 18 | `./suspicious_ip_detector.sh` | Executes detector with auto-detection; dynamically selects `/var/log/auth.log` and verifies clean status. |
| 19 | `./suspicious_ip_detector.sh ./test_auth.log 5` | Executes detector with explicit override against synthetic test data labeled as demonstration fallback. |

---

### Core Pipeline Breakdown for Viva / Evaluation

The primary data processing pipeline in `suspicious_ip_detector.sh` is:
```bash
echo "${failed_lines}" | grep -oP 'from \K([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr
```
- **`failed_lines`**: Pre-filtered using `grep -E 'sshd.*Failed password'` to isolate failed attempts.
- **`grep -oP`**: `-o` prints only matching parts; `-P` activates Perl-Compatible Regex.
- **`from \K`**: Matches literal `"from "` and drops it from the match via `\K` (keep-out / lookbehind equivalent).
- **`([0-9]{1,3}\.){3}[0-9]{1,3}`**: Standard regex for IPv4 address octets, eliminating fragility from column shifting (e.g. `invalid user` vs standard username).
- **`sort`**: Required prerequisite for `uniq` so that identical IP occurrences are adjacent.
- **`uniq -c`**: Counts occurrences of each unique IP address and prefixes the count.
- **`sort -nr`**: Sorts numerically (`-n`) and reversed (`-r`) to surface top attackers first.
