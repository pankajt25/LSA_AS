# Old Backup Cleanup — Automation Sprint (AS_12)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Backup Management, Storage Hygiene & Retention Lifecycle Policies  
**Problem Statement #12:** Backups accumulate over time and consume disk space. Write a script that retains recent backups and deletes backups older than N days.

---

## Command to Execute

```bash
cd AS_12 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_12\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_12/report.html
  ```
