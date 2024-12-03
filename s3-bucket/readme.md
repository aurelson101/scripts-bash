
# S3 Bucket Mount Script

  

A powerful script to mount S3 buckets from various providers using s3fs-fuse on Ubuntu/Debian systems.

  

## Features

  

- Support for multiple S3 providers (Infomaniak, OVH, Wasabi, etc.)

- Interactive credential management

- Secure credential storage

- Automatic s3fs installation

- Clean unmounting with Ctrl+C

  

## Prerequisites

  

- Ubuntu/Debian-based system

- sudo privileges

- Internet connection

  
  

## Supported Providers

  

- Infomaniak (default)

- OVH

- Wasabi

- Hostinger

- Scaleway

- Exoscale

- CloudFerro

- Google Cloud Storage

- DigitalOcean Spaces

- Linode Object Storage

- Configuration Files

  

## The script uses the following paths:

  

~/.s3fs-config: Saved credentials

~/.passwd-s3fs: S3fs credentials file

~/s3bucket: Default mount point

Security Features

600 permissions on credential files (user-only access)

Hidden secret key input

Secure credential storage

Safe unmounting process

Unmounting

Press Ctrl+C to safely unmount the bucket and exit the script.

  

## How to use

    ./mount-s3-bucket.sh --list

This command displays all supported S3 providers and their endpoints.

     ./mount-s3-bucket.sh ovh

Mount with specific provider

This mounts your S3 bucket using OVH's S3-compatible storage service.
