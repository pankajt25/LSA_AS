#!/usr/bin/env bash
# ==============================================================================
# Script: package_installer.sh
# Purpose: Menu-driven application installation & package management automation (AS_27).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/package_installer.log"
JSON_FILE="${LOG_DIR}/installation_report.json"

mkdir -p "$LOG_DIR"

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_MAGENTA="\033[35m"

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
        INSTALL_CMD="sudo apt-get install -y"
        CHECK_CMD="dpkg -s"
        REMOVE_CMD="sudo apt-get remove -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        INSTALL_CMD="sudo dnf install -y"
        CHECK_CMD="rpm -q"
        REMOVE_CMD="sudo dnf remove -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
        INSTALL_CMD="sudo yum install -y"
        CHECK_CMD="rpm -q"
        REMOVE_CMD="sudo yum remove -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
        CHECK_CMD="pacman -Q"
        REMOVE_CMD="sudo pacman -R --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
        INSTALL_CMD="sudo zypper install -y"
        CHECK_CMD="rpm -q"
        REMOVE_CMD="sudo zypper remove -y"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew"
        INSTALL_CMD="brew install"
        CHECK_CMD="brew list"
        REMOVE_CMD="brew uninstall"
    else
        echo -e "${COLOR_RED}[ERROR] No supported package manager found.${COLOR_RESET}" >&2
        log "ERROR" "No supported package manager detected on host system."
        exit 1
    fi
}

detect_pkg_manager

# ------------------------------------------------------------------------------
# Application Catalog Definition
# ------------------------------------------------------------------------------
# Array of catalog items: "package_name|category|safe_demo|description"
CATALOG=(
    "cowsay|Demo/Utility|true|Configurable ASCII art talking cow character"
    "figlet|Demo/Utility|true|ASCII banner and large stylized letter generator"
    "sl|Demo/Animation|true|Steam Locomotive terminal animation corrector"
    "curl|Network/Web|false|Command-line tool for transferring data with URLs"
    "git|Development|false|Fast, scalable, distributed revision control system"
    "htop|Monitoring|false|Interactive process viewer and system resource monitor"
    "tmux|Terminal|false|Terminal multiplexer for persistent shell workspaces"
    "jq|Data Processing|false|Lightweight and flexible command-line JSON processor"
    "vim|Text Editor|false|Extensible and ubiquitous modal terminal text editor"
    "tree|Filesystem|false|Recursive directory tree visualizer with color output"
)

# Function to check if a package is currently installed
is_installed() {
    local pkg="$1"
    case "$PKG_MGR" in
        apt)
            dpkg -s "$pkg" >/dev/null 2>&1 && return 0 || return 1
            ;;
        dnf|yum|zypper)
            rpm -q "$pkg" >/dev/null 2>&1 && return 0 || return 1
            ;;
        pacman)
            pacman -Q "$pkg" >/dev/null 2>&1 && return 0 || return 1
            ;;
        brew)
            brew list "$pkg" >/dev/null 2>&1 && return 0 || return 1
            ;;
        *)
            command -v "$pkg" >/dev/null 2>&1 && return 0 || return 1
            ;;
    esac
}

get_pkg_version() {
    local pkg="$1"
    if ! is_installed "$pkg"; then
        echo "Not Installed"
        return
    fi
    case "$PKG_MGR" in
        apt)
            dpkg -s "$pkg" 2>/dev/null | grep -i "^Version:" | head -n1 | awk '{print $2}' || echo "Installed"
            ;;
        dnf|yum|zypper)
            rpm -q --queryformat "%{VERSION}-%{RELEASE}" "$pkg" 2>/dev/null || echo "Installed"
            ;;
        pacman)
            pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || echo "Installed"
            ;;
        brew)
            brew list --versions "$pkg" 2>/dev/null | awk '{print $2}' || echo "Installed"
            ;;
        *)
            echo "Installed"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Installation Execution
