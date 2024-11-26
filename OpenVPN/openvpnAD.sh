#!/bin/bash

set -eo pipefail

# Logging functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error() { log "ERROR: $*" >&2; }
trap 'error "An error occurred on line $LINENO"' ERR

# Configuration variables
read -p "Enter AD domain name (e.g., domain.local): " AD_DOMAIN
read -p "Enter AD administrator name: " AD_ADMIN
read -p "Enter OpenVPN port (default: 1194): " OPENVPN_PORT

OPENVPN_PORT=${OPENVPN_PORT:-1194}
BACKUP_DIR="/backup/openvpn"
VPN_NETWORK="10.8.0.0"
VPN_NETMASK="255.255.255.0"

# Prerequisites check
log "Checking prerequisites..."
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Package installation
log "Installing packages..."
apt update && apt upgrade -y
apt install -y openvpn easy-rsa ufw realmd adcli samba-common-bin openvpn-auth-ldap \
    net-tools dnsutils curl wget

# OpenVPN configuration
log "Configuring OpenVPN..."
mkdir -p /etc/openvpn/{easy-rsa,auth,clients}
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa/

# Certificate variables generation
cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "State"
set_var EASYRSA_REQ_CITY       "City"
set_var EASYRSA_REQ_ORG        "Organization"
set_var EASYRSA_REQ_EMAIL      "admin@${AD_DOMAIN}"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
EOF

# Certificate generation
log "Generating certificates..."
./easyrsa init-pki
echo "yes" | ./easyrsa build-ca nopass
echo "yes" | ./easyrsa build-server-full server nopass
./easyrsa gen-dh
openvpn --genkey secret ta.key

# OpenVPN server configuration
log "Configuring OpenVPN server..."
cat > /etc/openvpn/server/server.conf << EOF
port ${OPENVPN_PORT}
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
server ${VPN_NETWORK} ${VPN_NETMASK}
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth /etc/openvpn/easy-rsa/ta.key 0
cipher AES-256-GCM
auth SHA512
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1
plugin /usr/lib/openvpn/openvpn-auth-ldap.so /etc/openvpn/auth/auth-ldap.conf
duplicate-cn
max-clients 100
EOF

# LDAP configuration for AD
log "Configuring LDAP authentication..."
read -sp "AD Admin Password: " AD_PASSWORD
echo

cat > /etc/openvpn/auth/auth-ldap.conf << EOF
<LDAP>
    URL             ldap://${AD_DOMAIN}
    BindDN          "${AD_ADMIN}@${AD_DOMAIN}"
    Password        "${AD_PASSWORD}"
    Timeout         15
    TLSEnable      no
    FollowReferrals no
</LDAP>
<Authorization>
    BaseDN          "DC=${AD_DOMAIN//./,DC=}"
    SearchFilter    "(&(sAMAccountName=%u)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
    RequireGroup    true
    <Group>
        BaseDN      "DC=${AD_DOMAIN//./,DC=}"
        SearchFilter "(cn=VPN-FULL)"
        MemberAttribute "member"
    </Group>
</Authorization>
EOF

chmod 600 /etc/openvpn/auth/auth-ldap.conf

# Firewall configuration
log "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ${OPENVPN_PORT}/udp
ufw allow from ${VPN_NETWORK}/${VPN_NETMASK}
echo "y" | ufw enable

# IP forwarding configuration
log "Configuring IP forwarding..."
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

# Join AD domain
log "Joining AD domain..."
realm join ${AD_DOMAIN} -U ${AD_ADMIN}

# Log configuration
log "Configuring logs..."
mkdir -p /var/log/openvpn
touch /var/log/openvpn/{openvpn-status.log,openvpn.log}
chown nobody:nogroup /var/log/openvpn/*

# Backup script
log "Configuring backups..."
mkdir -p ${BACKUP_DIR}

cat > /usr/local/sbin/backup_openvpn.sh << EOF
#!/bin/bash
BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
tar -czf ${BACKUP_DIR}/openvpn-config-\${BACKUP_DATE}.tar.gz /etc/openvpn
find ${BACKUP_DIR} -type f -mtime +30 -delete
EOF

chmod +x /usr/local/sbin/backup_openvpn.sh

# Schedule backups
echo "0 0 * * * root /usr/local/sbin/backup_openvpn.sh" > /etc/cron.d/openvpn-backup

# Monitoring script
cat > /usr/local/sbin/monitor_openvpn.sh << EOF
#!/bin/bash
if ! systemctl is-active --quiet openvpn@server; then
    systemctl restart openvpn@server
    echo "OpenVPN restarted on \$(date)" >> /var/log/openvpn/monitoring.log
fi
EOF

chmod +x /usr/local/sbin/monitor_openvpn.sh
echo "*/5 * * * * root /usr/local/sbin/monitor_openvpn.sh" > /etc/cron.d/openvpn-monitor

# Start services
log "Starting services..."
systemctl enable --now openvpn@server

# Final tests
log "Final verification..."
systemctl status openvpn@server --no-pager
realm list
ss -tulpn | grep openvpn

log "Installation completed successfully!"
log "Logs available in /var/log/openvpn/"
log "Backups stored in ${BACKUP_DIR}"
log "Automatic monitoring configured"
log "Note: Users must be members of the VPN-FULL AD group to connect"
