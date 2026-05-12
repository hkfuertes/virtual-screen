#!/bin/bash
#
# activate-virtual-display.sh
# Activate virtual display with client resolution.
# Used as global_prep_cmd in Sunshine.

set -e

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

LOGFILE="${XDG_RUNTIME_DIR:-/tmp}/virtual-display.log"
OUTPUT_FILE="/opt/sunshine-virtual-display/output_name"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ACTIVATE: $*" | tee -a "$LOGFILE" || true
}

log "=== Activating virtual display ==="

# Read output name set by init script at boot
if [[ -f "$OUTPUT_FILE" ]]; then
    VIRTUAL_OUTPUT=$(cat "$OUTPUT_FILE")
    log "Using output from $OUTPUT_FILE: $VIRTUAL_OUTPUT"
else
    # Fallback: first connected non-primary output
    PRIMARY=$(xrandr | grep " connected primary" | awk '{print $1}')
    VIRTUAL_OUTPUT=$(xrandr | grep " connected" | grep -v "^${PRIMARY} " | awk '{print $1}' | head -1)
    log "WARNING: $OUTPUT_FILE not found, detected: $VIRTUAL_OUTPUT"
fi

if [[ -z "$VIRTUAL_OUTPUT" ]]; then
    log "ERROR: No virtual output found"
    exit 1
fi

PRIMARY_OUTPUT=$(xrandr | grep " connected primary" | awk '{print $1}' | head -1)
if [[ -z "$PRIMARY_OUTPUT" ]]; then
    PRIMARY_OUTPUT=$(xrandr | grep " connected" | grep -v "^${VIRTUAL_OUTPUT} " | awk '{print $1}' | head -1)
fi

log "Virtual output: $VIRTUAL_OUTPUT  |  Primary: $PRIMARY_OUTPUT"

WIDTH="${SUNSHINE_CLIENT_WIDTH:-1920}"
HEIGHT="${SUNSHINE_CLIENT_HEIGHT:-1080}"
FPS="${SUNSHINE_CLIENT_FPS:-60}"

log "Resolution: ${WIDTH}x${HEIGHT}@${FPS}Hz  |  Client: ${SUNSHINE_CLIENT_NAME:-unknown}"

MODELINE=$(cvt "$WIDTH" "$HEIGHT" "$FPS" | grep Modeline | sed 's/Modeline //')
MODE_NAME=$(echo "$MODELINE" | awk '{print $1}' | tr -d '"')

log "Mode: $MODE_NAME  ($MODELINE)"

xrandr --delmode "$VIRTUAL_OUTPUT" "$MODE_NAME" 2>/dev/null || true
xrandr --rmmode "$MODE_NAME" 2>/dev/null || true
eval xrandr --newmode $MODELINE
xrandr --addmode "$VIRTUAL_OUTPUT" "$MODE_NAME"
xrandr --output "$VIRTUAL_OUTPUT" --mode "$MODE_NAME" --left-of "$PRIMARY_OUTPUT"

log "=== Done. Virtual display active ==="
xrandr | grep " connected" | tee -a "$LOGFILE"
