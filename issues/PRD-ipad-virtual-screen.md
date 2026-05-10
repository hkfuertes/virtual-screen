# PRD: iPad as Second Display over USB on Linux Mint

## Problem Statement

I have an iPad Air M1 and a Linux Mint laptop with only USB-C/USB-A ports (no native HDMI). I want to use the iPad as a true second display (extended desktop, not mirror) with minimal latency, even in offline scenarios where WiFi is unavailable. Existing solutions (Spacedesk, Sidecar) don't work on Linux, and standard WiFi-based streaming adds unnecessary latency and drains the iPad battery faster.

## Solution

Create a USB-based streaming setup using **Sunshine** (server) + **Moonlight** (iPad client) over a USB CDC-NCM network bridge. A dummy HDMI plug on the USB-C dock creates a virtual second display that Sunshine detects. Scripts auto-detect the client resolution and reconfigure the display dynamically when a Moonlight session connects. The iPad gets a proper extended desktop at its native 4:3 aspect ratio with sub-20ms latency.

## User Stories

1. As a Linux Mint user, I want to install all required usbmuxd dependencies with a single script, so that I don't have to manually compile 6 interdependent libraries.
2. As a Linux Mint user, I want usbmuxd configured in NCM mode via systemd, so that my iPad appears as a network interface over USB without manual intervention.
3. As a Linux Mint user, I want NetworkManager to automatically create a shared connection when I run a helper command, so that the iPad gets an IP address and can communicate with the host.
4. As a Linux Mint user, I want the "Apple Private" USB interface ignored by NetworkManager, so that it doesn't interfere with the tethering connection.
5. As a Linux Mint user, I want to install Sunshine with a single script, so that I don't have to manually download, configure, and set up the streaming server.
6. As a Linux Mint user, I want Sunshine configured to use Intel VA-API encoding, so that GPU resources are used efficiently without involving the secondary NVIDIA GPU.
7. As a Linux Mint user, I want Sunshine to detect the dummy HDMI plug (DP-1-1) as the streaming output, so that the iPad receives the extended display rather than mirroring my laptop screen.
8. As a user connecting from an iPad, I want the virtual display to automatically configure to my device's resolution and aspect ratio, so that I get a crisp, native-resolution experience.
9. As a user disconnecting a Moonlight session, I want the virtual display to automatically turn off, so that my desktop returns to the normal layout.
10. As a user, I want each component (usbmuxd, virtual display, Sunshine) installable independently, so that I can debug or reinstall one piece without affecting the others.
11. As a user, I want the entire setup to work without WiFi, so that I can use it on trains, planes, or anywhere without internet.
12. As a user, I want clear logging for both boot-time initialization and runtime session events, so that I can diagnose issues without guessing.
13. As a developer, I want each installation script to validate its prerequisites before running, so that failures are caught early with clear error messages.
14. As a developer, I want a documented end-to-end verification procedure, so that I can confirm the full pipeline works after installation.

## Implementation Decisions

### Modules to create/modify

- **usbmuxd installer script** — Compile the full libimobiledevice stack (libplist → libimobiledevice-glue → libusbmuxd → libtatsu → libimobiledevice → usbmuxd) from source with NCM mode enabled. Override the systemd service to set `USBMUXD_DEFAULT_DEVICE_MODE=3`.
- **NetworkManager configuration** — Drop-in config to unmanage the Apple Private interface. Helper script (`ipad-usb-connect`) to create and activate the shared Ethernet connection.
- **Virtual display scripts** — Rewrite the activate/deactivate scripts to target `DP-1-1` (the dummy plug output name on this hardware) instead of `HDMI-*`. Remove sysfs connector forcing entirely since the dummy plug provides real EDID and wakes automatically.
- **Virtual display installer** — Update to not install a systemd service (no longer needed since the connector is always awake). Install scripts to `/opt/sunshine-virtual-display/`.
- **Sunshine installer** — New script to install Sunshine, configure VA-API encoder, set output to DP-1-1, and wire up the prep/undo commands.
- **Sunshine config** — `~/.config/sunshine/sunshine.conf` with `output_name = DP-1-1`, `encoder = vaapi`, and `global_prep_cmd`/`global_undo_cmd` pointing to the virtual display scripts.

### Architectural decisions

