## Command to Execute

To run the automated file synchronization engine, mirror project files, verify cryptographic SHA-256 integrity, and generate the telemetry dashboard:

```bash
cd AS_49 && bash run.sh
```

To run the core synchronization script directly with custom parameters (e.g., dry-run mode or disabled deletion):

```bash
cd AS_49
bash sync_project.sh --help
bash sync_project.sh --dry-run
```

---

## Viewing the HTML Report

The script automatically generates a standalone, dark-themed HTML report at `AS_49/report.html` and launches it in your default web browser upon completion.

To reopen or inspect the report manually:

- **WSL2 (Windows Host Browser):**
  ```bash
  explorer.exe $(wslpath -w AS_49/report.html)
  ```
- **Standard Linux Desktop (xdg-open):**
  ```bash
  xdg-open AS_49/report.html
  ```
- **Direct Path:** Open `AS_49/report.html` directly in Google Chrome, Firefox, or any modern web browser.
