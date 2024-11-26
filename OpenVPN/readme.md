# OpenVPN Server with Active Directory Integration

This script automates the installation and configuration of an OpenVPN server with Active Directory authentication on Ubuntu/Debian systems.

## Features

- OpenVPN server installation and configuration
- Active Directory integration with LDAP authentication
- VPN-FULL AD group requirement for access control
- Automatic backup system
- Service monitoring
- UFW firewall configuration
- Detailed logging

## Prerequisites

- Ubuntu/Debian server
- Root access
- Active Directory domain
- Network connectivity to AD domain
- VPN-FULL group created in Active Directory

## Installation

1. Download the script:
```bash
wget https://your-repo/openvpn_ad_setup.sh