- **No sysfs forcing** — The dummy HDMI plug provides real EDID, so xrandr detects DP-1-1 automatically. The init script and systemd service from the original project are unnecessary.
- **xrandr-only display management** — activate/deactivate scripts use only `xrandr` (modeline generation with `cvt`, add/del mode, --on/--off). No kernel-level connector manipulation.
- **Auto-detection of output name** — Scripts search for `DP-1-1` (the naming convention from the Lenovo dock's DP Alt Mode). The activate script also detects the primary output (`eDP-1`) for positioning.
- **Dynamic resolution** — Read `SUNSHINE_CLIENT_WIDTH`, `SUNSHINE_CLIENT_HEIGHT`, `SUNSHINE_CLIENT_FPS` from environment variables set by Sunshine. Generate matching modeline.
- **Intel VA-API for encoding** — The Intel UHD Graphics is the primary GPU handling all displays. No PRIME offload needed.
- **Independent scripts** — Each component (usbmuxd, virtual display, Sunshine) has its own install script with no cross-dependencies.

### Network topology

```
iPad (10.42.0.x) ←USB NCM→ Host (10.42.0.1) ←Sunshine VA-API→ Moonlight
```

### Deep module opportunity: Display configuration module

The activate/deactivate logic (read resolution → generate modeline → apply via xrandr → log) can be extracted into a single deep module with a simple interface:
- `display activate <output> <width> <height> <fps> [--position <pos>]`
- `display deactivate <output>`

This encapsulates all the xrandr complexity, modeline generation, mode cleanup, and error handling behind two simple commands. It would work with any output name (HDMI, DP, virtual) and is testable in isolation.

### Deep module opportunity: Network setup module

The iPad USB network setup (detect interface → create NM connection → activate) can be a single deep module:
- `ipad-net up` — detect Apple Tethering interface, create shared connection
- `ipad-net down` — deactivate and remove the connection
- `ipad-net status` — show current connection status and IP addresses

## Testing Decisions

### What makes a good test

Tests should verify external behavior: does the display get configured correctly, does the network come up, does Sunshine start? Not implementation details like whether a specific xrandr flag is used.

### What to test

1. **Display scripts** — Mock `xrandr`, `cvt`, and `SUNSHINE_CLIENT_*` variables. Verify:
   - activate calls `xrandr --newmode`, `--addmode`, `--output ... --mode` with correct values
   - deactivate calls `xrandr --output ... --off`
   - Error handling when output not found
   - Cleanup of stale modes

2. **usbmuxd installer** — Verify post-install state:
   - systemd service runs with correct environment variable
   - custom binary is at `/usr/local/sbin/usbmuxd`
   - NetworkManager config file exists with correct content
   - `ipad-usb-connect` script is executable

3. **Sunshine installer** — Verify post-install state:
   - Sunshine binary installed and executable
   - Config file has correct values
   - Firewall ports open

4. **End-to-end** — Manual verification checklist (see Issue 004):
   - iPad gets IP on USB
   - Moonlight pairs with Sunshine
   - Desktop extends to iPad
   - Resolution matches iPad aspect ratio
   - Disconnect cleans up

### Prior art

The existing scripts already include logging and error handling. Tests should follow the same pattern: check prerequisites, perform action, verify state, clean up.

## Out of Scope

- **WiFi-based streaming** — This PRD focuses on USB-only. WiFi setup is not covered.
- **NVIDIA GPU encoding** — The MX250 is intentionally not used for encoding.
- **Wayland support** — The target session is X11 on Linux Mint. Wayland is out of scope.
- **Multiple client support** — Only one iPad client at a time.
- **Touch input from iPad to host** — Moonlight transmits gamepad input only.
- **Automatic iPad detection/plug-and-play** — The user must run `ipad-usb-connect` manually after connecting the USB cable.
- **Windows or macOS host support** — This is Linux Mint only.
- **Audio routing** — Sunshine handles audio, but specific audio routing configuration is not covered.

## Further Notes

- The dummy HDMI plug must be inserted into the Lenovo dock's HDMI port. Without it, there is no second connector for Sunshine to detect.
- The iPad Air M1 has a 4:3 aspect ratio screen (~2732×2048). The dynamic resolution system ensures the virtual display matches this ratio.
- Moonlight on iPad must be installed from the App Store and configured to connect to `10.42.0.1` manually.
- This setup works completely offline — no WiFi or internet required after initial installation.
- The libimobiledevice compilation takes 5-10 minutes on a typical laptop.
