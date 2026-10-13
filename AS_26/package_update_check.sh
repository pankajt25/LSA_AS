#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_26)
# Problem Statement #26: Package Update Check
# Focus: Package Management & System Update Status Auditing
# Author: System Administrator (Individual Sprint)
#
# ==============================================================================
# STRICT SAFETY & SANDBOXING DECLARATION (READ BEFORE EXECUTION):
#   - THIS SCRIPT IS ENTIRELY READ-ONLY IN ITS OPERATIONAL IMPACT.
#   - IT CHECKS AND REPORTS AVAILABLE PACKAGE UPDATES ONLY.
#   - IT DOES NOT INSTALL, UPGRADE, REMOVE, OR MODIFY ANY PACKAGES ON THIS SYSTEM.
#   - Index refresh commands (e.g. 'apt update') merely synchronize repository
#     metadata and package version lists; they modify NO installed binaries.
#   - To apply updates manually, the administrator must explicitly execute:
#       Debian/Ubuntu : sudo apt upgrade
#       RHEL/Rocky    : sudo dnf upgrade
#       macOS Homebrew: brew upgrade
#   - Sandboxing compliance: All generated output files and logs reside strictly
#     within the project directory ('AS_26/logs/').
# ==============================================================================
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   Package management is a cornerstone of Linux system administration, security,
#   and configuration reliability. Unpatched systems expose organizations to
#   known Common Vulnerabilities and Exposures (CVEs). This utility automates the
#   detection of outdated packages across diverse Linux distributions and macOS.
#
# CORE FUNCTIONALITY:
#   1. Cross-Platform Package Manager Auto-Detection:
#      Probes system binaries and OS release signatures without hardcoding:
#      - APT (Debian, Ubuntu, Kali, Mint, Pop!_OS)
#      - DNF / YUM (Fedora, RHEL 8/9, Rocky Linux, AlmaLinux, CentOS)
#      - Homebrew (macOS / Darwin, Linuxbrew)
#      - Pacman (Arch Linux, Manjaro)
#      - Zypper (openSUSE, SUSE Linux Enterprise)
#   2. Resilient Package Index Refresh:
#      Safely synchronizes repository metadata (e.g. 'sudo apt update').
#      Detects privilege state (root vs passwordless sudo vs unprivileged user)
#      and handles network timeouts or repository unreachable states gracefully
#      without crashing, falling back to local cached package metadata.
#   3. Upgradable Package Parsing & Classification:
#      Extracts package names, current installed versions, available upgrade
#      versions, repository/suite sources, and hardware architecture.
#      Classifies updates into 'Security Updates' (critical CVE patches) vs
#      'Standard / Feature Updates'.
#   4. Persistent Audit Trail & Structured Telemetry:
#      Appends timestamped human-readable execution records to 'logs/package_check.log'.
#      Exports structured machine-readable JSON telemetry to 'logs/package_check.json'
#      for consumption by the HTML dashboard generator.
#   5. Defensive Error Handling:
#      Follows strict bash hygiene, traps unexpected errors, and outputs clear,
#      actionable diagnostic messages.
# ==============================================================================

set -o pipefail

# ------------------------------------------------------------------------------
# 1. DIRECTORY CONFIGURATION & ENVIRONMENT SETUP
# ------------------------------------------------------------------------------
# Resolve the directory where this script is located so paths remain stable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/package_check.log"
JSON_FILE="${LOG_DIR}/package_check.json"

# Ensure the logs directory exists
mkdir -p "${LOG_DIR}"

# ------------------------------------------------------------------------------
# 2. COLOR DEFINITIONS & FORMATTING UTILITIES
# ------------------------------------------------------------------------------
# Enable ANSI colors if standard output is an interactive terminal
USE_COLOR=1
if [ ! -t 1 ]; then
    USE_COLOR=0
fi

setup_colors() {
    if [ "${USE_COLOR}" -eq 1 ]; then
        CLR_RESET="\033[0m"
        CLR_BOLD="\033[1m"
        CLR_DIM="\033[2m"
        CLR_RED="\033[1;31m"
        CLR_GREEN="\033[1;32m"
        CLR_YELLOW="\033[1;33m"
        CLR_BLUE="\033[1;34m"
        CLR_MAGENTA="\033[1;35m"
        CLR_CYAN="\033[1;36m"
        CLR_WHITE="\033[1;37m"
        CLR_BG_RED="\033[41;37m"
        CLR_BG_GREEN="\033[42;30m"
        CLR_BG_YELLOW="\033[43;30m"
        CLR_BG_BLUE="\033[44;37m"
    else
        CLR_RESET=""
        CLR_BOLD=""
        CLR_DIM=""
        CLR_RED=""
        CLR_GREEN=""
        CLR_YELLOW=""
        CLR_BLUE=""
        CLR_MAGENTA=""
        CLR_CYAN=""
        CLR_WHITE=""
        CLR_BG_RED=""
        CLR_BG_GREEN=""
        CLR_BG_YELLOW=""
        CLR_BG_BLUE=""
    fi
}
setup_colors

