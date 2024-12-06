# Certificate Authority Management Scripts

This repository contains two Bash scripts for managing a Certificate Authority (CA) and generating client/server certificates. These scripts provide a flexible and secure way to create and manage your own PKI (Public Key Infrastructure).

## Scripts Overview

1. `create_ca.sh`: Creates a new Certificate Authority
2. `create_cert.sh`: Generates client or server certificates signed by the CA

## Creating a Certificate Authority (create_ca.sh)

### Basic Usage
```bash
./create_ca.sh -n "MyCA" -o "My Company"
```

### Options
- `-n`: CA name (default: RootCA)
- `-v`: Validity period in days (default: 3650, 10 years)
- `-k`: Key size in bits (default: 4096)
- `-d`: Digest algorithm (default: sha512)
- `-c`: Country code (optional)
- `-s`: State (optional)
- `-l`: Locality (optional)
- `-o`: Organization (optional)
- `-u`: Organizational Unit (optional)
- `-e`: Email (optional)
- `-p`: Enable password protection for CA key
- `-h`: Show help

### Directory Structure
The script creates the following structure:
```
ca/
├── private/         # Contains CA private key
├── newcerts/       # Stores new certificates
├── clients/        # Client certificates directory
├── index.txt      # Database of certificates
├── serial         # Serial number tracker
└── [CA_NAME].crt  # CA certificate
```

## Creating Certificates (create_cert.sh)

### Basic Usage
```bash
./create_cert.sh -n "client1" -d "example.com,www.example.com"
```

### Options
Required:
- `-n`: Client/server name

Optional:
- `-d`: DNS names (comma-separated)
- `-i`: IP addresses (comma-separated)
- `-v`: Validity in days (default: 365)
- `-k`: Key size in bits (default: 2048)
- `-c`: CA name (default: RootCA)
- `-p`: Enable password protection for client key
- `-t`: Certificate type (server|client|both) (default: both)
- `-l`: Legacy mode for older Windows systems
- `-w`: Generate Windows-specific formats
- `-h`: Show help

### Output Files
The script generates these files in `ca/clients/[CLIENT_NAME]/`:
- `.key`: Private key
- `.csr`: Certificate signing request
- `.crt`: Signed certificate
- `.pfx`/`.p12`: PKCS#12 format (when Windows format requested)
- `_legacy.key`/`_legacy.crt`: Legacy format certificates (when legacy mode enabled)

## Security Considerations

1. Always store the CA private key securely
2. Consider using password protection (`-p` option) for sensitive keys
3. Keep backups of the CA directory
4. Use appropriate validity periods for certificates
5. Choose appropriate key sizes (4096 for CA, 2048+ for clients)

## Examples

### Create a CA with Organization Details
```bash
./create_ca.sh -n "CompanyCA" \
    -o "My Company Inc" \
    -c "US" \
    -s "California" \
    -l "San Francisco" \
    -e "ca@company.com" \
    -p
```

### Create a Server Certificate
```bash
./create_cert.sh \
    -n "webserver" \
    -d "website.com,www.website.com" \
    -t "server" \
    -v 730
```

### Create a Client Certificate with Multiple IPs
```bash
./create_cert.sh \
    -n "vpnclient" \
    -i "192.168.1.10,192.168.1.11" \
    -t "client" \
    -p
```

## Troubleshooting

1. Ensure both scripts have execution permissions (`chmod +x script.sh`)
2. Run `create_ca.sh` before attempting to create any certificates
3. Check the CA directory exists and contains all required files
4. Verify openssl is installed and accessible
5. For Windows compatibility issues, try using the `-l` or `-w` options

## Notes

- The CA script uses SHA-512 by default for maximum security
- Client certificates use SHA-256 for better compatibility
- Legacy mode generates additional certificates compatible with older systems
- Windows format generates PKCS#12 files for easy import into Windows systems