# ------------------------------------------------------------------------------
install_package() {
    local pkg="$1"
    local dry_run="${2:-false}"

    echo -e "${COLOR_CYAN}[PROCESS] Evaluating package: ${COLOR_BOLD}${pkg}${COLOR_RESET}..."
    log "INFO" "Evaluating package '$pkg' (dry_run=$dry_run)"

    if is_installed "$pkg"; then
        local current_ver
        current_ver="$(get_pkg_version "$pkg")"
        echo -e "  ${COLOR_GREEN}✓ Already Installed:${COLOR_RESET} Version ${COLOR_BOLD}${current_ver}${COLOR_RESET}"
        log "INFO" "Package '$pkg' already installed ($current_ver). Skipping."
        return 0
    fi

    if [[ "$dry_run" == true ]]; then
        echo -e "  ${COLOR_YELLOW}[DRY-RUN] Simulating installation of ${pkg} via ${PKG_MGR}...${COLOR_RESET}"
        log "DRY_RUN" "Simulated installation of '$pkg'"
        return 0
    fi

    echo -e "  ${COLOR_YELLOW}⚡ Installing ${pkg} via ${PKG_MGR}...${COLOR_RESET}"
    log "INSTALL_START" "Executing: $INSTALL_CMD $pkg"

    local install_out
    install_out="$(mktemp)"
    if $INSTALL_CMD "$pkg" > "$install_out" 2>&1; then
        local installed_ver
        installed_ver="$(get_pkg_version "$pkg")"
        echo -e "  ${COLOR_GREEN}✓ Installation Successful:${COLOR_RESET} Version ${COLOR_BOLD}${installed_ver}${COLOR_RESET}"
        log "SUCCESS" "Package '$pkg' installed successfully (Version: $installed_ver)"
        rm -f "$install_out"
        return 0
    else
        echo -e "  ${COLOR_RED}✗ Installation Failed:${COLOR_RESET} Check logs for details"
        cat "$install_out" >> "$LOG_FILE"
        cat "$install_out" >&2
        log "ERROR" "Failed to install package '$pkg'"
        rm -f "$install_out"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Menu Display Function
# ------------------------------------------------------------------------------
show_catalog_menu() {
    echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}         APPLICATION INSTALLATION & PACKAGE AUTOMATION (AS_27)                  ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
    echo -e " Package Manager : ${COLOR_BOLD}${PKG_MGR}${COLOR_RESET} (${INSTALL_CMD})"
    echo -e " System Host     : $(hostname) ($(uname -s) $(uname -r))"
    echo -e " Current Time    : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"
    printf "%-4s %-12s %-16s %-16s %s\n" "OPT" "PACKAGE" "CATEGORY" "STATUS" "DESCRIPTION"
    echo "--------------------------------------------------------------------------------"

    local idx=1
    for item in "${CATALOG[@]}"; do
        IFS='|' read -r pkg cat is_demo desc <<< "$item"
        local status_str
        if is_installed "$pkg"; then
            status_str="${COLOR_GREEN}Installed${COLOR_RESET}"
        else
            status_str="${COLOR_YELLOW}Available${COLOR_RESET}"
        fi
        local demo_tag=""
        if [[ "$is_demo" == "true" ]]; then
            demo_tag=" [Safe Demo]"
        fi
        printf "%-4s %-12s %-16s %-25b %s%s\n" "[$idx]" "$pkg" "$cat" "$status_str" "$desc" "$demo_tag"
        (( idx++ )) || true
    done
    echo "--------------------------------------------------------------------------------"
    echo -e " [D]  Install Safe Demonstration Packages (${COLOR_GREEN}cowsay, figlet${COLOR_RESET})"
    echo -e " [S]  Refresh & Display Package Statuses"
    echo -e " [Q]  Quit / Exit Menu"
    echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Telemetry Generation
# ------------------------------------------------------------------------------
generate_json_telemetry() {
    local json_packages=()
    local total_catalog=${#CATALOG[@]}
    local total_installed=0
    local total_available=0

    for item in "${CATALOG[@]}"; do
        IFS='|' read -r pkg cat is_demo desc <<< "$item"
        local inst=false
        local ver="Not Installed"
        if is_installed "$pkg"; then
            inst=true
            ver="$(get_pkg_version "$pkg")"
            (( total_installed++ )) || true
        else
            (( total_available++ )) || true
        fi
        json_packages+=("{\"name\":\"$pkg\",\"category\":\"$cat\",\"is_safe_demo\":$is_demo,\"description\":\"$desc\",\"installed\":$inst,\"version\":\"$ver\"}")
    done

    local pkgs_joined
    pkgs_joined="$(IFS=,; echo "${json_packages[*]}")"

    cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_27",
  "title": "Application Installation Automation",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "hostname": "$(hostname)",
  "package_manager": "$PKG_MGR",
  "install_command": "$INSTALL_CMD",
  "catalog_total": $total_catalog,
  "installed_total": $total_installed,
  "available_total": $total_available,
  "packages": [
    $pkgs_joined
  ]
}
EOF
}

# ------------------------------------------------------------------------------
# Command-Line Processing
# ------------------------------------------------------------------------------
DRY_RUN=false
OUTPUT_JSON=false
PACKAGES_TO_INSTALL=()
RUN_STATUS_ONLY=false

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Menu-driven application installer and package manager automation.

Options:
  --install <pkg1,pkg2>   Install comma-separated packages non-interactively
  --demo                  Install approved safe demonstration packages (cowsay, figlet)
  --status                Display catalog status and exit without installing
  --dry-run               Simulate package installation without modifying system
  --json                  Output structured telemetry to console and logs/installation_report.json
  -h, --help              Display this help manual and exit

Examples:
  ./package_installer.sh                       # Launches interactive menu (if TTY) or demo
  ./package_installer.sh --demo                # Installs safe demo packages (cowsay, figlet)
  ./package_installer.sh --install cowsay      # Installs cowsay non-interactively
  ./package_installer.sh --dry-run --demo      # Safe dry-run simulation
  ./package_installer.sh --status              # Displays current catalog installation status
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            shift
            IFS=',' read -ra ADDPKGS <<< "$1"
            PACKAGES_TO_INSTALL+=("${ADDPKGS[@]}")
            shift
            ;;
        --demo)
            PACKAGES_TO_INSTALL+=("cowsay" "figlet")
            shift
            ;;
        --status)
            RUN_STATUS_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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
        *)
            echo -e "${COLOR_RED}[ERROR] Unknown option: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
    esac
