#!/bin/bash
# x11-manager.sh - X11 HDMI-1 manager (modular version)
# Usage: ./x11-manager.sh <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]

CONNECTOR_SYSFS="/sys/class/drm/card1-HDMI-A-1"
FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"
OUTPUT="HDMI-1"

# Default values (iPad Air)
WIDTH=2360
HEIGHT=1640
REFRESH=60

# --- Functions ---

usage() {
  echo "Usage: $0 <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]"
  echo "Commands:"
  echo "  on       - Create mode + turn HDMI ON"
  echo "  off      - Turn HDMI OFF and clean modes"
  echo "  change   - Change resolution and apply"
  echo "  status   - Show current HDMI status"
  exit 1
}

parse_opts() {
  while getopts "w:h:r:" opt; do
    case $opt in
      w) WIDTH="$OPTARG" ;;
      h) HEIGHT="$OPTARG" ;;
      r) REFRESH="$OPTARG" ;;
      *) usage ;;
    esac
  done
  shift $((OPTIND - 1))
  CMD="$1"
}

force_connector_on() {
  if [ -w "$FORCE_FILE" ]; then
    echo "on" | sudo tee "$FORCE_FILE" >/dev/null
  else
    echo "on" | sudo tee "$STATUS_FILE" >/dev/null
  fi
}

force_connector_off() {
  if [ -w "$FORCE_FILE" ]; then
    echo "off" | sudo tee "$FORCE_FILE" >/dev/null
  else
    echo "off" | sudo tee "$STATUS_FILE" >/dev/null
  fi
}

generate_modeline() {
  MODELINE=$(cvt "$WIDTH" "$HEIGHT" "$REFRESH" 2>/dev/null | grep Modeline | sed 's/Modeline "\([^"]*\)" //')
}

create_mode() {
  generate_modeline
  if [ -n "$MODELINE" ]; then
    xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
    xrandr --addmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
  fi
}

turn_on_hdmi() {
  echo "Creating + turning HDLMI-1 ON: ${WIDTH}x${HEIGHT}@${REFRESH}Hz..."
  force_connector_on
  sleep 2
  xrandr --output "$OUTPUT" --off 2>/dev/null || true
  create_mode
  xrandr --output "$OUTPUT" --mode "$MODE_NAME" --left-of eDP-1
  echo "HDMI-1 ON: $MODE_NAME"
}

turn_off_hdmi() {
  echo "Turning HDMI-1 OFF and cleaning up..."
  xrandr --output "$OUTPUT" --off 2>/dev/null || true
  xrandr --delmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
  xrandr --rmmode "$MODE_NAME" 2>/dev/null || true
  force_connector_off
  echo "HDMI-1 OFF (force reset)"
}

change_hdmi_resolution() {
  echo "Changing HDMI-1 to ${WIDTH}x${HEIGHT}@${REFRESH}Hz..."
  create_mode
  xrandr --output "$OUTPUT" --mode "$MODE_NAME"
  echo "HDMI-1 changed: $MODE_NAME"
}

show_status() {
  echo "=== HDMI-1 Status ==="
  xrandr | grep "$OUTPUT" || echo "Output not detected in xrandr"
  echo "--- Connector ---"
  cat "$STATUS_FILE" 2>/dev/null || echo "Status not accessible"
  [ -r "$FORCE_FILE" ] && echo "--- Force ---" && cat "$FORCE_FILE" || true
}

# --- Main ---

parse_opts "$@"
MODE_NAME="${WIDTH}x${HEIGHT}_${REFRESH}.00"

case "$CMD" in
  on) turn_on_hdmi ;;
  off) turn_off_hdmi ;;
  change) change_hdmi_resolution ;;
  status) show_status ;;
  *) usage ;;
esac
