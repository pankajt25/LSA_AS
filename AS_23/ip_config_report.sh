#!/usr/bin/env bash
# ==============================================================================
# Linux System Administration (E1ITA307) — Automation Sprint (AS_23)
# Problem Statement #23: IP Configuration Report
# Focus: Network Administration & System Audit
#
# ARCHITECTURAL RATIONALE: WHY iproute2 (ip) OVER net-tools (ifconfig / route)
# ------------------------------------------------------------------------------
# In contemporary Linux system administration, the 'iproute2' suite (primarily
# the 'ip' binary) has completely superseded the legacy 'net-tools' package
# ('ifconfig', 'route', 'arp', 'netstat') for critical architectural reasons:
#
# 1. NETLINK KERNEL INTERACTION (rtnetlink) VS ARCHAIC IOCTL:
#    The legacy 'ifconfig' utility interacts with the Linux kernel via synchronous
#    ioctl() system calls (e.g. SIOCGIFADDR). These calls are slow, inflexible,
#    and cannot convey modern kernel networking state. In contrast, 'iproute2'
#    communicates with the kernel networking subsystem via rtnetlink (AF_NETLINK)
#    bidirectional datagram sockets. This allows asynchronous, high-throughput,
#    atomic transactions and real-time state event monitoring.
#
# 2. NATIVE MULTI-IP & CIDR ADDRESSING WITHOUT ALIAS HACKS:
#    In modern networking, interfaces frequently bind dozens or hundreds of
#    IPv4 and IPv6 addresses. Legacy 'ifconfig' required creating artificial
#    virtual sub-interface aliases (e.g., eth0:0, eth0:1) to assign secondary
#    addresses, and fails to display secondary addresses added without labels.
#    The 'ip' command natively treats IP addresses as discrete objects bound
#    to a link, displaying all primary and secondary addresses with native CIDR
#    prefix notation (e.g. 192.168.1.10/24) rather than dotted netmasks.
#
# 3. MODERN NAMESPACES, VRFs, AND VIRTUAL DEVICES:
#    Modern cloud-native and containerized workloads (Docker, Podman, Kubernetes)
#    rely on network namespaces (netns), virtual ethernet (veth) pairs, bridges,
#    and Virtual Routing and Forwarding (VRF) domains. Legacy 'ifconfig' has zero
#    concept of namespaces or modern link types. 'ip link' and 'ip netns' provide
#    full lifecycle management across all virtual and physical devices.
#
# 4. POLICY ROUTING AND MULTIPATH:
#    Legacy 'route' only interacts with the default kernel routing table.
#    'ip route' and 'ip rule' support Policy-Based Routing (PBR), multiple routing
#    tables (FIB), multipath routing, metric prioritizations, and flow attributes.
#
# 5. ACTIVE MAINTENANCE & DISTRO PACKAGING:
#    The Linux Foundation and core kernel developers deprecated 'net-tools' in
#    the late 2000s. Contemporary distributions (Ubuntu 20.04+, Debian 10+,
#    RHEL/CentOS 8+, Fedora, Arch) no longer install 'net-tools' by default.
#    'iproute2' is maintained in direct lockstep with Linux kernel releases.
# ==============================================================================

set -uo pipefail

# Determine script and report storage directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORTS_DIR}"

# Execution timestamp
TIMESTAMP_ISO="$(date '+%Y-%m-%d %H:%M:%S %Z')"
TIMESTAMP_FILE="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORTS_DIR}/ip_report_${TIMESTAMP_FILE}.txt"
LATEST_REPORT_FILE="${REPORTS_DIR}/latest_ip_report.txt"
JSON_META_FILE="${REPORTS_DIR}/.last_report.json"

# ANSI Color configuration (disabled if stdout is redirected or --no-color is set)
USE_COLOR=true
if [ ! -t 1 ] || [[ "${*:-}" == *"--no-color"* ]]; then
    USE_COLOR=false
fi

if [ "${USE_COLOR}" = true ]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_CYAN='\033[36m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_DIM='\033[2m'
else
    C_RESET=''
    C_BOLD=''
    C_CYAN=''
    C_GREEN=''
    C_YELLOW=''
    C_RED=''
    C_BLUE=''
    C_MAGENTA=''
    C_DIM=''
fi

# Print usage / help manual
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Comprehensive IP Configuration & Network Interface Audit Tool.
Queries hostname, active network interfaces, MAC addresses, MTU, default
gateway, and DNS configuration using modern 'iproute2' kernel utilities.

OPTIONS:
  -h, --help        Show this help documentation and exit
  --no-color        Disable ANSI terminal color output
  --json            Output network report in raw JSON format to stdout

OUTPUT FILES:
  reports/ip_report_<timestamp>.txt   Timestamped plain-text report
  reports/latest_ip_report.txt        Pointer to the most recent run
  reports/.last_report.json           Structured telemetry data for HTML generation

Course: Linux System Administration (E1ITA307)
EOF
    exit 0
}

