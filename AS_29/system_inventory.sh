#!/usr/bin/env bash
# ==============================================================================
# Script: system_inventory.sh
# Purpose: Comprehensive hardware, operating system, storage & network inventory (AS_29).
# Course: Linux System Administration (E1ITA307) - Automation Sprint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/system_inventory.log"
JSON_FILE="${LOG_DIR}/system_inventory.json"

mkdir -p "$LOG_DIR"

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
COLOR_BLUE="\033[34m"
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
# Help Manual
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Collect and display hardware specifications, operating system details, memory,
storage partitions, and network configuration.

Options:
  --json          Output structured JSON telemetry to console and logs/system_inventory.json
  --summary       Display compact high-level summary only
  -h, --help      Display this help manual and exit

Examples:
  ./system_inventory.sh                  # Full inventory audit
  ./system_inventory.sh --json           # Machine-readable JSON output
  ./system_inventory.sh --summary        # Quick executive summary
EOF
}

OUTPUT_JSON=false
SUMMARY_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --summary)
            SUMMARY_ONLY=true
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

# ------------------------------------------------------------------------------
# 1. Operating System & Kernel Telemetry
# ------------------------------------------------------------------------------
HOSTNAME_VAL="$(hostname 2>/dev/null || uname -n)"
KERNEL_VAL="$(uname -r)"
ARCH_VAL="$(uname -m)"
UPTIME_VAL="$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6,$7}')"

OS_NAME="Linux"
OS_VERSION="Unknown"
OS_PRETTY="Linux"

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_NAME="${NAME:-Linux}"
    OS_VERSION="${VERSION_ID:-Unknown}"
    OS_PRETTY="${PRETTY_NAME:-$OS_NAME}"
elif [ -f /etc/redhat-release ]; then
    OS_PRETTY="$(cat /etc/redhat-release)"
    OS_NAME="RedHat"
elif [ "$(uname -s)" = "Darwin" ]; then
    OS_NAME="macOS"
    OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo '')"
    OS_PRETTY="macOS $OS_VERSION"
fi

# ------------------------------------------------------------------------------
# 2. CPU Hardware Telemetry
# ------------------------------------------------------------------------------
CPU_MODEL="Unknown"
if [ -f /proc/cpuinfo ]; then
    CPU_MODEL="$(grep -m1 "model name" /proc/cpuinfo | awk -F': ' '{print $2}' | xargs)"
elif command -v lscpu >/dev/null 2>&1; then
    CPU_MODEL="$(lscpu | grep "Model name:" | awk -F': ' '{print $2}' | xargs)"
elif [ "$(uname -s)" = "Darwin" ]; then
    CPU_MODEL="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / Intel")"
fi

CPU_CORES="$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")"
CPU_MHZ="$(grep -m1 "cpu MHz" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' | cut -d'.' -f1 || echo "N/A")"

# ------------------------------------------------------------------------------
# 3. Memory & Swap Telemetry
# ------------------------------------------------------------------------------
MEM_TOTAL_MB=0
MEM_FREE_MB=0
MEM_AVAIL_MB=0
MEM_USED_MB=0
MEM_PCT=0

SWAP_TOTAL_MB=0
SWAP_FREE_MB=0
SWAP_USED_MB=0

if command -v free >/dev/null 2>&1; then
    # Parse free -m
    read -r _ MEM_TOTAL_MB MEM_USED_MB MEM_FREE_MB _ _ MEM_AVAIL_MB < <(free -m | grep -i "^Mem:" || echo "Mem: 0 0 0 0 0 0")
    read -r _ SWAP_TOTAL_MB SWAP_USED_MB SWAP_FREE_MB < <(free -m | grep -i "^Swap:" || echo "Swap: 0 0 0")
elif [ -f /proc/meminfo ]; then
    MEM_TOTAL_KB="$(grep -i "^MemTotal:" /proc/meminfo | awk '{print $2}')"
    MEM_AVAIL_KB="$(grep -i "^MemAvailable:" /proc/meminfo | awk '{print $2}')"
    MEM_TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
    MEM_AVAIL_MB=$(( MEM_AVAIL_KB / 1024 ))
    MEM_USED_MB=$(( MEM_TOTAL_MB - MEM_AVAIL_MB ))
