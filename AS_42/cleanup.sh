#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Reverses all group creations and sandbox directory modifications for AS_42.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUP_PREFIX="lsatest_"
DEPARTMENTS=("engineering" "finance" "marketing" "operations" "human_resources")

echo "======================================================================"
echo " LSA Sprint AS_42: Teardown & System Restoration"
echo "======================================================================"

REMOVED_GROUPS=0

for dept in "${DEPARTMENTS[@]}"; do
    group_name="${GROUP_PREFIX}${dept}"
    if getent group "${group_name}" >/dev/null 2>&1; then
        echo "[CLEANUP] Removing test group '${group_name}'..."
        sudo groupdel "${group_name}" || echo "[WARN] Failed to delete group '${group_name}'"
        REMOVED_GROUPS=$((REMOVED_GROUPS + 1))
    else
        echo "[CLEANUP] Group '${group_name}' not present. Skipping."
    fi
done

# Also catch any lingering lsatest_ groups related to this problem
for extra_group in $(getent group | grep "^${GROUP_PREFIX}" | cut -d: -f1 || true); do
    echo "[CLEANUP] Removing lingering group '${extra_group}'..."
    sudo groupdel "${extra_group}" 2>/dev/null || true
done

# Remove test folders in sandbox_data
if [ -d "${SCRIPT_DIR}/sandbox_data/departments" ]; then
    echo "[CLEANUP] Removing sandbox department folders..."
    sudo rm -rf "${SCRIPT_DIR}/sandbox_data/departments"
fi

echo "======================================================================"
echo " Teardown completed. Removed groups: ${REMOVED_GROUPS}. System restored."
echo "======================================================================"
