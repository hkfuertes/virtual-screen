#!/bin/bash
# sunshine-manager.sh - Sunshine management with automatic resolution

SCRIPT_DIR="$(dirname "$0")"
X11_MANAGER_SCRIPT="$SCRIPT_DIR/x11-manager.sh"

SUNSHINE_CONF="$HOME/.config/Sunshine/sunshine.conf"
SUNSHINE_CONF_BACKUP="$HOME/.config/Sunshine/sunshine.conf.backup"

# Backup and restore functions
backup_sunshine_config() {
  if [ -f "$SUNSHINE_CONF" ] && [ ! -f "$SUNSHINE_CONF_BACKUP" ]; then
    cp "$SUNSHINE_CONF" "$SUNSHINE_CONF_BACKUP"
    echo "Backed up original Sunshine configuration"
  fi
}

restore_sunshine_config() {
  if [ -f "$SUNSHINE_CONF_BACKUP" ]; then
    mv "$SUNSHINE_CONF_BACKUP" "$SUNSHINE_CONF"
    echo "Restored original Sunshine configuration"
  fi
}

# Get monitor index
get_monitor_index() {
  INDEX=$("$X11_MANAGER_SCRIPT" index 2>/dev/null)
  if [ -z "$INDEX" ] || [ "$INDEX" = "Error: Could not determine HDMI output index." ]; then
    echo "Error: Could not determine HDMI output index."
    exit 1
  fi
  echo "$INDEX"
}

# Configure Sunshine for virtual display
configure_sunshine() {
  local index=$(get_monitor_index)

  # Create or update sunshine.conf
  mkdir -p "$(dirname "$SUNSHINE_CONF")"

  # Write basic configuration with preup/predown using bash -c
  cat > "$SUNSHINE_CONF" << EOF
# Virtual Screen Configuration
output_name = $index

# Automatic resolution management
global_prep_cmd = [
  {"do":"bash -c 'DISPLAY=:0 $SCRIPT_DIR/x11-manager.sh change -w \$SUNSHINE_CLIENT_WIDTH -h \$SUNSHINE_CLIENT_HEIGHT -r \$SUNSHINE_CLIENT_FPS'","undo":"bash -c 'DISPLAY=:0 $SCRIPT_DIR/x11-manager.sh off'"}
]

# Basic settings
min_log_level = info
lan_encryption_mode = 0
notify_pre_releases = disabled
EOF

  echo "Sunshine configured for virtual display (output $index)"
}

# Main commands
case "$1" in
  start)
    echo "Backing up current Sunshine configuration..."
    backup_sunshine_config

    echo "Configuring Sunshine for virtual display..."
    configure_sunshine

    echo "Starting Sunshine service..."
    systemctl --user start sunshine
    systemctl --user is-active --quiet sunshine && echo "Sunshine started successfully" || echo "Failed to start Sunshine"
    ;;
  stop)
    echo "Stopping Sunshine service..."
    systemctl --user stop sunshine
    systemctl --user is-active --quiet sunshine || echo "Sunshine stopped successfully"

    echo "Restoring original Sunshine configuration..."
    restore_sunshine_config
    ;;
  restart)
    "$0" stop
    sleep 2
    "$0" start
    ;;
  status)
    if systemctl --user is-active --quiet sunshine; then
      echo "running"
    else
      echo "stopped"
    fi
    ;;
  configure)
    backup_sunshine_config
    configure_sunshine
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|configure}"
    echo ""
    echo "Commands:"
    echo "  start     - Backup config, configure and start Sunshine"
    echo "  stop      - Stop Sunshine and restore original config"
    echo "  restart   - Restart Sunshine"
    echo "  status    - Show Sunshine status"
    echo "  configure - Backup and configure Sunshine without starting"
    exit 1
    ;;
esac