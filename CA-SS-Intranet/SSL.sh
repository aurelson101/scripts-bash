#!/bin/bash

# Check if the CA name has been provided
if [ $# -eq 0 ]; then
    echo "Please provide the name of the Certificate Authority."
    echo "Usage: $0 <CA_name>"
    exit 1
fi

CA_NAME=$1

# Check if the CA files exist
if [ ! -f "${CA_NAME}/${CA_NAME}_rootCA.crt" ] || [ ! -f "${CA_NAME}/${CA_NAME}_rootCA.key" ]; then
    echo "CA files not found. Make sure you have first run the create_ca_certificate.sh script."
    exit 1
fi

# Extract organization from CA certificate
ORGANIZATION=$(openssl x509 -noout -subject -in "${CA_NAME}/${CA_NAME}_rootCA.crt" | sed -n 's/.*O = \([^,]*\).*/\1/p')

if [ -z "$ORGANIZATION" ]; then
    echo "Failed to extract organization from CA certificate. Please check the CA certificate."
    exit 1
fi

# Ask for the domain name
read -p "Enter the domain name (e.g., www.yourdomain.com): " DOMAIN

# Ask for country, state, and city
read -p "Enter the country code (e.g., FR): " COUNTRY
read -p "Enter the state or province: " STATE
read -p "Enter the city: " CITY

# Ask for certificate validity
while true; do
    read -p "Enter certificate validity (1 for 1 year, 3 for 3 years, 5 for 5 years): " VALIDITY
    if [[ "$VALIDITY" =~ ^[135]$ ]]; then
        break
    else
        echo "Please enter 1, 3, or 5."
    fi
done

# Calculate days
DAYS=$((VALIDITY * 365))

# Create a directory for the domain certificate
mkdir -p "${CA_NAME}/domains/${DOMAIN}"
cd "${CA_NAME}/domains/${DOMAIN}"

# Generate a private key for the domain
openssl genrsa -out "${DOMAIN}.key" 2048

# Create a certificate signing request (CSR)
openssl req -new -key "${DOMAIN}.key" -out "${DOMAIN}.csr" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=IT/CN=${DOMAIN}"

# Initialize subjectAltName string
SAN="DNS:${DOMAIN}, DNS:*.${DOMAIN#*.}"

# Ask for the number of additional subjectAltName entries
read -p "How many additional subjectAltName entries do you want to add? " SAN_COUNT

# Ask for additional subjectAltName entries
for ((i=1; i<=SAN_COUNT; i++)); do
    echo "Entry $i:"
    read -p "Enter the type (DNS or IP): " SAN_TYPE
    read -p "Enter the value: " SAN_VALUE
    
    SAN="${SAN}, ${SAN_TYPE}:${SAN_VALUE}"
done

# Create a configuration file for X509v3 extensions
cat > "${DOMAIN}.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = ${SAN}
EOF

# Sign the certificate with the root CA
openssl x509 -req -in "${DOMAIN}.csr" \
    -CA "../../${CA_NAME}_rootCA.crt" \
    -CAkey "../../${CA_NAME}_rootCA.key" \
    -CAcreateserial \
    -out "${DOMAIN}.crt" \
    -days $DAYS -sha256 \
    -extfile "${DOMAIN}.ext"

echo "Certificate for ${DOMAIN} created successfully."
echo "Certificate: ${DOMAIN}.crt"
echo "Private key: ${DOMAIN}.key"
echo "Validity: $VALIDITY year(s)"
echo "Country: $COUNTRY"
echo "State/Province: $STATE"
echo "City: $CITY"
echo "Organization: $ORGANIZATION (extracted from CA certificate)"
echo "Subject Alternative Names: ${SAN}"
echo ""
echo "To use this certificate on your web server:"
echo "1. Copy ${DOMAIN}.crt and ${DOMAIN}.key to your server."
echo "2. Configure your web server to use these files."
echo "3. Ensure that the CA certificate is installed on client machines."
