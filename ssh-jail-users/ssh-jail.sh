#!/bin/bash

# Script: ssh-jail.sh
# Description: Advanced SSH Jail Management System
# Version: 3.0

# Color definitions
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m'

# Security defaults
declare -r MAX_FD=1024
declare -r SECURE_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
declare -r SECURE_UMASK=0027

# Default configuration
declare -r DEFAULT_CONFIG="/etc/ssh-jail/config.conf"
declare -r LOG_FILE="/var/log/ssh-jail-setup.log"
declare -r BACKUP_DIR="/var/backups/ssh-jail"
declare -r JAIL_BASE="/home/jail"

# Global variables
VERBOSE=false
NO_BACKUP=false
SFTP_ONLY=false
ALLOW_X11=false
ALLOW_TCP=false

# Error recovery mechanism
trap 'cleanup_on_error $?' ERR EXIT

cleanup_on_error() {
    local exit_code=$1
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script failed with exit code $exit_code - cleaning up"
        if [[ -n "$USERNAME" && -d "$JAIL_BASE/$USERNAME" ]]; then
            handle_mounts "$JAIL_BASE/$USERNAME" unmount
            rm -rf "$JAIL_BASE/$USERNAME"
        fi
        [[ -f "/etc/ssh/sshd_config.bak" ]] && mv "/etc/ssh/sshd_config.bak" "/etc/ssh/sshd_config"
        systemctl restart sshd
    fi
}

# Mount management
handle_mounts() {
    local jail_dir=$1
    local action=$2

    case "$action" in
        mount)
            mount -t proc proc "$jail_dir/proc" || log ERROR "Failed to mount proc"
            mount -t devpts devpts "$jail_dir/dev/pts" || log ERROR "Failed to mount devpts"
            ;;
        unmount)
            umount "$jail_dir/proc" 2>/dev/null
            umount "$jail_dir/dev/pts" 2>/dev/null
            ;;
    esac
}

# Configuration validation
validate_config() {
    local error=0
    
    if [[ -z "$JAIL_BASE" ]]; then
        log ERROR "JAIL_BASE is not set"
        error=1
    fi
    
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        log ERROR "Log directory does not exist: $(dirname "$LOG_FILE")"
        error=1
    fi
    
    if [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
        log ERROR "Log directory is not writable: $(dirname "$LOG_FILE")"
        error=1
    fi
    
    if [[ ! -d "$JAIL_BASE" ]]; then
        if ! mkdir -p "$JAIL_BASE"; then
            log ERROR "Cannot create JAIL_BASE directory: $JAIL_BASE"
            error=1
        fi
    fi
    
    return $error
}

# Resource limits setup
set_resource_limits() {
    local username=$1
    
    cat > "/etc/security/limits.d/$username.conf" << EOF
$username soft nproc 100
$username hard nproc 200
$username soft nofile 1024
$username hard nofile 2048
$username soft core 0
$username hard core 0
EOF
}

# Enhanced logging
log() {
    local level=$1
    shift
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local message="[$timestamp] [$level] $*"
    
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")
        if [[ $log_size -gt 10485760 ]]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            gzip "$LOG_FILE.old"
        fi
    fi
    
    echo -e "$message" >> "$LOG_FILE"
    
    if [[ "$VERBOSE" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        case $level in
            INFO)    echo -e "${BLUE}$message${NC}" ;;
            SUCCESS) echo -e "${GREEN}$message${NC}" ;;
            WARNING) echo -e "${YELLOW}$message${NC}" ;;
            ERROR)   echo -e "${RED}$message${NC}" >&2 ;;
        esac
    fi
}

# System requirements check
check_system() {
    local required_packages=(
        "openssh-server"
        "rsync"
        "quota"
        "coreutils"
        "util-linux"
    )
    
    local required_commands=(
        "useradd"
        "chroot"
        "rsync"
        "quota"
        "ssh-keygen"
        "logger"
    )
    
    log INFO "Checking system requirements..."
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log ERROR "Required command not found: $cmd"
            return 1
        fi
    done
    
    return 0
}

# Create jail environment
create_jail() {
    local username=$1
    local jail_dir="$JAIL_BASE/$username"
    
    [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]] && {
        log ERROR "Invalid username format"
        return 1
    }
    
    useradd -r -s /bin/bash -d "/home/$username" -m "$username" || {
        log ERROR "Failed to create user"
        return 1
    }
    
    mkdir -p "$jail_dir"/{bin,lib,lib64,etc,home/$username,dev,proc,tmp,usr/{lib,lib64},var/log}
    
    # Setup devices
    mknod -m 666 "$jail_dir/dev/null" c 1 3
    mknod -m 666 "$jail_dir/dev/zero" c 1 5
    mknod -m 666 "$jail_dir/dev/random" c 1 8
    mknod -m 666 "$jail_dir/dev/urandom" c 1 9
    mknod -m 666 "$jail_dir/dev/tty" c 5 0
    
    # Set permissions
    chmod 755 "$jail_dir"
    chmod 700 "$jail_dir/home/$username"
    chmod 1777 "$jail_dir/tmp"
    
    # Copy system files
    cp -r /etc/{passwd,group,shadow,gshadow} "$jail_dir/etc/"
    
    # Mount filesystems
    handle_mounts "$jail_dir" mount
    
    # Set resource limits
    set_resource_limits "$username"
    
    log SUCCESS "Jail created for user $username"
    return 0
}

# Main execution
main() {
    check_system || exit 1
    validate_config || exit 1
    
    while getopts "u:b:svxth" opt; do
        case $opt in
            u) USERNAME="$OPTARG" ;;
            b) BINARIES="$OPTARG" ;;
            s) SFTP_ONLY=true ;;
            v) VERBOSE=true ;;
            x) ALLOW_X11=true ;;
            t) ALLOW_TCP=true ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
    
    [[ -z "$USERNAME" ]] && {
        log ERROR "Username required"
        exit 1
    }
    
    create_jail "$USERNAME" || exit 1
}

main "$@"
