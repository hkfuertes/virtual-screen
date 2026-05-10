#!/bin/bash
#
# install-usbmuxd.sh
# Standalone installer for custom usbmuxd with NCM mode support
# Usage: curl -fsSL REPO_URL/install-usbmuxd.sh | sudo bash -
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_PREFIX="/usr/local"
SRC_DIR="/tmp/imd-build-$$"
PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

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

check_distribution() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect Linux distribution"
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "linuxmint" && "$ID" != "ubuntu" && "$ID_LIKE" != *"ubuntu"* ]]; then
        warn "This script is designed for Linux Mint/Ubuntu. Your distribution: $ID"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Detected distribution: $PRETTY_NAME"
}

install_dependencies() {
    log "Updating package lists..."
    apt update
    
    log "Installing build dependencies..."
    apt install -y \
        git build-essential pkg-config autoconf automake libtool-bin \
        libusb-1.0-0-dev libssl-dev udev libcurl4-openssl-dev \
        libreadline-dev libncurses5-dev libfuse-dev \
        usbmuxd libimobiledevice-utils libplist-utils
    
    log "Dependencies installed successfully"
}

build_library() {
    local repo_name=$1
    local configure_args=${2:-""}
    
    log "Building ${repo_name}..."
    
    cd "${SRC_DIR}"
    
    if [[ ! -d "${repo_name}" ]]; then
        git clone --depth 1 "https://github.com/libimobiledevice/${repo_name}.git"
    fi
    
    cd "${repo_name}"
    
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
    
    ./autogen.sh --prefix="${INSTALL_PREFIX}" ${configure_args}
    make -j"$(nproc)"
    make install
    ldconfig
    
    log "${repo_name} built and installed successfully"
}

configure_usbmuxd_service() {
    log "Configuring usbmuxd systemd service for NCM mode..."
    
    systemctl stop usbmuxd 2>/dev/null || true
    
    mkdir -p /etc/systemd/system/usbmuxd.service.d
    cat > /etc/systemd/system/usbmuxd.service.d/override.conf <<'EOF'
[Service]
Environment=USBMUXD_DEFAULT_DEVICE_MODE=3
ExecStart=
ExecStart=/usr/local/sbin/usbmuxd --user usbmux --systemd
PIDFile=/run/usbmuxd.pid
EOF
    
    systemctl daemon-reload
    systemctl enable usbmuxd
    systemctl restart usbmuxd
    
    if systemctl is-active --quiet usbmuxd; then
        log "usbmuxd service configured and started successfully"
    else
        error "usbmuxd service failed to start"
        systemctl status usbmuxd --no-pager
        exit 1
    fi
}