# ------------------------------------------------------------------------------
# 3. CLI ARGUMENT PARSING & HELP SYSTEM
# ------------------------------------------------------------------------------
SKIP_REFRESH=0
OUTPUT_JSON_STDOUT=0

show_help() {
    echo -e "${CLR_BOLD}Package Update Check Utility — AS_26${CLR_RESET}
Course: Linux System Administration (E1ITA307)
Focus: Package Management & System Update Status Auditing

${CLR_BOLD}USAGE:${CLR_RESET}
    $0 [OPTIONS]

${CLR_BOLD}OPTIONS:${CLR_RESET}
    ${CLR_GREEN}-s, --skip-refresh${CLR_RESET}    Skip package index refresh and query existing cached metadata.
                            Useful for offline execution, fast audits, or restricted environments.
    ${CLR_GREEN}-j, --json${CLR_RESET}            Output raw structured JSON telemetry directly to stdout.
    ${CLR_GREEN}-h, --help${CLR_RESET}            Display this comprehensive reference manual and exit.
    ${CLR_GREEN}--no-color${CLR_RESET}            Disable ANSI color escapes in terminal output.

${CLR_BOLD}SAFETY GUARANTEE:${CLR_RESET}
    This script is ${CLR_BOLD}${CLR_GREEN}STRICTLY READ-ONLY${CLR_RESET}. It queries available updates but
    ${CLR_RED}NEVER${CLR_RESET} installs or upgrades any packages. To apply updates manually:
        Debian / Ubuntu:    sudo apt upgrade
        RHEL / Rocky Linux: sudo dnf upgrade
        macOS Homebrew:     brew upgrade

${CLR_BOLD}SUPPORTED PACKAGE MANAGERS:${CLR_RESET}
    - apt / apt-get  (Debian, Ubuntu, Linux Mint, Pop!_OS)
    - dnf / yum      (Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux)
    - brew           (macOS Homebrew, Linuxbrew)
    - pacman         (Arch Linux, Manjaro)
    - zypper         (openSUSE, SUSE Linux Enterprise)

${CLR_BOLD}OUTPUT DELIVERABLES:${CLR_RESET}
    - Terminal audit report table with version comparisons & security classifications
    - Persistent audit log: ${CLR_CYAN}logs/package_check.log${CLR_RESET}
    - Structured JSON file:  ${CLR_CYAN}logs/package_check.json${CLR_RESET}"
}

# Parse command line flags
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--skip-refresh)
            SKIP_REFRESH=1
            shift
            ;;
        -j|--json)
            OUTPUT_JSON_STDOUT=1
            shift
            ;;
        --no-color)
            USE_COLOR=0
            setup_colors
            shift
            ;;
        *)
            echo -e "${CLR_RED}❌ [ERROR] Unknown option: $1${CLR_RESET}" >&2
            echo "Execute '$0 --help' for syntax and options." >&2
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. SYSTEM DISCOVERY & PACKAGE MANAGER DETECTION
# ------------------------------------------------------------------------------
# Collect live host environment telemetry
HOST_NAME="$(hostname 2>/dev/null || uname -n 2>/dev/null || echo 'localhost')"
KERNEL_OS="$(uname -s 2>/dev/null || echo 'Linux')"
KERNEL_REV="$(uname -r 2>/dev/null || echo 'Unknown-Kernel')"
KERNEL_ARCH="$(uname -m 2>/dev/null || echo 'x86_64')"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
TIMESTAMP_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')"

# Determine OS distribution details from /etc/os-release if available
DISTRO_NAME="Unknown Linux"
DISTRO_VERSION=""
if [ -f /etc/os-release ]; then
    # Source os-release safely in a subshell to avoid polluting variable namespace
    DISTRO_NAME="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')"
    [ -z "${DISTRO_NAME}" ] && DISTRO_NAME="$(grep -E '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')"
elif [ "${KERNEL_OS}" = "Darwin" ]; then
    DISTRO_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
fi

# Detect active package manager dynamically (Requirement 1: do NOT hardcode apt only)
PKG_MANAGER=""
PKG_MANAGER_BIN=""
PKG_FAMILY=""

