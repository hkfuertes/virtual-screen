#!/bin/bash
# x11-manager.sh - HDMI X11 manager (On/Off)

PORT=HDMI-A-1; OUTPUT="HDMI-1"
CONNECTOR_SYSFS="/sys/class/drm/card1-${PORT}"
FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"

# ---------- Root helpers ----------
have_tty() { [ -t 0 ] && [ -t 1 ]; }
have_gui() { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }

run_root() {
  if have_tty; then
    sudo "$@"
  elif have_gui && command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    exit 1
  fi
}

write_sysfs() { printf '%s\n' "$1" | run_root /usr/bin/tee "$2" >/dev/null;}

# ---------- Helpers ----------
connector() {
  [ -w "$FORCE_FILE" ] && write_sysfs on "$FORCE_FILE" || write_sysfs "$1" "$STATUS_FILE"
}

set_mode() {
    width=$1
    height=$2
    refresh=$3

    MODELINE=$(cvt $width $height $refresh | grep Modeline | sed 's/Modeline //')
    MODE_NAME=$(echo "$MODELINE" | awk '{print $1}')

    xrandr | grep -q "$MODE_NAME" || xrandr --newmode $MODELINE
    xrandr --query | grep -A1 "^$OUTPUT" | grep -q "$MODE_NAME" || xrandr --addmode $OUTPUT $MODE_NAME
    xrandr --output $OUTPUT --mode $MODE_NAME --left-of eDP-1
}


# ---------- Main ----------
case "$1" in
  on)
    connector on
  ;;
  off)
    connector off
  ;;
  set)
    set_mode "$2" "$3" "$4"
  ;;
  index)
    INDEX=$(xrandr --listactivemonitors | grep "$OUTPUT" | awk '{print $1}' | tr -d ':')
    echo "$INDEX"
  ;;
  *)
    echo "Usage: $0 on|off|index|set <width> <height> <refresh_rate>"
    exit 1
  ;;
esac
