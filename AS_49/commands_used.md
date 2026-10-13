# Commands Used — AS_49: Automated File Synchronization

This document records the Linux utilities, commands, flags, and options utilized in the automated file synchronization engine and reporting driver.

---

### 1. File Synchronization & Delta Mirroring (`rsync`)

- **`rsync -avh --delete --stats <source>/ <dest>/`**
  - Synchronizes the source directory to the destination directory using the remote update protocol / delta-transfer algorithm.
  - `-a` (`--archive`): Archive mode; equals `-rlptgoD`. Preserves directory hierarchies recursively, symlinks, file permissions, modification timestamps, user ownership, group ownership, and special device nodes.
  - `-v` (`--verbose`): Increases verbosity, listing files as they are examined and transferred.
  - `-h` (`--human-readable`): Formats transfer sizes and throughput metrics in human-readable units (K, M, G).
  - `--delete`: Deletes files from the destination target if they no longer exist in the source directory, ensuring an exact mirror replica.
  - `--stats`: Emits comprehensive transfer statistics upon completion (number of files checked, files transferred, literal data sent, total byte size, speedup factor).
  - `--dry-run` (`-n`): Simulates execution without making any modifications on disk.

---

### 2. Cryptographic Integrity Verification

- **`sha256sum <file>`**
  - Generates the 256-bit Secure Hash Algorithm digest for every file in the source and destination trees to mathematically verify post-synchronization bit-level fidelity.
- **`stat -c%s <file>`**
  - Returns the exact size of a file in bytes, formatted via format sequence `%s`.

---

### 3. Filesystem Traversal & Safety Sanity Checks

- **`find <directory> -type f`**
  - Recursively finds all regular files in the directory tree for hash verification and change auditing.
- **`mkdir -p <dir>`**
  - Creates directory hierarchies safely without erroring if parents already exist.

---

### 4. Text Processing & Telemetry Extraction

- **`grep -oP '<regex>' <file>`**
  - Uses Perl-compatible regular expressions (`-P`) to extract specific statistical fields (e.g., `\K` discard syntax) from `rsync --stats` output.
- **`tr -d ','`**
  - Strips formatting commas from parsed integer counts.

---

### 5. Report Generation & Browser Launch

- **`python3 -`**
  - Executes inline Python script via heredoc to parse synchronization JSON telemetry, calculate integrity verification percentages, and generate a self-contained responsive dark-themed dashboard.
- **`wslpath -w <path>`**
  - Translates WSL2 Linux paths to Windows drive paths.
- **`explorer.exe <path>`**
  - Opens the generated `report.html` in the host Windows default web browser.