detect_package_manager() {
    # 1. macOS Homebrew check
    if [ "${KERNEL_OS}" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
        PKG_MANAGER_BIN="$(command -v brew)"
        PKG_FAMILY="macOS Homebrew"
    # 2. APT (Debian, Ubuntu, Kali, Linux Mint)
    elif command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_MANAGER_BIN="$(command -v apt)"
        PKG_FAMILY="Debian/Ubuntu (APT)"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_MANAGER_BIN="$(command -v apt-get)"
        PKG_FAMILY="Debian/Ubuntu (APT-GET)"
    # 3. DNF (Fedora, RHEL 8+, Rocky Linux, AlmaLinux)
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_MANAGER_BIN="$(command -v dnf)"
        PKG_FAMILY="RedHat/Fedora (DNF)"
    # 4. YUM (CentOS 7, older RHEL)
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_MANAGER_BIN="$(command -v yum)"
        PKG_FAMILY="RedHat/CentOS (YUM)"
    # 5. Homebrew on Linux
    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
        PKG_MANAGER_BIN="$(command -v brew)"
        PKG_FAMILY="Homebrew on Linux"
    # 6. Pacman (Arch Linux, Manjaro)
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_MANAGER_BIN="$(command -v pacman)"
        PKG_FAMILY="Arch Linux (Pacman)"
    # 7. Zypper (openSUSE, SUSE Linux Enterprise)
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        PKG_MANAGER_BIN="$(command -v zypper)"
        PKG_FAMILY="openSUSE / SLES (Zypper)"
    else
        PKG_MANAGER="unknown"
        PKG_MANAGER_BIN=""
        PKG_FAMILY="Unsupported / Unrecognized"
    fi
}

detect_package_manager

# Requirement 7: Error handling when no supported package manager is found
if [ "${PKG_MANAGER}" = "unknown" ] || [ -z "${PKG_MANAGER_BIN}" ]; then
    echo -e "${CLR_RED}❌ [FATAL ERROR] No supported package manager detected on this system!${CLR_RESET}" >&2
    echo -e "   Audited system: ${KERNEL_OS} ${KERNEL_REV} (${KERNEL_ARCH})" >&2
    echo -e "   Expected one of: apt, dnf, yum, brew, pacman, zypper in system PATH." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. REFRESH PACKAGE INDEX (REQUIREMENT 2 & SAFETY NOTICE)
# ------------------------------------------------------------------------------
# Refreshing the package index (e.g. 'apt update') synchronizes repository
# metadata. It is a read-only metadata synchronization and DOES NOT install
# or modify installed packages.
INDEX_REFRESH_STATUS="SKIPPED"
INDEX_REFRESH_DETAIL="Index refresh bypassed by user flag (--skip-refresh)."

refresh_package_index() {
    if [ "${SKIP_REFRESH}" -eq 1 ]; then
        INDEX_REFRESH_STATUS="SKIPPED"
        INDEX_REFRESH_DETAIL="Bypassed via --skip-refresh flag. Inspecting existing local package cache."
        return 0
    fi

    echo -e "${CLR_CYAN}🔄 [INFO] Synchronizing package repository index metadata (${PKG_MANAGER})...${CLR_RESET}"

    local refresh_cmd=""
    local refresh_rc=0

    case "${PKG_MANAGER}" in
        apt)
            # Check privilege level for apt update
            if [ "$(id -u)" -eq 0 ]; then
                refresh_cmd="apt-get update -qq"
            elif sudo -n true 2>/dev/null; then
                refresh_cmd="sudo apt-get update -qq"
            elif command -v sudo >/dev/null 2>&1; then
                # Sudo requires password; attempt with clear notification or warn gracefully
                if [ -t 0 ]; then
                    refresh_cmd="sudo apt-get update"
                else
                    INDEX_REFRESH_STATUS="CACHE_ONLY"
                    INDEX_REFRESH_DETAIL="Passwordless sudo unavailable in non-interactive mode. Querying cached index."
                    echo -e "${CLR_YELLOW}⚠️  [WARN] Passwordless sudo not available for index refresh; querying existing local package cache.${CLR_RESET}"
                    return 0
                fi
            else
                INDEX_REFRESH_STATUS="CACHE_ONLY"
                INDEX_REFRESH_DETAIL="Non-root user without sudo; querying existing cached package index."
                echo -e "${CLR_YELLOW}⚠️  [WARN] Non-root execution; checking existing local package cache.${CLR_RESET}"
                return 0
            fi

            # Execute refresh command safely with error trap
            set +e
            local refresh_err
            refresh_err="$(eval "${refresh_cmd}" 2>&1)"
            refresh_rc=$?
            set -e

            if [ "${refresh_rc}" -eq 0 ]; then
                INDEX_REFRESH_STATUS="SUCCESS"
                INDEX_REFRESH_DETAIL="Repository metadata successfully synchronized via '${refresh_cmd}'."
                echo -e "${CLR_GREEN}✅ [SUCCESS] Package repository index refreshed successfully.${CLR_RESET}"
            else
                # Requirement 7: apt update fails (e.g. no internet, lock held, DNS issue) -> clear message, don't crash
                INDEX_REFRESH_STATUS="REFRESH_FAILED"
                INDEX_REFRESH_DETAIL="Index refresh exited with code ${refresh_rc}. Error: $(echo "${refresh_err}" | head -n 2 | tr '\n' ' ')"
                echo -e "${CLR_YELLOW}⚠️  [WARN] Package index refresh encountered an issue (Exit Code ${refresh_rc}):${CLR_RESET}"
                echo -e "${CLR_DIM}   $(echo "${refresh_err}" | head -n 2)${CLR_RESET}"
                echo -e "${CLR_YELLOW}   Continuing update check using existing cached repository metadata...${CLR_RESET}"
            fi
            ;;

        dnf|yum)
            # In DNF/YUM, check-update automatically refreshes expired metadata caches.
            # Running check-update will be handled in the listing step.
            INDEX_REFRESH_STATUS="INTEGRATED"
            INDEX_REFRESH_DETAIL="DNF/YUM automatically synchronizes repository metadata cache during check-update."
            echo -e "${CLR_GREEN}✅ [INFO] Metadata refresh is integrated into '${PKG_MANAGER} check-update'.${CLR_RESET}"
            ;;

        brew)
            set +e
            local brew_err
            brew_err="$(brew update 2>&1)"
            refresh_rc=$?
            set -e

            if [ "${refresh_rc}" -eq 0 ]; then
                INDEX_REFRESH_STATUS="SUCCESS"
                INDEX_REFRESH_DETAIL="Homebrew formulas and casks updated successfully."
                echo -e "${CLR_GREEN}✅ [SUCCESS] Homebrew index updated successfully.${CLR_RESET}"
            else
                INDEX_REFRESH_STATUS="REFRESH_FAILED"
                INDEX_REFRESH_DETAIL="Homebrew update exited with code ${refresh_rc}."
                echo -e "${CLR_YELLOW}⚠️  [WARN] Homebrew update failed; querying cached outdated list.${CLR_RESET}"
            fi
            ;;

        pacman)
            # On Arch, checkupdates is read-only and queries sync DB without root
            if command -v checkupdates >/dev/null 2>&1; then
                INDEX_REFRESH_STATUS="INTEGRATED"
                INDEX_REFRESH_DETAIL="Using checkupdates helper (read-only sync database)."
            else
                INDEX_REFRESH_STATUS="CACHE_ONLY"
                INDEX_REFRESH_DETAIL="Querying pacman local sync database."
            fi
            ;;

        zypper)
            INDEX_REFRESH_STATUS="INTEGRATED"
            INDEX_REFRESH_DETAIL="Zypper checks repository caches automatically."
            ;;
    esac
}

