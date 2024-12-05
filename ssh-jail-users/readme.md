
# SSH Jail Management System


## Description
SSH Jail Management System is an advanced Bash script designed to create and manage secure chroot jail environments for SSH users. It provides a controlled and isolated environment for SSH users, enhancing system security by restricting user access to specific system resources.

## Features
- Secure chroot jail environment creation
- Resource usage limitations
- Automated mount point management
- Comprehensive logging system
- Color-coded output for better visibility
- Error recovery mechanism
- System requirements verification
- Configurable security settings
- Support for SFTP-only access
- Optional X11 forwarding support
- TCP forwarding control

## Prerequisites
The script requires the following packages to be installed:
- openssh-server
- rsync
- quota
- coreutils
- util-linux

## Installation
1. Clone or download the script to your system
2. Make it executable:
```bash
chmod +x ssh-jail.sh
```
3. Ensure you have root privileges to run the script

## Usage
```bash
./ssh-jail.sh -u USERNAME [OPTIONS]
```

### Options
- `-u USERNAME`: Specify the username (required)
- `-b BINARIES`: Specify additional binaries to include in the jail
- `-s`: Enable SFTP-only mode
- `-v`: Enable verbose output
- `-x`: Allow X11 forwarding
- `-t`: Allow TCP forwarding
- `-h`: Display help message

### Examples
1. Create a basic jail for user 'testuser':
```bash
./ssh-jail.sh -u testuser
```

2. Create an SFTP-only jail with verbose output:
```bash
./ssh-jail.sh -u testuser -s -v
```

3. Create a jail with X11 forwarding enabled:
```bash
./ssh-jail.sh -u testuser -x
```

## Directory Structure
The script creates the following directory structure for each jail:
```
/home/jail/USERNAME/
├── bin/
├── dev/
├── etc/
├── home/USERNAME/
├── lib/
├── lib64/
├── proc/
├── tmp/
├── usr/
│   ├── lib/
│   └── lib64/
└── var/
    └── log/
```

## Security Features
- Resource limits for processes and file descriptors
- Secure mount point management
- Restricted system access
- Automated cleanup on failure
- Secure device node creation
- Configurable umask settings
- Backup management
- Log rotation

## Logging
The script maintains detailed logs at `/var/log/ssh-jail-setup.log` with the following features:
- Timestamp for each entry
- Log level indication (INFO, SUCCESS, WARNING, ERROR)
- Automatic log rotation when size exceeds 10MB
- Color-coded output in verbose mode

## Error Handling
The script includes comprehensive error handling:
- Automatic cleanup on failure
- Mount point management
- Configuration validation
- System requirements verification
- User input validation

## Configuration
Default configuration values are stored in the script and can be modified:
- `JAIL_BASE`: Base directory for jails (/home/jail)
- `MAX_FD`: Maximum file descriptors (1024)
- `SECURE_PATH`: Restricted PATH variable
- `SECURE_UMASK`: Default umask setting (0027)

## Troubleshooting
1. Check the log file at `/var/log/ssh-jail-setup.log` for detailed error messages
2. Ensure all required packages are installed
3. Verify you have sufficient permissions
4. Check available disk space
5. Ensure mount points are available

## Limitations
- Requires root privileges
- Some features may not work on all Linux distributions
- X11 forwarding requires additional system configuration
- Resource limits may need adjustment based on system capabilities
