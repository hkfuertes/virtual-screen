#!/bin/bash
#
# activate-virtual-display.sh
# Activate virtual display with client resolution
# Used as global_prep_cmd in Sunshine

set -e

LOGFILE="/var/log/virtual-display.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ACTIVATE: $*" | tee -a "$LOGFILE"
}

log "=== Activating virtual display ==="

# Auto-detect HDMI output
HDMI_OUTPUT=$(xrandr | grep -E "^HDMI.*connected" | awk '{print $1}' | head -1)
if [[ -z "$HDMI_OUTPUT" ]]; then
    log "ERROR: No connected HDMI output found"
    xrandr | tee -a "$LOGFILE"
    exit 1
fi

# Auto-detect primary output
PRIMARY_OUTPUT=$(xrandr | grep " connected primary" | awk '{print $1}' | head -1)
if [[ -z "$PRIMARY_OUTPUT" ]]; then
    log "WARNING: No primary output found, using first connected output"
    PRIMARY_OUTPUT=$(xrandr | grep " connected" | grep -v "^$HDMI_OUTPUT" | awk '{print $1}' | head -1)
fi

log "HDMI output: $HDMI_OUTPUT"
log "Primary output: $PRIMARY_OUTPUT"

# Sunshine exports these variables when a client connects
WIDTH="${SUNSHINE_CLIENT_WIDTH:-1920}"
HEIGHT="${SUNSHINE_CLIENT_HEIGHT:-1080}"
FPS="${SUNSHINE_CLIENT_FPS:-60}"

log "Requested resolution: ${WIDTH}x${HEIGHT}@${FPS}Hz"
log "Client: ${SUNSHINE_CLIENT_NAME:-unknown}"

# 1. Generate modeline with cvt
MODELINE=$(cvt "$WIDTH" "$HEIGHT" "$FPS" | grep Modeline | sed 's/Modeline //')
MODE_NAME=$(echo "$MODELINE" | awk '{print $1}' | tr -d '"')

log "Modeline: $MODELINE"
log "Mode name: $MODE_NAME"

# 2. Remove previous mode if it exists (avoid errors)
xrandr --delmode "$HDMI_OUTPUT" "$MODE_NAME" 2>/dev/null || true
xrandr --rmmode "$MODE_NAME" 2>/dev/null || true

# 3. Create new mode
log "Creating mode with xrandr --newmode"
xrandr --newmode $MODELINE

# 4. Add mode to output
log "Adding mode to $HDMI_OUTPUT"
xrandr --addmode "$HDMI_OUTPUT" "$MODE_NAME"

# 5. Activate output with mode and position it
log "Activating $HDMI_OUTPUT with mode $MODE_NAME left of $PRIMARY_OUTPUT"
xrandr --output "$HDMI_OUTPUT" --mode "$MODE_NAME" --left-of "$PRIMARY_OUTPUT"

log "Virtual display activated successfully"
xrandr | grep " connected" | tee -a "$LOGFILE"