refresh_package_index

# ------------------------------------------------------------------------------
# 6. QUERY & PARSE UPGRADABLE PACKAGES (REQUIREMENT 3 & 4)
# ------------------------------------------------------------------------------
# Real-data requirement: Query live upgradable packages from this machine.
echo -e "${CLR_CYAN}🔍 [INFO] Querying live upgradable packages from ${PKG_FAMILY}...${CLR_RESET}"

RAW_PACKAGE_OUTPUT=""
PARSED_PACKAGES=()
TOTAL_UPGRADABLE=0
SECURITY_UPDATES=0
STANDARD_UPDATES=0

# Temporary working file for intermediate line parsing
TMP_PKG_RAW="$(mktemp 2>/dev/null || mktemp -t 'pkg_raw_XXXXXX')"
trap 'rm -f "${TMP_PKG_RAW}"' EXIT

case "${PKG_MANAGER}" in
    apt)
        # Query apt list --upgradable, suppressing terminal stderr warnings
        apt list --upgradable 2>/dev/null | grep -E '\[upgradable from:' > "${TMP_PKG_RAW}" || true
        ;;

    dnf|yum)
        # Note on DNF/YUM: check-update exits with:
        #   100 = Updates are available
        #   0   = No updates available
        #   1   = Error
        set +e
        ${PKG_MANAGER} check-update 2>&1 > "${TMP_PKG_RAW}"
        local dnf_rc=$?
        set -e
        if [ "${dnf_rc}" -ne 0 ] && [ "${dnf_rc}" -ne 100 ]; then
            echo -e "${CLR_YELLOW}⚠️  [WARN] ${PKG_MANAGER} check-update returned code ${dnf_rc}.${CLR_RESET}"
        fi
        ;;

    brew)
        # Homebrew outdated list with verbose version info
        brew outdated --verbose 2>/dev/null > "${TMP_PKG_RAW}" || true
        ;;

    pacman)
        if command -v checkupdates >/dev/null 2>&1; then
            checkupdates 2>/dev/null > "${TMP_PKG_RAW}" || true
        else
            pacman -Qu 2>/dev/null > "${TMP_PKG_RAW}" || true
        fi
        ;;

    zypper)
        zypper list-updates 2>/dev/null | grep -E '^v\s*\|' > "${TMP_PKG_RAW}" || true
        ;;
