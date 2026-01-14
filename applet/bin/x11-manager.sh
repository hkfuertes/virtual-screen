#!/bin/bash
# x11-manager.sh - X11 HDMI-1 manager
# Usage: ./x11-manager.sh <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]

CONNECTOR_SYSFS="/sys/class/drm/card1-HDMI-A-1"
FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"
OUTPUT="HDMI-1"

# Defaults (iPad Air)
WIDTH=2360
HEIGHT=1640
REFRESH=60

# Parse options (getopts para -w -h -r)
while getopts "w:h:r:" opt; do
  case $opt in
    w) WIDTH="$OPTARG" ;;
    h) HEIGHT="$OPTARG" ;;
    r) REFRESH="$OPTARG" ;;
    *) echo "Usage: $0 <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]"; exit 1 ;;
  esac
done
shift $((OPTIND-1))

MODE_NAME="${WIDTH}x${HEIGHT}_${REFRESH}.00"

case "$1" in
  on)
    echo "Creating + turning HDMI-1 ON: ${WIDTH}x${HEIGHT}@${REFRESH}Hz..."
    
    # Forzar conector "on"
    if [ -w "$FORCE_FILE" ]; then
      echo "on" | sudo tee "$FORCE_FILE" >/dev/null
    else
      echo "on" | sudo tee "$STATUS_FILE" >/dev/null
    fi
    
    sleep 2
    xrandr --output "$OUTPUT" --off 2>/dev/null || true

    MODELINE=$(cvt "$WIDTH" "$HEIGHT" "$REFRESH" 2>/dev/null | grep Modeline | sed 's/Modeline "\([^"]*\)" //')
    if [ -n "$MODELINE" ]; then
      xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
      xrandr --addmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
    fi
    
    xrandr --output "$OUTPUT" --mode "$MODE_NAME"
    echo "HDMI-1 ON: $MODE_NAME"
    ;;

  off)
    echo "Turning HDMI-1 OFF + cleanup..."
    xrandr --output "$OUTPUT" --off 2>/dev/null || true
    xrandr --delmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
    xrandr --rmmode "$MODE_NAME" 2>/dev/null || true
    
    # Reset force (state 0)
    if [ -w "$FORCE_FILE" ]; then
      echo "detect" | sudo tee "$FORCE_FILE" >/dev/null
    fi
    echo "HDMI-1 OFF (force reset)"
    ;;

  change)
    echo "Changing HDMI-1 to ${WIDTH}x${HEIGHT}@${REFRESH}Hz..."
    
    MODELINE=$(cvt "$WIDTH" "$HEIGHT" "$REFRESH" 2>/dev/null | grep Modeline | sed 's/Modeline "\([^"]*\)" //')
    if [ -n "$MODELINE" ]; then
      xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
      xrandr --addmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
    fi
    
    xrandr --output "$OUTPUT" --mode "$MODE_NAME"
    echo "HDMI-1 changed: $MODE_NAME"
    ;;

  status)
    echo "=== HDMI-1 Status ==="
    xrandr | grep "$OUTPUT" || echo "Output not detected in xrandr"
    echo "--- Connector ---"
    cat "$STATUS_FILE" 2>/dev/null || echo "Status not accessible"
    [ -r "$FORCE_FILE" ] && echo "--- Force ---" && cat "$FORCE_FILE" || true
    ;;

  *)
    echo "Usage: $0 <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]"
    echo "Commands:"
    echo "  on       - Create connector + turn ON (default: 2360x1640@60)"
    echo "  off      - Turn OFF + cleanup mode + force=0"
    echo "  change   - Change resolution (and apply)"
    echo "  status   - Current status"
    exit 1
    ;;
esac
