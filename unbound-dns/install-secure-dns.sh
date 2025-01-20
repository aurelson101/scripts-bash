#!/bin/bash

# Variables
DOMAIN="dns.yourdomain.com"
EMAIL="admin@yourdomain.com"
ENABLE_PROMETHEUS=false  # Set to true if you want Prometheus monitoring

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# System update
log "Updating system"
apt update && apt upgrade -y

# Install required packages
log "Installing packages"
apt install -y unbound unbound-anchor nginx certbot python3-certbot-nginx dnsdist fail2ban

# Install Prometheus if enabled
if [ "$ENABLE_PROMETHEUS" = true ]; then
    apt install -y prometheus-unbound-exporter
fi

# Create directories
log "Creating directories"
mkdir -p /etc/unbound/blocklists
mkdir -p /var/log/unbound

# Create blocklist update script
cat > /usr/local/bin/update-blocklists.sh << 'EOF'
#!/bin/bash
BLOCKLIST_DIR="/etc/unbound/blocklists"
mkdir -p $BLOCKLIST_DIR

curl -o $BLOCKLIST_DIR/malware.txt "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
curl -o $BLOCKLIST_DIR/phishing.txt "https://raw.githubusercontent.com/mitchellkrogza/Phishing.Database/master/phishing-domains-ACTIVE.txt"
curl -o $BLOCKLIST_DIR/ransomware.txt "https://raw.githubusercontent.com/blocklistproject/Lists/master/ransomware.txt"
EOF

# Create blocked domains generator script
cat > /usr/local/bin/generate-blocked-domains.sh << 'EOF'
#!/bin/bash
OUTPUT_FILE="/etc/unbound/blocked-domains.conf"

echo "local-zone: \"malware-domain.com\" always_nxdomain" > $OUTPUT_FILE

for list in /etc/unbound/blocklists/*.txt; do
    grep -v '^#' $list | grep -o '[a-zA-Z0-9\.-]*\.[a-zA-Z]\{2,\}' | sort -u | \
    while read domain; do
        echo "local-zone: \"$domain\" always_nxdomain" >> $OUTPUT_FILE
    done
done
EOF

# Unbound configuration
cat > /etc/unbound/unbound.conf << EOF
server:
    interface: 0.0.0.0
    interface: ::0
    port: 53
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes

    access-control: 127.0.0.0/8 allow
    access-control: ::1 allow
    access-control: 192.168.0.0/16 allow

    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    root-hints: "/var/lib/unbound/root.hints"
    
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    harden-algo-downgrade: yes
    
    qname-minimisation: yes
    aggressive-nsec: yes
    
    hide-identity: yes
    hide-version: yes
    use-caps-for-id: yes
    
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    rate-limit: 1000
    
    msg-cache-size: 128m
    rrset-cache-size: 256m
    
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    tls-service-key: "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
    tls-service-pem: "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    tls-port: 853

include: "/etc/unbound/blocked-domains.conf"
EOF

# Nginx DoH configuration
cat > /etc/nginx/sites-available/doh << EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    location /dns-query {
        proxy_pass http://127.0.0.1:8053;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# DNSdist configuration
cat > /etc/dnsdist/dnsdist.conf << 'EOF'
addLocal('127.0.0.1:8053')
addDOHLocal('127.0.0.1:8053', {"/dns-query"}, {reusePort=true})
newServer({address='127.0.0.1:53'})
setMaxTCPClientThreads(10)
setMaxTCPQueuedConnections(1000)
EOF

# Fail2ban configuration
cat > /etc/fail2ban/jail.d/unbound.conf << 'EOF'
[unbound]
enabled = true
port = 53
protocol = udp,tcp
filter = unbound
logpath = /var/log/unbound/unbound.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

# Make scripts executable
chmod +x /usr/local/bin/update-blocklists.sh
chmod +x /usr/local/bin/generate-blocked-domains.sh

# Set up cron job
echo "0 4 * * * root /usr/local/bin/update-blocklists.sh && /usr/local/bin/generate-blocked-domains.sh && systemctl reload unbound" > /etc/cron.d/update-unbound-blocklists

# Get SSL certificate
certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL}

# Enable nginx configuration
ln -sf /etc/nginx/sites-available/doh /etc/nginx/sites-enabled/

# Initial blocklist download
/usr/local/bin/update-blocklists.sh
/usr/local/bin/generate-blocked-domains.sh

# Start and enable services
systemctl enable --now unbound
systemctl enable --now nginx
systemctl enable --now dnsdist
systemctl enable --now fail2ban

if [ "$ENABLE_PROMETHEUS" = true ]; then
    systemctl enable --now prometheus-unbound-exporter
fi

# Restart services
systemctl restart unbound
systemctl restart nginx
systemctl restart dnsdist
systemctl restart fail2ban

log "Installation completed!"
log "Your DNS server is accessible at:"
log "Classic DNS: ${DOMAIN}:53"
log "DNS-over-TLS: ${DOMAIN}:853"
log "DNS-over-HTTPS: https://${DOMAIN}/dns-query"
