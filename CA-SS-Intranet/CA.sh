#!/bin/bash

# Ask for the CA name
read -p "Enter the name of your Certificate Authority (e.g., MyIntranetCA): " CA_NAME

# Ask for country, state, and city
read -p "Enter the country code (e.g., FR): " COUNTRY
read -p "Enter the state or province: " STATE
read -p "Enter the city: " CITY

# Create a directory for the CA
mkdir -p "${CA_NAME}"
cd "${CA_NAME}"

# Generate the CA private key
openssl genrsa -out "${CA_NAME}_rootCA.key" 4096

# Generate the self-signed CA certificate
openssl req -x509 -new -nodes -key "${CA_NAME}_rootCA.key" -sha256 -days 3650 -out "${CA_NAME}_rootCA.crt" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${CA_NAME}/OU=IT/CN=${CA_NAME} Root CA"

# Export for Windows (DER format)
openssl x509 -in "${CA_NAME}_rootCA.crt" -outform DER -out "${CA_NAME}_rootCA.cer"

# Export for macOS (PEM format, but with .crt extension)
cp "${CA_NAME}_rootCA.crt" "${CA_NAME}_rootCA_mac.crt"

# Export for Linux (PEM format)
cp "${CA_NAME}_rootCA.crt" "${CA_NAME}_rootCA_linux.pem"

echo "CA Certificate created successfully."
echo "Generated files:"
echo "- CA Certificate (PEM): ${CA_NAME}_rootCA.crt"
echo "- CA Private Key: ${CA_NAME}_rootCA.key"
echo "- CA Certificate for Windows (DER): ${CA_NAME}_rootCA.cer"
echo "- CA Certificate for macOS: ${CA_NAME}_rootCA_mac.crt"
echo "- CA Certificate for Linux: ${CA_NAME}_rootCA_linux.pem"

echo ""
echo "Import instructions:"
echo "Windows: Double-click on ${CA_NAME}_rootCA.cer and install it in 'Trusted Root Certification Authorities'"
echo "macOS: Double-click on ${CA_NAME}_rootCA_mac.crt and add it to the Keychain Access as 'Always Trust'"
echo "Linux: Copy ${CA_NAME}_rootCA_linux.pem to /usr/local/share/ca-certificates/ and run 'sudo update-ca-certificates'"

echo ""
echo "Procedure for deploying via Group Policy Object (GPO):"
echo "1. Copy ${CA_NAME}_rootCA.cer to a network share accessible by domain computers."
echo "2. Open the Group Policy Management Console (gpmc.msc)."
echo "3. Create a new GPO or edit an existing one."
echo "4. Navigate to: Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies."
echo "5. Right-click on 'Trusted Root Certification Authorities' and select 'Import'."
echo "6. Follow the Certificate Import Wizard:"
echo "   a. Browse to the location of ${CA_NAME}_rootCA.cer on the network share."
echo "   b. Select 'Place all certificates in the following store' and choose 'Trusted Root Certification Authorities'."
echo "   c. Complete the wizard."
echo "7. Close the Group Policy Management Editor."
echo "8. Link the GPO to the appropriate Organizational Unit (OU) containing the target computers."
echo "9. Force a Group Policy update on client computers or wait for the next automatic update."
echo ""
echo "Note: Ensure that domain computers have read access to the network share containing the certificate."
