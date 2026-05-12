#!/bin/bash
#
# install-usbmuxd.sh
# Build and install libimobiledevice stack with NCM mode support.
# Only task: compile → install → start usbmuxd in NCM mode.
# Does NOT configure NetworkManager or networking — that's handled separately.
#
# Usage: ./scripts/install-usbmuxd.sh   (do NOT run as root)

set -euo pipefail

INSTALL_PREFIX="/usr/local"
SRC_DIR="${HOME}/src/imd"

log() { echo "[usbmuxd-install] $*"; }

# ── Checks ──────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "ERROR: Do not run as root. Use your normal user (sudo is invoked internally)."
        exit 1
    fi
}

# ── Dependencies ────────────────────────────────────────────────
install_deps() {
    log "Installing build dependencies..."
    sudo apt update
    sudo apt install -y \
        git build-essential pkg-config autoconf automake libtool-bin \
        libusb-1.0-0-dev libssl-dev udev libcurl4-openssl-dev \
        libreadline-dev libncurses5-dev
    log "Build dependencies OK"
}

# ── Build one library from the libimobiledevice stack ───────────
# Usage: build_lib <repo_name> [extra_autogen_args]
build_lib() {
    local repo="$1"
    local extra_args="${2:-}"

    log ">>> Building ${repo}..."

    cd "${SRC_DIR}"
    if [[ -d "${repo}" ]]; then
        cd "${repo}"
        git pull --quiet
    else
        git clone "https://github.com/libimobiledevice/${repo}.git"
        cd "${repo}"
    fi

    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    ./autogen.sh --prefix="${INSTALL_PREFIX}" ${extra_args}
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig

    log ">>> ${repo} OK"
}

# ── Configure usbmuxd systemd service (NCM mode = 3) ───────────
configure_service() {
    log "Configuring usbmuxd systemd service (NCM mode)..."

    sudo systemctl stop usbmuxd 2>/dev/null || true

    # Full unit pointing to our compiled binary with NCM enabled
    sudo tee /etc/systemd/system/usbmuxd.service > /dev/null <<'EOF'
[Unit]
Description=Socket daemon for the usbmux protocol used by Apple devices
Documentation=man:usbmuxd(8)

[Service]
Environment=USBMUXD_DEFAULT_DEVICE_MODE=3
ExecStart=/usr/local/sbin/usbmuxd --user usbmux --systemd
PIDFile=/run/usbmuxd.pid

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now usbmuxd

    log "usbmuxd service enabled and started"
}

# ── Main ────────────────────────────────────────────────────────
main() {
    log "=== usbmuxd NCM Installation ==="
    log "This will compile the libimobiledevice stack and start usbmuxd in NCM mode."

    check_root

    mkdir -p "${SRC_DIR}"
    install_deps

    # Build order: libplist → glue → usbmuxd → libtatsu → imobiledevice → usbmuxd daemon
    build_lib "libplist"
    build_lib "libimobiledevice-glue"
    build_lib "libusbmuxd"
    build_lib "libtatsu"
    build_lib "libimobiledevice"
    build_lib "usbmuxd" "--sysconfdir=/etc --localstatedir=/var --runstatedir=/run"

    configure_service

    log ""
    log "=== Done ==="
    log ""
    log "usbmuxd is now running with NCM mode (DEVICE_MODE=3)."
    log "Connect your iPad via USB-C and check:"
    log "  dmesg | grep -i 'Apple Tethering'"
    log ""
    log "You should see CDC-NCM network interfaces appear (enx...d0 / enx...d1)."
    log "Network setup is handled separately — this script only provides the USB daemon."
}

main "$@"
