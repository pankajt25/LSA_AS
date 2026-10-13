# Application Installation — Automation Sprint (AS_27)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Package Management, Application Automation & Menu-Driven Provisioning  
**Problem Statement #27:** Manual software installation is repetitive. Write a menu-driven script that presents a list of applications (e.g., git, curl, vim, nginx) and allows the user to select and install them.

---

## Command to Execute

```bash
cd AS_27 && bash run.sh
```

*(Run `bash cleanup.sh` afterward to restore system)*

---

## Viewing the HTML Report

If your environment is headless or the browser does not open automatically, view the generated dashboard manually:

- **Windows Subsystem for Linux (WSL):**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows Path:**
  ```text
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_27\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_27/report.html
  ```
