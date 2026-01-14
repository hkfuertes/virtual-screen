#!/bin/bash
# x11-manager.sh - HDMI X11 manager (On/Off)

CONNECTOR_SYSFS="/sys/class/drm/card1-HDMI-A-1"
FORCE_FILE="${CONNECTOR_SYSFS}/force"
STATUS_FILE="${CONNECTOR_SYSFS}/status"
OUTPUT="HDMI-1"

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
connector_on() {
  [ -w "$FORCE_FILE" ] && write_sysfs on "$FORCE_FILE" || write_sysfs on "$STATUS_FILE"
}

connector_off() {
  [ -w "$FORCE_FILE" ] && write_sysfs detect "$FORCE_FILE" || write_sysfs off "$STATUS_FILE"
}

# ---------- Status ----------
status_internal() {
  echo "connector=$(cat "$STATUS_FILE" 2>/dev/null || echo unknown)"
}

# ---------- Args ----------
CMD="$1"

# ---------- Main ----------
case "$CMD" in
  on)
    connector_on
  ;;
  off)
    connector_off
  ;;
  status)
    status_internal
  ;;
  *)
    echo "Usage: $0 on|off|status"
    exit 1
  ;;
esac
