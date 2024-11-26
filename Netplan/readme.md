
# Netplan Manager Script

A powerful bash script to manage network configurations using Netplan on Ubuntu/Debian systems.

## Features

- Network interface detection and configuration
- DHCP and Static IP configuration
- Advanced networking options:
  - Interface bonding/failover
  - Network bridging
  - VLAN configuration
  - Interface monitoring
- Automatic backup and restore functionality
- Comprehensive logging
- Configuration validation


**═══ Main Menu ═══**
1. Detect Network Interfaces
   ├─ List all available network cards
   └─ Show interface status

2. Configure Single Interface
   ├─ DHCP configuration
   └─ Static IP configuration

3. Advanced Configuration
   ├─ Bonding/Failover
   ├─ Network Bridge
   ├─ VLAN Setup
   └─ Interface Monitoring

4. Show Current Configuration
   └─ Display active netplan settings

5. Show Configuration Backups
   └─ List all saved configurations

6. Exit

**═══ Advanced Configuration Menu ═══**
1. Configure Bonding/Failover
   ├─ Link aggregation
   ├─ Load balancing
   └─ Failover setup

2. Configure Bridge
   ├─ Network bridging
   └─ Virtual networking

3. Configure VLAN
   ├─ VLAN tagging
   └─ Network segmentation

4. Monitor Interface
   ├─ Real-time statistics
   └─ Interface status

5. Return to Main Menu
6. 
## Prerequisites

The script requires the following dependencies:
- ip
- netplan
- ethtool
- Root privileges

## Installation

1. Clone or download the script
2. Make it executable:
```bash
chmod +x netplan.sh
