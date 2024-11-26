#!/bin/bash

# Check if the CA name has been provided
if [ $# -eq 0 ]; then
    echo "Please provide the name of the Certificate Authority."
    echo "Usage: $0 <CA_name>"
    exit 1
fi

CA_NAME=$1

# Check if the CA directory exists
if [ ! -d "$CA_NAME" ]; then
    echo "CA directory not found. Make sure you have first run the CA creation script."
    exit 1
fi

# Ask for the domain name
read -p "Enter the domain name for which you want to create a PFX file: " DOMAIN

# Create necessary directories
mkdir -p "${CA_NAME}/domains/${DOMAIN}"

# Generate private key for the domain (using 2048 bits for broader compatibility)
openssl genrsa -out "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.key" 2048

# Generate a Certificate Signing Request (CSR)
openssl req -new -key "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.key" -out "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.csr" -subj "/CN=${DOMAIN}"

# Sign the CSR with the CA to generate the domain certificate
openssl x509 -req -in "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.csr" \
    -CA "${CA_NAME}/${CA_NAME}_rootCA.crt" \
    -CAkey "${CA_NAME}/${CA_NAME}_rootCA.key" \
    -CAcreateserial \
    -out "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.crt" \
    -days 365 -sha256

# Ask for the PFX password
read -s -p "Enter the password for the PFX file: " PFX_PASSWORD
echo

# Create the PFX file with broader compatibility
openssl pkcs12 -export \
    -out "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.pfx" \
    -inkey "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.key" \
    -in "${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.crt" \
    -certfile "${CA_NAME}/${CA_NAME}_rootCA.crt" \
    -password pass:$PFX_PASSWORD \
    -legacy \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES

# Check if the PFX file was created successfully
if [ $? -eq 0 ]; then
    echo "PFX file created successfully: ${CA_NAME}/domains/${DOMAIN}/${DOMAIN}.pfx"
    echo "You can now import this PFX file into systems that require it."
    echo "Remember to keep the PFX password safe, as you'll need it when importing the certificate."
    
    echo ""
    echo "Instructions for importing the PFX file:"
    echo ""
    echo "1. Importing into Windows (including Windows Server):"
    echo "   a. Double-click the PFX file"
    echo "   b. Select 'Local Machine' and click 'Next'"
    echo "   c. Click 'Next' to confirm the file path"
    echo "   d. Enter the PFX password when prompted and click 'Next'"
    echo "   e. Select 'Automatically select the certificate store based on the type of certificate' and click 'Next'"
    echo "   f. Click 'Finish' to complete the import"
    echo ""
    echo "2. Importing using PowerShell (useful for Windows Server):"
    echo "   \$pfxPath = \"C:\\path\\to\\${DOMAIN}.pfx\""
    echo "   \$pfxPass = ConvertTo-SecureString -String \"${PFX_PASSWORD}\" -Force -AsPlainText"
    echo "   Import-PfxCertificate -FilePath \$pfxPath -CertStoreLocation Cert:\\LocalMachine\\My -Password \$pfxPass"
    echo ""
    echo "3. Importing into SQL Server:"
    echo "   a. Open SQL Server Configuration Manager"
    echo "   b. Expand 'SQL Server Network Configuration'"
    echo "   c. Right-click on 'Protocols for <INSTANCE_NAME>' and select 'Properties'"
    echo "   d. Go to the 'Certificate' tab"
    echo "   e. Click 'Import' and browse to the PFX file"
    echo "   f. Enter the PFX password when prompted"
    echo "   g. Select the imported certificate and click 'Apply'"
    echo "   h. Restart the SQL Server service for changes to take effect"
    echo ""
    echo "Note: Ensure you have the necessary permissions to import certificates and modify configurations."
    echo "If you encounter issues on Windows Server, check security settings and try the PowerShell method."
else
    echo "Failed to create PFX file. Please check the error messages above."
fi
