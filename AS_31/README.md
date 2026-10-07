# User Login Audit — Automation Sprint (AS_31)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Security Auditing, Session Inspection & Authentication Tracking  
**Problem Statement #31:** Develop a script that generates a report of recent user login activities from the system.

---

## Command to Execute

```bash
cd AS_31 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_31\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_31/report.html
  ```
