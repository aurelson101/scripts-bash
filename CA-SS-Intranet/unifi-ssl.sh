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

# Ask for the UniFi Controller hostname
read -p "Enter the UniFi Controller hostname (e.g., unifi.yourdomain.com): " DOMAIN

# Ask for country, state, and city
read -p "Enter the country code (e.g., FR): " COUNTRY
read -p "Enter the state or province: " STATE
read -p "Enter the city: " CITY

# Set validity to 825 days (maximum allowed for public CAs)
DAYS=825

# Create a directory for the domain certificate
mkdir -p "${CA_NAME}/domains/${DOMAIN}"
cd "${CA_NAME}/domains/${DOMAIN}"

# Generate a private key for the domain
openssl genrsa -out "${DOMAIN}.key" 2048

# Create a certificate signing request (CSR)
openssl req -new -key "${DOMAIN}.key" -out "${DOMAIN}.csr" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=IT/CN=${DOMAIN}"

# Create a configuration file for X509v3 extensions
cat > "${DOMAIN}.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = DNS:${DOMAIN}
EOF

# Sign the certificate with the root CA
openssl x509 -req -in "${DOMAIN}.csr" \
    -CA "../../${CA_NAME}_rootCA.crt" \
    -CAkey "../../${CA_NAME}_rootCA.key" \
    -CAcreateserial \
    -out "${DOMAIN}.crt" \
    -days $DAYS -sha256 \
    -extfile "${DOMAIN}.ext"

# Create PKCS12 file
openssl pkcs12 -export \
    -in "${DOMAIN}.crt" \
    -inkey "${DOMAIN}.key" \
    -out "${DOMAIN}.p12" \
    -name unifi \
    -CAfile "../../${CA_NAME}_rootCA.crt" \
    -caname root \
    -password pass:aircontrolenterprise

echo "Certificate for ${DOMAIN} created successfully."
echo "PKCS12 file: ${DOMAIN}.p12"
echo "Validity: $((DAYS/365)) year(s)"
echo "Country: $COUNTRY"
echo "State/Province: $STATE"
echo "City: $CITY"
echo "Organization: $ORGANIZATION (extracted from CA certificate)"
echo ""
echo "To use this certificate on your UniFi Controller:"
echo "1. Copy ${DOMAIN}.p12 to your UniFi Controller server."
echo "2. Use the following command to import the certificate:"
echo "   keytool -importkeystore -srckeystore ${DOMAIN}.p12 -srcstoretype PKCS12 -srcstorepass aircontrolenterprise -destkeystore /usr/lib/unifi/data/keystore -deststorepass aircontrolenterprise -destkeypass aircontrolenterprise -alias unifi -noprompt"
echo "3. Modify /usr/lib/unifi/data/system.properties to include:"
echo "   unifi.https.keystore=/usr/lib/unifi/data/keystore"
echo "   unifi.https.keystorepass=aircontrolenterprise"
echo "4. Restart the UniFi Controller service."
echo "5. Ensure that the CA certificate is installed on client machines."
