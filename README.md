The idea is to re-use my daily iPad Air M1 as a second display. I regularly use Linux Mint so the guide will focus around it. If using Windows you can use [Spacedesk](https://www.spacedesk.net/)'s USB driver and if using Mac... Official Sidecar!

The easiest way of displaying a screen onto a device is by using the combo [Sunshine](https://github.com/LizardByte/Sunshine) + [Moonlight](https://github.com/moonlight-stream/moonlight-ios). Sunshine is the server and Moonlight is the client. This combo is optimized to run games from your big gaming machine onto a light client (i.e. Android TV), so latency has to be low. That's why it uses GPU enc/decoding to transmit the image via network.

Installation and configuration of the combo via WiFi is pretty straight forward and wont be covered here. Just install both apps, configure Sunshine, and the "server" will appear automagically on the client (in my case the iPad).

... _**the extra mile is the edge cases!**_ What if I don't have a wifi because I'm travelling (i.e. train trips with no cell towers)?, or if I have to be careful with my tether device's battery? Or if I want to reduce latency at minimum? Can I just create a bridge over a USB cable? Indeed it can be done, and again... doing so with a cellular iPad is also straight forward, as the Cellular iPad does have USB-tethering available from the settings page... but if the iPad is a WiFi only device (like mine)? This is what I want to explore in this guide.

---

## `usbmuxd` - or how the answer is right in front of us!

**Up to iOS 26.1** (my current iOS version), all iDevices support multiple USB modes including **CDC-NCM** (networking). When activated via `usbmuxd`, the iPad exposes USB network interfaces on Linux with zero iPadOS UI changes - just plug & automatic DHCP negotiation creates the network bridge.

**Repo packages lack NCM mode support**, so custom `usbmuxd` compilation is required (Linux Mint/Ubuntu).

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install-usbmuxd.sh | sudo bash -
```

This installer will (takes 5-10 minutes to compile):
1. Install build dependencies
2. Compile libimobiledevice stack from source
3. Configure usbmuxd with NCM mode enabled
4. Set up NetworkManager to ignore Apple Private interface
5. Create `ipad-usb-connect` helper script

Or if you prefer, follow the manual steps below:

First install from apt to bootstrap systemd services:

```bash
sudo apt update
sudo apt install usbmuxd libimobiledevice-utils libplist-utils
```

And the dependencies to build the custom version:
```bash
sudo apt install \
  autoconf automake libtool pkg-config \
  libplist-dev libssl-dev libusb-1.0-0-dev \
  libreadline-dev libncurses5-dev \
  git cmake build-essential python3 \
  libfuse-dev
```

Then build custom version from [libimobiledevice](https://github.com/libimobiledevice):

```bash
# Compile libimobiledevice stack from source (cascade /usr/local) - for Mint 22.2
# Order: libplist -> libimobiledevice-glue -> libusbmuxd -> libtatsu -> libimobiledevice -> usbmuxd
# PKG_CONFIG_PATH ensures each step finds previous libs

mkdir -p ~/src/imd && cd ~/src/imd

# 0) Install build dependencies
sudo apt update
sudo apt install -y git build-essential pkg-config autoconf automake libtool-bin \
  libusb-1.0-0-dev libssl-dev udev libcurl4-openssl-dev

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

# 1) libplist
git clone https://github.com/libimobiledevice/libplist.git
cd libplist
./autogen.sh --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# 2) libimobiledevice-glue
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue
./autogen.sh --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# 3) libusbmuxd
git clone https://github.com/libimobiledevice/libusbmuxd.git
cd libusbmuxd
./autogen.sh --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# 4) libtatsu (new dependency for recent libimobiledevice)
git clone https://github.com/libimobiledevice/libtatsu.git
cd libtatsu
./autogen.sh --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# 5) libimobiledevice (tools like idevicepair/ideviceinfo)
git clone https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice
./autogen.sh --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# 6) usbmuxd (the daemon)
git clone https://github.com/libimobiledevice/usbmuxd.git
cd usbmuxd
./autogen.sh --prefix=/usr/local --sysconfdir=/etc --localstatedir=/var --runstatedir=/run
make -j"$(nproc)"
sudo make install
sudo ldconfig
```

Edit service for custom binary + NCM mode:

```bash
sudo systemctl edit --full usbmuxd
```

```service
[Unit]
Description=Socket daemon for the usbmux protocol used by Apple devices
Documentation=man:usbmuxd(8)

[Service]
Environment=USBMUXD_DEFAULT_DEVICE_MODE=3
ExecStart=/usr/local/sbin/usbmuxd --user usbmux --systemd
PIDFile=/run/usbmuxd.pid
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now usbmuxd
```

---

## The USB network is up... now what?

Why the NetworkManager bridge is essential: At this point you have USB link-layer connectivity (L2), but no IP addresses or routable network (L3). The iPad exposes raw CDC-NCM interfaces without any DHCP server or IP configuration - and since iPadOS shows zero UI changes, you can't manually assign IPs either. NetworkManager's shared mode provides the missing DHCP server + NAT routing to create the actual IP network bridge between your Linux Mint host and iPad.

### iPad-USB-Tethering bridge (nmcli "shared")

Connect iPad via USB-C. Check `dmesg | grep -i Apple` - **two CDC-NCM interfaces** appear:

- **"Apple Tethering"** (`enx...d0`): Main data networking interface for Linux↔iPad traffic.
- **"Apple Private"** (`enx...d1`, MAC `fe:7d:5e:22:5c:e0`): iOS internal services - mark unmanaged.

1) Identify Tethering iface:
```bash
ip link | grep -E '^[0-9]+: enx'
dmesg | grep -i 'Apple Tethering'
```

2) Create connection (or use `ipad-usb-connect` if you used the automated installer):
```bash
IF=enxa2b40fe978d0
nmcli con down iPad-USB-Tethering 2>/dev/null || true
nmcli con del iPad-USB-Tethering 2>/dev/null || true
nmcli con add con-name iPad-USB-Tethering type ethernet ifname "$IF" ipv4.method shared ipv6.method shared
nmcli con up iPad-USB-Tethering
```

3) Block "Apple Private" (automatically done by installer):
```bash
sudo tee /etc/NetworkManager/conf.d/99-unmanaged-ipad-private.conf >/dev/null <<'EOF'
[keyfile]
unmanaged-devices=mac:fe:7d:5e:22:5c:e0
EOF
sudo systemctl restart NetworkManager
```

### Sunshine/Moonlight over USB bridge

iPad gets IP (10.42.0.x), host 10.42.0.1. Manually add USB IP `10.42.0.1` in Moonlight iPad client. Minimal latency, perfect for offline travel.

---

## Extending the Desktop (Virtual Display Setup)

To extend your desktop rather than mirroring the main screen, you need a separate video output. The most reliable method on Linux (specifically X11) is forcing an HDMI connector via sysfs, even without a physical monitor connected.

This approach creates a virtual second display that:
- Exists in xrandr but stays disabled until Sunshine activates it
- Automatically matches the client device's resolution (iPad's 4:3 aspect ratio, etc.)
- Turns off cleanly when the session ends

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install-virtual-display.sh | sudo bash -
```

This installer will:
1. Download the required scripts (init, activate, deactivate)
2. Install systemd service for boot initialization
3. Configure virtual HDMI display

### Configure Sunshine

After installation, edit `~/.config/sunshine/sunshine.conf`:

```conf
output_name = HDMI-1
global_prep_cmd = /opt/sunshine-virtual-display/activate-virtual-display.sh
global_undo_cmd = /opt/sunshine-virtual-display/deactivate-virtual-display.sh
```

Or configure via Sunshine Web UI at `https://localhost:47990`

### How It Works

The scripts automatically:
1. **On boot**: Force HDMI connector "on" via sysfs, keep it disabled in xrandr
2. **On connect**: Read client resolution from Sunshine environment variables
3. **On connect**: Generate custom modeline with `cvt` matching client aspect ratio
4. **On connect**: Activate HDMI with exact client resolution
5. **On disconnect**: Turn off HDMI and clean up custom modes

This provides automatic resolution matching - an iPad gets 4:3, a desktop client gets 16:9, etc.

### Verification

After reboot, verify the setup:

```bash
# Check HDMI is connected but inactive
xrandr | grep HDMI
# Should show: HDMI-1 connected (no resolution active)

# Check service status
sudo systemctl status virtual-display-init.service

# Monitor logs
sudo tail -f /var/log/virtual-display.log
```

---

## Troubleshooting

### USB Networking Issues

**No Apple Tethering interface:**
- Check usbmuxd: `systemctl status usbmuxd`
- Verify NCM mode: `systemctl show usbmuxd | grep DEVICE_MODE=3`
- Check kernel: `dmesg | grep -i cdc_ncm`

**iPad doesn't get IP:**
- Check connection: `nmcli con show iPad-USB-Tethering`
- Verify host IP: `ip addr show` (should be 10.42.0.1/24)
- Restart: `nmcli con down iPad-USB-Tethering && nmcli con up iPad-USB-Tethering`

**Moonlight can't find server:**
- Manually add `10.42.0.1` in Moonlight settings
- Test connectivity: `ping 10.42.0.2` (or actual iPad IP)

### Virtual Display Issues

**Service fails at boot:**
- View logs: `sudo journalctl -u virtual-display-init.service`
- Check HDMI connector: `ls /sys/class/drm/ | grep HDMI`

**Sunshine doesn't start:**
- Verify output name: `xrandr | grep HDMI`
- Check Sunshine logs: `journalctl --user -u sunshine`

**Display doesn't activate:**
- Check logs: `sudo tail -f /var/log/virtual-display.log`
- Test manually: `sudo DISPLAY=:0 bash /opt/sunshine-virtual-display/activate-virtual-display.sh`

---

## Uninstallation

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

### Virtual Display

```bash
sudo systemctl disable virtual-display-init.service
sudo systemctl stop virtual-display-init.service
sudo rm /etc/systemd/system/virtual-display-init.service
sudo rm -rf /opt/sunshine-virtual-display
sudo systemctl daemon-reload
```

Remove from Sunshine config: `output_name`, `global_prep_cmd`, `global_undo_cmd`

---

## Key references

- [Sunshine](https://github.com/LizardByte/Sunshine) - Game streaming server
- [Moonlight](https://github.com/moonlight-stream/moonlight-ios) - Game streaming client
- [libimobiledevice/usbmuxd](https://github.com/libimobiledevice/usbmuxd)
- [usbmuxd modes](https://github.com/libimobiledevice/usbmuxd/issues/205)
- [iOS USB stack](https://www.synacktiv.com/en/publications/ios-a-journey-in-the-usb-networking-stack)
- [NetworkManager sharing](https://fedoramagazine.org/internet-connection-sharing-networkmanager/)