fi

if (( MEM_TOTAL_MB > 0 )); then
    MEM_PCT="$(awk -v u="$MEM_USED_MB" -v t="$MEM_TOTAL_MB" 'BEGIN { printf "%.1f", (u/t)*100 }')"
fi

# ------------------------------------------------------------------------------
# 4. Storage & Filesystem Partitions
# ------------------------------------------------------------------------------
DISK_PARTITIONS=()
JSON_DISKS=()

# Using df -hP, ignoring transient virtual filesystems
while read -r fs size used avail pcent mount; do
    [[ "$fs" =~ ^(Filesystem|none)$ ]] && continue
    # Skip loop / snap mounts
    [[ "$fs" =~ ^/dev/loop ]] && continue
    DISK_PARTITIONS+=("$fs|$size|$used|$avail|$pcent|$mount")
    pct_clean="$(echo "$pcent" | tr -d '%')"
    JSON_DISKS+=("{\"filesystem\":\"$fs\",\"size\":\"$size\",\"used\":\"$used\",\"available\":\"$avail\",\"use_percent\":\"$pcent\",\"use_percent_val\":$pct_clean,\"mount_point\":\"$mount\"}")
done < <(df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -hP)

# ------------------------------------------------------------------------------
# 5. Network Interfaces & IP Addresses
# ------------------------------------------------------------------------------
NET_INTERFACES=()
JSON_NET=()

if command -v ip >/dev/null 2>&1; then
    while read -r iface state addrs; do
        [[ -z "$iface" ]] && continue
        mac="N/A"
        if [ -f "/sys/class/net/${iface}/address" ]; then
            mac="$(cat "/sys/class/net/${iface}/address" 2>/dev/null || echo "N/A")"
        fi
        NET_INTERFACES+=("$iface|$state|$mac|$addrs")
        JSON_NET+=("{\"interface\":\"$iface\",\"state\":\"$state\",\"mac_address\":\"$mac\",\"ip_addresses\":\"$addrs\"}")
    done < <(ip -br addr show 2>/dev/null || true)
elif command -v ifconfig >/dev/null 2>&1; then
    # Fallback to ifconfig
    for iface in $(ifconfig -s 2>/dev/null | awk 'NR>1 {print $1}'); do
        ip_addr="$(ifconfig "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo "None")"
        mac="N/A"
        NET_INTERFACES+=("$iface|UP|$mac|$ip_addr")
        JSON_NET+=("{\"interface\":\"$iface\",\"state\":\"UP\",\"mac_address\":\"$mac\",\"ip_addresses\":\"$ip_addr\"}")
    done
fi

log "INFO" "Audited system inventory for host '$HOSTNAME_VAL' ($OS_PRETTY)"

# ------------------------------------------------------------------------------
# Terminal Display
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}         COMPREHENSIVE SYSTEM INVENTORY & SPECIFICATION (AS_29)                 ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e " Hostname            : ${COLOR_BOLD}${HOSTNAME_VAL}${COLOR_RESET}"
echo -e " Operating System    : ${COLOR_GREEN}${COLOR_BOLD}${OS_PRETTY}${COLOR_RESET} (Version: ${OS_VERSION})"
echo -e " Kernel Version      : ${COLOR_BOLD}${KERNEL_VAL}${COLOR_RESET} (${ARCH_VAL})"
echo -e " System Uptime       : ${COLOR_CYAN}${UPTIME_VAL}${COLOR_RESET}"
echo -e " Timestamp           : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_CYAN}--------------------------------------------------------------------------------${COLOR_RESET}"

echo -e "${COLOR_BOLD}1. CPU HARDWARE SPECIFICATIONS:${COLOR_RESET}"
echo -e "  Processor Model    : ${COLOR_BOLD}${CPU_MODEL}${COLOR_RESET}"
echo -e "  CPU Cores / Threads: ${COLOR_GREEN}${COLOR_BOLD}${CPU_CORES}${COLOR_RESET} Cores"
if [[ "$CPU_MHZ" != "N/A" ]]; then
    echo -e "  Clock Frequency    : ~${CPU_MHZ} MHz"
