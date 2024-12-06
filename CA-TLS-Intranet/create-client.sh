#!/bin/bash

# Default variables
DEFAULT_VALIDITY="365"
CA_DIR="ca"
DEFAULT_CA_NAME="RootCA"
DEFAULT_KEY_SIZE="2048"
DEFAULT_DIGEST="sha256"

# Help function
usage() {
    echo "Usage: $0 [options]"
    echo "Required:"
    echo "  -n    Client name"
    echo "Optional:"
    echo "  -d    DNS names (comma-separated)"
    echo "  -i    IP addresses (comma-separated)"
    echo "  -v    Validity in days (default: $DEFAULT_VALIDITY)"
    echo "  -k    Key size in bits (default: $DEFAULT_KEY_SIZE)"
    echo "  -c    CA name (default: $DEFAULT_CA_NAME)"
    echo "  -p    Enable password protection for client key"
    echo "  -t    Certificate type (server|client|both) (default: both)"
    echo "  -l    Legacy mode for older Windows systems"
    echo "  -w    Generate Windows-specific formats"
    echo "  -h    Show this help"
    exit 1
}

# Process arguments
while getopts "n:d:i:v:k:c:pt:lwh" opt; do
    case $opt in
        n) CLIENT_NAME="$OPTARG";;
        d) DOMAINS="$OPTARG";;
        i) IPS="$OPTARG";;
        v) VALIDITY="$OPTARG";;
        k) KEY_SIZE="$OPTARG";;
        c) CA_NAME="$OPTARG";;
        p) USE_PASSWORD=1;;
        t) CERT_TYPE="$OPTARG";;
        l) LEGACY_MODE=1;;
        w) WINDOWS_FORMAT=1;;
        h) usage;;
        ?) usage;;
    esac
done

# Verify required arguments
if [ -z "$CLIENT_NAME" ]; then
    echo "Error: Client name is required"
    usage
fi

# Initialize variables
CA_NAME=${CA_NAME:-$DEFAULT_CA_NAME}
VALIDITY=${VALIDITY:-$DEFAULT_VALIDITY}
KEY_SIZE=${KEY_SIZE:-$DEFAULT_KEY_SIZE}
CERT_TYPE=${CERT_TYPE:-"both"}
CLIENT_DIR="${CA_DIR}/clients/${CLIENT_NAME}"
PRIVATE_KEY="${CLIENT_DIR}/${CLIENT_NAME}.key"
CSR="${CLIENT_DIR}/${CLIENT_NAME}.csr"
CERT="${CLIENT_DIR}/${CLIENT_NAME}.crt"
CONFIG_FILE="${CLIENT_DIR}/${CLIENT_NAME}.cnf"
CA_CERT="${CA_DIR}/${CA_NAME}.crt"
CA_KEY="${CA_DIR}/private/${CA_NAME}.key"
CA_CONFIG="${CA_DIR}/${CA_NAME}.cnf"
PFX_FILE="${CLIENT_DIR}/${CLIENT_NAME}.pfx"
P12_FILE="${CLIENT_DIR}/${CLIENT_NAME}.p12"
PEM_FILE="${CLIENT_DIR}/${CLIENT_NAME}.pem"
LEGACY_KEY="${CLIENT_DIR}/${CLIENT_NAME}_legacy.key"
LEGACY_CERT="${CLIENT_DIR}/${CLIENT_NAME}_legacy.crt"

# Verify CA existence
if [ ! -f "$CA_CERT" ] || [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CONFIG" ]; then
    echo "Error: CA not found. Please run create_ca.sh first."
    exit 1
fi

# Create client directory
mkdir -p "$CLIENT_DIR"

# Create OpenSSL configuration for client
cat > "$CONFIG_FILE" << EOF
[ req ]
default_bits            = ${KEY_SIZE}
default_md              = ${DEFAULT_DIGEST}
distinguished_name      = req_distinguished_name
req_extensions         = req_ext
string_mask            = utf8only
prompt                 = no

[ req_distinguished_name ]
commonName             = ${CLIENT_NAME}

[ req_ext ]
subjectAltName         = @alt_names
keyUsage               = digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth, clientAuth

[ alt_names ]
DNS.1 = ${CLIENT_NAME}
EOF

# Set certificate type and extensions
case "$CERT_TYPE" in
    "server")
        CERT_EXT="server_cert"
        ;;
    "client")
        CERT_EXT="client_cert"
        ;;
    "both")
        CERT_EXT="server_cert"  # Using server cert with both server and client auth
        ;;
    *)
        echo "Error: Invalid certificate type"
        exit 1
        ;;
esac

# Add additional domains
if [ -n "$DOMAINS" ]; then
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    counter=2
    for domain in "${DOMAIN_ARRAY[@]}"; do
        echo "DNS.${counter} = ${domain}" >> "$CONFIG_FILE"
        ((counter++))
    done
fi

# Add IP addresses
if [ -n "$IPS" ]; then
    IFS=',' read -ra IP_ARRAY <<< "$IPS"
    counter=1
    for ip in "${IP_ARRAY[@]}"; do
        echo "IP.${counter} = ${ip}" >> "$CONFIG_FILE"
        ((counter++))
    done
fi

# Generate client private key
if [ "$USE_PASSWORD" = "1" ]; then
    openssl genrsa -aes256 -out "$PRIVATE_KEY" "$KEY_SIZE"
else
    openssl genrsa -out "$PRIVATE_KEY" "$KEY_SIZE"
fi
chmod 400 "$PRIVATE_KEY"

# Generate legacy RSA key if needed
if [ "$LEGACY_MODE" = "1" ]; then
    openssl rsa -in "$PRIVATE_KEY" -out "$LEGACY_KEY" -outform PEM
    chmod 400 "$LEGACY_KEY"
fi

# Generate CSR
if [ "$USE_PASSWORD" = "1" ]; then
    openssl req -new -key "$PRIVATE_KEY" -out "$CSR" -config "$CONFIG_FILE" -passin stdin
else
    openssl req -new -key "$PRIVATE_KEY" -out "$CSR" -config "$CONFIG_FILE"
fi

# Sign client certificate with CA
openssl ca -batch \
    -config "$CA_CONFIG" \
    -in "$CSR" \
    -out "$CERT" \
    -days "$VALIDITY" \
    -extensions "${CERT_EXT}" \
    -notext

# Generate Windows-compatible formats if requested
if [ "$WINDOWS_FORMAT" = "1"