#!/bin/bash
#
# install-virtual-display.sh
# Standalone installer for Sunshine virtual display support
# Usage: curl -fsSL REPO_URL/install-virtual-display.sh | sudo bash -
#

set -e

# Repository configuration - CHANGE THIS TO YOUR REPO URL
REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/sunshine-virtual-display"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in xrandr cvt curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        log "Install with: sudo apt install x11-xserver-utils curl"
        exit 1
    fi
    
    log "All dependencies satisfied"
}

check_hdmi_connector() {
    log "Detecting HDMI connector..."
    
    CONNECTOR=$(ls -d /sys/class/drm/card*-HDMI-A-* 2>/dev/null | head -1)
    
    if [[ -z "$CONNECTOR" ]]; then
        error "No HDMI connector found in /sys/class/drm/"
        log "Available connectors:"
        ls /sys/class/drm/ | grep "^card"
        exit 1
    fi
    
    log "Found HDMI connector: $CONNECTOR"
}

download_script() {
    local script_name=$1
    local dest_path=$2
    
    log "Downloading ${script_name}..."
    
    if ! curl -fsSL "${REPO_URL}/scripts/${script_name}" -o "${dest_path}"; then
        error "Failed to download ${script_name}"
        exit 1
    fi
    
    chmod +x "${dest_path}"
}

download_systemd_service() {
    log "Downloading systemd service..."
    
    if ! curl -fsSL "${REPO_URL}/systemd/virtual-display-init.service" -o /etc/systemd/system/virtual-display-init.service; then
        error "Failed to download systemd service"
        exit 1
    fi
    
    systemctl daemon-reload
    systemctl enable virtual-display-init.service
    
    log "Systemd service created and enabled"
}

print_sunshine_config() {
    echo
    log "========================================="
    log "  Sunshine Configuration Required"
    log "========================================="
    echo
    log "Add the following to your Sunshine configuration:"
    log "File: ~/.config/sunshine/sunshine.conf"
    echo
    echo "output_name = HDMI-1"
    echo "global_prep_cmd = /opt/sunshine-virtual-display/activate-virtual-display.sh"
    echo "global_undo_cmd = /opt/sunshine-virtual-display/deactivate-virtual-display.sh"
    echo
    log "Or configure via Sunshine Web UI at https://localhost:47990"
    echo
}

main() {
    echo
    log "========================================="
    log "  Virtual Display Installer"
    log "========================================="
    echo
    
    check_root
    check_dependencies
    check_hdmi_connector
    
    # Create installation directory
    mkdir -p "${INSTALL_DIR}"
    
    # Download scripts from repository
    download_script "init-virtual-display.sh" "${INSTALL_DIR}/init-virtual-display.sh"
    download_script "activate-virtual-display.sh" "${INSTALL_DIR}/activate-virtual-display.sh"
    download_script "deactivate-virtual-display.sh" "${INSTALL_DIR}/deactivate-virtual-display.sh"
    
    # Download and install systemd service
    download_systemd_service
    
    echo
    log "========================================="
    log "  Installation Complete!"
    log "========================================="
    echo
    
    print_sunshine_config
    
    log "Next steps:"
    echo "  1. Configure Sunshine (see above)"
    echo "  2. Reboot: sudo reboot"
    echo "  3. Connect from Moonlight client"
    echo
    log "Logs:"
    echo "  Boot: /var/log/virtual-display-init.log"
    echo "  Runtime: /var/log/virtual-display.log"
    echo
    log "Service status: systemctl status virtual-display-init.service"
    echo
}

main "$@"
