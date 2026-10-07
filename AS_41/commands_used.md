# Linux Commands Used — AS_41: Archive Old Project Files

This document summarizes the core Linux utilities and techniques utilized in the project file archival automation solution.

---

### 1. `find` — Locating Aged Project Files
- **Command:** `find "${SOURCE_DIR}" -type f -mtime +"${DAYS_THRESHOLD}"`
- **Purpose:** Recursively searches the source project directory for regular files whose last modification time (`mtime`) is strictly greater than the threshold in days (e.g. `+30`).
- **Pruning Empty Folders:** `find "${SOURCE_DIR}" -mindepth 1 -type d -empty -delete` cleans up abandoned parent folders after file relocation.

### 2. `stat` — Inspecting File Metadata & Timestamps
- **File Size:** `stat -c%s <filepath>` retrieves exact file size in bytes without reading full file content.
- **Modification Time:** `stat -c%y <filepath>` and `stat -c%Y <filepath>` retrieve human-readable and unix epoch modification timestamps, enabling exact age verification.

### 3. `tar` — Packaging and Compressing Files
- **Command:** `tar -czf "${ARCHIVE_BUNDLE}" -C "${ARCHIVE_DIR}" "archive_${BATCH_STAMP}"`
- **Options:**
  - `-c`: Create new archive.
  - `-z`: Filter archive through `gzip` compression.
  - `-f`: Specify output archive filename.
  - `-C`: Change directory before archiving to preserve clean relative path hierarchy.

### 4. `sha256sum` — Cryptographic Checksum Generation
- **Command:** `sha256sum <filepath>`
- **Purpose:** Generates a SHA-256 digest before moving files to guarantee forensic integrity and verify that archived files can be recovered without data corruption.

### 5. `touch` — Synthetic Age Simulation
- **Command:** `touch -d "120 days ago" <filepath>`
- **Purpose:** Adjusts file atime and mtime into the past to construct repeatable, realistic test cases within the sandbox directory without affecting real production data.

### 6. `python3` — JSON Telemetry & Responsive HTML Dashboard Generation
- **Command:** `python3 - <<'PYEOF' ... PYEOF`
- **Purpose:** Parses last run metrics, queries tar archive contents using Python's standard `tarfile` module, and renders a self-contained HTML dashboard.
