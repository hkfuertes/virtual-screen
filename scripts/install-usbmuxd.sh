#!/bin/bash
#
# install-usbmuxd.sh
# Install custom usbmuxd with NCM mode support for iPad USB networking
# Based on: https://github.com/libimobiledevice/usbmuxd

set -e

INSTALL_PREFIX="/usr/local"
SRC_DIR="${HOME}/src/imd"
PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "ERROR: Do not run this script as root. Use your normal user (sudo will be invoked when needed)"
        exit 1
    fi
}

install_dependencies() {
    log "Installing build dependencies..."
    sudo apt update
    sudo apt install -y \
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
    
    if [[ -d "${SRC_DIR}/${repo_name}" ]]; then
        log "Directory ${repo_name} exists, pulling latest changes..."
        cd "${SRC_DIR}/${repo_name}"
        git pull
    else
        log "Cloning ${repo_name}..."
        cd "${SRC_DIR}"
        git clone "https://github.com/libimobiledevice/${repo_name}.git"
        cd "${repo_name}"
    fi
    
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
    
    ./autogen.sh --prefix="${INSTALL_PREFIX}" ${configure_args}
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
    
    log "${repo_name} built and installed successfully"
}

configure_usbmuxd_service() {
    log "Configuring usbmuxd systemd service for NCM mode..."
    
    sudo systemctl stop usbmuxd || true
    
    # Create service override
    sudo mkdir -p /etc/systemd/system/usbmuxd.service.d
    sudo tee /etc/systemd/system/usbmuxd.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment=USBMUXD_DEFAULT_DEVICE_MODE=3
ExecStart=
ExecStart=/usr/local/sbin/usbmuxd --user usbmux --systemd
PIDFile=/run/usbmuxd.pid
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable usbmuxd
    sudo systemctl start usbmuxd
    
    log "usbmuxd service configured and started"
}

configure_network_manager() {
    log "Configuring NetworkManager to ignore Apple Private interface..."
    
    sudo tee /etc/NetworkManager/conf.d/99-unmanaged-ipad-private.conf > /dev/null <<'EOF'
[keyfile]
unmanaged-devices=mac:fe:7d:5e:22:5c:e0
EOF
    
    sudo systemctl restart NetworkManager
    
    log "NetworkManager configured"
}

create_connection_script() {
    log "Creating iPad USB connection helper script..."
    
    sudo tee /usr/local/bin/ipad-usb-connect > /dev/null <<'EOF'
#!/bin/bash
# ipad-usb-connect - Create NetworkManager connection for iPad USB tethering

set -e

# Find the Apple Tethering interface
IFACE=$(ip link | grep -E 'enx.*d0:' | awk '{print $2}' | tr -d ':' | head -1)

if [[ -z "$IFACE" ]]; then
    echo "ERROR: No Apple Tethering interface found. Is iPad connected via USB?"
    echo "Available interfaces:"
    ip link | grep -E '^[0-9]+: enx'
    exit 1
fi

echo "Found Apple Tethering interface: $IFACE"

# Remove existing connection if present
nmcli con down iPad-USB-Tethering 2>/dev/null || true
nmcli con del iPad-USB-Tethering 2>/dev/null || true

# Create new shared connection
echo "Creating NetworkManager connection..."
nmcli con add con-name iPad-USB-Tethering type ethernet ifname "$IFACE" \
    ipv4.method shared \
    ipv6.method shared

# Activate connection
echo "Activating connection..."
nmcli con up iPad-USB-Tethering

echo "Done! iPad should now have network access."
echo "Host IP: 10.42.0.1"
echo "iPad IP: Check with 'nmcli con show iPad-USB-Tethering | grep IP4.ADDRESS'"
EOF
    
    sudo chmod +x /usr/local/bin/ipad-usb-connect
    
    log "Connection script created at /usr/local/bin/ipad-usb-connect"
}

main() {
    log "=== usbmuxd Custom Installation Script ==="
    log "This will build and install libimobiledevice stack with NCM support"
    
    check_root
    
    # Create source directory
    mkdir -p "${SRC_DIR}"
    
    # Install dependencies from apt
    install_dependencies
    
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
    
    log "=== Installation Complete ==="
    log ""
    log "Next steps:"
    log "1. Connect your iPad via USB-C"
    log "2. Run: ipad-usb-connect"
    log "3. The iPad should get IP 10.42.0.x (host is 10.42.0.1)"
    log "4. Add 10.42.0.1 manually in Moonlight on iPad"
    log ""
    log "To verify usbmuxd is running in NCM mode:"
    log "  systemctl status usbmuxd"
    log "  dmesg | grep -i 'Apple Tethering'"
}

main "$@"
