#!/bin/bash
#
# init-virtual-display.sh
# Initialize virtual HDMI display on boot
# - Force HDMI connector to "on" via sysfs
# - Leave output available in xrandr but disabled (--off)
# - This allows Sunshine to start correctly but Cinnamon does not manage the display

set -e

LOGFILE="/var/log/virtual-display-init.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "=== Initializing virtual display ==="

# 1. Auto-detect HDMI connector in sysfs
CONNECTOR_SYSFS=$(ls -d /sys/class/drm/card*-HDMI-A-* 2>/dev/null | head -1)

if [[ -z "$CONNECTOR_SYSFS" ]]; then
    log "ERROR: No HDMI connector found in /sys/class/drm/"
    log "Available connectors:"
    ls /sys/class/drm/ | grep "^card" | tee -a "$LOGFILE"
    exit 1
fi

log "Detected HDMI connector: $CONNECTOR_SYSFS"

FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"

if [[ ! -f "$STATUS_FILE" ]]; then
    log "ERROR: Cannot find $STATUS_FILE"
    exit 1
fi

# 2. Force HDMI connector to "on"
if [[ -w "$FORCE_FILE" ]]; then
    log "Forcing HDMI to 'on' via $FORCE_FILE"
    echo on > "$FORCE_FILE"
else
    log "Force file not available, using status file: $STATUS_FILE"
    echo on > "$STATUS_FILE"
fi

# 2. Force HDMI connector to "on"
if [[ -w "$FORCE_FILE" ]]; then
    log "Forcing HDMI to 'on' via $FORCE_FILE"
    echo on > "$FORCE_FILE"
else
    log "Force file not available, using status file: $STATUS_FILE"
    echo on > "$STATUS_FILE"
fi

# 3. Wait for X11 to be available
# This script runs before user login, so we wait for DISPLAY
TIMEOUT=30
ELAPSED=0
while [[ -z "$DISPLAY" ]] && [[ $ELAPSED -lt $TIMEOUT ]]; do
    export DISPLAY=:0
    if xrandr &>/dev/null; then
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [[ $ELAPSED -ge $TIMEOUT ]]; then
    log "ERROR: X11 not available after ${TIMEOUT}s"
    exit 1
fi

log "X11 available at DISPLAY=$DISPLAY"

# 4. Auto-detect HDMI output name in xrandr
HDMI_OUTPUT=$(xrandr | grep -E "^HDMI.*connected" | awk '{print $1}' | head -1)

if [[ -z "$HDMI_OUTPUT" ]]; then
    log "WARNING: No connected HDMI output found in xrandr"
    xrandr | tee -a "$LOGFILE"
    exit 1
fi

log "Detected HDMI output: $HDMI_OUTPUT"

# 5. Ensure it is disabled (--off)
log "Setting $HDMI_OUTPUT to --off"
xrandr --output "$HDMI_OUTPUT" --off

log "Virtual display initialized successfully: exists in xrandr but is off"
log "Sunshine can start. Use prep_cmd to activate when needed."
