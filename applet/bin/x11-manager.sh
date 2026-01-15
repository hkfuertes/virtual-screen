#!/bin/bash
# x11-manager.sh - X11 HDMI-1 manager (terminal + GUI compatible)
# Usage: ./x11-manager.sh <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]

CONNECTOR_SYSFS="/sys/class/drm/card1-HDMI-A-1"
FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"
OUTPUT="HDMI-1"

# Default values (iPad Air)
WIDTH=2360
HEIGHT=1640
REFRESH=60

# --- Root helpers (terminal/GUI auto-detect) ---

have_tty() {
  [ -t 0 ] && [ -t 1 ]
}

have_gui() {
  [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

run_root() {
  if have_tty; then
    sudo "$@"
    return $?
  fi
  if have_gui && command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
    return $?
  fi
  echo "Error: need root privileges but no TTY for sudo and no GUI/pkexec available." >&2
  return 1
}

write_sysfs() {
  local value="$1"
  local path="$2"
  printf '%s\n' "$value" | run_root /usr/bin/tee "$path" >/dev/null
}

# --- Functions ---

usage() {
  echo "Usage: $0 <cmd> [-w WIDTH] [-h HEIGHT] [-r REFRESH]"
  echo "Commands:"
  echo "  on       - Create mode + turn HDMI ON"
  echo "  off      - Turn HDMI OFF and clean modes"
  echo "  change   - Change resolution and apply"
  echo "  status   - Show current HDMI status"
  echo "  index    - Show monitor index for Sunshine"
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
    write_sysfs "on" "$FORCE_FILE"
  else
    write_sysfs "on" "$STATUS_FILE"
  fi
}

force_connector_off() {
  if [ -w "$FORCE_FILE" ]; then
    write_sysfs "detect" "$FORCE_FILE"
  else
    write_sysfs "off" "$STATUS_FILE"
  fi
}

generate_modeline() {
  local width="$1"
  local height="$2"
  local refresh="$3"
  MODELINE=$(cvt "$width" "$height" "$refresh" 2>/dev/null | grep Modeline | sed 's/Modeline "\([^"]*\)" //')
}

create_mode() {
  generate_modeline "$@"
  if [ -n "$MODELINE" ]; then
    xrandr --newmode "$MODE_NAME" $MODELINE 2>/dev/null || true
    xrandr --addmode "$OUTPUT" "$MODE_NAME" 2>/dev/null || true
  fi
}

change_hdmi_resolution() {
  local width="$1"
  local height="$2"
  local refresh="$3"

  echo "Changing HDMI-1 to ${width}x${height}@${refresh}Hz..."
  xrandr --output "$OUTPUT" --off 2>/dev/null || true
  create_mode "$width" "$height" "$refresh"
  xrandr --output "$OUTPUT" --mode "$MODE_NAME" --left-of eDP-1
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
  on)
    force_connector_on
    sleep 2
    change_hdmi_resolution "$WIDTH" "$HEIGHT" "$REFRESH"
  ;;
  off) force_connector_off ;;
  change) change_hdmi_resolution "$WIDTH" "$HEIGHT" "$REFRESH" ;;
  status) show_status ;;
  index)
    INDEX=$(xrandr --listactivemonitors 2>/dev/null | grep "$OUTPUT" | awk '{print $1}' | tr -d ':')
    echo "$INDEX"
  ;;
  *) usage ;;
esac