#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Reverses software packages installed during AS_27 automation demo.
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/cleanup.log"

COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"

mkdir -p "${SCRIPT_DIR}/logs"

echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}        AS_27 TEARDOWN & RECOVERY CLEANUP                                       ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "Executing safe removal of demonstration packages (cowsay, figlet)..."

log() {
    local msg="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $msg" >> "$LOG_FILE"
}

# Detect package manager
detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
        REMOVE_CMD="sudo apt-get remove -y"
        CHECK_CMD="dpkg -s"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        REMOVE_CMD="sudo dnf remove -y"
        CHECK_CMD="rpm -q"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
        REMOVE_CMD="sudo pacman -R --noconfirm"
        CHECK_CMD="pacman -Q"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew"
        REMOVE_CMD="brew uninstall"
        CHECK_CMD="brew list"
    else
        echo -e "${COLOR_RED}[ERROR] Unsupported package manager.${COLOR_RESET}" >&2
        exit 1
    fi
}

detect_pkg_manager

TARGET_PACKAGES=("cowsay" "figlet")

for pkg in "${TARGET_PACKAGES[@]}"; do
    if $CHECK_CMD "$pkg" >/dev/null 2>&1; then
        echo -e "  ${COLOR_YELLOW}Removing demo package: ${pkg}...${COLOR_RESET}"
        log "Removing package '$pkg'"
        if $REMOVE_CMD "$pkg" >> "$LOG_FILE" 2>&1; then
            echo -e "  ${COLOR_GREEN}✓ Successfully uninstalled ${pkg}.${COLOR_RESET}"
            log "Successfully uninstalled '$pkg'"
        else
            echo -e "  ${COLOR_RED}✗ Failed to uninstall ${pkg}.${COLOR_RESET}"
            log "Failed to uninstall '$pkg'"
        fi
    else
        echo -e "  ${COLOR_GREEN}✓ Package ${pkg} is not installed (already clean).${COLOR_RESET}"
        log "Package '$pkg' was not installed."
    fi
done

echo -e "\n${COLOR_GREEN}${COLOR_BOLD}System restoration complete. All demonstration packages uninstalled.${COLOR_RESET}"
echo -e "Cleanup logs stored in: ${LOG_FILE}"
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"
exit 0
