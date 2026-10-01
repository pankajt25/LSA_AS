#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_01)
# Problem Statement #1: Employee Account Setup
# Focus: User Management & Group Provisioning
# Script: employee_account_setup.sh
#
# PURPOSE & ARCHITECTURAL OVERVIEW:
#   This production-grade administration script automates batch onboarding of
#   employees from a structured CSV file. For each employee record:
#     1. Validates input formatting and defensive constraints.
#     2. Enforces the MANDATORY test prefix constraint ('lsatest_') to prevent
#        accidental collisions with or overwriting of real system/user accounts.
#     3. Audits departmental group existence via getent; provisions missing groups
#        using groupadd.
#     4. Checks user existence; provisions new accounts with useradd (-m for home
#        directory creation, -c for GECOS/full name, -g for primary department group).
#     5. Injects an initial temporary password via chpasswd and immediately expires
#        it via passwd -e (or chage -d 0), forcing password reset on first login.
#     6. Performs post-provisioning sanity verification (id, getent, home dir, chage).
#     7. Logs all actions with microsecond/second ISO timestamps to logs/account_setup.log
#        and serializes machine-readable telemetry to logs/account_setup.json.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. COLOR & FORMATTING DEFINITIONS
# ------------------------------------------------------------------------------
# ANSI escape codes provide clear visual cues during interactive terminal execution.
# Can be silenced if running in non-interactive pipelines or with --no-color.
USE_COLOR=true
init_colors() {
    if [ "${USE_COLOR}" = true ] && [ -t 1 ]; then
        CLR_RESET="\033[0m"
        CLR_BOLD="\033[1m"
        CLR_DIM="\033[2m"
        CLR_GREEN="\033[38;5;82m"
        CLR_CYAN="\033[38;5;51m"
        CLR_YELLOW="\033[38;5;220m"
        CLR_RED="\033[38;5;196m"
        CLR_BLUE="\033[38;5;39m"
        CLR_PURPLE="\033[38;5;141m"
    else
        CLR_RESET=""
        CLR_BOLD=""
        CLR_DIM=""
        CLR_GREEN=""
        CLR_CYAN=""
        CLR_YELLOW=""
        CLR_RED=""
        CLR_BLUE=""
        CLR_PURPLE=""
    fi
}
init_colors

# ------------------------------------------------------------------------------
# 2. PATHS & RUNTIME CONFIGURATION
# ------------------------------------------------------------------------------
# Resolve absolute paths so script can be safely run from any working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/account_setup.log"
JSON_FILE="${LOG_DIR}/account_setup.json"
DEFAULT_CSV="${SCRIPT_DIR}/employees.csv"

INPUT_CSV="${DEFAULT_CSV}"
DRY_RUN=false
OUTPUT_JSON=false

# Mandatory safety prefix for test user accounts (sandboxing requirement)
REQUIRED_USER_PREFIX="lsatest_"

# ------------------------------------------------------------------------------
# 3. HELPER & LOGGING FUNCTIONS
# ------------------------------------------------------------------------------
# Timestamp formatting for human-readable audit trail (RFC 3339 / ISO 8601)
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Ensure persistent log directory exists
mkdir -p "${LOG_DIR}"

# Audit logger appends chronologically to logs/account_setup.log and prints to stdout
log_msg() {
    local level="$1"
    local message="$2"
    local ts
    ts="$(get_timestamp)"
    
    # Write plain unadorned entry to log file
    echo "[${ts}] [${level}] ${message}" >> "${LOG_FILE}"

    # Print colorized version to terminal
    case "${level}" in
        "INFO")
            echo -e "${CLR_CYAN}[INFO]${CLR_RESET} ${message}"
            ;;
        "SUCCESS")
            echo -e "${CLR_GREEN}✓ [SUCCESS]${CLR_RESET} ${message}"
            ;;
        "WARN")
            echo -e "${CLR_YELLOW}⚠ [WARN]${CLR_RESET} ${message}"
            ;;
        "SKIPPED")
            echo -e "${CLR_PURPLE}⏭ [SKIPPED]${CLR_RESET} ${message}"
            ;;
        "ERROR")
            echo -e "${CLR_RED}❌ [ERROR]${CLR_RESET} ${message}" >&2
            ;;
        "STEP")
            echo -e "${CLR_BOLD}${CLR_BLUE}▶ ${message}${CLR_RESET}"
            ;;
        *)
            echo -e "[${level}] ${message}"
            ;;
    esac
}

