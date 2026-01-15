# Virtual Screen

A Cinnamon desktop applet that manages virtual HDMI displays, allowing users to activate/deactivate virtual outputs and manage custom resolutions.

## Overview

Virtual Screen is a Cinnamon panel applet that provides control over virtual HDMI outputs through sysfs and X11 manipulation. It's particularly useful for:

- Creating virtual displays for software testing
- Setting up displays for game streaming (Sunshine integration)
- Developing applications that require multiple monitors
- Testing display configurations without additional hardware

## Key Features

- **Dynamic Toggle Buttons** for virtual display and Sunshine
- **Automatic Resolution Management** via Sunshine prep commands
- **Simple Sunshine Integration** with inline bash commands
- **Clean Architecture** with separated responsibilities
- **Simple Interface** from the Cinnamon panel
- **Development Support** with symlink installation

## System Requirements

- **Cinnamon Desktop** (Linux Mint, Ubuntu with Cinnamon, etc.)
- **X11 System** (not compatible with Wayland)
- **Administrator Privileges** for sysfs manipulation
- **Virtual HDMI Compatible** (card1-HDMI-A-1)
- **Optional**: Sunshine for game streaming

## Installation

### Method 1: Using Makefile (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd virtual-screen

# Install for current user
make install

# Restart Cinnamon to load the applet
make restart-cinnamon
```

### Method 2: Development Installation

```bash
# Symlink installation (ideal for development)
make dev

# This installs and restarts Cinnamon automatically
```

### Method 3: Distributable Package

```bash
# Create zip package for distribution
make package

# Package will be generated in dist/virtual-screen@hkfuertes.zip
```

## Usage Guide

### Basic Panel Usage

1. **Locate the applet**: Find the display icon in the Cinnamon panel
2. **Context menu**: Right-click to see options
3. **Virtual Display Toggle**: Use the switch to enable/disable virtual HDMI
4. **Sunshine Toggle**: Use the switch to start/stop Sunshine streaming

The applet automatically:
- Updates button states in real-time
- Saves/restores your original display resolution
- Configures Sunshine with appropriate settings
- Handles backup/restore of Sunshine configuration

### Command Line Usage

```bash
# Activate virtual display connector (no resolution change)
./applet/bin/x11-manager.sh on

# Deactivate virtual display
./applet/bin/x11-manager.sh off

# Change resolution (requires active connector)
./applet/bin/x11-manager.sh -w 1920 -h 1080 -r 60 change

# Get monitor index
./applet/bin/x11-manager.sh index
```

### Sunshine Integration

```bash
# Start Sunshine with automatic configuration (backs up original config)
./applet/bin/sunshine-manager.sh start

# Stop Sunshine and restore original configuration automatically
./applet/bin/sunshine-manager.sh stop

# Check Sunshine status
./applet/bin/sunshine-manager.sh status

# Configure Sunshine without starting (also backs up config)
./applet/bin/sunshine-manager.sh configure
```

### Advanced Resolution Management

```bash
# Set custom resolution
./applet/bin/x11-manager.sh set 1920 1080 60

# Save current resolution as original
./applet/bin/x11-manager.sh save-original

# Restore original resolution
./applet/bin/x11-manager.sh restore-original

# Get current resolution
./applet/bin/x11-manager.sh get-res
```

## Technical Details

### Project Architecture

```
virtual-screen/
├── applet/
│   ├── applet.js          # Main Cinnamon applet code with dynamic toggles
│   ├── metadata.json      # Applet metadata
│   └── bin/
│       ├── x11-manager.sh      # Simple HDMI/X11 management
│       └── sunshine-manager.sh # Sunshine service management
├── Makefile               # Build system
└── README.md             # This documentation
```

### Internal Functionality

#### HDMI Management (`x11-manager.sh`)

The script manipulates kernel filesystem to control the HDMI connector:

```bash
# Sysfs files used
/sys/class/drm/card1-HDMI-A-1/force    # Force connector state
/sys/class/drm/card1-HDMI-A-1/status  # Current connector state
```

#### Resolution Management

Uses `cvt` and `xrandr` to create and apply custom video modes:

```bash
# Generate video mode
cvt 1920 1080 60

# Create new mode in X11
xrandr --newmode "1920x1080_60.00" [...]

# Add mode to output
xrandr --addmode HDMI-1 "1920x1080_60.00"

# Apply configuration
xrandr --output HDMI-1 --mode "1920x1080_60.00" --left-of eDP-1
```

#### Sunshine Integration

The Sunshine manager provides simple service control:

**Configuration:**
- Automatically detects virtual display index
- Configures Sunshine with `global_prep_cmd` using inline bash commands
- Uses environment variables for dynamic resolution management

**Environment Variables:**
- `SUNSHINE_CLIENT_WIDTH` - Client resolution width
- `SUNSHINE_CLIENT_HEIGHT` - Client resolution height
- `SUNSHINE_CLIENT_FPS` - Client refresh rate

**Inline Commands:**
- **Pre-up**: `bash -c 'DISPLAY=:0 x11-manager.sh change -w $SUNSHINE_CLIENT_WIDTH -h $SUNSHINE_CLIENT_HEIGHT -r $SUNSHINE_CLIENT_FPS'`
- **Pre-down**: `bash -c 'DISPLAY=:0 x11-manager.sh off'`

## Development Guide

### Cinnamon Applet Structure

The applet follows standard Cinnamon applet structure:

```javascript
// applet.js - Main class
class VirtualScreenApplet extends Applet.IconApplet {
  constructor(metadata, orientation, panel_height, instance_id) {
    // Applet initialization
  }
  
