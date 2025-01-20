
# Secure DNS Server Installation Script

  

A comprehensive script to deploy a secure DNS server with DNS-over-TLS (DoT) and DNS-over-HTTPS (DoH) support.

  

## Features

  

- IPv4 and IPv6 support

- DNSSEC enabled

- DNS-over-TLS (DoT)

- DNS-over-HTTPS (DoH)

- Malware and phishing domain filtering

- Automatic blocklist updates

- Fail2ban protection

- UFW firewall rules

- Optional Prometheus monitoring

  

## Prerequisites

  

- Debian/Ubuntu based system

- Root access

- Valid domain name pointing to your server

- Open ports: 53 (TCP/UDP), 853 (TCP), 443 (TCP)

  

## Installation

  

1. Download the script:

  

wget https://github.com/aurelson101/scripts-bash/tree/main/unbound-dns/install-secure-dns.sh

  

2. Make it executable:

chmod +x install-secure-dns.sh

  

3. Edit the configuration variables:

  

nano install-secure-dns.sh

  

# Modify these variables

DOMAIN="dns.yourdomain.com"

EMAIL="admin@yourdomain.com"

ENABLE_PROMETHEUS=false

  

4. Run the script:

./install-secure-dns.sh

  

## Usage

After installation, your DNS server will be available at:

Standard DNS: dns.yourdomain.com:53
DNS-over-TLS: dns.yourdomain.com:853
DNS-over-HTTPS: https://dns.yourdomain.com/dns-query

  

Test standard DNS:
dig @dns.yourdomain.com google.com

Test DoT:
kdig @dns.yourdomain.com +tls-ca +tls google.com

Test DoH:
curl -H 'accept: application/dns-json' 'https://dns.yourdomain.com/dns-query?name=google.com&type=A'

## Maintenance:

Blocklists are automatically updated daily at 4 AM. Manual update:
/usr/local/bin/update-blocklists.sh

## Security Features:

DNSSEC validation
Query rate limiting
Malware domain blocking
IP-based access control
TLS 1.2/1.3 support
Fail2ban protection
UFW firewall rules

## Monitoring

If Prometheus monitoring is enabled:
Metrics available at: http://localhost:9167/metrics

## Service status:

systemctl status prometheus-unbound-exporter

## Logs:

Unbound logs: /var/log/unbound/unbound.log
Nginx logs: /var/log/nginx/
DNSdist logs: /var/log/dnsdist/

## Check service status:

systemctl status unbound
systemctl status nginx
systemctl status dnsdist
systemctl status fail2ban