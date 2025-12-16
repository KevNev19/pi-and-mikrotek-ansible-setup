#!/bin/bash
# =============================================================================
# Raspberry Pi Ansible Boot Sync Script
# =============================================================================
#
# This script is triggered on every boot by systemd to:
# 1. Pull the latest configuration from Git
# 2. Run Ansible playbooks to configure the system
#
# Logs are written to: /var/log/ansible-boot-sync.log
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO_URL="https://github.com/KevNev19/pi-and-mikrotek-ansible-setup.git"
CONFIG_DIR="/home/pi/pi-and-mikrotek-ansible-setup"
LOG_FILE="/var/log/ansible-boot-sync.log"
LOCK_FILE="/tmp/ansible-boot-sync.lock"
MAX_RETRIES=3
RETRY_DELAY=10

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

cleanup() {
    rm -f "$LOCK_FILE"
    log_info "Cleanup complete"
}

wait_for_network() {
    log_info "Waiting for network connectivity..."
    local attempt=1
    while [ $attempt -le 30 ]; do
        if ping -c 1 -W 2 github.com &> /dev/null; then
            log_info "Network is available"
            return 0
        fi
        log_info "Waiting for network... attempt $attempt/30"
        sleep 2
        ((attempt++))
    done
    log_error "Network not available after 60 seconds"
    return 1
}

sync_repository() {
    log_info "Syncing configuration repository..."

    if [ -d "$CONFIG_DIR/.git" ]; then
        log_info "Pulling latest changes..."
        cd "$CONFIG_DIR"

        # Fetch and reset to handle force pushes
        git fetch origin
        git reset --hard origin/main
        git clean -fd

        log_info "Repository updated to commit: $(git rev-parse --short HEAD)"
    else
        log_info "Cloning repository..."
        rm -rf "$CONFIG_DIR"
        git clone "$REPO_URL" "$CONFIG_DIR"
        log_info "Repository cloned at commit: $(cd "$CONFIG_DIR" && git rev-parse --short HEAD)"
    fi
}

install_ansible_requirements() {
    log_info "Installing Ansible requirements..."
    cd "$CONFIG_DIR"

    if [ -f "requirements.yml" ]; then
        ansible-galaxy collection install -r requirements.yml --force 2>&1 | tee -a "$LOG_FILE"
    fi
}

run_ansible() {
    log_info "Running Ansible playbook..."
    cd "$CONFIG_DIR"

    # Run with retries
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Ansible run attempt $attempt/$MAX_RETRIES"

        if ansible-playbook playbooks/site.yml 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Ansible completed successfully"
            return 0
        else
            log_warn "Ansible failed on attempt $attempt"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi
        ((attempt++))
    done

    log_error "Ansible failed after $MAX_RETRIES attempts"
    return 1
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------
main() {
    # Header
    log_info "=============================================="
    log_info "Ansible Boot Sync Starting"
    log_info "=============================================="
    log_info "Hostname: $(hostname)"
    log_info "Date: $(date)"

    # Check for lock file (prevent concurrent runs)
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE")))
        if [ $lock_age -gt 1800 ]; then
            log_warn "Stale lock file found (${lock_age}s old), removing..."
            rm -f "$LOCK_FILE"
        else
            log_error "Lock file exists. Another sync may be running."
            exit 1
        fi
    fi

    # Create lock file and setup cleanup trap
    trap cleanup EXIT
    touch "$LOCK_FILE"

    # Wait for network
    if ! wait_for_network; then
        log_error "Aborting due to network failure"
        exit 1
    fi

    # Sync repository
    if ! sync_repository; then
        log_error "Repository sync failed"
        exit 1
    fi

    # Install Ansible requirements
    install_ansible_requirements

    # Run Ansible
    if ! run_ansible; then
        log_error "Ansible run failed"
        exit 1
    fi

    # Success
    log_info "=============================================="
    log_info "Boot Sync Completed Successfully"
    log_info "=============================================="

    exit 0
}

# Run main function
main "$@"
