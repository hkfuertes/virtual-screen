#!/bin/bash
#
# install-sunshine.sh
# Installs Sunshine and configures it for virtual display use.
# Run as a regular user (sudo is used internally where needed).
#
# Usage: bash install-sunshine.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SUNSHINE_CONF="${HOME}/.config/sunshine/sunshine.conf"
VIRTUAL_DISPLAY_INSTALL_DIR="/opt/sunshine-virtual-display"
OUTPUT_FILE="/run/virtual-display-output"

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root."
        error "It uses sudo internally. Run as your regular user."
        exit 1
    fi
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log "This script needs sudo for package installation. You may be prompted for your password."
        sudo true
    fi
}

# ---------------------------------------------------------------------------
# Detect Ubuntu base codename (Mint ships UBUNTU_CODENAME in /etc/os-release)
# ---------------------------------------------------------------------------

detect_ubuntu_codename() {
    local codename
    codename=$(grep -oP '(?<=UBUNTU_CODENAME=)\S+' /etc/os-release 2>/dev/null || true)
    if [[ -z "$codename" ]]; then
        codename=$(grep -oP '(?<=VERSION_CODENAME=)\S+' /etc/os-release 2>/dev/null || true)
    fi
    echo "$codename"
}

# ---------------------------------------------------------------------------
# Install Sunshine
# ---------------------------------------------------------------------------

install_sunshine() {
    if command -v sunshine &>/dev/null; then
        log "Sunshine is already installed: $(sunshine --version 2>/dev/null || echo 'version unknown')"
        return 0
    fi

    local codename
    codename=$(detect_ubuntu_codename)

    log "Detected Ubuntu base: $codename"
    log "Fetching latest Sunshine release from GitHub..."

    local api_url="https://api.github.com/repos/LizardByte/Sunshine/releases/latest"
    local release_json
    release_json=$(curl -fsSL "$api_url")

    # Find .deb asset matching our Ubuntu codename (e.g. ubuntu-24.04-amd64)
    local deb_url
    deb_url=$(echo "$release_json" | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep "ubuntu-" | grep "amd64.deb" \
        | grep "$codename" | head -1 || true)

    # Fallback: try with ubuntu version number mapping
    if [[ -z "$deb_url" ]]; then
        local version_num
        case "$codename" in
            noble)   version_num="24.04" ;;
            jammy)   version_num="22.04" ;;
            focal)   version_num="20.04" ;;
            *)       version_num="" ;;
        esac
        if [[ -n "$version_num" ]]; then
            deb_url=$(echo "$release_json" | grep -oP '"browser_download_url":\s*"\K[^"]+' \
                | grep "ubuntu-${version_num}-amd64.deb" | head -1 || true)
        fi
    fi

    if [[ -z "$deb_url" ]]; then
        error "Could not find a Sunshine .deb for Ubuntu $codename"
        info "Available packages:"
        echo "$release_json" | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep ".deb"
        exit 1
    fi

    local deb_file="/tmp/sunshine-install.deb"
    log "Downloading: $deb_url"
    curl -fsSL -o "$deb_file" "$deb_url"

    log "Installing Sunshine..."
    sudo apt install -y "$deb_file"
    rm -f "$deb_file"

    log "Sunshine installed successfully"
}

# ---------------------------------------------------------------------------
# Enable Sunshine user service
# ---------------------------------------------------------------------------

enable_sunshine_service() {
    log "Enabling Sunshine user service..."

    systemctl --user daemon-reload
    systemctl --user enable sunshine

    if systemctl --user is-active --quiet sunshine; then
        log "Sunshine service is already running"
    else
        systemctl --user start sunshine || warn "Could not start Sunshine now (may need reboot)"
    fi
}

# ---------------------------------------------------------------------------
# Detect virtual output name
# ---------------------------------------------------------------------------

detect_virtual_output() {
    # Prefer the name saved by init script (post-reboot)
    if [[ -f "$OUTPUT_FILE" ]]; then
        cat "$OUTPUT_FILE"
        return
    fi

    # Derive from sysfs (same logic as init-virtual-display.sh)
    for path in /sys/class/drm/card*-DP-* /sys/class/drm/card*-HDMI-A-*; do
        [[ -f "$path/status" ]] || continue
        [[ "$(cat "$path/status")" == "disconnected" ]] || continue
        basename "$path" | sed 's/^card[0-9]*-//' | sed 's/HDMI-A-\([0-9]*\)/HDMI-\1/'
        return
    done

    echo ""
}

# ---------------------------------------------------------------------------
# Configure Sunshine
# ---------------------------------------------------------------------------

set_conf_key() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -qE "^#?[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
        # Key exists (possibly commented) — replace it
        sed -i "s|^#\?[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        echo "${key} = ${value}" >> "$file"
    fi
}

configure_sunshine() {
    local virtual_output
    virtual_output=$(detect_virtual_output)

    if [[ -z "$virtual_output" ]]; then
        warn "Could not detect virtual output — skipping output_name configuration."
        warn "Set it manually in $SUNSHINE_CONF after rebooting."
        virtual_output="<your-output-name>"
    else
        log "Detected virtual output: $virtual_output"
    fi

    log "Configuring Sunshine..."
    mkdir -p "$(dirname "$SUNSHINE_CONF")"
    touch "$SUNSHINE_CONF"

    local prep_json="[{\"do\":\"${VIRTUAL_DISPLAY_INSTALL_DIR}/activate-virtual-display.sh\",\"undo\":\"${VIRTUAL_DISPLAY_INSTALL_DIR}/deactivate-virtual-display.sh\",\"elevated\":false}]"

    set_conf_key "output_name"     "$virtual_output" "$SUNSHINE_CONF"
    set_conf_key "global_prep_cmd" "$prep_json"      "$SUNSHINE_CONF"

    log "Sunshine configuration written to $SUNSHINE_CONF"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    echo
    log "========================================="
    log "  Sunshine Installer + Virtual Display"
    log "========================================="
    echo

    check_not_root
    check_sudo
    install_sunshine
    enable_sunshine_service
    configure_sunshine

    echo
    log "========================================="
    log "  Done!"
    log "========================================="
    echo
    info "Next steps:"
    echo "  1. Install virtual display scripts (if not done):"
    echo "       sudo bash scripts/install-virtual-display.sh"
    echo "  2. Reboot so the virtual display init service runs"
    echo "  3. Open Moonlight on your iPad and add the host manually: 10.42.0.1"
    echo
    info "Sunshine Web UI (after reboot): https://localhost:47990"
    info "Logs: journalctl --user -u sunshine -f"
    echo
}

main "$@"