# Parse command-line flags
OUTPUT_JSON_ONLY=false
for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            show_help
            ;;
        --no-color)
            USE_COLOR=false
            ;;
        --json)
            OUTPUT_JSON_ONLY=true
            ;;
        *)
            # Ignore unknown flags or let execution proceed
            ;;
    esac
done

# ==============================================================================
# SECTION 1: SYSTEM & HOST IDENTIFICATION
# Logic: Query system hostname using 'hostname', 'uname -n', or /etc/hostname.
# Query all assigned IPs in one single line summary using 'hostname -I'.
# If 'hostname -I' is unsupported (e.g. macOS or stripped container), fall back
# to extracting all IPv4 addresses from network interfaces.
# ==============================================================================
SYS_HOSTNAME="$(hostname 2>/dev/null || uname -n 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'localhost')"
SYS_HOSTNAME="$(echo "${SYS_HOSTNAME}" | tr -d '\r\n')"

# Gather all assigned IP addresses as a quick one-line summary
ALL_IPS_SUMMARY=""
if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
    ALL_IPS_SUMMARY="$(hostname -I | awk '{$1=$1;print}')"
fi

# Fallback if hostname -I is empty or failed
if [ -z "${ALL_IPS_SUMMARY}" ]; then
    if command -v ip >/dev/null 2>&1; then
        ALL_IPS_SUMMARY="$(ip -4 addr show 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | tr '\n' ' ' | awk '{$1=$1;print}')"
    elif command -v ifconfig >/dev/null 2>&1; then
        ALL_IPS_SUMMARY="$(ifconfig 2>/dev/null | grep -oE 'inet (addr:)?([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $NF}' | tr '\n' ' ' | awk '{$1=$1;print}')"
    fi
fi
[ -z "${ALL_IPS_SUMMARY}" ] && ALL_IPS_SUMMARY="None detected"

# System OS details
SYS_OS="$(uname -s)"
SYS_KERNEL="$(uname -r 2>/dev/null || echo 'Unknown')"
SYS_ARCH="$(uname -m 2>/dev/null || echo 'Unknown')"
SYS_DISTRO="Linux"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    SYS_DISTRO="${PRETTY_NAME:-$NAME}"
elif [ "${SYS_OS}" = "Darwin" ]; then
    SYS_DISTRO="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
fi

# ==============================================================================
# SECTION 2: DEFAULT GATEWAY & ROUTING AUDIT
# Logic: Query kernel routing table using 'ip route' (preferred) or 'route -n'.
# Extract the default gateway IP address, outgoing interface, and protocol/metric.
# ==============================================================================
DEFAULT_GW_IP="None"
DEFAULT_GW_IFACE="None"
DEFAULT_GW_METRIC="N/A"
DEFAULT_GW_PROTO="kernel"
RAW_DEFAULT_ROUTE=""

if command -v ip >/dev/null 2>&1; then
    # Parse modern ip route output: "default via <IP> dev <IFACE> proto <PROTO> metric <METRIC>"
    RAW_DEFAULT_ROUTE="$(ip route show default 2>/dev/null | head -n 1)"
    if [ -z "${RAW_DEFAULT_ROUTE}" ]; then
        RAW_DEFAULT_ROUTE="$(ip route 2>/dev/null | grep -E '^default' | head -n 1 || true)"
    fi

    if [ -n "${RAW_DEFAULT_ROUTE}" ]; then
        DEFAULT_GW_IP="$(echo "${RAW_DEFAULT_ROUTE}" | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}')"
        DEFAULT_GW_IFACE="$(echo "${RAW_DEFAULT_ROUTE}" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')"
        METRIC_VAL="$(echo "${RAW_DEFAULT_ROUTE}" | awk '{for(i=1;i<=NF;i++) if($i=="metric") print $(i+1)}')"
        PROTO_VAL="$(echo "${RAW_DEFAULT_ROUTE}" | awk '{for(i=1;i<=NF;i++) if($i=="proto") print $(i+1)}')"
        [ -n "${METRIC_VAL}" ] && DEFAULT_GW_METRIC="${METRIC_VAL}"
        [ -n "${PROTO_VAL}" ] && DEFAULT_GW_PROTO="${PROTO_VAL}"
    fi
elif command -v route >/dev/null 2>&1; then
    # Legacy Linux fallback: route -n
    LEGACY_ROUTE="$(route -n 2>/dev/null | awk '$1=="0.0.0.0" {print $2, $8; exit}')"
    if [ -n "${LEGACY_ROUTE}" ]; then
        DEFAULT_GW_IP="$(echo "${LEGACY_ROUTE}" | awk '{print $1}')"
        DEFAULT_GW_IFACE="$(echo "${LEGACY_ROUTE}" | awk '{print $2}')"
        RAW_DEFAULT_ROUTE="0.0.0.0 via ${DEFAULT_GW_IP} dev ${DEFAULT_GW_IFACE}"
    fi
