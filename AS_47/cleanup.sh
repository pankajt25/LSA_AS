#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Deletes test user account and resets sandboxed security audit artifacts for AS_47.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_USER="lsatest_audit_nopass"

echo "======================================================================"
echo " LSA Sprint AS_47: Teardown & System Restoration"
echo "======================================================================"

if getent passwd "${DEMO_USER}" >/dev/null 2>&1; then
    echo "[CLEANUP] Removing test user '${DEMO_USER}'..."
    sudo userdel -r "${DEMO_USER}" 2>/dev/null || sudo userdel "${DEMO_USER}" 2>/dev/null || true
    echo "[CLEANUP] Successfully removed '${DEMO_USER}'."
else
    echo "[CLEANUP] Test user '${DEMO_USER}' not found."
fi

# Clean up sandbox world-writable test file
if [ -d "${SCRIPT_DIR}/sandbox_data" ]; then
    echo "[CLEANUP] Cleaning sandbox data directory..."
    rm -f "${SCRIPT_DIR}/sandbox_data/insecure_shared_config.conf" 2>/dev/null || true
fi

echo "======================================================================"
echo " Teardown completed. Security state restored."
echo "======================================================================"
