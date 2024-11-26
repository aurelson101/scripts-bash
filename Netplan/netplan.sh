#!/bin/bash

# Constants and color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly BACKUP_DIR="/etc/netplan/backups"
readonly LOG_FILE="/var/log/netplan-manager.log"

# Logging function
log_action() {
    local action=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $action" >> "$LOG_FILE"
}

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    fi
    return 1
}

validate_vlan_id() {
    local id=$1
    if [[ $id =~ ^[0-9]+$ ]] && [ "$id" -ge 1 ] && [ "$id" -le 4094 ]; then
        return 0
    fi
    return 1
}

# Backup function
backup_netplan_config() {
    local backup_path="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_path"
    cp /etc/netplan/*.yaml "$backup_path/"
    log_action "Configuration backup created at $backup_path"
}

# Test configuration
test_netplan_config() {
    if netplan try --timeout 30; then
        log_action "Configuration test successful"
        return 0
    else
        log_action "Configuration test failed"
        return 1
    fi
}

# Monitor interface
monitor_interface() {
    local interface=$1
    echo -e "${GREEN}Interface Status for $interface:${NC}"
    ip -s link show dev "$interface"
    ethtool "$interface" 2>/dev/null
    log_action "Monitored interface $interface"
}

# Check dependencies
check_dependencies() {
    local deps=(ip netplan ethtool)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${RED}Missing dependency: $dep${NC}"
            log_action "Missing dependency: $dep"
            exit 1
        fi
    done
}

# Detect network interfaces
detect_interfaces() {
    echo -e "${GREEN}Detected Network Interfaces:${NC}"
    echo "-------------------------"
    ip -br link show | grep -v "lo" | awk '{print $1}'
    log_action "Network interfaces detected"
}

# Configure bonding
configure_bonding() {
    backup_netplan_config

    local bond_name="bond0"
    local interfaces=()

    echo -e "${GREEN}Available interfaces for bonding:${NC}"
    mapfile -t available_interfaces < <(ip -br link show | grep -v "lo" | awk '{print $1}')

    for i in "${!available_interfaces[@]}"; do
        echo "$((i+1)). ${available_interfaces[i]}"
    done

    read -p "Enter interface numbers (space-separated): " selections
    for num in $selections; do
        interfaces+=("${available_interfaces[$((num-1))]}")
    done

    echo -e "\nBonding Modes:"
    echo "1. active-backup (failover)"
    echo "2. balance-rr (round-robin)"
    echo "3. balance-xor"
    echo "4. broadcast"
    echo "5. 802.3ad (LACP)"
    echo "6. balance-tlb"
    echo "7. balance-alb"

    read -p "Choose bonding mode (1-7): " mode_choice

    case $mode_choice in
        1) mode="active-backup";;
        2) mode="balance-rr";;
        3) mode="balance-xor";;
        4) mode="broadcast";;
        5) mode="802.3ad";;
        6) mode="balance-tlb";;
        7) mode="balance-alb";;
        *)
            echo -e "${RED}Invalid choice${NC}"
            log_action "Invalid bonding mode selection"
            return
            ;;
    esac

    cat > /etc/netplan/02-bonding.yaml << EOF
network:
  version: 2
  renderer: networkd
  bonds:
    $bond_name:
      interfaces: [${interfaces[@]}]
      parameters:
        mode: $mode
        mii-monitor-interval: 100
      dhcp4: true
EOF

    if test_netplan_config; then
        netplan apply
        log_action "Bonding configuration applied for $bond_name with mode $mode"
        echo -e "${GREEN}Bonding configuration applied successfully${NC}"
    else
        echo -e "${RED}Configuration failed, reverting to backup${NC}"
        restore_backup
    fi
}

# Configure bridge
configure_bridge() {
    backup_netplan_config

    local bridge_name="br0"

    echo -e "${GREEN}Available interfaces for bridge:${NC}"
    mapfile -t available_interfaces < <(ip -br link show | grep -v "lo" | awk '{print $1}')

    for i in "${!available_interfaces[@]}"; do
        echo "$((i+1)). ${available_interfaces[i]}"
    done

    read -p "Enter interface number: " selection
    interface="${available_interfaces[$((selection-1))]}"

    cat > /etc/netplan/03-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  bridges:
    $bridge_name:
      interfaces: [$interface]
      dhcp4: true
EOF

    if test_netplan_config; then
        netplan apply
        log_action "Bridge configuration applied for $bridge_name"
        echo -e "${GREEN}Bridge configuration applied successfully${NC}"
    else
        echo -e "${RED}Configuration failed, reverting to backup${NC}"
        restore_backup
    fi
}

# Configure VLAN
configure_vlan() {
    backup_netplan_config

    echo -e "${GREEN}Available interfaces for VLAN:${NC}"
    mapfile -t available_interfaces < <(ip -br link show | grep -v "lo" | awk '{print $1}')

    for i in "${!available_interfaces[@]}"; do
        echo "$((i+1)). ${available_interfaces[i]}"
    done

    read -p "Enter interface number: " selection
    interface="${available_interfaces[$((selection-1))]}"

    read -p "Enter VLAN ID (1-4094): " vlan_id

    if ! validate_vlan_id "$vlan_id"; then
        echo -e "${RED}Invalid VLAN ID${NC}"
        log_action "Invalid VLAN ID entered: $vlan_id"
        return
    fi

    cat > /etc/netplan/04-vlan.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: no
  vlans:
    ${interface}.${vlan_id}:
      id: $vlan_id
      link: $interface
      dhcp4: true
EOF

    if test_netplan_config; then
        netplan apply
        log_action "VLAN configuration applied for VLAN $vlan_id on $interface"
        echo -e "${GREEN}VLAN configuration applied successfully${NC}"
    else
        echo -e "${RED}Configuration failed, reverting to backup${NC}"
        restore_backup
    fi
}

# Configure static IP
configure_static() {
    local interface=$1
    backup_netplan_config

    read -p "Enter IP address (e.g., 192.168.1.100/24): " ip_address
    if ! validate_ip "$ip_address"; then
        echo -e "${RED}Invalid IP address format${NC}"
        log_action "Invalid IP address entered: $ip_address"
        return
    fi

    read -p "Enter gateway (e.g., 192.168.1.1): " gateway
    read -p "Enter DNS servers (comma-separated, e.g., 8.8.8.8,8.8.4.4): " nameservers

    cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: false
      addresses: [$ip_address]
      gateway4: $gateway
      nameservers:
        addresses: [${nameservers//,/, }]
EOF

    if test_netplan_config; then
        netplan apply
        log_action "Static IP configuration applied for $interface"
        echo -e "${GREEN}Static IP configuration applied${NC}"
    else
        echo -e "${RED}Configuration failed, reverting to backup${NC}"
        restore_backup
    fi
}

# Configure DHCP
configure_dhcp() {
    local interface=$1
    backup_netplan_config

    cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: true
EOF

    if test_netplan_config; then
        netplan apply
        log_action "DHCP configuration applied for $interface"
        echo -e "${GREEN}DHCP configuration applied${NC}"
    else
        echo -e "${RED}Configuration failed, reverting to backup${NC}"
        restore_backup
    fi
}

# Restore backup
restore_backup() {
    local latest_backup=$(ls -t "$BACKUP_DIR" | head -n1)
    if [ -n "$latest_backup" ]; then
        cp "$BACKUP_DIR/$latest_backup"/*.yaml /etc/netplan/
        netplan apply
        log_action "Configuration restored from backup"
        echo -e "${YELLOW}Configuration restored from backup${NC}"
    fi
}

# Advanced configuration menu
advanced_config_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Advanced Network Configuration ===${NC}"
        echo "1. Configure Bonding/Failover"
        echo "2. Configure Bridge"
        echo "3. Configure VLAN"
        echo "4. Monitor Interface"
        echo "5. Return to Main Menu"

        read -p "Choose an option (1-5): " choice

        case $choice in
            1) configure_bonding ;;
            2) configure_bridge ;;
            3) configure_vlan ;;
            4)
                detect_interfaces
                read -p "Enter interface to monitor: " mon_interface
                monitor_interface "$mon_interface"
                ;;
            5) return ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Netplan Manager ===${NC}"
        echo "1. Detect Network Interfaces"
        echo "2. Configure Single Interface"
        echo "3. Advanced Configuration"
        echo "4. Show Current Configuration"
        echo "5. Show Configuration Backups"
        echo "6. Exit"

        read -p "Choose an option (1-6): " choice

        case $choice in
            1)
                detect_interfaces
                ;;
            2)
                detect_interfaces
                echo "Select interface number:"
                read -p "Interface: " interface_num
                interface=$(ip -br link show | grep -v "lo" | awk '{print $1}' | sed -n "${interface_num}p")
                if [ -n "$interface" ]; then
                    echo "1. DHCP"
                    echo "2. Static IP"
                    read -p "Choose configuration type (1-2): " config_type
                    case $config_type in
                        1) configure_dhcp "$interface" ;;
                        2) configure_static "$interface" ;;
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                else
                    echo -e "${RED}Invalid interface selection${NC}"
                fi
                ;;
            3)
                advanced_config_menu
                ;;
            4)
                echo -e "${GREEN}Current Netplan Configuration:${NC}"
                cat /etc/netplan/*.yaml
                ;;
            5)
                echo -e "${GREEN}Available Backups:${NC}"
                ls -l "$BACKUP_DIR"
                ;;
            6)
                log_action "Program terminated"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Script initialization
check_dependencies
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    log_action "Script execution attempted without root privileges"
    exit 1
fi

# Start script
log_action "Script started"
main_menu