#!/bin/bash
# =============================================================================
# Raspberry Pi Initial Bootstrap Script
# =============================================================================
#
# Run this script on a fresh Raspberry Pi to set up everything automatically.
#
# Usage (from a fresh Pi):
#   curl -sSL https://raw.githubusercontent.com/KevNev19/pi-and-mikrotek-ansible-setup/main/scripts/bootstrap.sh | bash
#
# Or if you've already cloned the repo:
#   ./scripts/bootstrap.sh
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/KevNev19/pi-and-mikrotek-ansible-setup.git"
INSTALL_DIR="/home/pi/pi-and-mikrotek-ansible-setup"
LOG_FILE="/var/log/ansible-boot-sync.log"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run this script as the 'pi' user, not as root"
        log_info "Usage: ./bootstrap.sh"
        exit 1
    fi
}

check_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_warn "This doesn't appear to be a Raspberry Pi. Continuing anyway..."
    fi
}

# -----------------------------------------------------------------------------
# Main Installation
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=============================================="
    echo "  Raspberry Pi Ansible Bootstrap"
    echo "=============================================="
    echo ""

    check_root
    check_pi

    # Step 1: Update system and install prerequisites
    log_info "Step 1/7: Updating system and installing prerequisites..."
    sudo apt update
    sudo apt install -y ansible git curl wget

    # Verify Ansible installation
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible installation failed"
        exit 1
    fi
    log_info "Ansible version: $(ansible --version | head -n1)"

    # Step 2: Clone or update repository
    log_info "Step 2/7: Setting up repository..."
    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Repository exists, pulling latest changes..."
        cd "$INSTALL_DIR"
        git fetch origin
        git reset --hard origin/main
        git clean -fd
    else
        log_info "Cloning repository..."
        rm -rf "$INSTALL_DIR"
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    # Step 3: Install Ansible Galaxy collections
    log_info "Step 3/7: Installing Ansible Galaxy collections..."
    ansible-galaxy collection install -r requirements.yml --force

    # Step 4: Make scripts executable
    log_info "Step 4/7: Setting script permissions..."
    chmod +x scripts/*.sh

    # Step 5: Create log file
    log_info "Step 5/7: Creating log file..."
    sudo touch "$LOG_FILE"
    sudo chown pi:pi "$LOG_FILE"

    # Step 6: Install systemd service
    log_info "Step 6/7: Installing systemd service..."
    sudo cp "$INSTALL_DIR/systemd/ansible-boot-sync.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable ansible-boot-sync.service

    # Step 7: Run Ansible playbook
    log_info "Step 7/7: Running initial Ansible playbook..."
    echo ""
    log_warn "This may take 10-15 minutes on first run..."
    echo ""

    cd "$INSTALL_DIR"
    sudo ansible-playbook playbooks/site.yml

    # Success message
    echo ""
    echo "=============================================="
    echo -e "${GREEN}  Bootstrap Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "Services should now be available at:"
    echo "  - Grafana:        http://192.168.88.253:3000"
    echo "  - Prometheus:     http://192.168.88.253:9090"
    echo "  - Home Assistant: http://192.168.88.253:8123"
    echo "  - Portainer:      https://192.168.88.253:9443"
    echo ""
    echo "Next steps:"
    echo "  1. Complete Home Assistant onboarding"
    echo "  2. Add HACS integration in Home Assistant"
    echo "  3. Connect Tailscale: sudo tailscale up --advertise-routes=192.168.88.0/24"
    echo "  4. Change default Grafana password (admin/ChangeMe123!)"
    echo ""
    echo "The system will now auto-sync on every boot."
    echo "To manually trigger a sync: sudo systemctl start ansible-boot-sync"
    echo ""
}

# Run main function
main "$@"
