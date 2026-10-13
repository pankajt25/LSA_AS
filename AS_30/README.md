# Logged-in User Report — Automation Sprint (AS_30)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** User Monitoring, Terminal Inspection & Session Auditing  
**Problem Statement #30:** Sysadmins need to know who is currently using the system. Write a script that checks and displays: all currently logged-in users, terminal (tty/pts) they are using, login time, remote host/IP (if logged in remotely), idle time.

---

## Command to Execute

```bash
cd AS_30 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_30\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_30/report.html
  ```
