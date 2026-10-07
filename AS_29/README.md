# System Inventory — Automation Sprint (AS_29)

**Course:** Linux System Administration (`E1ITA307`)  
**Sprint Focus:** System Inventory, Hardware Specifications & OS Telemetry  
**Problem Statement #29:** Before configuring new software, you need full hardware and OS specifications. Write a script that collects and displays: OS name and version, kernel version, CPU model and core count, total and available RAM, disk partitions and sizes, network interfaces and IP addresses.

---

## Command to Execute

```bash
cd AS_29 && bash run.sh
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
  D:\Users\Dell\Downloads\Projects\LSA\Automation_sprint\AS_29\report.html
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
  file:///mnt/d/Users/Dell/Downloads/Projects/LSA/Automation_sprint/AS_29/report.html
  ```
