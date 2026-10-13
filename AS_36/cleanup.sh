#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #36: Routine Server Maintenance & Cron Scheduling
# Script: cleanup.sh
#
# PURPOSE:
#   Full system restoration and teardown script:
#   1. Removes any user crontab entries tagged with '# LSA_SPRINT_TEST'.
#   2. Restores user crontab to clean state without touching pre-existing jobs.
#   3. Cleans temporary sandbox test artifacts created during demonstration.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_TAG="# LSA_SPRINT_TEST"

echo "================================================================================"
echo "       LSA AUTOMATION SPRINT (AS_36) — CLEANUP & RESTORATION                    "
echo "================================================================================"

echo "[INFO] Inspecting user crontab for '${CRON_TAG}' entries..."

CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"

if [ -n "${CURRENT_CRONTAB}" ]; then
    if echo "${CURRENT_CRONTAB}" | grep -q "${CRON_TAG}"; then
        echo "[INFO] Found LSA test crontab entries. Purging matching lines..."
        REMAINING_CRONTAB="$(echo "${CURRENT_CRONTAB}" | grep -v "${CRON_TAG}" || true)"
        
        if [ -n "$(echo "${REMAINING_CRONTAB}" | tr -d '[:space:]')" ]; then
            echo "${REMAINING_CRONTAB}" | crontab -
            echo "[SUCCESS] Crontab restored. Retained non-test cron entries."
        else
            crontab -r 2>/dev/null || true
            echo "[SUCCESS] Crontab was cleared as no other jobs existed."
        fi
    else
        echo "[INFO] No crontab entries with '${CRON_TAG}' found. Crontab is clean."
    fi
else
    echo "[INFO] Crontab is already empty. No cleanup required."
fi

# Clean up sandbox test files if present
if [ -d "${SCRIPT_DIR}/sandbox_data/tmp" ]; then
    echo "[INFO] Cleaning sandbox temporary test files..."
    rm -rf "${SCRIPT_DIR}/sandbox_data/tmp"/*
    echo "[SUCCESS] Sandbox quarantine reset."
fi

echo "[SUCCESS] AS_36 cleanup completed successfully. System fully restored."
echo "================================================================================"
