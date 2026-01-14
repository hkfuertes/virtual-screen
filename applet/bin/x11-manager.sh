#!/bin/bash
# x11-manager.sh - HDMI X11 manager (On/Off)

CARD=1; PORT=HDMI-A-1; OUTPUT="HDMI-1"
CONNECTOR_SYSFS="/sys/class/drm/card${CARD}-${PORT}"
CONNECTOR_DEBUGFS="/sys/kernel/debug/dri/${CARD}/${PORT}"

FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"
OVERRIDE_FILE="${CONNECTOR_DEBUGFS}/edid_override"

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

write_sysfs() {
  printf '%s\n' "$1" | run_root /usr/bin/tee "$2" >/dev/null
}

# ---------- Helpers ----------
connector() {
  [ -w "$FORCE_FILE" ] && write_sysfs on "$FORCE_FILE" || write_sysfs "$1" "$STATUS_FILE"
}

override_edid() {
  run_root cat $OVERRIDE_FILE < "$1"
}

# ---------- Main ----------
case "$1" in
  on)
    connector on
  ;;
  off)
    connector off
  ;;
  edid)
    override_edid ./edid.bin
  ;;
  *)
    echo "Usage: $0 on|off|edid"
    exit 1
  ;;
esac
