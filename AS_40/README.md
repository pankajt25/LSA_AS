# Mounted File System Space Report — Automation Sprint (AS_40)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Virtual File System (VFS) Auditing, Mount Hierarchies & Capacity Reporting  
**Problem Statement #40:** Create a script to display all mounted file systems along with their total, used, and available space.

---

## Command to Execute

```bash
cd AS_40 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_40\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_40\report.html
  ```