esac

# ------------------------------------------------------------------------------
# 7. STRUCTURED PARSING (CROSS-PLATFORM TELEMETRY EXTRACTION)
# ------------------------------------------------------------------------------
# We leverage Python 3 for robust, precise JSON serialization and version parsing
# Python is universally available on modern Linux systems, but we ensure graceful
# fallback if Python is unavailable.

TMP_JSON_EXPORT="$(mktemp 2>/dev/null || mktemp -t 'pkg_json_XXXXXX')"
trap 'rm -f "${TMP_PKG_RAW}" "${TMP_JSON_EXPORT}"' EXIT

export TMP_PKG_RAW PKG_MANAGER DISTRO_NAME HOST_NAME KERNEL_REV KERNEL_ARCH TIMESTAMP TIMESTAMP_ISO INDEX_REFRESH_STATUS INDEX_REFRESH_DETAIL PKG_MANAGER_BIN JSON_FILE

python3 - << 'PY_PARSER_EOF' > "${TMP_JSON_EXPORT}" 2>/dev/null || true
import sys
import json
import re
import os
import platform
import subprocess

raw_file = os.environ.get("TMP_PKG_RAW", "")
pkg_manager = os.environ.get("PKG_MANAGER", "apt")
distro_name = os.environ.get("DISTRO_NAME", "Linux")
host_name = os.environ.get("HOST_NAME", platform.node())
kernel_rev = os.environ.get("KERNEL_REV", platform.release())
kernel_arch = os.environ.get("KERNEL_ARCH", platform.machine())
timestamp = os.environ.get("TIMESTAMP", "")
timestamp_iso = os.environ.get("TIMESTAMP_ISO", "")
index_status = os.environ.get("INDEX_REFRESH_STATUS", "UNKNOWN")
index_detail = os.environ.get("INDEX_REFRESH_DETAIL", "")
pkg_manager_bin = os.environ.get("PKG_MANAGER_BIN", "")

packages = []
security_count = 0
standard_count = 0

