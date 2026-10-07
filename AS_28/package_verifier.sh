#!/usr/bin/env bash
# ==============================================================================
# Script: package_verifier.sh
# Purpose: Verify presence, versions, and installation commands for package manifests (AS_28).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/package_verifier.log"
JSON_FILE="${LOG_DIR}/package_verification.json"
DEFAULT_MANIFEST="${SCRIPT_DIR}/packages.txt"

mkdir -p "$LOG_DIR"

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# Package Manager Detection
# ------------------------------------------------------------------------------
detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
        INSTALL_SUGGESTION="sudo apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        INSTALL_SUGGESTION="sudo dnf install -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
        INSTALL_SUGGESTION="sudo yum install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
        INSTALL_SUGGESTION="sudo pacman -S --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
        INSTALL_SUGGESTION="sudo zypper install -y"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew"
        INSTALL_SUGGESTION="brew install"
    else
        PKG_MGR="generic"
        INSTALL_SUGGESTION="sudo package-manager install -y"
    fi
}

detect_pkg_manager

# ------------------------------------------------------------------------------
# Package Status and Version Extraction
# ------------------------------------------------------------------------------
check_package() {
    local pkg="$1"
    local installed=false
    local version="N/A"
    local bin_path="N/A"

    case "$PKG_MGR" in
        apt)
            if dpkg -s "$pkg" >/dev/null 2>&1; then
                # Check status line to verify it's really installed, not half-installed/removed
                if dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
                    installed=true
                    version="$(dpkg -s "$pkg" 2>/dev/null | grep -i "^Version:" | head -n1 | awk '{print $2}')"
                fi
            fi
            ;;
        dnf|yum|zypper)
            if rpm -q "$pkg" >/dev/null 2>&1; then
                installed=true
                version="$(rpm -q --queryformat "%{VERSION}-%{RELEASE}" "$pkg" 2>/dev/null || echo "Unknown")"
            fi
            ;;
        pacman)
            if pacman -Q "$pkg" >/dev/null 2>&1; then
                installed=true
                version="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')"
            fi
            ;;
        brew)
            if brew list "$pkg" >/dev/null 2>&1; then
                installed=true
                version="$(brew list --versions "$pkg" 2>/dev/null | awk '{print $2}')"
            fi
            ;;
    esac

    # Fallback to command -v if package manager query missed it (e.g., custom binary/alias)
    if [[ "$installed" == false ]] && command -v "$pkg" >/dev/null 2>&1; then
        installed=true
        bin_path="$(command -v "$pkg")"
        if "$pkg" --version >/dev/null 2>&1; then
            version="$("$pkg" --version 2>&1 | head -n1 | awk '{print $NF}' | tr -d 'vV()')"
        fi
    elif [[ "$installed" == true ]]; then
        bin_path="$(command -v "$pkg" 2>/dev/null || echo "Package Library / Daemon")"
    fi

    echo "$installed|$version|$bin_path"
}

# ------------------------------------------------------------------------------
# Help Manual
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PACKAGE_NAME...]

Verify if packages are installed on the system, reporting versions or install suggestions.

Arguments:
  PACKAGE_NAME...         One or more package names to verify directly.

Options:
  -f, --file <MANIFEST>   Read list of packages from specified manifest file.
                          (Defaults to ./packages.txt if no arguments given).
  --json                  Emit structured machine-readable JSON telemetry.
  -h, --help              Display this help manual and exit.

Examples:
  ./package_verifier.sh                           # Checks packages in packages.txt
  ./package_verifier.sh curl git python3 nginx    # Checks specific packages
  ./package_verifier.sh -f custom_list.txt        # Checks custom manifest
  ./package_verifier.sh --json                    # Outputs JSON telemetry
EOF
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------
OUTPUT_JSON=false
MANIFEST_FILE=""
TARGET_PACKAGES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            shift
            MANIFEST_FILE="$1"
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${COLOR_RED}[ERROR] Unknown option: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
        *)
            TARGET_PACKAGES+=("$1")
            shift
            ;;
    esac
done

