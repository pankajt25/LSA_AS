# Backup Verification — Automation Sprint (AS_11)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** Backup Validation, Archive Integrity Testing & Cryptographic Verification  
**Problem Statement #11:** A backup is only useful if it is valid. Write a script that verifies whether the latest backup file exists, is non-empty, checks archive integrity (e.g., using `tar -tzf`), reports status, size, and calculates its SHA-256 checksum.

---

## Command to Execute

```bash
cd AS_11 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_11\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_11/report.html
  ```
