#!/bin/bash

# List of available S3 providers
declare -A S3_PROVIDERS=(
    ["infomaniak"]="https://s3.infomaniak.com"
    ["ovh"]="https://s3.gra.cloud.ovh.net"
    ["wasabi"]="https://s3.wasabisys.com"
    ["hostinger"]="https://s3.hostinger.com"
    ["scaleway"]="https://s3.fr-par.scw.cloud"
    ["exoscale"]="https://sos-ch-gva-2.exo.io"
    ["cloudferro"]="https://s3.cloudferro.com"
    ["google"]="https://storage.googleapis.com"
    ["digitalocean"]="https://nyc3.digitaloceanspaces.com"
    ["linode"]="https://us-east-1.linodeobjects.com"
)

MOUNT_POINT="$HOME/s3bucket"
PROVIDER="infomaniak"
CONFIG_FILE="$HOME/.s3fs-config"
CREDENTIALS_FILE="$HOME/.passwd-s3fs"

# Function to display available providers
show_providers() {
    echo "Available S3 providers:"
    for provider in "${!S3_PROVIDERS[@]}"; do
        echo "- $provider (${S3_PROVIDERS[$provider]})"
    done
}

# Function to load saved credentials
load_credentials() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Previous configuration found. Do you want to use it? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            source "$CONFIG_FILE"
            return 0
        fi
    fi
    return 1
}

# Function to request credentials
get_credentials() {
    read -p "Enter S3 bucket name: " BUCKET_NAME
    while [ -z "$BUCKET_NAME" ]; do
        read -p "Bucket name cannot be empty. Try again: " BUCKET_NAME
    done

    read -p "Enter your S3 access key: " ACCESS_KEY
    while [ -z "$ACCESS_KEY" ]; do
        read -p "Access key cannot be empty. Try again: " ACCESS_KEY
    done

    read -s -p "Enter your S3 secret key: " SECRET_KEY
    echo
    while [ -z "$SECRET_KEY" ]; do
        read -s -p "Secret key cannot be empty. Try again: " SECRET_KEY
        echo
    done
}

# Function to save credentials
save_credentials() {
    echo "Do you want to save these settings for future use? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "BUCKET_NAME=$BUCKET_NAME" > "$CONFIG_FILE"
        echo "ACCESS_KEY=$ACCESS_KEY" >> "$CONFIG_FILE"
        echo "SECRET_KEY=$SECRET_KEY" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo "Configuration saved to $CONFIG_FILE"
    fi
}

# Function for clean unmounting
cleanup() {
    echo "Unmounting S3 bucket..."
    fusermount -u "$MOUNT_POINT"
    exit 0
}

# Check arguments
if [ "$1" = "--list" ]; then
    show_providers
    exit 0
fi

if [ -n "$1" ]; then
    if [ -n "${S3_PROVIDERS[$1]}" ]; then
        PROVIDER="$1"
    else
        echo "Unrecognized provider: $1"
        show_providers
        exit 1
    fi
fi

# Check for s3fs
if ! command -v s3fs &> /dev/null; then
    echo "Installing s3fs..."
    sudo apt-get update && sudo apt-get install -y s3fs
fi

# Load or request credentials
if ! load_credentials; then
    get_credentials
    save_credentials
fi

# Create s3fs credentials file
echo "${ACCESS_KEY}:${SECRET_KEY}" > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount S3 bucket
s3fs "$BUCKET_NAME" "$MOUNT_POINT" \
    -o passwd_file="$CREDENTIALS_FILE" \
    -o url="${S3_PROVIDERS[$PROVIDER]}" \
    -o use_path_request_style \
    -o allow_other \
    -o umask=0022

# Capture SIGINT signal for clean unmounting
trap cleanup SIGINT

# Confirmation message
echo "S3 bucket mounted at $MOUNT_POINT via ${S3_PROVIDERS[$PROVIDER]}"
echo "Press Ctrl+C to unmount and exit"

# Keep script running
while true; do
    sleep 1
done