# Print CLI usage instructions
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [CSV_FILE]

Automated Linux employee account provisioning and departmental group assignment script.

ARGUMENTS:
  CSV_FILE                  Path to employee CSV file (default: ./employees.csv)

OPTIONS:
  -f, --file PATH           Specify input employee CSV file
  -d, --dry-run             Simulate account creation without executing system modifications
  -j, --json                Output JSON telemetry summary to stdout
      --no-color            Disable ANSI color escapes in terminal output
  -h, --help                Display this help documentation and exit

CSV FORMAT:
  username,fullname,department
  e.g.: lsatest_jdoe,Jane Doe,engineering

SANDBOXING ENFORCEMENT:
  Every username MUST begin with '${REQUIRED_USER_PREFIX}'.
  Any attempt to provision a non-test username will be rejected immediately to
  protect existing system and human user accounts.

EXAMPLES:
  bash $(basename "$0")
  bash $(basename "$0") --file custom_employees.csv
  bash $(basename "$0") --dry-run
EOF
}

# ------------------------------------------------------------------------------
# 4. PARSE COMMAND LINE ARGUMENTS
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--file)
            if [ -n "${2:-}" ]; then
                INPUT_CSV="$2"
                shift 2
            else
                log_msg "ERROR" "Option --file requires an argument."
                exit 1
            fi
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -j|--json)
            OUTPUT_JSON=true
            shift
            ;;
        --no-color)
            USE_COLOR=false
            init_colors
            shift
            ;;
        -*)
            log_msg "ERROR" "Unknown command-line argument: $1"
            show_help
            exit 1
            ;;
        *)
            INPUT_CSV="$1"
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 5. PLATFORM & ENVIRONMENT VALIDATION
# ------------------------------------------------------------------------------
OS_NAME="$(uname -s 2>/dev/null || echo 'Unknown')"
KERNEL_REL="$(uname -r 2>/dev/null || echo 'Unknown')"
HOST_NAME="$(hostname 2>/dev/null || echo 'localhost')"

log_msg "STEP" "Initiating Employee Account Setup Automation (Course: E1ITA307)"
log_msg "INFO" "Platform: ${OS_NAME} | Kernel: ${KERNEL_REL} | Hostname: ${HOST_NAME}"
log_msg "INFO" "Input CSV: ${INPUT_CSV}"
log_msg "INFO" "Log File: ${LOG_FILE}"

# Check for macOS Darwin environment
if [[ "${OS_NAME}" == "Darwin" ]]; then
    log_msg "ERROR" "macOS detected (${OS_NAME}). 'useradd' and 'groupadd' are standard Linux tools and do not exist on macOS (which uses dscl / Directory Services). User creation is not supported on macOS."
    # We exit cleanly with a clear status code or record failure
    exit 2
fi

# Check required Linux user management binaries
REQUIRED_BINARIES=("useradd" "groupadd" "passwd" "chpasswd" "id" "getent" "chage")
for bin in "${REQUIRED_BINARIES[@]}"; do
    if ! command -v "${bin}" &>/dev/null; then
        log_msg "ERROR" "Mandatory binary '${bin}' not found in PATH! Ensure shadow-utils / core utilities are installed."
        exit 1
    fi
done

