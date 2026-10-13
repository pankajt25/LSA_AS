# Permission Audit — Automation Sprint (AS_04)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Security Auditing, File Permissions & Least-Privilege Verification  
**Problem Statement #04:** A company security administrator wants to identify all world-writable files in a specified directory. Develop a script to generate an audit report.

---

## Command to Execute

```bash
cd AS_04 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_04\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_04/report.html
  ```
