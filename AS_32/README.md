# File Modification Monitor — Automation Sprint (AS_32)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Filesystem Monitoring, Inode Timestamp Analysis & Change Auditing  
**Problem Statement #32:** A project directory contains important files. Write a script to identify files modified within the last 24 hours.

---

## Command to Execute

```bash
cd AS_32 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_32\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_32/report.html
  ```
