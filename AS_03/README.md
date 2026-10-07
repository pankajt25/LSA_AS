# Department Access — Automation Sprint (AS_03)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Groups, SGID Inheritance & Shared Directory Permissions  
**Problem Statement #03:** Create a department group and configure a shared directory so that only members of that group can access it.

---

## Command to Execute

```bash
cd AS_03 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_03\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_03/report.html
  ```
