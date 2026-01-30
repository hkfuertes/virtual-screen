#!/bin/bash
#
# deactivate-virtual-display.sh
# Deactivate virtual display when Sunshine session ends
# Used as global_undo_cmd in Sunshine

set -e

LOGFILE="/var/log/virtual-display.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEACTIVATE: $*" | tee -a "$LOGFILE"
}

log "=== Deactivating virtual display ==="

# Auto-detect HDMI output
HDMI_OUTPUT=$(xrandr | grep -E "^HDMI" | awk '{print $1}' | head -1)

if [[ -z "$HDMI_OUTPUT" ]]; then
    log "WARNING: No HDMI output found, nothing to deactivate"
    exit 0
fi

log "HDMI output: $HDMI_OUTPUT"

# 1. Deactivate HDMI output
log "Turning off $HDMI_OUTPUT with xrandr --off"
xrandr --output "$HDMI_OUTPUT" --off

# 2. Clean up custom modes (optional, to avoid accumulation)
# Get all custom modes from HDMI and remove them
CUSTOM_MODES=$(xrandr | grep -A 20 "^$HDMI_OUTPUT" | grep -E '^\s+[0-9]+x[0-9]+' | awk '{print $1}' | grep -v '^$' || true)

if [[ -n "$CUSTOM_MODES" ]]; then
    log "Cleaning up custom modes"
    while IFS= read -r mode; do
        xrandr --delmode "$HDMI_OUTPUT" "$mode" 2>/dev/null || true
        xrandr --rmmode "$mode" 2>/dev/null || true
    done <<< "$CUSTOM_MODES"
fi

log "Virtual display deactivated successfully"
xrandr | grep " connected" | tee -a "$LOGFILE"
