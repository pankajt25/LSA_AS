## Command to Execute

```bash
cd AS_43 && bash run.sh
bash cleanup.sh
```

## Viewing the HTML Report

The script automatically detects your environment and launches `report.html` in your default web browser (supporting WSL, native Linux, macOS, and Windows/Git Bash).

If the browser does not open automatically, you can view the report manually:

- **WSL (Windows Explorer):**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Native Linux:**
  ```bash
  xdg-open report.html
  ```
- **macOS:**
  ```bash
  open report.html
  ```
- **Windows / Git Bash:**
  ```bash
  start report.html
  ```
- **Any Terminal / Browser:**
  Open `file:///path/to/AS_43/report.html` directly in Google Chrome, Firefox, Edge, or Safari.