elif [ "${SYS_OS}" = "Darwin" ] && command -v netstat >/dev/null 2>&1; then
    # macOS fallback: route -n get default or netstat -rn
    MAC_GW="$(route -n get default 2>/dev/null || true)"
    if [ -n "${MAC_GW}" ]; then
        DEFAULT_GW_IP="$(echo "${MAC_GW}" | awk '/gateway:/ {print $2}')"
        DEFAULT_GW_IFACE="$(echo "${MAC_GW}" | awk '/interface:/ {print $2}')"
        RAW_DEFAULT_ROUTE="default via ${DEFAULT_GW_IP} dev ${DEFAULT_GW_IFACE}"
    fi
fi

[ -z "${DEFAULT_GW_IP}" ] && DEFAULT_GW_IP="None"
[ -z "${DEFAULT_GW_IFACE}" ] && DEFAULT_GW_IFACE="None"

# ==============================================================================
# SECTION 3: DNS RESOLVER DISCOVERY
# Logic: Inspect /etc/resolv.conf for active 'nameserver' and 'search' directives.
# Also probe 'resolvectl' / 'systemd-resolve' if present for systemd-resolved info.
# ==============================================================================
DNS_SERVERS_LIST=()
DNS_SEARCH_DOMAINS=""

if [ -r /etc/resolv.conf ]; then
    while read -r line; do
        # Extract nameservers (ignoring comments and blank lines)
        if [[ "${line}" =~ ^[[:space:]]*nameserver[[:space:]]+([^[:space:]#]+) ]]; then
            DNS_SERVERS_LIST+=("${BASH_REMATCH[1]}")
        elif [[ "${line}" =~ ^[[:space:]]*(search|domain)[[:space:]]+(.*) ]]; then
            DNS_SEARCH_DOMAINS="${BASH_REMATCH[2]}"
        fi
    done < /etc/resolv.conf
fi

# Fallback or supplemental DNS query via resolvectl if /etc/resolv.conf has only stub
if [ "${#DNS_SERVERS_LIST[@]}" -eq 0 ] && command -v resolvectl >/dev/null 2>&1; then
    SYSTEMD_DNS="$(resolvectl dns 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)"
    if [ -n "${SYSTEMD_DNS}" ]; then
        while read -r dns_ip; do
            [ -n "${dns_ip}" ] && DNS_SERVERS_LIST+=("${dns_ip}")
        done <<< "${SYSTEMD_DNS}"
    fi
fi

# Format DNS display string
DNS_SERVERS_STR="None detected"
if [ "${#DNS_SERVERS_LIST[@]}" -gt 0 ]; then
    DNS_SERVERS_STR="$(IFS=', '; echo "${DNS_SERVERS_LIST[*]}")"
fi

# ==============================================================================
# SECTION 4: ACTIVE INTERFACES & PER-INTERFACE DETAIL AUDIT
# Logic:
# 1. Discover all active interfaces. An interface is active if it is administratively
#    UP (or UNKNOWN for loopback devices carrying UP flag).
# 2. Prefer modern 'ip -br addr show up' or parse 'ip addr show'.
# 3. For each active interface:
#    - Query interface state (UP, UNKNOWN)
#    - Query link/MAC address via 'ip link show <iface>' (fallback to /sys/class/net/<iface>/address)
#    - Query MTU via 'ip link show <iface>' (fallback to /sys/class/net/<iface>/mtu)
#    - Extract all IPv4 addresses with CIDR
#    - Extract all IPv6 addresses with CIDR
#    - Identify interface type (Loopback, Ethernet, Wi-Fi, Virtual Bridge/Tunnel)
# ==============================================================================

# Data structures to store interface records
declare -a IFACE_NAMES=()
declare -A IFACE_STATE=()
declare -A IFACE_MAC=()
declare -A IFACE_MTU=()
declare -A IFACE_IPV4=()
declare -A IFACE_IPV6=()
declare -A IFACE_TYPE=()

TOOL_USED="iproute2 (ip)"

# Check tool availability and populate interface list
if command -v ip >/dev/null 2>&1; then
    # Test if 'ip -br' (brief format) is supported
    if ip -br addr show up >/dev/null 2>&1; then
        # 'ip -br addr show up' returns: <iface> <state> <addrs...>
        while read -r line; do
            [ -z "${line}" ] && continue
            read -r if_name if_state if_addrs <<< "${line}"
            IFACE_NAMES+=("${if_name}")
            IFACE_STATE["${if_name}"]="${if_state}"

            # Separate IPv4 and IPv6 addresses
            local_ipv4=()
            local_ipv6=()
            for addr in ${if_addrs:-}; do
                if [[ "${addr}" == *":"* ]]; then
                    local_ipv6+=("${addr}")
                elif [[ "${addr}" == *"."* ]]; then
                    local_ipv4+=("${addr}")
                fi
            done
            IFACE_IPV4["${if_name}"]="$(IFS=', '; echo "${local_ipv4[*]:-None}")"
            IFACE_IPV6["${if_name}"]="$(IFS=', '; echo "${local_ipv6[*]:-None}")"
        done < <(ip -br addr show up 2>/dev/null)
    else
        # Fallback to parsing standard 'ip addr show'
        current_if=""
        while read -r line; do
            if [[ "${line}" =~ ^[0-9]+:[[:space:]]+([^:@]+) ]]; then
                current_if="${BASH_REMATCH[1]}"
                flag_up_pattern='<[^>]*UP[^>]*>'
                if [[ "${line}" =~ ${flag_up_pattern} ]]; then
                    IFACE_NAMES+=("${current_if}")
                    if [[ "${line}" =~ state[[:space:]]+([A-Z]+) ]]; then
                        IFACE_STATE["${current_if}"]="${BASH_REMATCH[1]}"
                    else
                        IFACE_STATE["${current_if}"]="UP"
                    fi
                    IFACE_IPV4["${current_if}"]=""
                    IFACE_IPV6["${current_if}"]=""
                else
                    current_if=""
                fi
            elif [ -n "${current_if}" ]; then
                if [[ "${line}" =~ inet[[:space:]]+([^[:space:]]+) ]]; then
                    cur_v4="${IFACE_IPV4["${current_if}"]}"
                    ip_cidr="${BASH_REMATCH[1]}"
                    IFACE_IPV4["${current_if}"]="${cur_v4:+${cur_v4}, }${ip_cidr}"
                elif [[ "${line}" =~ inet6[[:space:]]+([^[:space:]]+) ]]; then
                    cur_v6="${IFACE_IPV6["${current_if}"]}"
                    ip_cidr="${BASH_REMATCH[1]}"
                    IFACE_IPV6["${current_if}"]="${cur_v6:+${cur_v6}, }${ip_cidr}"
                fi
            fi
        done < <(ip addr show 2>/dev/null)
        for ifn in "${IFACE_NAMES[@]}"; do
            [ -z "${IFACE_IPV4["${ifn}"]}" ] && IFACE_IPV4["${ifn}"]="None"
            [ -z "${IFACE_IPV6["${ifn}"]}" ] && IFACE_IPV6["${ifn}"]="None"
        done
    fi

    # Query per-interface MAC and MTU via 'ip link show'
    for ifn in "${IFACE_NAMES[@]}"; do
        LINK_OUTPUT="$(ip link show "${ifn}" 2>/dev/null || true)"
        
        # MAC extraction: link/ether, link/loopback, etc.
        mac_val="$(echo "${LINK_OUTPUT}" | awk '/link\// {print $2}' | head -n 1)"
        if [ -z "${mac_val}" ] && [ -r "/sys/class/net/${ifn}/address" ]; then
            mac_val="$(cat "/sys/class/net/${ifn}/address" 2>/dev/null || echo '00:00:00:00:00:00')"
        fi
        [ -z "${mac_val}" ] && mac_val="00:00:00:00:00:00"
        IFACE_MAC["${ifn}"]="${mac_val}"

        # MTU extraction
        mtu_val="$(echo "${LINK_OUTPUT}" | awk '{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}' | head -n 1)"
        if [ -z "${mtu_val}" ] && [ -r "/sys/class/net/${ifn}/mtu" ]; then
            mtu_val="$(cat "/sys/class/net/${ifn}/mtu" 2>/dev/null || echo '1500')"
        fi
        [ -z "${mtu_val}" ] && mtu_val="1500"
        IFACE_MTU["${ifn}"]="${mtu_val}"

        # Determine Interface Type
        if [ "${ifn}" = "lo" ]; then
            IFACE_TYPE["${ifn}"]="Loopback"
        elif [[ "${ifn}" =~ ^(eth|en|em|eno|ens|enp) ]]; then
            IFACE_TYPE["${ifn}"]="Physical Ethernet"
        elif [[ "${ifn}" =~ ^(wl|wlan|wifi) ]]; then
            IFACE_TYPE["${ifn}"]="Wireless (Wi-Fi)"
        elif [[ "${ifn}" =~ ^(br|docker|cni|flannel|virbr) ]]; then
            IFACE_TYPE["${ifn}"]="Bridge / Container"
        elif [[ "${ifn}" =~ ^(veth) ]]; then
            IFACE_TYPE["${ifn}"]="Virtual Ethernet Pair"
        elif [[ "${ifn}" =~ ^(tun|tap|wg) ]]; then
            IFACE_TYPE["${ifn}"]="Tunnel / VPN"
        else
            IFACE_TYPE["${ifn}"]="Virtual / Other"
        fi
    done

elif command -v ifconfig >/dev/null 2>&1; then
    # Legacy fallback: net-tools ifconfig
    TOOL_USED="net-tools (ifconfig [LEGACY])"
    
    # Parse active interfaces from ifconfig
    IFCONFIG_RAW="$(ifconfig 2>/dev/null)"
    # Collect interface names
    while IFS= read -r if_line; do
        if [[ "${if_line}" =~ ^([a-zA-Z0-9_.-]+):?[[:space:]]+flags ]]; then
            # Modern BSD / Linux ifconfig format
            ifn="${BASH_REMATCH[1]}"
            IFACE_NAMES+=("${ifn}")
            IFACE_STATE["${ifn}"]="UP"
        elif [[ "${if_line}" =~ ^([a-zA-Z0-9_.-]+)[[:space:]]+Link ]]; then
            # Classic Linux ifconfig format
            ifn="${BASH_REMATCH[1]}"
            IFACE_NAMES+=("${ifn}")
            IFACE_STATE["${ifn}"]="UP"
        fi
    done <<< "${IFCONFIG_RAW}"

    # Extract details for each interface
    for ifn in "${IFACE_NAMES[@]}"; do
        SINGLE_IF="$(ifconfig "${ifn}" 2>/dev/null || true)"
        
        # MAC
        mac_val="$(echo "${SINGLE_IF}" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n 1 || true)"
        [ -z "${mac_val}" ] && mac_val="00:00:00:00:00:00"
        IFACE_MAC["${ifn}"]="${mac_val}"

        # MTU
        mtu_val="$(echo "${SINGLE_IF}" | grep -oE '(mtu|MTU:)[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -n 1 || true)"
        [ -z "${mtu_val}" ] && mtu_val="1500"
        IFACE_MTU["${ifn}"]="${mtu_val}"

        # IPv4
        v4_val="$(echo "${SINGLE_IF}" | grep -oE 'inet (addr:)?[0-9.]+' | awk '{print $NF}' | tr '\n' ', ' | sed 's/, $//' || true)"
        [ -z "${v4_val}" ] && v4_val="None"
        IFACE_IPV4["${ifn}"]="${v4_val}"

        # IPv6
        v6_val="$(echo "${SINGLE_IF}" | grep -oE 'inet6 (addr:)?[0-9a-fA-F:]+' | awk '{print $NF}' | tr '\n' ', ' | sed 's/, $//' || true)"
        [ -z "${v6_val}" ] && v6_val="None"
        IFACE_IPV6["${ifn}"]="${v6_val}"

        if [ "${ifn}" = "lo" ]; then
            IFACE_TYPE["${ifn}"]="Loopback"
        else
            IFACE_TYPE["${ifn}"]="Network Interface"
        fi
    done
else
    # Sysfs/procfs emergency fallback
    TOOL_USED="Kernel Sysfs/Procfs (/sys/class/net)"
    if [ -d /sys/class/net ]; then
        for dev in /sys/class/net/*; do
            [ -e "${dev}" ] || continue
            ifn="$(basename "${dev}")"
            operstate="$(cat "${dev}/operstate" 2>/dev/null || echo 'unknown')"
            if [ "${operstate}" = "up" ] || [ "${operstate}" = "unknown" ]; then
                IFACE_NAMES+=("${ifn}")
                IFACE_STATE["${ifn}"]="$(echo "${operstate}" | tr '[:lower:]' '[:upper:]')"
                IFACE_MAC["${ifn}"]="$(cat "${dev}/address" 2>/dev/null || echo '00:00:00:00:00:00')"
                IFACE_MTU["${ifn}"]="$(cat "${dev}/mtu" 2>/dev/null || echo '1500')"
                IFACE_IPV4["${ifn}"]="Query tool unavailable"
                IFACE_IPV6["${ifn}"]="Query tool unavailable"
                IFACE_TYPE["${ifn}"]="Kernel Sysfs Link"
            fi
        done
    fi
fi

# Detect primary interface and primary IPv4 address
PRIMARY_IFACE="${DEFAULT_GW_IFACE}"
PRIMARY_IP="None"
if [ "${PRIMARY_IFACE}" != "None" ] && [ -n "${IFACE_IPV4["${PRIMARY_IFACE}"]:-}" ]; then
    PRIMARY_IP="$(echo "${IFACE_IPV4["${PRIMARY_IFACE}"]}" | cut -d',' -f1 | tr -d ' ')"
elif [ "${#IFACE_NAMES[@]}" -gt 0 ]; then
    # Pick first non-loopback active interface
    for ifn in "${IFACE_NAMES[@]}"; do
        if [ "${ifn}" != "lo" ] && [ -n "${IFACE_IPV4["${ifn}"]:-}" ] && [ "${IFACE_IPV4["${ifn}"]}" != "None" ]; then
            PRIMARY_IFACE="${ifn}"
            PRIMARY_IP="$(echo "${IFACE_IPV4["${ifn}"]}" | cut -d',' -f1 | tr -d ' ')"
            break
        fi
    done
fi

TOTAL_ACTIVE_IFACES="${#IFACE_NAMES[@]}"

# ==============================================================================
# SECTION 5: STRUCTURED DATA EXPORT (.last_report.json)
# Saves complete machine-readable telemetry for run.sh HTML dashboard generation.
# ==============================================================================
cat > "${JSON_META_FILE}" << EOF
{
  "timestamp": "${TIMESTAMP_ISO}",
  "hostname": "${SYS_HOSTNAME}",
  "os_distro": "${SYS_DISTRO}",
  "kernel": "${SYS_KERNEL}",
  "arch": "${SYS_ARCH}",
  "tool_used": "${TOOL_USED}",
  "all_ips_summary": "${ALL_IPS_SUMMARY}",
  "default_gateway": {
    "ip": "${DEFAULT_GW_IP}",
    "interface": "${DEFAULT_GW_IFACE}",
    "protocol": "${DEFAULT_GW_PROTO}",
    "metric": "${DEFAULT_GW_METRIC}",
    "raw": "${RAW_DEFAULT_ROUTE}"
  },
  "dns": {
    "servers": [$(printf '"%s",' "${DNS_SERVERS_LIST[@]}" | sed 's/,$//')],
    "search_domains": "${DNS_SEARCH_DOMAINS}"
  },
  "summary": {
    "total_active_interfaces": ${TOTAL_ACTIVE_IFACES},
    "primary_interface": "${PRIMARY_IFACE}",
    "primary_ip": "${PRIMARY_IP}"
  },
  "interfaces": [
EOF

    total_items="${#IFACE_NAMES[@]}"
    idx=0
    for ifn in "${IFACE_NAMES[@]}"; do
        idx=$((idx + 1))
        comma=","
        [ "${idx}" -eq "${total_items}" ] && comma=""
        cat >> "${JSON_META_FILE}" << EOF
    {
      "name": "${ifn}",
      "state": "${IFACE_STATE["${ifn}"]:-UNKNOWN}",
      "type": "${IFACE_TYPE["${ifn}"]:-Unknown}",
      "mac": "${IFACE_MAC["${ifn}"]:-00:00:00:00:00:00}",
      "mtu": ${IFACE_MTU["${ifn}"]:-1500},
      "ipv4": "${IFACE_IPV4["${ifn}"]:-None}",
      "ipv6": "${IFACE_IPV6["${ifn}"]:-None}"
    }${comma}
EOF
    done

echo "  ]" >> "${JSON_META_FILE}"
echo "}" >> "${JSON_META_FILE}"

if [ "${OUTPUT_JSON_ONLY}" = true ]; then
    cat "${JSON_META_FILE}"
    exit 0
fi

# ==============================================================================
# SECTION 6: FORMATTED TERMINAL & PLAIN-TEXT REPORT GENERATION
# Outputs clean, human-readable tables with status indicators.
# Simultaneously writes clean plain-text (without ANSI colors) to REPORT_FILE.
# ==============================================================================

# Helper function to print to terminal (with ANSI) and file (without ANSI)
print_report_line() {
    local colored_msg="$1"
    local plain_msg="$2"
    echo -e "${colored_msg}"
    echo -e "${plain_msg}" >> "${REPORT_FILE}"
}

# Clear destination file
> "${REPORT_FILE}"

# Header Banner
print_report_line "${C_CYAN}${C_BOLD}================================================================================${C_RESET}" \
                  "================================================================================"
print_report_line "${C_CYAN}${C_BOLD}        LINUX SYSTEM ADMINISTRATION (E1ITA307) — IP CONFIGURATION REPORT        ${C_RESET}" \
                  "        LINUX SYSTEM ADMINISTRATION (E1ITA307) — IP CONFIGURATION REPORT        "
print_report_line "${C_CYAN}${C_BOLD}================================================================================${C_RESET}" \
                  "================================================================================"

print_report_line "${C_DIM}Generated On :${C_RESET} ${C_BOLD}${TIMESTAMP_ISO}${C_RESET}" \
                  "Generated On : ${TIMESTAMP_ISO}"
print_report_line "${C_DIM}Operating Sys:${C_RESET} ${SYS_DISTRO} (Kernel: ${SYS_KERNEL}, Arch: ${SYS_ARCH})" \
                  "Operating Sys: ${SYS_DISTRO} (Kernel: ${SYS_KERNEL}, Arch: ${SYS_ARCH})"
print_report_line "${C_DIM}Query Engine :${C_RESET} ${C_GREEN}${TOOL_USED}${C_RESET}" \
                  "Query Engine : ${TOOL_USED}"
print_report_line "" ""

# 1. Host Identity & IP Summary
print_report_line "${C_YELLOW}${C_BOLD}--- [1] HOST IDENTIFICATION & IP SUMMARY ---------------------------------------${C_RESET}" \
                  "--- [1] HOST IDENTIFICATION & IP SUMMARY ---------------------------------------"
print_report_line "  Hostname        : ${C_BOLD}${C_GREEN}${SYS_HOSTNAME}${C_RESET}" \
                  "  Hostname        : ${SYS_HOSTNAME}"
print_report_line "  Assigned IPs    : ${C_BOLD}${C_CYAN}${ALL_IPS_SUMMARY}${C_RESET}" \
                  "  Assigned IPs    : ${ALL_IPS_SUMMARY}"
print_report_line "  Primary IPv4    : ${C_BOLD}${PRIMARY_IP}${C_RESET} (on interface: ${C_BOLD}${PRIMARY_IFACE}${C_RESET})" \
                  "  Primary IPv4    : ${PRIMARY_IP} (on interface: ${PRIMARY_IFACE})"
print_report_line "" ""

# 2. Routing & Gateway
print_report_line "${C_YELLOW}${C_BOLD}--- [2] DEFAULT GATEWAY & ROUTING TABLE ----------------------------------------${C_RESET}" \
                  "--- [2] DEFAULT GATEWAY & ROUTING TABLE ----------------------------------------"
if [ "${DEFAULT_GW_IP}" != "None" ]; then
    print_report_line "  Default Gateway : ${C_BOLD}${C_GREEN}${DEFAULT_GW_IP}${C_RESET}" \
                      "  Default Gateway : ${DEFAULT_GW_IP}"
    print_report_line "  Egress Interface: ${C_BOLD}${C_CYAN}${DEFAULT_GW_IFACE}${C_RESET}" \
                      "  Egress Interface: ${DEFAULT_GW_IFACE}"
    print_report_line "  Protocol/Metric : ${DEFAULT_GW_PROTO} (metric: ${DEFAULT_GW_METRIC})" \
                      "  Protocol/Metric : ${DEFAULT_GW_PROTO} (metric: ${DEFAULT_GW_METRIC})"
    print_report_line "  Route Directive : ${C_DIM}${RAW_DEFAULT_ROUTE}${C_RESET}" \
                      "  Route Directive : ${RAW_DEFAULT_ROUTE}"
else
    print_report_line "  ${C_RED}[!] No default gateway route detected in current routing table.${C_RESET}" \
                      "  [!] No default gateway route detected in current routing table."
fi
print_report_line "" ""

# 3. DNS Configuration
print_report_line "${C_YELLOW}${C_BOLD}--- [3] DNS RESOLUTION CONFIGURATION -------------------------------------------${C_RESET}" \
                  "--- [3] DNS RESOLUTION CONFIGURATION -------------------------------------------"
print_report_line "  Nameservers     : ${C_BOLD}${DNS_SERVERS_STR}${C_RESET}" \
                  "  Nameservers     : ${DNS_SERVERS_STR}"
if [ -n "${DNS_SEARCH_DOMAINS}" ]; then
    print_report_line "  Search Domains  : ${DNS_SEARCH_DOMAINS}" \
                      "  Search Domains  : ${DNS_SEARCH_DOMAINS}"
fi
print_report_line "  Source File     : /etc/resolv.conf" \
                  "  Source File     : /etc/resolv.conf"
print_report_line "" ""

# 4. Active Network Interfaces Table & Details
print_report_line "${C_YELLOW}${C_BOLD}--- [4] ACTIVE NETWORK INTERFACES (${TOTAL_ACTIVE_IFACES} Detected) ---------------------------${C_RESET}" \
                  "--- [4] ACTIVE NETWORK INTERFACES (${TOTAL_ACTIVE_IFACES} Detected) ---------------------------"

if [ "${TOTAL_ACTIVE_IFACES}" -eq 0 ]; then
    print_report_line "  ${C_RED}[!] No active network interfaces were found in UP state.${C_RESET}" \
                      "  [!] No active network interfaces were found in UP state."
    print_report_line "  Verify physical link connectivity, wireless switches, or virtual network drivers." \
                      "  Verify physical link connectivity, wireless switches, or virtual network drivers."
else
    # Table Header
    HEADER_COLORED="$(printf "${C_BOLD}  %-10s %-8s %-18s %-6s %-25s %-20s${C_RESET}" 'INTERFACE' 'STATE' 'MAC ADDRESS' 'MTU' 'IPv4 ADDRESS / CIDR' 'TYPE')"
    HEADER_PLAIN="$(printf '  %-10s %-8s %-18s %-6s %-25s %-20s' 'INTERFACE' 'STATE' 'MAC ADDRESS' 'MTU' 'IPv4 ADDRESS / CIDR' 'TYPE')"
    print_report_line "${HEADER_COLORED}" "${HEADER_PLAIN}"
    print_report_line "  --------------------------------------------------------------------------------" \
                      "  --------------------------------------------------------------------------------"

    for ifn in "${IFACE_NAMES[@]}"; do
        state_str="${IFACE_STATE["${ifn}"]:-UNKNOWN}"
        mac_str="${IFACE_MAC["${ifn}"]:-00:00:00:00:00:00}"
        mtu_str="${IFACE_MTU["${ifn}"]:-1500}"
        v4_str="${IFACE_IPV4["${ifn}"]:-None}"
        type_str="${IFACE_TYPE["${ifn}"]:-Interface}"

        # Truncate v4 if multiple for single-line table display
        v4_table_disp="$(echo "${v4_str}" | cut -d',' -f1)"

        # Exact column spacing
        pad_state="$(printf '%-8s' "${state_str}")"
        if [ "${USE_COLOR}" = true ]; then
            if [ "${state_str}" = "UP" ]; then
                state_cell="${C_GREEN}${pad_state}${C_RESET}"
            else
                state_cell="${C_YELLOW}${pad_state}${C_RESET}"
            fi
            colored_row="  $(printf "${C_BOLD}%-10s${C_RESET}" "${ifn}") ${state_cell} $(printf "%-18s %-6s %-25s %-20s" "${mac_str}" "${mtu_str}" "${v4_table_disp}" "${type_str}")"
        else
            colored_row="$(printf "  %-10s %-8s %-18s %-6s %-25s %-20s" "${ifn}" "${state_str}" "${mac_str}" "${mtu_str}" "${v4_table_disp}" "${type_str}")"
        fi
        plain_row="$(printf "  %-10s %-8s %-18s %-6s %-25s %-20s" \
                    "${ifn}" "${state_str}" "${mac_str}" "${mtu_str}" "${v4_table_disp}" "${type_str}")"
        
        print_report_line "${colored_row}" "${plain_row}"
    done

    print_report_line "" ""
    print_report_line "${C_CYAN}${C_BOLD}Detailed Interface Breakdown:${C_RESET}" \
                      "Detailed Interface Breakdown:"

    for ifn in "${IFACE_NAMES[@]}"; do
        print_report_line "  ${C_BOLD}* Interface [${C_GREEN}${ifn}${C_RESET}${C_BOLD}]:${C_RESET}" \
                          "  * Interface [${ifn}]:"
        print_report_line "      Type       : ${IFACE_TYPE["${ifn}"]}" \
                          "      Type       : ${IFACE_TYPE["${ifn}"]}"
        print_report_line "      Oper State : ${IFACE_STATE["${ifn}"]}" \
                          "      Oper State : ${IFACE_STATE["${ifn}"]}"
        print_report_line "      Hardware/MAC: ${IFACE_MAC["${ifn}"]}" \
                          "      Hardware/MAC: ${IFACE_MAC["${ifn}"]}"
        print_report_line "      MTU Payload: ${IFACE_MTU["${ifn}"]} bytes" \
                          "      MTU Payload: ${IFACE_MTU["${ifn}"]} bytes"
        print_report_line "      IPv4 / CIDR: ${IFACE_IPV4["${ifn}"]}" \
                          "      IPv4 / CIDR: ${IFACE_IPV4["${ifn}"]}"
        print_report_line "      IPv6 / CIDR: ${IFACE_IPV6["${ifn}"]}" \
                          "      IPv6 / CIDR: ${IFACE_IPV6["${ifn}"]}"
    done
fi

print_report_line "" ""

# 5. Architecture Summary & Engineering Note
print_report_line "${C_YELLOW}${C_BOLD}--- [5] ARCHITECTURAL NOTE: MODERN iproute2 VS LEGACY net-tools --------------${C_RESET}" \
                  "--- [5] ARCHITECTURAL NOTE: MODERN iproute2 VS LEGACY net-tools --------------"
print_report_line "  * Protocol Standard : iproute2 communicates via Netlink sockets (AF_NETLINK)," \
                  "  * Protocol Standard : iproute2 communicates via Netlink sockets (AF_NETLINK),"
print_report_line "                        avoiding legacy synchronous ioctl() overhead." \
                  "                        avoiding legacy synchronous ioctl() overhead."
print_report_line "  * Subnet Semantics  : Native CIDR prefix notation (/24, /20, /64) replaces" \
                  "  * Subnet Semantics  : Native CIDR prefix notation (/24, /20, /64) replaces"
print_report_line "                        archaic dotted classful/classless netmasks." \
                  "                        archaic dotted classful/classless netmasks."
print_report_line "  * Multi-IP Support  : Multiple IP addresses per device are first-class objects," \
                  "  * Multi-IP Support  : Multiple IP addresses per device are first-class objects,"
print_report_line "                        eliminating fragile sub-interface aliases (eth0:1)." \
                  "                        eliminating fragile sub-interface aliases (eth0:1)."
print_report_line "  * Deprecation Status: net-tools (ifconfig/route) was deprecated in ~2009 and" \
                  "  * Deprecation Status: net-tools (ifconfig/route) was deprecated in ~2009 and"
print_report_line "                        is omitted by default in modern enterprise Linux." \
                  "                        is omitted by default in modern enterprise Linux."
print_report_line "================================================================================" \
                  "================================================================================"

# Copy to latest_ip_report.txt
cp -f "${REPORT_FILE}" "${LATEST_REPORT_FILE}"

echo -e "\n${C_GREEN}${C_BOLD}[OK] Network configuration report saved to:${C_RESET} ${REPORT_FILE}"
echo -e "${C_DIM}     Latest symlink/pointer updated at :${C_RESET} ${LATEST_REPORT_FILE}\n"

exit 0
