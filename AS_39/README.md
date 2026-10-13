# Disk Space and Inode Utilization Audit — Automation Sprint (AS_39)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Storage Capacity Monitoring, Inode Exhaustion Detection & Threshold Alerting  
**Problem Statement #39:** Develop a script that checks both disk-space and inode utilization and reports file systems exceeding a specified threshold.

---

## Command to Execute

```bash
cd AS_39 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_39\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_39\report.html
  ```
