# Custom Certificate Authority and Domain Certificate Creation Scripts

## Overview

This repository contains two bash scripts for creating a custom Certificate Authority (CA) and domain certificates signed by that CA. These scripts are designed for internal or testing use, providing a simple way to generate self-signed certificates.

## Scripts

1. `CA.sh`: Creates a new Certificate Authority (CA)
2. `CA-SEC.sh`: Creates a new Certificate Authority (CA) with secure password
3. `ssl.sh`: Creates a domain certificate signed by the CA
4. `ssl-sec.sh`: Creates a domain certificate signed by the CA with secure password
5. `ssl-sec.sh`: Creates a domain certificate signed by the CA with secure password
6. `ssl-p12.sh`: Creates a domain certificate signed by the CA
7. `unifi-ssl.sh`: This option allows you to create an SSL for the Unifi controller
   
## Usage

### Creating a Certificate Authority

To create a new Certificate Authority:


`./CA.sh`

Or with key password:

`./CA-sec.sh`


This script will:

- Prompt for the CA name
- Ask for country code, state/province, city, and organization details
- Generate a CA private key and certificate
- Export the CA certificate in formats suitable for Windows, macOS, and Linux
- Provide instructions for importing the CA certificate on different systems

### Creating a Domain Certificate

To create a domain certificate signed by your CA:


`./ssl.sh <CA_name>`

or with key password :

`./ssl-sec.sh`

Replace `<CA_name>` with the name of your Certificate Authority.

This script will:

- Check for the existence of CA files
- Extract the organization name from the CA certificate
- Prompt for the domain name
- Ask for country code, state/province, and city
- Allow choosing certificate validity (1, 3, or 5 years)
- Generate a domain private key and certificate signing request (CSR)
- Sign the CSR with your CA to create the domain certificate
- Provide a summary of the created certificate and instructions for use
- Your CA are will be like /yourfolder/CAfolder
- Your SSL are will be like /yourfolder/CAfolder/domains/xxx.yourdomain.com

### Creating a P12 Domain Certificate
You need to create Certificate domain first and after generate a p12 format like exemple:

`./ssl.sh <CA_name>`  
`./ssl-p12.sh <CA_name>`

## Important Notes

- Keep your CA private key (`<CA_name>_rootCA.key`) secure at all times.
- If you password-protect the domain private key, you'll need to provide this password when configuring your web server.
- Install the CA certificate on all client machines that need to trust the domain certificates.
- These scripts are for internal or testing use. For public-facing websites, use a recognized public Certificate Authority.

