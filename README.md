# LSA_AS — Linux System Administration (Automation Sprint)

Central repository for **Linux System Administration (E1ITA307)** Automation Sprint solutions and scripts.

---

## 📁 Repository Structure

```text
LSA_AS/
├── .gitignore
├── README.md
├── AS_14/                          # Automation Sprint Problem #14
│   ├── suspicious_ip_detector.sh   # Core bash script for IP detection
│   ├── commands_used.md            # Command log & viva preparation
│   ├── test_auth.log               # Synthetic test authentication log
│   ├── empty_auth.log              # Empty log edge-case test file
│   ├── reports/                    # Audit report logs
│   └── README.md                   # Problem documentation & usage
├── AS_15/                          # Automation Sprint Problem #15
│   ├── error_log_report.sh         # Core bash script for error log analysis
│   ├── commands_used.md            # Command log & viva preparation
│   ├── sample_syslog.log           # Synthetic test syslog
│   ├── clean_syslog.log            # Clean log edge-case test file
│   ├── empty_syslog.log            # Empty log edge-case test file
│   ├── reports/                    # Timestamped error reports
│   └── README.md                   # Problem documentation & usage
├── AS_16/                          # Automation Sprint Problem #16
│   ├── service_availability_check.sh # Core service monitoring & reporting script
│   ├── commands_used.md            # Command log & viva preparation
│   ├── report.html                 # Standalone dark-themed dashboard report
│   ├── logs/                       # Audit trail directory
│   └── README.md                   # Problem documentation & usage
└── (Upcoming Projects)/            # Future Automation Sprint additions
```

---

## 🚀 Projects Index

| Sprint / Problem | Title | Description | Status | Folder |
|---|---|---|---|---|
| **AS_14** | **Suspicious IP Detection** | Automated SSH brute-force monitor, regex parsing, descending frequency ranking, and timestamped audit reporting. | ✅ Completed | [`AS_14/`](./AS_14) |
| **AS_15** | **Error Log Report** | Automated error extraction with severity categorization, frequency ranking, distribution bars, and tail-style review. | ✅ Completed | [`AS_15/`](./AS_15) |
| **AS_16** | **Service Availability Check** | Real-time service monitoring, boot persistence verification, systemd/SysV fallback, audit logging, and dark-themed HTML report dashboard. | ✅ Completed | [`AS_16/`](./AS_16) |
| *Upcoming* | *Future Sprints* | Additional automation tasks and administration solutions. | ⏳ Planned | — |

---

## 🛠️ General Guidelines

- All scripts are self-contained within their respective project directories (`AS_XX/`).
- Scripts adhere to defensive bash standards (`set -euo pipefail`), proper validation, and clear exit codes.
- Refer to individual project folders for setup instructions, command logs, and sample outputs.
