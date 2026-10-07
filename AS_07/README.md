# Low Disk Space Alert — Automation Sprint (AS_07)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Storage Administration, Filesystem Capacity & Threshold Alerting  
**Problem Statement #07:** A server administrator wants to know if any file system has crossed 80% utilization. Write a script that displays the affected file systems and an appropriate warning.

---

## Command to Execute

```bash
cd AS_07 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_07\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_07/report.html
  ```