if os.path.exists(raw_file):
    with open(raw_file, "r", encoding="utf-8", errors="replace") as f:
        lines = [line.strip() for line in f if line.strip()]

    if pkg_manager == "apt":
        for idx, line in enumerate(lines, 1):
            # Standard APT format:
            # name/repo available_version arch [upgradable from: current_version]
            # e.g.: dmidecode/resolute-updates 3.6-2ubuntu1 amd64 [upgradable from: 3.6-2build1]
            match = re.match(r'^([^/\s]+)/([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+\[upgradable from:\s*([^\]]+)\]', line)
            if match:
                pkg_name, repo, avail_ver, arch, curr_ver = match.groups()
            else:
                # Robust token fallback
                parts = line.split()
                pkg_repo = parts[0].split('/')
                pkg_name = pkg_repo[0]
                repo = pkg_repo[1] if len(pkg_repo) > 1 else "unknown"
                avail_ver = parts[1] if len(parts) > 1 else "unknown"
                arch = parts[2] if len(parts) > 2 else "unknown"
                curr_match = re.search(r'\[upgradable from:\s*([^\]]+)\]', line)
                curr_ver = curr_match.group(1) if curr_match else "unknown"

            # Identify security updates
            is_sec = "security" in repo.lower()
            if is_sec:
                security_count += 1
                classification = "Security Update"
            else:
                standard_count += 1
                classification = "Standard Update"

            packages.append({
                "index": idx,
                "name": pkg_name,
                "repository": repo,
                "current_version": curr_ver,
                "available_version": avail_ver,
                "arch": arch,
                "update_type": classification
            })

    elif pkg_manager in ("dnf", "yum"):
        # Format: package_name.arch    available_version    repo
        line_idx = 1
        for line in lines:
            parts = line.split()
            if len(parts) >= 3 and not line.startswith("Loaded plugins") and not line.startswith("Last metadata"):
                pkg_arch = parts[0].rsplit('.', 1)
                pkg_name = pkg_arch[0]
                arch = pkg_arch[1] if len(pkg_arch) > 1 else "unknown"
                avail_ver = parts[1]
                repo = parts[2]
                
                # In DNF/RPM, query current version via rpm -q if available
                curr_ver = "installed"
                try:
                    rpm_out = subprocess.check_output(["rpm", "-q", "--qf", "%{VERSION}-%{RELEASE}", pkg_name], stderr=subprocess.DEVNULL, text=True).strip()
                    if rpm_out and not rpm_out.startswith("package"):
                        curr_ver = rpm_out
                except Exception:
                    pass

                is_sec = "security" in repo.lower()
                if is_sec:
                    security_count += 1
                    classification = "Security Update"
                else:
                    standard_count += 1
                    classification = "Standard Update"

                packages.append({
                    "index": line_idx,
                    "name": pkg_name,
                    "repository": repo,
                    "current_version": curr_ver,
                    "available_version": avail_ver,
                    "arch": arch,
                    "update_type": classification
                })
                line_idx += 1

    elif pkg_manager == "brew":
        # Format: package (current_version) < available_version
        for idx, line in enumerate(lines, 1):
            match = re.match(r'^([^\s]+)\s+\(([^)]+)\)\s*<\s*([^\s]+)', line)
            if match:
                pkg_name, curr_ver, avail_ver = match.groups()
            else:
                parts = line.split()
                pkg_name = parts[0]
                curr_ver = parts[1] if len(parts) > 1 else "installed"
                avail_ver = parts[-1] if len(parts) > 2 else "latest"

            standard_count += 1
            packages.append({
                "index": idx,
                "name": pkg_name,
                "repository": "homebrew",
                "current_version": curr_ver,
                "available_version": avail_ver,
                "arch": kernel_arch,
                "update_type": "Standard Update"
            })

    elif pkg_manager == "pacman":
        # Format: package current_version -> available_version
        for idx, line in enumerate(lines, 1):
            parts = line.split()
            if len(parts) >= 3 and parts[2] == "->":
                pkg_name = parts[0]
                curr_ver = parts[1]
                avail_ver = parts[3] if len(parts) > 3 else parts[2]
            else:
                pkg_name = parts[0]
                curr_ver = parts[1] if len(parts) > 1 else "installed"
                avail_ver = parts[2] if len(parts) > 2 else "new"

            standard_count += 1
            packages.append({
                "index": idx,
                "name": pkg_name,
                "repository": "arch-repos",
                "current_version": curr_ver,
                "available_version": avail_ver,
                "arch": kernel_arch,
                "update_type": "Standard Update"
            })

result = {
    "timestamp": timestamp,
    "timestamp_iso": timestamp_iso,
    "hostname": host_name,
    "os_name": distro_name,
    "kernel": kernel_rev,
    "architecture": kernel_arch,
    "package_manager": pkg_manager,
    "package_manager_path": pkg_manager_bin,
    "index_refresh_status": index_status,
    "index_refresh_detail": index_detail,
    "total_upgradable": len(packages),
    "security_updates": security_count,
    "standard_updates": standard_count,
    "packages": packages,
    "safety_disclaimer": "READ-ONLY AUDIT. Zero packages were installed, removed, or upgraded."
}

print(json.dumps(result, indent=2))
PY_PARSER_EOF

# If the Python parser succeeded, save structured JSON telemetry
if [ -s "${TMP_JSON_EXPORT}" ]; then
    cp "${TMP_JSON_EXPORT}" "${JSON_FILE}"
    TOTAL_UPGRADABLE="$(python3 -c "import json; d=json.load(open('${JSON_FILE}')); print(d['total_upgradable'])" 2>/dev/null || echo 0)"
    SECURITY_UPDATES="$(python3 -c "import json; d=json.load(open('${JSON_FILE}')); print(d['security_updates'])" 2>/dev/null || echo 0)"
    STANDARD_UPDATES="$(python3 -c "import json; d=json.load(open('${JSON_FILE}')); print(d['standard_updates'])" 2>/dev/null || echo 0)"
