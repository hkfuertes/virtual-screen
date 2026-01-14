#!/bin/bash
# hdmi-ipad-manager.sh - HDMI-1 Sunshine-aware

# Sunshine env vars (fallback iPad)
WIDTH=${SUNSHINE_APP_WIDTH:-2360}
HEIGHT=${SUNSHINE_APP_HEIGHT:-1640}
REFRESH=${SUNSHINE_APP_FPS:-60}
MODE_NAME="${WIDTH}x${HEIGHT}_${REFRESH}.00"

case "$1" in
  create)
    echo "Creating HDMI-1 virtual (standby)..."
    echo "on" | sudo tee /sys/class/drm/card1-HDMI-A-1/status >/dev/null
    sleep 2
    xrandr --output HDMI-1 --off 2>/dev/null || true
    echo "✓ HDMI-1 ready (off)"
    ;;
  on)
    echo "Turning HDMI-1 ON: ${WIDTH}x${HEIGHT}@${REFRESH}Hz..."
    
    MODELINE=$(cvt $WIDTH $HEIGHT $REFRESH 2>/dev/null | grep Modeline | sed 's/Modeline "\([^"]*\)" //')
    if [ -n "$MODELINE" ]; then
      xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null
      xrandr --addmode HDMI-1 "$MODE_NAME" 2>/dev/null
    fi
    
    xrandr --output HDMI-1 --mode "$MODE_NAME"
    echo "✓ HDMI-1 ON: $MODE_NAME"
    ;;
  off)
    echo "Turning HDMI-1 OFF..."
    xrandr --output HDMI-1 --off
    echo "✓ HDMI-1 OFF"
    ;;
  status)
    xrandr | grep HDMI-1
    cat /sys/class/drm/card1-HDMI-A-1/status
    ;;
  *)
    echo "Usage: $0 {create|on|off|status}"
    echo "Env: SUNSHINE_APP_WIDTH=1920 SUNSHINE_APP_HEIGHT=1080 SUNSHINE_APP_FPS=60"
    exit 1
    ;;
esac