fi
echo ""

echo -e "${COLOR_BOLD}2. MEMORY & SWAP ALLOCATION:${COLOR_RESET}"
printf "  %-18s : %s MB Total | %s MB Used (%s%%) | %s MB Available\n" \
    "Physical RAM" "${MEM_TOTAL_MB}" "${MEM_USED_MB}" "${MEM_PCT}" "${MEM_AVAIL_MB}"
printf "  %-18s : %s MB Total | %s MB Used | %s MB Free\n" \
    "Virtual Swap" "${SWAP_TOTAL_MB}" "${SWAP_USED_MB}" "${SWAP_FREE_MB}"
echo ""

echo -e "${COLOR_BOLD}3. DISK PARTITIONS & STORAGE VOLUMES:${COLOR_RESET}"
printf "  %-18s %-10s %-10s %-10s %-8s %s\n" "FILESYSTEM" "SIZE" "USED" "AVAIL" "USE%" "MOUNT POINT"
echo "  --------------------------------------------------------------------------"
for d in "${DISK_PARTITIONS[@]}"; do
    IFS='|' read -r fs size used avail pcent mount <<< "$d"
    printf "  %-18s %-10s %-10s %-10s %-8s %s\n" "$fs" "$size" "$used" "$avail" "$pcent" "$mount"
done
echo ""

echo -e "${COLOR_BOLD}4. NETWORK INTERFACES & IP CONFIGURATION:${COLOR_RESET}"
printf "  %-14s %-10s %-20s %s\n" "INTERFACE" "STATE" "MAC ADDRESS" "IP ADDRESSES"
echo "  --------------------------------------------------------------------------"
for n in "${NET_INTERFACES[@]}"; do
    IFS='|' read -r iface state mac addrs <<< "$n"
    state_colored="${COLOR_GREEN}${state}${COLOR_RESET}"
    [[ "$state" == "DOWN" ]] && state_colored="${COLOR_RED}${state}${COLOR_RESET}"
    printf "  %-14s %-19b %-20s %s\n" "$iface" "$state_colored" "$mac" "$addrs"
done
echo -e "${COLOR_CYAN}================================================================================${COLOR_RESET}"

# ------------------------------------------------------------------------------
# JSON Serialization
# ------------------------------------------------------------------------------
JSON_DISKS_JOINED="$(IFS=,; echo "${JSON_DISKS[*]}")"
JSON_NET_JOINED="$(IFS=,; echo "${JSON_NET[*]}")"

cat <<EOF > "$JSON_FILE"
{
  "problem_id": "AS_29",
  "title": "System Inventory Audit",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "timestamp_epoch": $(date +%s),
  "system": {
    "hostname": "$HOSTNAME_VAL",
    "os_name": "$OS_NAME",
    "os_version": "$OS_VERSION",
    "os_pretty": "$OS_PRETTY",
    "kernel": "$KERNEL_VAL",
    "architecture": "$ARCH_VAL",
    "uptime": "$UPTIME_VAL"
  },
  "cpu": {
    "model": "$CPU_MODEL",
    "cores": $CPU_CORES,
    "clock_mhz": "$CPU_MHZ"
  },
  "memory": {
    "total_mb": $MEM_TOTAL_MB,
    "used_mb": $MEM_USED_MB,
    "available_mb": $MEM_AVAIL_MB,
    "free_mb": $MEM_FREE_MB,
    "usage_percent": "$MEM_PCT%",
    "swap_total_mb": $SWAP_TOTAL_MB,
    "swap_used_mb": $SWAP_USED_MB,
    "swap_free_mb": $SWAP_FREE_MB
  },
  "storage": [
    $JSON_DISKS_JOINED
  ],
  "network": [
    $JSON_NET_JOINED
  ]
}
EOF

if [[ "$OUTPUT_JSON" == true ]]; then
    cat "$JSON_FILE"
fi

exit 0