else
    # Fallback line counter in pure Bash if python was unavailable
    TOTAL_UPGRADABLE="$(wc -l < "${TMP_PKG_RAW}" | tr -d ' ')"
    SECURITY_UPDATES="$(grep -ic 'security' "${TMP_PKG_RAW}" || echo 0)"
    STANDARD_UPDATES=$(( TOTAL_UPGRADABLE - SECURITY_UPDATES ))
fi

# If JSON stdout mode requested, stream and exit
if [ "${OUTPUT_JSON_STDOUT}" -eq 1 ]; then
    if [ -f "${JSON_FILE}" ]; then
        cat "${JSON_FILE}"
    else
        echo '{"error": "Failed to serialize JSON"}'
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# 8. TERMINAL REPORT PRESENTATION (REQUIREMENT 4 & 5)
# ------------------------------------------------------------------------------
echo "================================================================================"
echo -e "${CLR_BOLD}${CLR_CYAN}         AUTOMATION SPRINT (AS_26) — PACKAGE UPDATE CHECK REPORT         ${CLR_RESET}"
echo "================================================================================"
echo -e "${CLR_BOLD}Target Host      :${CLR_RESET} ${HOST_NAME}"
echo -e "${CLR_BOLD}Operating System :${CLR_RESET} ${DISTRO_NAME}"
echo -e "${CLR_BOLD}Kernel Release   :${CLR_RESET} ${KERNEL_OS} ${KERNEL_REV} (${KERNEL_ARCH})"
echo -e "${CLR_BOLD}Package Manager  :${CLR_RESET} ${PKG_FAMILY} [${PKG_MANAGER_BIN}]"
echo -e "${CLR_BOLD}Audit Timestamp  :${CLR_RESET} ${TIMESTAMP}"
echo -e "${CLR_BOLD}Index Status     :${CLR_RESET} ${INDEX_REFRESH_STATUS} (${INDEX_REFRESH_DETAIL})"
echo "--------------------------------------------------------------------------------"
echo -e "${CLR_BOLD}UPDATE SUMMARY METRICS:${CLR_RESET}"
if [ "${TOTAL_UPGRADABLE}" -gt 0 ]; then
    echo -e "  • Total Upgradable Packages : ${CLR_BOLD}${CLR_YELLOW}${TOTAL_UPGRADABLE}${CLR_RESET}"
    if [ "${SECURITY_UPDATES}" -gt 0 ]; then
        echo -e "  • Critical Security Updates : ${CLR_BOLD}${CLR_RED}${SECURITY_UPDATES}${CLR_RESET} ${CLR_RED}⚠️  (Action Recommended)${CLR_RESET}"
    else
        echo -e "  • Critical Security Updates : ${CLR_BOLD}${CLR_GREEN}0${CLR_RESET} (No pending CVE fixes)"
    fi
    echo -e "  • Standard Feature Updates  : ${CLR_BOLD}${CLR_CYAN}${STANDARD_UPDATES}${CLR_RESET}"
else
    echo -e "  • Total Upgradable Packages : ${CLR_BOLD}${CLR_GREEN}0 (System is fully up to date!)${CLR_RESET}"
fi
echo "--------------------------------------------------------------------------------"

# Display Upgradable Packages Table
if [ "${TOTAL_UPGRADABLE}" -gt 0 ]; then
    echo -e "${CLR_BOLD}DETAILED UPGRADABLE PACKAGES LIST:${CLR_RESET}"
    printf "${CLR_BOLD}%-4s | %-28s | %-20s -> %-20s | %-16s | %s${CLR_RESET}\n" "NO." "PACKAGE NAME" "CURRENT VERSION" "AVAILABLE VERSION" "SUITE/REPO" "CLASSIFICATION"
    echo "-----+------------------------------+---------------------------------------------+------------------+----------------"

    if [ -f "${JSON_FILE}" ]; then
        python3 - << 'PY_RENDER_EOF'
import json
import os

json_file = os.environ.get("JSON_FILE", "logs/package_check.json")
try:
    with open(json_file, "r") as f:
        data = json.load(f)
    for pkg in data.get("packages", []):
        idx = pkg.get("index", 0)
        name = pkg.get("name", "")
        curr = pkg.get("current_version", "")
        avail = pkg.get("available_version", "")
        repo = pkg.get("repository", "")
        utype = pkg.get("update_type", "")
        
        # Color coding
        if utype == "Security Update":
            type_tag = "\033[1;31m[SECURITY]\033[0m"
        else:
            type_tag = "\033[1;36m[STANDARD]\033[0m"
            
        print(f"{idx:03d}  | {name:<28} | {curr:<20} -> {avail:<20} | {repo:<16} | {type_tag}")
