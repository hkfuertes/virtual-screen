#!/bin/bash
#
# deactivate-virtual-display.sh
# Deactivate virtual display when Sunshine session ends.
# Used as global_undo_cmd in Sunshine.

set -e

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

LOGFILE="${XDG_RUNTIME_DIR:-/tmp}/virtual-display.log"
OUTPUT_FILE="/opt/sunshine-virtual-display/output_name"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEACTIVATE: $*" | tee -a "$LOGFILE" || true
}

log "=== Deactivating virtual display ==="

if [[ -f "$OUTPUT_FILE" ]]; then
    VIRTUAL_OUTPUT=$(cat "$OUTPUT_FILE")
    log "Using output: $VIRTUAL_OUTPUT"
else
    PRIMARY=$(xrandr | grep " connected primary" | awk '{print $1}')
    VIRTUAL_OUTPUT=$(xrandr | grep " connected" | grep -v "^${PRIMARY} " | awk '{print $1}' | head -1)
    log "WARNING: $OUTPUT_FILE not found, detected: $VIRTUAL_OUTPUT"
fi

if [[ -z "$VIRTUAL_OUTPUT" ]]; then
    log "WARNING: No virtual output found, nothing to deactivate"
    exit 0
fi

xrandr --output "$VIRTUAL_OUTPUT" --auto
log "=== Done. $VIRTUAL_OUTPUT reset to auto ==="
