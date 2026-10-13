#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Reverses user account creation and restores system state for AS_43.
# ==============================================================================

set -euo pipefail

TARGET_USER="lsatest_offboard_demo"

echo "======================================================================"
echo " LSA Sprint AS_43: Teardown & System Restoration"
echo "======================================================================"

if getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
    echo "[CLEANUP] Terminating any remaining processes for '${TARGET_USER}'..."
    sudo pkill -u "${TARGET_USER}" 2>/dev/null || true
    
    echo "[CLEANUP] Removing test user '${TARGET_USER}' and home directory..."
    sudo userdel -r "${TARGET_USER}" 2>/dev/null || {
        echo "[WARN] userdel -r exited with non-zero, forcing userdel..."
        sudo userdel "${TARGET_USER}" 2>/dev/null || true
        sudo rm -rf "/home/${TARGET_USER}" 2>/dev/null || true
    }
    echo "[CLEANUP] Successfully deleted '${TARGET_USER}'."
else
    echo "[CLEANUP] Target user '${TARGET_USER}' does not exist on the system."
fi

# Also check for any group with that name
if getent group "${TARGET_USER}" >/dev/null 2>&1; then
    echo "[CLEANUP] Removing group '${TARGET_USER}'..."
    sudo groupdel "${TARGET_USER}" 2>/dev/null || true
fi

echo "======================================================================"
echo " Teardown completed. Test accounts removed. System restored."
echo "======================================================================"