except Exception as e:
    print(f"Error rendering table: {e}")
PY_RENDER_EOF
    else
        # Plain bash rendering
        cat "${TMP_PKG_RAW}"
    fi
else
    echo -e "${CLR_GREEN}✅ All packages are currently up-to-date with upstream repositories.${CLR_RESET}"
fi

echo "================================================================================"
# Requirement 5: Explicitly does NOT install anything & comment clearly
echo -e "${CLR_BOLD}${CLR_YELLOW}⚠️  SAFETY CONFIRMATION & ADMINISTRATIVE GUIDANCE:${CLR_RESET}"
echo -e "   1. ${CLR_BOLD}ZERO PACKAGES WERE MODIFIED OR INSTALLED.${CLR_RESET} This script is strictly a check utility."
echo -e "   2. To review or apply available updates manually, run:"
case "${PKG_MANAGER}" in
    apt)
        echo -e "      ${CLR_GREEN}sudo apt update && sudo apt upgrade${CLR_RESET}   (to apply standard & security updates)"
        echo -e "      ${CLR_GREEN}apt-get -s upgrade${CLR_RESET}                    (to simulate upgrade safely)"
        ;;
    dnf|yum)
        echo -e "      ${CLR_GREEN}sudo ${PKG_MANAGER} upgrade${CLR_RESET}                     (to apply updates)"
        ;;
    brew)
        echo -e "      ${CLR_GREEN}brew upgrade${CLR_RESET}                            (to upgrade outdated packages)"
        ;;
    pacman)
        echo -e "      ${CLR_GREEN}sudo pacman -Syu${CLR_RESET}                        (to synchronize and upgrade)"
        ;;
    zypper)
        echo -e "      ${CLR_GREEN}sudo zypper update${CLR_RESET}                      (to apply package updates)"
        ;;
esac
echo "================================================================================"

# ------------------------------------------------------------------------------
# 9. PERSISTENT CHRONOLOGICAL AUDIT LOGGING (REQUIREMENT 6)
# ------------------------------------------------------------------------------
# Log each check with full timestamp and diagnostic metadata to logs/package_check.log
{
    echo "================================================================================"
    echo "PACKAGE UPDATE CHECK AUDIT LOG ENTRY"
    echo "Timestamp           : ${TIMESTAMP} (${TIMESTAMP_ISO})"
    echo "Target Hostname     : ${HOST_NAME}"
    echo "Operating System    : ${DISTRO_NAME}"
    echo "Kernel Architecture : ${KERNEL_OS} ${KERNEL_REV} (${KERNEL_ARCH})"
    echo "Package Manager     : ${PKG_FAMILY} [${PKG_MANAGER_BIN}]"
    echo "Index Refresh Status: ${INDEX_REFRESH_STATUS}"
    echo "Index Refresh Detail: ${INDEX_REFRESH_DETAIL}"
    echo "Total Upgradable    : ${TOTAL_UPGRADABLE}"
    echo "Security Updates    : ${SECURITY_UPDATES}"
    echo "Standard Updates    : ${STANDARD_UPDATES}"
    echo "Safety Guarantee    : READ-ONLY CHECK. NO PACKAGES WERE INSTALLED OR UPGRADED."
    echo "--------------------------------------------------------------------------------"
    if [ "${TOTAL_UPGRADABLE}" -gt 0 ] && [ -f "${JSON_FILE}" ]; then
        python3 - << 'PY_LOG_EOF'
import json
import os
json_file = os.environ.get("JSON_FILE", "logs/package_check.json")
try:
    with open(json_file, "r") as f:
        data = json.load(f)
    print(f"{'No.':<4} | {'Package Name':<28} | {'Current Version':<20} | {'Available Version':<20} | {'Repository':<18} | {'Classification'}")
    print("-" * 115)
    for pkg in data.get("packages", []):
        print(f"{pkg['index']:03d}  | {pkg['name']:<28} | {pkg['current_version']:<20} | {pkg['available_version']:<20} | {pkg['repository']:<18} | {pkg['update_type']}")
except Exception:
    pass
PY_LOG_EOF
    elif [ "${TOTAL_UPGRADABLE}" -eq 0 ]; then
        echo "Status: System packages are fully up to date. Zero pending updates."
    fi
    echo "================================================================================"
    echo ""
} >> "${LOG_FILE}"

echo -e "${CLR_DIM}📝 Audit record appended to: ${LOG_FILE}${CLR_RESET}"
echo -e "${CLR_DIM}📊 Structured JSON saved to: ${JSON_FILE}${CLR_RESET}"

exit 0
