# Server Health Check — Automation Sprint (AS_06)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** System Monitoring, Performance Metrics & Host Telemetry  
**Problem Statement #06:** Before starting the workday, an administrator wants a quick report showing CPU, memory, disk usage, uptime, and logged-in users. Create a Bash health-check script.

---

## Command to Execute

```bash
cd AS_06 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_06\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_06/report.html
  ```
