# iPad as Second Display for Linux Mint via USB/Sunshine

Turn your iPad (WiFi-only or Cellular) into a second display for Linux Mint using Sunshine + Moonlight over USB networking.

## Overview

This guide covers:

1. **Virtual Display Setup** - Force HDMI output via sysfs for Sunshine streaming
2. **USB Networking (Optional)** - Connect iPad via USB using usbmuxd NCM mode for offline/low-latency streaming
3. **Custom Resolution Matching** - Automatically match client device aspect ratio

## Table of Contents

- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Part 1: Virtual Display Setup](#part-1-virtual-display-setup)
- [Part 2: USB Networking (Optional)](#part-2-usb-networking-optional)
- [Part 3: Custom Resolution Matching](#part-3-custom-resolution-matching)
- [Troubleshooting](#troubleshooting)

## Requirements

- Linux Mint x64 (Cinnamon) or Ubuntu-based distribution
- [Sunshine](https://github.com/LizardByte/Sunshine) streaming server
- [Moonlight](https://github.com/moonlight-stream/moonlight-ios) client on iPad
- Graphics driver with sysfs connector control (Intel i915, AMD, NVIDIA)
- xrandr, cvt utilities

## Quick Start

```bash
# 1. Clone or download this repository
cd sunshine-virtual-display/

# 2. Install virtual display scripts
sudo mkdir -p /opt/sunshine-virtual-display
sudo cp scripts/{init,activate,deactivate}-virtual-display.sh /opt/sunshine-virtual-display/
sudo chmod +x /opt/sunshine-virtual-display/*.sh

# 3. Install systemd service
sudo cp systemd/virtual-display-init.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable virtual-display-init.service

# 4. Configure Sunshine (edit ~/.config/sunshine/sunshine.conf)
# Add:
#   output_name = HDMI-1
#   global_prep_cmd = /opt/sunshine-virtual-display/activate-virtual-display.sh
#   global_undo_cmd = /opt/sunshine-virtual-display/deactivate-virtual-display.sh

# 5. Reboot
sudo reboot

# 6. (Optional) Install USB networking support
bash scripts/install-usbmuxd.sh
```

---

## Part 1: Virtual Display Setup

### The Problem

Sunshine needs a display output to stream, but:
- Mirroring the main display is not ideal for extended desktop workflows
- Physical HDMI dummy plugs work but are limited to fixed resolutions
- Linux needs the HDMI connector "on" but Cinnamon shouldn't manage it

### The Solution

Force the HDMI connector via sysfs at boot, keep it disabled in xrandr, then activate it dynamically when Sunshine connects.

### Architecture

```
Boot
  └─> systemd service
       └─> init-virtual-display.sh
            ├─> Force HDMI connector "on" via sysfs
            └─> Set xrandr output to --off
                └─> Sunshine starts (HDMI exists but inactive)
                     └─> Moonlight connects
                          └─> activate-virtual-display.sh
                               ├─> Read client resolution
                               ├─> Generate custom modeline
                               └─> Activate HDMI with exact resolution
                                    └─> Session ends
                                         └─> deactivate-virtual-display.sh
                                              └─> Turn off HDMI, clean modes
```

### Installation

Scripts auto-detect:
- HDMI connector path in `/sys/class/drm/`
- HDMI output name in xrandr
- Primary display output

#### 1. Copy Scripts

```bash
sudo mkdir -p /opt/sunshine-virtual-display
sudo cp scripts/*.sh /opt/sunshine-virtual-display/
sudo chmod +x /opt/sunshine-virtual-display/*.sh
```

#### 2. Install Systemd Service

```bash
sudo cp systemd/virtual-display-init.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable virtual-display-init.service
```

#### 3. Configure Sunshine

Edit `~/.config/sunshine/sunshine.conf`:

```conf
output_name = HDMI-1
global_prep_cmd = /opt/sunshine-virtual-display/activate-virtual-display.sh
global_undo_cmd = /opt/sunshine-virtual-display/deactivate-virtual-display.sh
```

#### 4. Reboot

```bash
sudo reboot
```

### Verification

Check that HDMI is connected but inactive:

```bash
xrandr | grep HDMI
# Should show: HDMI-1 connected (no resolution active)
```

Check service status:

```bash
sudo systemctl status virtual-display-init.service
sudo journalctl -u virtual-display-init.service
```

Check logs:

```bash
sudo tail -f /var/log/virtual-display.log
```

---

## Part 2: USB Networking (Optional)

### Why USB Networking?

WiFi streaming works great, but USB networking provides:
- **Zero WiFi dependency** - Work on trains, planes, areas with no cell towers
- **Lower latency** - Direct USB link eliminates WiFi overhead
- **Battery efficiency** - No WiFi radio usage on tethering device
- **Privacy** - No network exposure

### The Challenge

WiFi-only iPads don't expose USB tethering in Settings like cellular models do. However, all iOS devices up to iOS 26.1+ support **CDC-NCM** (USB networking mode) via `usbmuxd`.

When activated, iPad exposes USB network interfaces with zero UI changes in iPadOS. The Linux host negotiates DHCP automatically creating a network bridge.

### Solution: Custom usbmuxd with NCM Support

Repository packages lack NCM mode support. We compile from source with NCM enabled.

#### Automated Installation

```bash
cd sunshine-virtual-display/
bash scripts/install-usbmuxd.sh
```

This script:
1. Installs build dependencies
2. Compiles libimobiledevice stack (libplist, libimobiledevice-glue, libusbmuxd, libtatsu, libimobiledevice, usbmuxd)
3. Configures usbmuxd systemd service with `USBMUXD_DEFAULT_DEVICE_MODE=3` (NCM mode)
4. Configures NetworkManager to ignore "Apple Private" interface
5. Creates `/usr/local/bin/ipad-usb-connect` helper script

#### Manual Setup After Installation

1. **Connect iPad via USB-C**

2. **Verify CDC-NCM interfaces appear:**

```bash
dmesg | grep -i 'Apple Tethering'
ip link | grep enx
```

You should see two interfaces:
- `enx...d0` - **Apple Tethering** (main data interface)
- `enx...d1` - **Apple Private** (iOS internal, ignored by NetworkManager)

3. **Create NetworkManager Bridge:**

```bash
ipad-usb-connect
```

Or manually:

```bash
# Find Apple Tethering interface
IFACE=$(ip link | grep -E 'enx.*d0:' | awk '{print $2}' | tr -d ':' | head -1)

# Create shared connection
nmcli con add con-name iPad-USB-Tethering type ethernet ifname "$IFACE" \
    ipv4.method shared \
    ipv6.method shared

nmcli con up iPad-USB-Tethering
```

4. **Verify Network:**

```bash
# Host IP is always 10.42.0.1
# iPad gets 10.42.0.x
nmcli con show iPad-USB-Tethering | grep IP4.ADDRESS
```

5. **Add Host IP in Moonlight:**

In Moonlight iPad app, manually add server: `10.42.0.1`

### Why NetworkManager Bridge is Essential

At this point you have USB link-layer connectivity (L2), but no IP addresses or routing (L3). The iPad exposes raw CDC-NCM interfaces without DHCP server or IP configuration - and iPadOS shows zero UI changes.

NetworkManager's `shared` mode provides:
- DHCP server for iPad
- NAT routing for internet passthrough
- Automatic IP assignment (10.42.0.x/24)

---

## Part 3: Custom Resolution Matching

### The Problem

HDMI dummy plugs provide standard resolutions (1920x1080), but client devices often have different aspect ratios:
- iPad Air: 2360x1640 (4:3-ish)
- iPad Pro 11": 2388x1668 (closer to 3:2)
- Desktop clients: Variable

Streaming at 1920x1080 to a 4:3 device wastes screen real estate with black bars.

### The Solution

The `activate-virtual-display.sh` script automatically:
1. Reads `SUNSHINE_CLIENT_WIDTH`, `SUNSHINE_CLIENT_HEIGHT`, `SUNSHINE_CLIENT_FPS` from Sunshine
2. Generates custom modeline with `cvt`
3. Registers mode with xrandr
4. Activates HDMI with exact client resolution

No manual configuration needed - resolution adapts to each connecting client.

### How It Works

Sunshine exports environment variables when a client connects:

```bash
SUNSHINE_CLIENT_WIDTH=1920
SUNSHINE_CLIENT_HEIGHT=1080
SUNSHINE_CLIENT_FPS=60
SUNSHINE_CLIENT_NAME="iPad"
```

The `activate-virtual-display.sh` script uses these to generate the perfect mode:

```bash
# Generate modeline
MODELINE=$(cvt $WIDTH $HEIGHT $FPS | grep Modeline | sed 's/Modeline //')
MODE_NAME=$(echo "$MODELINE" | awk '{print $1}' | tr -d '"')

# Register and activate
xrandr --newmode $MODE_NAME $MODELINE
xrandr --addmode HDMI-1 $MODE_NAME
xrandr --output HDMI-1 --mode $MODE_NAME --left-of eDP-1
```

---

## Troubleshooting

### Virtual Display Issues

**Service fails at boot:**
- Check sysfs path exists: `ls /sys/class/drm/ | grep HDMI`
- View service logs: `sudo journalctl -u virtual-display-init.service`
- Scripts auto-detect connectors, but verify in logs

**Sunshine doesn't start:**
- Verify `output_name` matches xrandr: `xrandr | grep HDMI`
- Check Sunshine logs: `journalctl --user -u sunshine`

**Cinnamon extends desktop automatically:**
- Ensure init script runs before Cinnamon
- Check service ordering: `systemctl show virtual-display-init.service | grep Before`

**Display doesn't activate on connect:**
- Check prep_cmd logs: `sudo tail -f /var/log/virtual-display.log`
- Verify scripts are executable: `ls -l /opt/sunshine-virtual-display/`
- Test manually: `sudo DISPLAY=:0 bash /opt/sunshine-virtual-display/activate-virtual-display.sh`

### USB Networking Issues

**No Apple Tethering interface appears:**
- Check usbmuxd service: `systemctl status usbmuxd`
- Verify NCM mode: `systemctl show usbmuxd | grep Environment`
  - Should show: `USBMUXD_DEFAULT_DEVICE_MODE=3`
- Check kernel messages: `dmesg | grep -i cdc_ncm`

**iPad doesn't get IP:**
- Verify NetworkManager connection: `nmcli con show iPad-USB-Tethering`
- Check DHCP range: `ip addr show`
  - Host should be 10.42.0.1/24
- Restart connection: `nmcli con down iPad-USB-Tethering && nmcli con up iPad-USB-Tethering`

**Moonlight can't find server:**
- Manually add IP: `10.42.0.1` in Moonlight settings
- Verify connectivity: On Linux, `ping 10.42.0.2` (or check actual iPad IP)
- Check firewall: `sudo ufw status`

### Resolution Issues

**Wrong aspect ratio:**
- Check Sunshine variables: `sudo grep SUNSHINE_CLIENT /var/log/virtual-display.log`
- Verify modeline generation: Look for "Modeline:" in logs
- Test with fixed resolution: `SUNSHINE_CLIENT_WIDTH=1920 SUNSHINE_CLIENT_HEIGHT=1080 sudo -E bash activate-virtual-display.sh`

**Black screen or no video:**
- Check xrandr output is active: `xrandr | grep HDMI`
- Verify mode is applied: Should show resolution and refresh rate
- Try different position: Edit script to use `--same-as eDP-1` instead of `--left-of`

---

## Project Structure

```
sunshine-virtual-display/
├── scripts/
│   ├── init-virtual-display.sh        # Boot initialization (force HDMI, set --off)
│   ├── activate-virtual-display.sh    # Sunshine prep_cmd (create mode, activate)
│   ├── deactivate-virtual-display.sh  # Sunshine undo_cmd (turn off, cleanup)
│   └── install-usbmuxd.sh             # Install custom usbmuxd with NCM support
├── systemd/
│   └── virtual-display-init.service   # Systemd service for boot
└── README.md                          # This file
```

## Uninstallation

### Virtual Display

```bash
sudo systemctl disable virtual-display-init.service
sudo systemctl stop virtual-display-init.service
sudo rm /etc/systemd/system/virtual-display-init.service
sudo rm -rf /opt/sunshine-virtual-display
sudo systemctl daemon-reload
```

Remove from Sunshine config:
- `output_name`
- `global_prep_cmd`
- `global_undo_cmd`

### USB Networking

```bash
# Remove NetworkManager config
sudo rm /etc/NetworkManager/conf.d/99-unmanaged-ipad-private.conf
sudo systemctl restart NetworkManager

# Remove connection
nmcli con del iPad-USB-Tethering

# Remove helper script
sudo rm /usr/local/bin/ipad-usb-connect

# (Optional) Remove compiled libraries
sudo rm -rf ~/src/imd
sudo rm /usr/local/lib/libimobiledevice*
sudo rm /usr/local/lib/libusbmuxd*
sudo rm /usr/local/sbin/usbmuxd
sudo ldconfig
```

## References

- [Sunshine](https://github.com/LizardByte/Sunshine) - Game streaming server
- [Moonlight](https://github.com/moonlight-stream/moonlight-ios) - Game streaming client
- [libimobiledevice/usbmuxd](https://github.com/libimobiledevice/usbmuxd) - iOS USB communication
- [usbmuxd NCM modes](https://github.com/libimobiledevice/usbmuxd/issues/205)
- [iOS USB networking stack](https://www.synacktiv.com/en/publications/ios-a-journey-in-the-usb-networking-stack)
- [NetworkManager internet sharing](https://fedoramagazine.org/internet-connection-sharing-networkmanager/)

## License

Scripts are provided as-is for educational purposes. Use at your own risk.