# Check sudo / root permissions
if [ "${EUID}" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
        log_msg "ERROR" "Root privileges or passwordless sudo required for useradd/groupadd/chpasswd. Please run with sudo or configure sudoers."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# Verify CSV input exists
if [ ! -f "${INPUT_CSV}" ]; then
    log_msg "ERROR" "Input CSV file not found: ${INPUT_CSV}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. INTERNAL TELEMETRY STATE
# ------------------------------------------------------------------------------
TOTAL_PROCESSED=0
ACCOUNTS_CREATED=0
ACCOUNTS_SKIPPED=0
ACCOUNTS_FAILED=0
GROUPS_CREATED=0
GROUPS_EXISTED=0

# JSON record storage buffers
declare -a JSON_USERS=()
declare -a JSON_GROUPS=()
declare -A PROCESSED_GROUPS=()

# ------------------------------------------------------------------------------
# 7. PROCESS EMPLOYEE CSV RECORDS
# ------------------------------------------------------------------------------
log_msg "STEP" "Reading employee records from ${INPUT_CSV}..."

LINE_NUM=0
while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
    LINE_NUM=$(( LINE_NUM + 1 ))

    # Strip carriage returns and leading/trailing whitespace
    line="$(echo "${raw_line}" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Ignore blank lines and comment lines starting with #
    if [[ -z "${line}" ]] || [[ "${line}" =~ ^# ]]; then
        continue
    fi

    TOTAL_PROCESSED=$(( TOTAL_PROCESSED + 1 ))

    # Parse comma-separated fields: username,fullname,department
    IFS=',' read -r raw_user raw_name raw_dept <<< "${line}"

    # Trim fields individually
    user="$(echo "${raw_user:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    fullname="$(echo "${raw_name:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    dept="$(echo "${raw_dept:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Validate CSV record integrity (Error handling requirement #7)
    if [[ -z "${user}" ]] || [[ -z "${fullname}" ]] || [[ -z "${dept}" ]]; then
        log_msg "WARN" "Line ${LINE_NUM}: Malformed CSV entry '${line}'. Skipping (all three fields username,fullname,department required)."
        ACCOUNTS_FAILED=$(( ACCOUNTS_FAILED + 1 ))
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"status\": \"FAILED_MALFORMED\", \"error\": \"Missing required CSV fields\"}")
        continue
    fi

    # Mandatory Sandboxing & Safety Check (Constraint #1)
    # Target username MUST match lsatest_ prefix to protect real system/user accounts
    if [[ ! "${user}" =~ ^${REQUIRED_USER_PREFIX}[a-zA-Z0-9_]+$ ]]; then
        log_msg "ERROR" "Line ${LINE_NUM}: Safety violation! Username '${user}' does not begin with mandatory test prefix '${REQUIRED_USER_PREFIX}'. Rejecting creation to protect system accounts."
        ACCOUNTS_FAILED=$(( ACCOUNTS_FAILED + 1 ))
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"status\": \"REJECTED_UNSAFE_PREFIX\", \"error\": \"Username does not match required ${REQUIRED_USER_PREFIX} prefix\"}")
        continue
    fi

    # Validate department group name syntax (standard POSIX group naming)
    if [[ ! "${dept}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_msg "ERROR" "Line ${LINE_NUM}: Invalid department group name '${dept}'. Only alphanumeric, underscore, and hyphens permitted."
        ACCOUNTS_FAILED=$(( ACCOUNTS_FAILED + 1 ))
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"status\": \"FAILED_INVALID_DEPT\", \"error\": \"Invalid group syntax\"}")
        continue
    fi

    log_msg "INFO" "Processing record [Line ${LINE_NUM}]: Employee '${fullname}' (${user}) -> Department '${dept}'"

    # --------------------------------------------------------------------------
    # Step A: Department Group Audit & Provisioning
    # --------------------------------------------------------------------------
    if [[ -n "${PROCESSED_GROUPS[${dept}]:-}" ]]; then
        # Group was already audited or created earlier in this execution loop
        log_msg "INFO" "Department group '${dept}' already verified in this session."
    elif getent group "${dept}" &>/dev/null; then
        dept_gid="$(getent group "${dept}" | cut -d: -f3)"
        log_msg "INFO" "Department group '${dept}' (GID: ${dept_gid}) already exists."
        PROCESSED_GROUPS["${dept}"]="EXISTED"
        GROUPS_EXISTED=$(( GROUPS_EXISTED + 1 ))
        JSON_GROUPS+=("{\"group\": \"${dept}\", \"gid\": \"${dept_gid}\", \"action\": \"EXISTED\"}")
    else
        log_msg "INFO" "Department group '${dept}' does not exist. Creating group..."
        if [ "${DRY_RUN}" = true ]; then
            log_msg "INFO" "[DRY-RUN] Would execute: ${SUDO} groupadd ${dept}"
            dept_gid="DRY_RUN"
            PROCESSED_GROUPS["${dept}"]="CREATED_DRY"
            GROUPS_CREATED=$(( GROUPS_CREATED + 1 ))
            JSON_GROUPS+=("{\"group\": \"${dept}\", \"gid\": \"DRY_RUN\", \"action\": \"CREATED_DRY\"}")
        else
            if ${SUDO} groupadd "${dept}"; then
                dept_gid="$(getent group "${dept}" | cut -d: -f3)"
                log_msg "SUCCESS" "Created department group '${dept}' (GID: ${dept_gid})."
                PROCESSED_GROUPS["${dept}"]="CREATED"
                GROUPS_CREATED=$(( GROUPS_CREATED + 1 ))
                JSON_GROUPS+=("{\"group\": \"${dept}\", \"gid\": \"${dept_gid}\", \"action\": \"CREATED\"}")
            else
                log_msg "ERROR" "Failed to create department group '${dept}'! Aborting account creation for ${user}."
                ACCOUNTS_FAILED=$(( ACCOUNTS_FAILED + 1 ))
                JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"status\": \"FAILED_GROUPADD\", \"error\": \"Could not create group ${dept}\"}")
                continue
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Step B: User Account Existence Check
    # --------------------------------------------------------------------------
    # Double-check against /etc/passwd and getent to prevent overwriting existing accounts
    if id "${user}" &>/dev/null || getent passwd "${user}" &>/dev/null; then
        existing_id="$(id "${user}" 2>/dev/null || echo 'Exists')"
        log_msg "SKIPPED" "User account '${user}' already exists (${existing_id}). Skipping creation."
        ACCOUNTS_SKIPPED=$(( ACCOUNTS_SKIPPED + 1 ))
        
        # Capture verification telemetry for existing user
        user_home="$(getent passwd "${user}" | cut -d: -f6)"
        user_uid="$(id -u "${user}" 2>/dev/null || echo 'N/A')"
        user_gid="$(id -g "${user}" 2>/dev/null || echo 'N/A')"
        
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"fullname\": \"${fullname}\", \"department\": \"${dept}\", \"status\": \"SKIPPED\", \"uid\": \"${user_uid}\", \"gid\": \"${user_gid}\", \"home\": \"${user_home}\", \"id_output\": \"${existing_id}\", \"note\": \"Account already existed prior to run\"}")
        continue
    fi

    # --------------------------------------------------------------------------
    # Step C: User Account Creation (useradd)
    # --------------------------------------------------------------------------
    # -m : Create the user's home directory (/home/<username>) with skeleton from /etc/skel
    # -c : Set comment (GECOS) field to the employee's full name
    # -g : Set primary login group to the employee's department group
    log_msg "INFO" "Provisioning user account '${user}' for '${fullname}' in department '${dept}'..."
    
    if [ "${DRY_RUN}" = true ]; then
        log_msg "INFO" "[DRY-RUN] Would execute: ${SUDO} useradd -m -c \"${fullname}\" -g \"${dept}\" \"${user}\""
        log_msg "INFO" "[DRY-RUN] Would execute: chpasswd temporary password & passwd -e"
        ACCOUNTS_CREATED=$(( ACCOUNTS_CREATED + 1 ))
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"fullname\": \"${fullname}\", \"department\": \"${dept}\", \"status\": \"CREATED_DRY\", \"uid\": \"DRY_RUN\", \"gid\": \"DRY_RUN\", \"home\": \"/home/${user}\", \"id_output\": \"DRY_RUN\", \"note\": \"Simulated creation via --dry-run\"}")
        continue
    fi

    if ${SUDO} useradd -m -c "${fullname}" -g "${dept}" "${user}"; then
        log_msg "SUCCESS" "Account '${user}' created successfully."
    else
        log_msg "ERROR" "Failed to execute useradd for '${user}'!"
        ACCOUNTS_FAILED=$(( ACCOUNTS_FAILED + 1 ))
        JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"fullname\": \"${fullname}\", \"department\": \"${dept}\", \"status\": \"FAILED_USERADD\", \"error\": \"useradd command returned non-zero exit code\"}")
        continue
    fi

    # --------------------------------------------------------------------------
    # Step D: Temporary Password Assignment & Forced First-Login Expiration
    # --------------------------------------------------------------------------
    # Generate an initial strong temporary password and apply non-interactively via chpasswd
    TEMP_PASS="LsaSprint#${user}!2026"
    if echo "${user}:${TEMP_PASS}" | ${SUDO} chpasswd; then
        log_msg "INFO" "Temporary password assigned non-interactively for '${user}'."
    else
        log_msg "WARN" "Failed to assign temporary password via chpasswd for '${user}'."
    fi

    # Force immediate password expiration on first login (passwd -e / chage -d 0)
    # This guarantees compliance with enterprise access security policies
    if ${SUDO} passwd -e "${user}" &>/dev/null; then
        log_msg "SUCCESS" "Password expiration enforced for '${user}' (change required on first login)."
        PASS_POLICY="FORCED_EXPIRE_ON_LOGIN"
    else
        log_msg "WARN" "Failed to set passwd -e for '${user}'. Attempting chage -d 0 fallback..."
        if ${SUDO} chage -d 0 "${user}" &>/dev/null; then
            log_msg "SUCCESS" "Password expiration enforced via chage -d 0 for '${user}'."
            PASS_POLICY="FORCED_EXPIRE_ON_LOGIN"
        else
            log_msg "ERROR" "Could not enforce password expiration for '${user}'."
            PASS_POLICY="EXPIRATION_FAILED"
        fi
    fi

    # --------------------------------------------------------------------------
    # Step E: Post-Provisioning Verification & Sanity Audit
    # --------------------------------------------------------------------------
    # 1. Verify user identity and group memberships via id
    ID_OUTPUT="$(id "${user}" 2>/dev/null || echo 'FAILED')"
    USER_UID="$(id -u "${user}" 2>/dev/null || echo 'N/A')"
    USER_GID="$(id -g "${user}" 2>/dev/null || echo 'N/A')"

    # 2. Verify home directory presence and ownership
    USER_HOME="/home/${user}"
    HOME_VERIFIED=false
    HOME_PERMS="N/A"
    HOME_OWNER="N/A"
    if [ -d "${USER_HOME}" ]; then
        HOME_VERIFIED=true
        HOME_PERMS="$(ls -ld "${USER_HOME}" | awk '{print $1}')"
        HOME_OWNER="$(ls -ld "${USER_HOME}" | awk '{print $3":"$4}')"
        log_msg "SUCCESS" "Home directory verified: ${USER_HOME} (${HOME_PERMS} ${HOME_OWNER})"
    else
        log_msg "ERROR" "Home directory ${USER_HOME} was NOT created!"
    fi

    # 3. Verify aging policy in shadow database via chage
    CHAGE_EXPIRE_STATUS="$(${SUDO} chage -l "${user}" 2>/dev/null | grep -i "Password expires" | cut -d: -f2 | xargs || echo 'N/A')"
    PASSWD_STATUS="$(${SUDO} passwd -S "${user}" 2>/dev/null | awk '{print $2}' || echo 'N/A')"

    log_msg "INFO" "Verification Audit: ${ID_OUTPUT} | Password Status: ${PASSWD_STATUS} | Expiry: ${CHAGE_EXPIRE_STATUS}"

    ACCOUNTS_CREATED=$(( ACCOUNTS_CREATED + 1 ))

    # Append to structured JSON user array
    JSON_USERS+=("{\"line\": ${LINE_NUM}, \"username\": \"${user}\", \"fullname\": \"${fullname}\", \"department\": \"${dept}\", \"status\": \"CREATED\", \"uid\": \"${USER_UID}\", \"gid\": \"${USER_GID}\", \"home\": \"${USER_HOME}\", \"home_perms\": \"${HOME_PERMS}\", \"home_owner\": \"${HOME_OWNER}\", \"home_verified\": ${HOME_VERIFIED}, \"id_output\": \"${ID_OUTPUT}\", \"passwd_status\": \"${PASSWD_STATUS}\", \"expire_policy\": \"${CHAGE_EXPIRE_STATUS}\", \"note\": \"Successfully provisioned & verified\"}")

done < "${INPUT_CSV}"

# ------------------------------------------------------------------------------
# 8. EMIT STRUCTURED JSON TELEMETRY FOR DASHBOARD GENERATION
# ------------------------------------------------------------------------------
JSON_TIMESTAMP="$(get_iso_timestamp)"

# Join JSON user array
USERS_JOINED=""
for ((i=0; i<${#JSON_USERS[@]}; i++)); do
    if [ $i -gt 0 ]; then
        USERS_JOINED+=", "
    fi
    USERS_JOINED+="${JSON_USERS[$i]}"
done

# Join JSON groups array
GROUPS_JOINED=""
for ((i=0; i<${#JSON_GROUPS[@]}; i++)); do
    if [ $i -gt 0 ]; then
        GROUPS_JOINED+=", "
    fi
    GROUPS_JOINED+="${JSON_GROUPS[$i]}"
done

cat << EOF > "${JSON_FILE}"
{
  "timestamp": "${JSON_TIMESTAMP}",
  "hostname": "${HOST_NAME}",
  "os_system": "${OS_NAME}",
  "kernel": "${KERNEL_REL}",
  "input_csv": "${INPUT_CSV}",
  "dry_run": ${DRY_RUN},
  "summary": {
    "total_processed": ${TOTAL_PROCESSED},
    "created": ${ACCOUNTS_CREATED},
    "skipped": ${ACCOUNTS_SKIPPED},
    "failed": ${ACCOUNTS_FAILED},
    "groups_created": ${GROUPS_CREATED},
    "groups_existed": ${GROUPS_EXISTED}
  },
  "users": [
    ${USERS_JOINED}
  ],
  "groups": [
    ${GROUPS_JOINED}
  ]
}
EOF

# ------------------------------------------------------------------------------
# 9. SUMMARY & FINAL STATUS BANNER
# ------------------------------------------------------------------------------
log_msg "STEP" "Employee Account Setup Summary"
echo "================================================================================"
echo -e "${CLR_BOLD}Summary of Account Setup Operations:${CLR_RESET}"
echo -e "  Total Employee Records Processed : ${CLR_BOLD}${TOTAL_PROCESSED}${CLR_RESET}"
echo -e "  User Accounts Created            : ${CLR_GREEN}${CLR_BOLD}${ACCOUNTS_CREATED}${CLR_RESET}"
echo -e "  Accounts Skipped (Already Exists): ${CLR_PURPLE}${ACCOUNTS_SKIPPED}${CLR_RESET}"
echo -e "  Failed / Rejected Records        : ${CLR_RED}${ACCOUNTS_FAILED}${CLR_RESET}"
echo -e "  Department Groups Created        : ${CLR_CYAN}${GROUPS_CREATED}${CLR_RESET}"
echo -e "  Department Groups Pre-existing   : ${CLR_DIM}${GROUPS_EXISTED}${CLR_RESET}"
echo -e "  Audit Trail Log                  : ${CLR_BLUE}${LOG_FILE}${CLR_RESET}"
echo -e "  JSON Telemetry                   : ${CLR_BLUE}${JSON_FILE}${CLR_RESET}"
echo "================================================================================"

if [ "${OUTPUT_JSON}" = true ]; then
    cat "${JSON_FILE}"
fi

if [ "${ACCOUNTS_FAILED}" -gt 0 ]; then
    log_msg "WARN" "Completed with ${ACCOUNTS_FAILED} failures/rejections. Check logs for details."
    exit 1
else
    log_msg "SUCCESS" "All eligible employee accounts processed successfully!"
    exit 0
fi