  on_applet_clicked() {
    // Handle user click
  }
  
  _run(cmd, args = []) {
    // Execute system scripts
  }
}
```

### Modification and Testing

```bash
# Install for development (symlink)
make install

# Modify files in applet/
# Changes are reflected immediately

# Restart Cinnamon to test changes
make restart-cinnamon
```

### System Scripts

#### `x11-manager.sh`

**Commands:**
- `on`: Activate HDMI connector (no resolution change)
- `off`: Deactivate HDMI connector
- `change`: Change resolution using current WIDTH/HEIGHT/REFRESH values
- `status`: Show current HDMI status
- `index`: Get monitor index for Sunshine

**Options:**
- `-w WIDTH`: Set width for resolution operations
- `-h HEIGHT`: Set height for resolution operations
- `-r REFRESH`: Set refresh rate for resolution operations

**Permissions:** Requires administrator privileges for sysfs writing

#### `sunshine-manager.sh`

**Commands:**
- `start`: Backup original config, configure for virtual display, and start service
- `stop`: Stop service and automatically restore original configuration
- `restart`: Restart Sunshine service
- `status`: Show current Sunshine status
- `configure`: Backup config and configure for virtual display (without starting)

**Features:**
- Automatic backup and restore of Sunshine configuration
- Inline bash commands for dynamic resolution management
- Service management via systemd
- Clean configuration management

## Advanced Configuration

### Custom Resolutions

To add custom resolutions:

```bash
# Create custom video mode
./applet/bin/x11-manager.sh set 2560 1440 75

# Verify mode has been applied
xrandr --query | grep HDMI-1
```

### Sunshine Configuration

Manually edit `~/.config/Sunshine/sunshine.conf`:

```ini
# Basic configuration
output_name = 1
resolution = 1920x1080
fps = 60
```

### Hardware Compatibility

The applet is configured for:
- **Graphics Card**: card1 (second card)
- **HDMI Port**: HDMI-A-1
- **X11 Output**: HDMI-1

To adapt to different hardware, modify variables in `x11-manager.sh`:

```bash
PORT=HDMI-A-1          # Change according to hardware
OUTPUT="HDMI-1"        # Change according to xrandr
CONNECTOR_SYSFS="/sys/class/drm/card1-${PORT}"  # Adjust card
```

## Troubleshooting

### Common Issues

#### **Applet doesn't appear in panel**

```bash
# Verify installation
ls -la ~/.local/share/cinnamon/applets/virtual-screen@hkfuertes/

# Check applet logs
journalctl -f | grep cinnamon

# Restart Cinnamon
cinnamon --replace &
```

#### **Permission error when activating display**

```bash
# Check sysfs files
ls -la /sys/class/drm/card1-HDMI-A-1/

# Test manually with sudo
sudo echo "on" > /sys/class/drm/card1-HDMI-A-1/status

# Check polkit integration
pkexec --version
```

#### **Virtual display not detected**

```bash
# Check connector status
cat /sys/class/drm/card1-HDMI-A-1/status

# Test x11-manager directly
./applet/bin/x11-manager.sh status
./applet/bin/x11-manager.sh on

# List X11 outputs
xrandr --query
```

#### **Sunshine doesn't recognize display**

```bash
# Check configuration
cat ~/.config/Sunshine/sunshine.conf

# Test sunshine-manager
./applet/bin/sunshine-manager.sh configure
./applet/bin/sunshine-manager.sh status

# Check service status
systemctl --user restart sunshine
systemctl --user status sunshine

# Check Sunshine logs
journalctl --user -u sunshine -f
```

#### **Resolution not changing automatically**

```bash
# Test Sunshine configuration
./applet/bin/sunshine-manager.sh configure

# Check Sunshine config file
cat ~/.config/Sunshine/sunshine.conf

# Test manual resolution change
./applet/bin/x11-manager.sh change -w 1920 -h 1080 -r 60
```

#### **Buttons not updating**

```bash
# Check display status
xrandr | grep HDMI-1

# Check Sunshine service
systemctl --user status sunshine

# Restart applet
make restart-cinnamon
```

### Debugging

To enable debug messages:

```bash
# Run scripts with verbose output
bash -x ./applet/bin/x11-manager.sh on

# Check Cinnamon logs
journalctl -f | grep cinnamon
```

## License

This project is distributed under the same license as other Cinnamon applets.

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## Support

For help or reporting issues:

- Create an issue in the project repository
- Consult Cinnamon applets documentation
- Check system logs for diagnosis

---

**Note:** This applet requires system-level access to manipulate hardware interfaces. Ensure you understand the security implications before installing.