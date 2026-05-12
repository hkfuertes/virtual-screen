#!/bin/bash
#
# install-ipad-nm.sh
# Configure NetworkManager to manage iPad USB networking (method=shared).
# NM handles DHCP internally — no udhcpd needed.
#
# Usage: sudo ./scripts/install-ipad-nm.sh
#   iPad should be connected via USB when running this script.

set -euo pipefail

log() { echo "[ipad-nm] $*"; }

if [[ $EUID -ne 0 ]]; then
    log "ERROR: Run with sudo"
    exit 1
fi

HOST_IP="10.42.0.1/24"
CON_NAME="ipad-usb"

# ── Cleanup old udhcpd-based setup ──────────────────────────────
log "Cleaning up old udhcpd setup (if any)..."
systemctl stop "ipad-usb@*.service"  2>/dev/null || true
systemctl disable "ipad-usb@*.service" 2>/dev/null || true
rm -f /etc/systemd/system/ipad-usb@.service
rm -f /etc/systemd/system/ipad-usb-stop@.service
rm -f /etc/udev/rules.d/99-ipad-usb.rules
rm -f /etc/udhcpd-ipad.conf
rm -f /etc/NetworkManager/conf.d/ipad-usb-unmanaged.conf
rm -f /usr/local/bin/ipad-usb-link.sh
systemctl daemon-reload
udevadm control --reload
nmcli connection delete "$CON_NAME" 2>/dev/null || true
log "Cleanup done"

# ── Detect iPad interface ────────────────────────────────────────
IFACE=$(ip -o link show | awk -F': ' '$2 ~ /^enx/ {print $2}' | head -1)
if [[ -z "$IFACE" ]]; then
    log "ERROR: No iPad USB interface found. Connect the iPad and run again."
    exit 1
fi

# Derive MAC from interface name (enxAABBCCDDEEFF → AA:BB:CC:DD:EE:FF)
RAW="${IFACE#enx}"
MAC=$(echo "$RAW" | sed 's/\(..\)/\1:/g;s/:$//')
log "iPad interface: $IFACE  (MAC $MAC)"

# ── Create NetworkManager connection ────────────────────────────
log "Creating NM connection '$CON_NAME'..."
nmcli connection add \
    type ethernet \
    con-name "$CON_NAME" \
    802-3-ethernet.mac-address "$MAC" \
    ipv4.method shared \
    ipv4.addresses "$HOST_IP" \
    connection.autoconnect yes

# ── Prevent NM from auto-connecting to other enx* interfaces ────
log "Disabling NM auto-connect for unknown enx* interfaces..."
cat > /etc/NetworkManager/conf.d/ipad-usb-only.conf << 'EOF'
# Prevent NetworkManager from auto-connecting to unrecognised USB ethernet
# interfaces (e.g. second iPad interface). The explicit ipad-usb profile
# (matched by MAC) still activates normally.
[main]
no-auto-default=*
EOF
nmcli general reload

# ── Activate ────────────────────────────────────────────────────
log "Activating connection..."
nmcli connection up "$CON_NAME" ifname "$IFACE"
sleep 2

# ── Verify ──────────────────────────────────────────────────────
log ""
log "=== Done ==="
log ""
LEASE_FILE=$(ls /var/lib/NetworkManager/dnsmasq-*/leases 2>/dev/null | head -1 || true)
if [[ -n "$LEASE_FILE" ]]; then
    log "DHCP leases:"
    cat "$LEASE_FILE" | while read -r line; do log "  $line"; done
fi
IPAD_IP=$(nmcli -t -f IP4.ADDRESS connection show "$CON_NAME" 2>/dev/null | awk -F: '{print $2}' | head -1 || true)
log "Host IP on $IFACE: $HOST_IP"
log ""
log "Flow:"
log "  Connect    → NM auto-activates '$CON_NAME' → iPad gets IP via DHCP"
log "  Disconnect → NM deactivates automatically"
log ""
log "Check iPad IP:  nmcli connection show ipad-usb | grep IP4"
log "Check leases:   cat /var/lib/NetworkManager/dnsmasq-*/leases"
