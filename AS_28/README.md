# Package Verification — Automation Sprint (AS_28)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Package Management, Dependency Auditing & Software Inventory  
**Problem Statement #28:** Verify if a given list of packages is installed on the system. For each package: print installed or not installed, if installed display its version, if not installed suggest the installation command.

---

## Command to Execute

```bash
cd AS_28 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_28\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_28/report.html
  ```