detect_apple_private_mac() {
    # Find Apple Private interface MAC dynamically
    # It typically starts with fe:7d:5e: and appears as enx* interface
    # with an unusual MAC (not matching standard OUI patterns)
    
    # Method 1: Check dmesg for Apple interfaces
    local mac
    mac=$(dmesg | grep -i 'Apple.*NCM\|Apple.*Private\|Apple.*networking' | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    if [[ -z "$mac" ]]; then
        # Method 2: Look for enx interfaces with fe:* MAC (Apple Private convention)
        mac=$(ip -o link show | grep 'enx' | grep -oE 'link/ether fe:[0-9a-f:]{14}' | awk '{print $2}' | head -1)
    fi
    
    if [[ -z "$mac" ]]; then
        # Method 3: Fallback - known Apple Private MAC pattern
        # fe:7d:5e:xx:xx:xx is common for iPad Air/Pro NCM interfaces
        warn "Could not detect Apple Private MAC automatically"
        log "Using known Apple Private MAC pattern (fe:7d:5e:*)"
        mac="fe:7d:5e:22:5c:e0"
    fi
    
    echo "$mac"
}

configure_network_manager() {
    log "Configuring NetworkManager to ignore Apple Private interface..."
    
    local private_mac
    private_mac=$(detect_apple_private_mac)
    
    log "Apple Private MAC: $private_mac"
    
    cat > /etc/NetworkManager/conf.d/99-unmanaged-ipad-private.conf <<EOF
[keyfile]
unmanaged-devices=mac:$private_mac
EOF
    
    systemctl restart NetworkManager
    
    log "NetworkManager configured"
}

create_connection_script() {
    log "Creating iPad USB connection helper script..."
    
    cat > /usr/local/bin/ipad-usb-connect <<'SCRIPT_EOF'
#!/bin/bash
# ipad-usb-connect - Create NetworkManager connection for iPad USB tethering

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}iPad USB Tethering Connection Setup${NC}"
echo

# Step 1: Check if any Apple device is connected via USB
if ! lsusb | grep -q 'Apple, Inc.'; then
    echo -e "${RED}ERROR: No Apple device detected via USB.${NC}"
    echo "Connect your iPad and try again."
    exit 1
fi

# Step 2: Trust the device if not already paired
if command -v idevicepair &>/dev/null; then
    PAIRED=$(idevicepair validate 2>/dev/null && echo "yes" || echo "no")
    if [[ "$PAIRED" == "no" ]]; then
        echo -e "${YELLOW}Device not trusted. Attempting to pair...${NC}"
        echo "Check your iPad screen and tap 'Trust' if prompted."
        idevicepair pair || {
            echo -e "${RED}Pairing failed. Unlock your iPad and tap 'Trust'.${NC}"
            exit 1
        }
        echo -e "${GREEN}Device paired successfully.${NC}"
    fi
fi

# Step 3: Find the Apple Tethering interface
# Apple Tethering interfaces typically appear as enx* with standard MAC
# Apple Private interfaces start with fe:* MAC (these should be ignored)
IFACES=$(ip -o link show | grep 'enx' | grep -v 'link/ether fe:' | awk '{print $2}' | tr -d ':')

if [[ -z "$IFACES" ]]; then
    echo -e "${RED}ERROR: No Apple Tethering interface found.${NC}"
    echo
    echo "Is usbmuxd running in NCM mode?"
    echo "  systemctl status usbmuxd"
    echo
    echo "Check dmesg for Apple interfaces:"
    echo "  dmesg | grep -i apple"
    echo
    echo "All enx interfaces:"
    ip link | grep -E '^[0-9]+: enx'
    exit 1
fi

# Use the first non-Private interface (should be only one for tethering)
IFACE=$(echo "$IFACES" | head -1)

echo -e "${GREEN}Found Apple Tethering interface: $IFACE${NC}"

# Step 4: Remove existing connection if present
nmcli con down iPad-USB-Tethering 2>/dev/null || true
nmcli con del iPad-USB-Tethering 2>/dev/null || true

# Step 5: Create new shared connection
echo "Creating NetworkManager connection..."
nmcli con add con-name iPad-USB-Tethering type ethernet ifname "$IFACE" \
    ipv4.method shared \
    ipv6.method shared

# Step 6: Activate connection
echo "Activating connection..."
nmcli con up iPad-USB-Tethering

echo
echo -e "${GREEN}Done! iPad should now have network access.${NC}"
echo "Host IP: 10.42.0.1"
echo
echo "To find iPad IP address:"
echo "  nmcli con show iPad-USB-Tethering | grep IP4.ADDRESS"
echo
echo "In Moonlight on iPad, add server manually: 10.42.0.1"
SCRIPT_EOF
    
    chmod +x /usr/local/bin/ipad-usb-connect
    
    log "Connection script created at /usr/local/bin/ipad-usb-connect"
}

cleanup() {
    log "Cleaning up build directory..."
    rm -rf "${SRC_DIR}"
}

main() {
    echo
    log "========================================="
    log "  usbmuxd NCM Mode Installer"
    log "========================================="
    echo
    
    check_root
    check_distribution
    
    # Create temporary build directory
    mkdir -p "${SRC_DIR}"
    trap cleanup EXIT
    
    # Install dependencies from apt
    install_dependencies
    
    echo
    log "Building libimobiledevice stack from source..."
    log "This may take 5-10 minutes..."
    echo
    
    # Build libraries in order (dependency chain)
    build_library "libplist"
    build_library "libimobiledevice-glue"
    build_library "libusbmuxd"
    build_library "libtatsu"
    build_library "libimobiledevice"
    build_library "usbmuxd" "--sysconfdir=/etc --localstatedir=/var --runstatedir=/run"
    
    # Configure systemd service
    configure_usbmuxd_service
    
    # Configure NetworkManager
    configure_network_manager
    
    # Create helper script
    create_connection_script
    
    echo
    log "========================================="
    log "  Installation Complete!"
    log "========================================="
    echo
    log "Next steps:"
    echo "  1. Connect your iPad via USB-C"
    echo "  2. Run: ipad-usb-connect"
    echo "  3. The iPad should get IP 10.42.0.x (host is 10.42.0.1)"
    echo "  4. Add 10.42.0.1 manually in Moonlight on iPad"
    echo
    log "To verify usbmuxd is running in NCM mode:"
    echo "  systemctl status usbmuxd"
    echo "  dmesg | grep -i 'Apple Tethering'"
    echo
}

main "$@"
