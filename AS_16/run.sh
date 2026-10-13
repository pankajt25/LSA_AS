#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_16)
# Problem Statement #16: Service Availability Check
# Script: run.sh — Single Cross-Platform Execute + Report Command
#
# PURPOSE:
#   1. Sets working directory to script location (runs cleanly from anywhere).
#   2. Executes service_availability_check.sh to inspect target service status.
#   3. Regenerates self-contained dark-themed report.html from scratch every run.
#   4. Automatically detects host OS (WSL, Linux, macOS, Git Bash) and launches
#      report.html in default web browser.
# ==============================================================================

set -euo pipefail

# 1. cd to script's own directory so execution works from any working directory
cd "$(dirname "$0")"

echo "================================================================================"
echo "          AUTOMATION SPRINT (AS_16) — SERVICE AVAILABILITY CHECK                "
echo "================================================================================"

# Verify service_availability_check.sh exists and is executable
if [ ! -f "./service_availability_check.sh" ]; then
    echo "[ERROR] service_availability_check.sh not found in $(pwd)!" >&2
    exit 1
fi
chmod +x ./service_availability_check.sh

# 2. Run service_availability_check.sh with --report to generate/refresh report.html
echo "[INFO] Running service_availability_check.sh with HTML report generation..."
echo "--------------------------------------------------------------------------------"

# Pass default 'cron' if no arguments provided, ensuring report.html is regenerated
set +e
if [ "$#" -eq 0 ]; then
    ./service_availability_check.sh cron --report
else
    ./service_availability_check.sh --report "$@"
fi
CHECK_EXIT=$?
set -e

echo "--------------------------------------------------------------------------------"

if [ ! -f "report.html" ]; then
    echo "[ERROR] report.html was not generated!" >&2
    exit 1
fi
echo "[INFO] report.html regenerated successfully."

# 3. OS detection and browser dispatch
echo "[INFO] Dispatching dashboard to default browser..."
OPENED=0

# A. WSL (Windows Subsystem for Linux)
if grep -qi microsoft /proc/version 2>/dev/null && command -v explorer.exe >/dev/null 2>&1; then
    echo "[INFO] Detected WSL environment."
    WIN_PATH="$(wslpath -w "${PWD}/report.html" 2>/dev/null || echo "report.html")"
    echo "[INFO] Windows Path: ${WIN_PATH}"
    echo "[LAUNCH] Invoking explorer.exe to launch report in Windows default browser..."
    explorer.exe "${WIN_PATH}" 2>/dev/null || true
    OPENED=1
# B. macOS (Darwin)
elif [ "${OS_NAME:-$(uname -s)}" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    echo "[INFO] Detected macOS environment."
    echo "[LAUNCH] Invoking 'open report.html'..."
    open report.html 2>/dev/null || true
    OPENED=1
# C. Windows Git Bash / MSYS / Cygwin
elif [[ "${OSTYPE:-}" =~ msys|cygwin|win32 ]] && command -v start >/dev/null 2>&1; then
    echo "[INFO] Detected Windows Git Bash / MSYS / Cygwin environment."
    echo "[LAUNCH] Invoking 'start \"\" report.html'..."
    start "" report.html 2>/dev/null || true
    OPENED=1
# D. Native Linux Desktop (X11 / Wayland)
elif command -v xdg-open >/dev/null 2>&1; then
    echo "[INFO] Detected Linux desktop environment."
    echo "[LAUNCH] Invoking 'xdg-open report.html'..."
    xdg-open report.html 2>/dev/null || true
    OPENED=1
# E. Python Webbrowser module fallback
elif command -v python3 >/dev/null 2>&1; then
    echo "[INFO] Attempting browser launch via python3 -m webbrowser..."
    python3 -m webbrowser "file://${PWD}/report.html" 2>/dev/null || true
    OPENED=1
# F. Headless / Terminal Fallback
else
    echo "[INFO] Web browser auto-launch unavailable in current terminal/headless environment."
    echo "[INFO] You can view report.html directly using either:"
    if grep -qi microsoft /proc/version 2>/dev/null && command -v wslpath >/dev/null 2>&1; then
        echo "       explorer.exe \"$(wslpath -w "${PWD}/report.html")\""
    fi
    echo "       file://${PWD}/report.html"
fi

if [ "${OPENED}" -eq 1 ]; then
    echo "[SUCCESS] Dashboard launch command dispatched successfully."
fi

echo "================================================================================"
exit 0
