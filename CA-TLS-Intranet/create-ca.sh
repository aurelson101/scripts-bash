#!/bin/bash

# Default variables
DEFAULT_CA_NAME="RootCA"
DEFAULT_VALIDITY="3650"  # 10 years default
DEFAULT_KEY_SIZE="4096"
DEFAULT_DIGEST="sha512"
CA_DIR="ca"
CRL_DAYS="30"

# Help function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n    CA name (default: $DEFAULT_CA_NAME)"
    echo "  -v    Validity in days (default: $DEFAULT_VALIDITY)"
    echo "  -k    Key size in bits (default: $DEFAULT_KEY_SIZE)"
    echo "  -d    Digest algorithm (default: $DEFAULT_DIGEST)"
    echo "  -c    Country code (optional)"
    echo "  -s    State (optional)"
    echo "  -l    Locality (optional)"
    echo "  -o    Organization (optional)"
    echo "  -u    Organizational Unit (optional)"
    echo "  -e    Email (optional)"
    echo "  -p    Enable password protection for CA key"
    echo "  -h    Show this help"
    exit 1
}

# Process arguments
while getopts "n:v:k:d:c:s:l:o:u:e:ph" opt; do
    case $opt in
        n) CA_NAME="$OPTARG";;
        v) VALIDITY="$OPTARG";;
        k) KEY_SIZE="$OPTARG";;
        d) DIGEST="$OPTARG";;
        c) COUNTRY="$OPTARG";;
        s) STATE="$OPTARG";;
        l) LOCALITY="$OPTARG";;
        o) ORGANIZATION="$OPTARG";;
        u) ORG_UNIT="$OPTARG";;
        e) EMAIL="$OPTARG";;
        p) USE_PASSWORD=1;;
        h) usage;;
        ?) usage;;
    esac
done

# Initialize variables
CA_NAME=${CA_NAME:-$DEFAULT_CA_NAME}
VALIDITY=${VALIDITY:-$DEFAULT_VALIDITY}
KEY_SIZE=${KEY_SIZE:-$DEFAULT_KEY_SIZE}
DIGEST=${DIGEST:-$DEFAULT_DIGEST}
PRIVATE_KEY="${CA_DIR}/private/${CA_NAME}.key"
CERT="${CA_DIR}/${CA_NAME}.crt"
CRL_FILE="${CA_DIR}/${CA_NAME}.crl"
CONFIG_FILE="${CA_DIR}/${CA_NAME}.cnf"
SUBJECT="/CN=${CA_NAME}"

# Build subject string with optional fields
[ -n "$COUNTRY" ] && SUBJECT="/C=${COUNTRY}${SUBJECT}"
[ -n "$STATE" ] && SUBJECT="/ST=${STATE}${SUBJECT}"
[ -n "$LOCALITY" ] && SUBJECT="/L=${LOCALITY}${SUBJECT}"
[ -n "$ORGANIZATION" ] && SUBJECT="/O=${ORGANIZATION}${SUBJECT}"
[ -n "$ORG_UNIT" ] && SUBJECT="/OU=${ORG_UNIT}${SUBJECT}"
[ -n "$EMAIL" ] && SUBJECT="/emailAddress=${EMAIL}${SUBJECT}"

# Create CA directory structure
mkdir -p "${CA_DIR}/private" "${CA_DIR}/newcerts" "${CA_DIR}/clients"
touch "${CA_DIR}/index.txt"
[ ! -f "${CA_DIR}/serial" ] && echo "01" > "${CA_DIR}/serial"

# Create OpenSSL configuration file
cat > "$CONFIG_FILE" << EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ${CA_DIR}
certs             = \$dir
crl_dir           = \$dir
database          = \$dir/index.txt
new_certs_dir     = \$dir/newcerts
certificate       = ${CERT}
serial            = \$dir/serial
crl               = ${CRL_FILE}
private_key       = ${PRIVATE_KEY}
RANDFILE          = \$dir/private/.rand
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 365
default_crl_days  = ${CRL_DAYS}
default_md        = ${DIGEST}
preserve          = no
policy            = policy_strict
copy_extensions   = copy

[ policy_strict ]
countryName             = optional
stateOrProvinceName     = optional
localityName           = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[ req ]
default_bits            = ${KEY_SIZE}
default_md              = ${DIGEST}
distinguished_name      = req_distinguished_name
string_mask            = utf8only
x509_extensions        = v3_ca

[ req_distinguished_name ]
countryName            = Country Name (2 letter code)
stateOrProvinceName    = State or Province Name
localityName           = Locality Name
organizationName       = Organization Name
organizationalUnitName = Organizational Unit Name
commonName             = Common Name
emailAddress           = Email Address

[ v3_ca ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical,CA:true
keyUsage               = critical,digitalSignature,cRLSign,keyCertSign

[ server_cert ]
basicConstraints        = CA:FALSE
nsCertType             = server
nsComment              = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth

[ client_cert ]
basicConstraints        = CA:FALSE
nsCertType             = client
nsComment              = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage               = critical, digitalSignature
extendedKeyUsage       = clientAuth
EOF

# Check if CA exists
if [ -f "$PRIVATE_KEY" ] || [ -f "$CERT" ]; then
    echo "CA already exists. Do you want to renew it? (y/N)"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        backup_dir="${CA_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        [ -f "$PRIVATE_KEY" ] && cp "$PRIVATE_KEY" "$backup_dir/"
        [ -f "$CERT" ] && cp "$CERT" "$backup_dir/"
        [ -f "$CRL_FILE" ] && cp "$CRL_FILE" "$backup_dir/"
        rm -f "$PRIVATE_KEY" "$CERT" "$CRL_FILE"
    else
        echo "Operation cancelled."
        exit 0
    fi
fi

# Generate CA private key
if [ "$USE_PASSWORD" = "1" ]; then
    openssl genrsa -aes256 -out "$PRIVATE_KEY" "$KEY_SIZE"
else
    openssl genrsa -out "$PRIVATE_KEY" "$KEY_SIZE"
fi
chmod 400 "$PRIVATE_KEY"

# Generate self-signed CA certificate
if [ "$USE_PASSWORD" = "1" ]; then
    openssl req -x509 -new -nodes \
        -key "$PRIVATE_KEY" \
        -${DIGEST} \
        -days "$VALIDITY" \
        -out "$CERT" \
        -config "$CONFIG_FILE" \
        -subj "$SUBJECT" \
        -passin stdin
else
    openssl req -x509 -new -nodes \
        -key "$PRIVATE_KEY" \
        -${DIGEST} \
        -days "$VALIDITY" \
        -out "$CERT" \
        -config "$CONFIG_FILE" \
        -subj "$SUBJECT"
fi

# Generate initial CRL
openssl ca -config "$CONFIG_FILE" -gencrl -out "$CRL_FILE"

# Verify the certificate
openssl x509 -in "$CERT" -text -noout > "${CA_DIR}/${CA_NAME}.info"

echo "CA generated successfully:"
echo "Private key: $PRIVATE_KEY"
echo "Certificate: $CERT"
echo "CRL: $CRL_FILE"
echo "Configuration: $CONFIG_FILE"
echo "Certificate info: ${CA_DIR}/${CA_NAME}.info"

if [ "$USE_PASSWORD" = "1" ]; then
    echo "Important: Your CA private key is password protected. Keep the password safe!"
fi
