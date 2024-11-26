#!/bin/bash

# Check if the CA name has been provided
if [ $# -eq 0 ]; then
    echo "Please provide the name of the Certificate Authority."
    echo "Usage: $0 <CA_name>"
    exit 1
fi

CA_NAME=$1

# Ask for the domain name
read -p "Enter the domain name for the PKCS#12 certificate: " DOMAIN

# Check if the domain certificate exists
if [ ! -f "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.crt" ] || [ ! -f "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.key" ]; then
    echo "Domain certificate not found. Please create it first using the create_domain_cert.sh script."
    exit 1
fi

# Ask for the PKCS#12 file password
read -s -p "Enter password for the PKCS#12 file: " P12_PASSWORD
echo

# Create the PKCS#12 file
openssl pkcs12 -export \
    -in "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.crt" \
    -inkey "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.key" \
    -out "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.p12" \
    -name "${DOMAIN}" \
    -CAfile "${CA_NAME}/${CA_NAME}_rootCA.crt" \
    -caname "${CA_NAME} Root CA" \
    -password pass:${P12_PASSWORD}

echo "PKCS#12 certificate for ${DOMAIN} created successfully."
echo "PKCS#12 file: ${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.p12"
echo ""
echo "You can now use this .p12 file with your Unifi controller or other devices that require PKCS#12 format."
