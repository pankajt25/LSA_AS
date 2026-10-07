# Scheduled Linux System Health Report via Cron — Automation Sprint (AS_38)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** System Telemetry Monitoring, Periodic Reporting & Cron Automation  
**Problem Statement #38:** Configure a Cron job to periodically generate a Linux system health report.

---

## Command to Execute

```bash
cd AS_38 && bash run.sh
bash cleanup.sh
```

---

## Viewing the HTML Report

If your environment is headless or the browser does not open automatically, view the generated dashboard manually:

- **Windows Subsystem for Linux (WSL):**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows Path:**
  ```text
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_38\report.html
  ```
- **Native Linux Desktop:**
  ```bash
  xdg-open report.html
  ```
- **macOS:**
  ```bash
  open report.html
  ```
- **Windows Git Bash:**
  ```bash
  start report.html
  ```
- **Direct Browser URL:**
  ```text
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_38\report.html
  ```
