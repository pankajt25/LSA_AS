## Command to Execute

To execute the integrated Mini Linux Administration Dashboard, sample vital system metrics (CPU, RAM, Disk, Users, Services, Uptime), and open the live HTML dashboard:

```bash
cd AS_50 && bash run.sh
```

To run the terminal dashboard script directly with custom parameters (e.g., custom CPU sampling duration or headless JSON export):

```bash
cd AS_50
bash mini_dashboard.sh --help
bash mini_dashboard.sh --sample-interval 1.0
bash mini_dashboard.sh --json-only
```

---

## Viewing the HTML Report

The script generates a comprehensive, self-contained, dark-themed HTML report dashboard at `AS_50/report.html` and automatically opens it in your default web browser.

To reopen or inspect the report manually:

- **WSL2 (Windows Host Browser):**
  ```bash
  explorer.exe $(wslpath -w AS_50/report.html)
  ```
- **Standard Linux Desktop (xdg-open):**
  ```bash
  xdg-open AS_50/report.html
  ```
- **Direct Path:** Open `AS_50/report.html` directly in Google Chrome, Firefox, or any modern web browser.
