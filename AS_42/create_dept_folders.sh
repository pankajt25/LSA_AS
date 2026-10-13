#!/usr/bin/env bash
# ==============================================================================
# Script: create_dept_folders.sh
# Purpose: Provision department directories with SGID permission & group ownership.
# Author: System Administrator (LSA Sprint AS_42)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/dept_creation_${TIMESTAMP}.log"
SUMMARY_JSON="${LOG_DIR}/last_run.json"

# Defaults
BASE_DIR="${SCRIPT_DIR}/sandbox_data/departments"
GROUP_PREFIX="lsatest_"
PERMISSIONS="2770"
DEPARTMENTS=("engineering" "finance" "marketing" "operations" "human_resources")

log() {
    local level="$1"
    shift
    local msg="[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*"
    echo -e "${msg}"
    echo -e "${msg}" >> "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -b, --base-dir <DIR>     Base directory for department folders (default: sandbox_data/departments)
  -p, --perms <OCTAL>      Permissions mode to apply (default: 2770)
  --prefix <PREFIX>        Group prefix for security isolation (default: lsatest_)
  -d, --depts "d1 d2..."   Space-separated list of departments
  -h, --help               Display this help message
EOF
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        -p|--perms)
            PERMISSIONS="$2"
            shift 2
            ;;
        --prefix)
            GROUP_PREFIX="$2"
            shift 2
            ;;
        -d|--depts)
            read -r -a DEPARTMENTS <<< "$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            ;;
    esac
done

log "INFO" "============================================================"
log "INFO" "LSA Sprint AS_42 - Department Folder Provisioning Engine"
log "INFO" "Base Directory:       ${BASE_DIR}"
log "INFO" "Group Prefix:         ${GROUP_PREFIX}"
log "INFO" "Permission Mode:      ${PERMISSIONS} (SGID)"
log "INFO" "Departments:          ${DEPARTMENTS[*]}"
log "INFO" "Log File:             ${LOG_FILE}"
log "INFO" "============================================================"

mkdir -p "${BASE_DIR}"

RESULTS=()
CREATED_GROUPS=0
EXISTING_GROUPS=0
CREATED_FOLDERS=0

for dept in "${DEPARTMENTS[@]}"; do
    group_name="${GROUP_PREFIX}${dept}"
    dept_folder="${BASE_DIR}/${dept}"
    
    log "INFO" "Processing department: [${dept}]..."

    # 1. Check / Create Linux Group
    if getent group "${group_name}" >/dev/null 2>&1; then
        log "INFO" "Group '${group_name}' already exists."
        EXISTING_GROUPS=$((EXISTING_GROUPS + 1))
    else
        log "INFO" "Group '${group_name}' does not exist. Creating..."
        if sudo groupadd "${group_name}"; then
            log "SUCCESS" "Created group '${group_name}' (GID: $(getent group "${group_name}" | cut -d: -f3))."
            CREATED_GROUPS=$((CREATED_GROUPS + 1))
        else
            log "ERROR" "Failed to create group '${group_name}'."
            continue
        fi
    fi

    # 2. Create Department Folder
    if [ ! -d "${dept_folder}" ]; then
        mkdir -p "${dept_folder}"
        CREATED_FOLDERS=$((CREATED_FOLDERS + 1))
        log "SUCCESS" "Created directory: ${dept_folder}"
    else
        log "INFO" "Directory already exists: ${dept_folder}"
    fi

    # 3. Assign Ownership & Permissions
    # Use current user or root as owner, and department group as group
    current_user="$(id -un)"
    sudo chown "${current_user}:${group_name}" "${dept_folder}"
    sudo chmod "${PERMISSIONS}" "${dept_folder}"

    # 4. Verify SGID Inheritance by dropping a placeholder
    sample_file="${dept_folder}/dept_charter.txt"
    echo "# Department charter for ${dept^^}" > "${sample_file}"
    echo "Managed under group: ${group_name}" >> "${sample_file}"
    echo "Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${sample_file}"

    # Verify attributes
    folder_stat="$(stat -c "%A|%a|%U|%G" "${dept_folder}")"
    file_stat="$(stat -c "%A|%a|%U|%G" "${sample_file}")"
    
    IFS="|" read -r f_perm_str f_perm_oct f_owner f_group <<< "${folder_stat}"
    IFS="|" read -r file_perm_str file_perm_oct file_owner file_group <<< "${file_stat}"

    log "SUCCESS" "Folder: ${dept} -> Perms: ${f_perm_str} (${f_perm_oct}) Owner: ${f_owner} Group: ${f_group}"
    log "INFO" "SGID Test File: ${sample_file##*/} -> Owner: ${file_owner} Group: ${file_group} (Inherited: $( [ "${file_group}" == "${group_name}" ] && echo "YES" || echo "NO" ))"

    RESULTS+=("{\"dept\": \"${dept}\", \"group\": \"${group_name}\", \"folder\": \"${dept_folder}\", \"perms\": \"${f_perm_str}\", \"octal\": \"${f_perm_oct}\", \"owner\": \"${f_owner}\", \"gid\": \"$(getent group "${group_name}" | cut -d: -f3)\", \"inherited\": \"$([ "${file_group}" == "${group_name}" ] && echo "true" || echo "false")\"}")
done

# Generate Summary JSON
python3 - <<PYEOF
import json, os, datetime

results_list = [${RESULTS[*]/*/&,}]
# remove trailing comma if any
data = {
    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "base_dir": "${BASE_DIR}",
    "group_prefix": "${GROUP_PREFIX}",
    "permissions": "${PERMISSIONS}",
    "total_departments": len("${DEPARTMENTS[*]}".split()),
    "groups_created": ${CREATED_GROUPS},
    "groups_existing": ${EXISTING_GROUPS},
    "folders_created": ${CREATED_FOLDERS},
    "log_file": "${LOG_FILE}",
    "details": [
        $(IFS=,; echo "${RESULTS[*]}")
    ]
}

with open("${SUMMARY_JSON}", "w") as f:
    json.dump(data, f, indent=2)

print(f"Summary JSON saved to ${SUMMARY_JSON}")
PYEOF

log "INFO" "Department folder provisioning completed successfully."
exit 0
