#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint
# Problem Statement #38: Scheduled Linux System Health Report via Cron
# Script: cleanup.sh
#
# PURPOSE:
#   Full system restoration and teardown script:
#   1. Removes any user crontab entries tagged with '# LSA_SPRINT_TEST'.
#   2. Restores user crontab to clean state without touching pre-existing jobs.
#   3. Leaves health report logs intact for inspection/grading.
# ==============================================================================

set -euo pipefail

CRON_TAG="# LSA_SPRINT_TEST"

echo "================================================================================"
echo "       LSA AUTOMATION SPRINT (AS_38) — CLEANUP & RESTORATION                    "
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

echo "[SUCCESS] AS_38 cleanup completed successfully. System fully restored."
echo "================================================================================"