# If no target packages specified via CLI arguments:
if [[ ${#TARGET_PACKAGES[@]} -eq 0 ]]; then
    if [[ -n "$MANIFEST_FILE" ]]; then
        if [[ ! -r "$MANIFEST_FILE" ]]; then
            echo -e "${COLOR_RED}[ERROR] Cannot read manifest file: '$MANIFEST_FILE'${COLOR_RESET}" >&2
            exit 1
        fi
        mapfile -t FILE_LINES < <(grep -v '^[[:space:]]*#' "$MANIFEST_FILE" | grep -v '^[[:space:]]*$' || true)
        for line in "${FILE_LINES[@]}"; do
            pkg_name="$(echo "$line" | awk '{print $1}')"
            [[ -n "$pkg_name" ]] && TARGET_PACKAGES+=("$pkg_name")
        done
    elif [[ -f "$DEFAULT_MANIFEST" ]]; then
        mapfile -t FILE_LINES < <(grep -v '^[[:space:]]*#' "$DEFAULT_MANIFEST" | grep -v '^[[:space:]]*$' || true)
        for line in "${FILE_LINES[@]}"; do
            pkg_name="$(echo "$line" | awk '{print $1}')"
            [[ -n "$pkg_name" ]] && TARGET_PACKAGES+=("$pkg_name")
        done
        MANIFEST_FILE="$DEFAULT_MANIFEST"
    else
        # Built-in fallback list
        TARGET_PACKAGES=("curl" "git" "python3" "tar" "tmux" "nginx" "docker" "cowsay")
    fi
fi

# ------------------------------------------------------------------------------
# Execution & Reporting
# ------------------------------------------------------------------------------
TOTAL_CHECKED=${#TARGET_PACKAGES[@]}
TOTAL_INSTALLED=0
TOTAL_MISSING=0

echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         PACKAGE VERIFICATION & AUDIT ENGINE (AS_28)                            ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Package Manager    : ${COLOR_BOLD}${PKG_MGR}${COLOR_RESET} (${INSTALL_SUGGESTION} <package>)"
echo -e " Target Host        : $(hostname) ($(uname -s) $(uname -r))"
echo -e " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e " Total Packages     : ${COLOR_BOLD}${TOTAL_CHECKED}${COLOR_RESET}"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
printf "%-4s %-16s %-16s %-20s %s\n" "NO." "PACKAGE" "STATUS" "VERSION" "INSTALLATION / PATH"
echo "--------------------------------------------------------------------------------"

JSON_RESULTS=()
IDX=1

for pkg in "${TARGET_PACKAGES[@]}"; do
    pkg="$(echo "$pkg" | tr -d ' ')"
    [[ -z "$pkg" ]] && continue

    IFS='|' read -r is_inst ver path <<< "$(check_package "$pkg")"

    if [[ "$is_inst" == "true" ]]; then
        (( TOTAL_INSTALLED++ )) || true
        status_disp="${COLOR_GREEN}INSTALLED${COLOR_RESET}"
        detail_disp="${path}"
        log "VERIFY" "Package '$pkg' is INSTALLED (Version: $ver, Path: $path)"
        JSON_RESULTS+=("{\"name\":\"$pkg\",\"status\":\"INSTALLED\",\"installed\":true,\"version\":\"$ver\",\"path\":\"$path\",\"suggestion\":\"\"}")
        printf "%-4s %-16s %-25b %-20s %s\n" "[$IDX]" "$pkg" "$status_disp" "$ver" "$detail_disp"
    else
        (( TOTAL_MISSING++ )) || true
        status_disp="${COLOR_RED}NOT INSTALLED${COLOR_RESET}"
        suggest_cmd="${INSTALL_SUGGESTION} ${pkg}"
        detail_disp="${COLOR_YELLOW}${suggest_cmd}${COLOR_RESET}"
        log "VERIFY" "Package '$pkg' is NOT INSTALLED (Suggestion: $suggest_cmd)"
        JSON_RESULTS+=("{\"name\":\"$pkg\",\"status\":\"NOT_INSTALLED\",\"installed\":false,\"version\":\"N/A\",\"path\":\"N/A\",\"suggestion\":\"$suggest_cmd\"}")
        printf "%-4s %-16s %-25b %-20s %b\n" "[$IDX]" "$pkg" "$status_disp" "N/A" "$detail_disp"
    fi
    (( IDX++ )) || true
done

echo "--------------------------------------------------------------------------------"
INSTALLED_PCT=0
MISSING_PCT=0
if (( TOTAL_CHECKED > 0 )); then
    INSTALLED_PCT="$(awk -v i="$TOTAL_INSTALLED" -v t="$TOTAL_CHECKED" 'BEGIN { printf "%.1f", (i/t)*100 }')"
    MISSING_PCT="$(awk -v m="$TOTAL_MISSING" -v t="$TOTAL_CHECKED" 'BEGIN { printf "%.1f", (m/t)*100 }')"
fi

echo -e " Summary: ${COLOR_GREEN}${TOTAL_INSTALLED} Installed (${INSTALLED_PCT}%)${COLOR_RESET} | ${COLOR_RED}${TOTAL_MISSING} Missing (${MISSING_PCT}%)${COLOR_RESET} | Total: ${COLOR_BOLD}${TOTAL_CHECKED}${COLOR_RESET}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

# ------------------------------------------------------------------------------
# JSON Serialization
# ------------------------------------------------------------------------------
JSON_JOINED="$(IFS=,; echo "${JSON_RESULTS[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_28",
  "title": "Package Verification Audit",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "package_manager": "$PKG_MGR",
  "install_command_template": "$INSTALL_SUGGESTION <package>",
  "manifest_file": "${MANIFEST_FILE:-CLI_ARGUMENTS}",
  "total_checked": $TOTAL_CHECKED,
  "total_installed": $TOTAL_INSTALLED,
  "total_missing": $TOTAL_MISSING,
  "installed_percentage": "$INSTALLED_PCT%",
  "missing_percentage": "$MISSING_PCT%",
  "packages": [
    $JSON_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

exit 0