done

# If arguments were provided:
if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 || "$RUN_STATUS_ONLY" == true ]]; then
    show_catalog_menu
    if [[ "$RUN_STATUS_ONLY" == true ]]; then
        generate_json_telemetry
        if [[ "$OUTPUT_JSON" == true ]]; then
            cat "$JSON_FILE"
        fi
        exit 0
    fi

    echo -e "${COLOR_BOLD}Executing Package Installation Queue:${COLOR_RESET}"
    for target in "${PACKAGES_TO_INSTALL[@]}"; do
        # Trim whitespace
        target="$(echo "$target" | tr -d ' ')"
        [[ -z "$target" ]] && continue
        install_package "$target" "$DRY_RUN"
    done
    generate_json_telemetry
    if [[ "$OUTPUT_JSON" == true ]]; then
        cat "$JSON_FILE"
    fi
    exit 0
fi

# If interactive TTY is available and no CLI flags were passed:
if [[ -t 0 ]]; then
    while true; do
        show_catalog_menu
        echo -n "Select package number(s) (e.g. 1, 1 2, D for demo, Q to quit): "
        read -r USER_CHOICE
        case "${USER_CHOICE,,}" in
            q|quit|exit)
                echo "Exiting package installer. Goodbye!"
                break
                ;;
            s|status)
                continue
                ;;
            d|demo)
                echo -e "\nInstalling Safe Demonstration Packages..."
                install_package "cowsay" false
                install_package "figlet" false
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
            *)
                for choice in $USER_CHOICE; do
                    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#CATALOG[@]} )); then
                        selected_entry="${CATALOG[$((choice - 1))]}"
                        IFS='|' read -r sel_pkg _ _ _ <<< "$selected_entry"
                        install_package "$sel_pkg" false
                    else
                        echo -e "${COLOR_RED}Invalid choice: $choice${COLOR_RESET}"
                    fi
                done
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
        esac
    done
    generate_json_telemetry
else
    # Non-interactive fallback (e.g. background automation or piped input)
    show_catalog_menu
    echo -e "${COLOR_YELLOW}[NON-INTERACTIVE] Running automated demonstration installation of approved packages: cowsay, figlet...${COLOR_RESET}"
    install_package "cowsay" "$DRY_RUN"
    install_package "figlet" "$DRY_RUN"
    generate_json_telemetry
fi

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

echo -e "\n${COLOR_GREEN}✓ Package installer operations completed successfully.${COLOR_RESET}"
exit 0
