#!/bin/bash
#
# uninstall-virtual-display.sh
# Removes all virtual display components: scripts and sunshine config.
# Usage: sudo bash scripts/uninstall-virtual-display.sh

set -e

GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }

INSTALL_DIR="/opt/sunshine-virtual-display"
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

log "Removing installed scripts..."
rm -rf "$INSTALL_DIR"

log "Cleaning Sunshine config..."
SUNSHINE_CONF="${USER_HOME}/.config/sunshine/sunshine.conf"
if [[ -f "$SUNSHINE_CONF" ]]; then
    sed -i '/global_prep_cmd/d' "$SUNSHINE_CONF"
    sed -i '/output_name/d' "$SUNSHINE_CONF"
fi

log "Done."
