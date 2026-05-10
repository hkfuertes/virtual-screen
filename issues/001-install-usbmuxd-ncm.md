# Issue 001: Instalar usbmuxd con modo NCM desde fuente

## Contexto
El paquete `usbmuxd` del repositorio de Linux Mint 22.3 no soporta el modo CDC-NCM. Necesitamos compilar el stack completo de libimobiledevice desde GitHub para habilitar la red USB entre el host Linux y el iPad.

## Hardware objetivo
- **OS**: Linux Mint 22.3 (Zena)
- **iPad**: Air M1 conectado por USB-C
- **Dock**: Lenovo ThinkPad Universal USB-C Dock (17ef:30a9)
- **iPad detectado**: `lsusb` → `05ac:12ab Apple, Inc. iPad`

## Tareas

### 1. Instalar dependencias de build
```bash
sudo apt install -y git build-essential pkg-config autoconf automake libtool-bin \
  libusb-1.0-0-dev libssl-dev udev libcurl4-openssl-dev \
  usbmuxd libimobiledevice-utils libplist-utils
```

### 2. Compilar el stack en orden (cascade /usr/local)
Orden de dependencia:
1. `libplist`
2. `libimobiledevice-glue`
3. `libusbmuxd`
4. `libtatsu`
5. `libimobiledevice`
6. `usbmuxd` (con `--sysconfdir=/etc --localstatedir=/var --runstatedir=/run`)

Cada uno: `./autogen.sh --prefix=/usr/local` → `make -j$(nproc)` → `sudo make install` → `sudo ldconfig`

### 3. Configurar servicio systemd de usbmuxd
Override para modo NCM (`DEVICE_MODE=3`):
```ini
[Service]
Environment=USBMUXD_DEFAULT_DEVICE_MODE=3
ExecStart=
ExecStart=/usr/local/sbin/usbmuxd --user usbmux --systemd
PIDFile=/run/usbmuxd.pid
```

### 4. Configurar NetworkManager
Bloquear interfaz "Apple Private":
```ini
# /etc/NetworkManager/conf.d/99-unmanaged-ipad-private.conf
[keyfile]
unmanaged-devices=mac:fe:7d:5e:22:5c:e0
```

### 5. Script helper `ipad-usb-connect`
Script en `/usr/local/bin/ipad-usb-connect` que:
- Detecta la interfaz `enx...d0` (Apple Tethering)
- Crea conexión NetworkManager `iPad-USB-Tethering` con `ipv4.method shared`
- La activa

## Script: `install-usbmuxd.sh`
Ya existe en el repo. Revisar y adaptar si es necesario para Mint 22.3.

## Criterios de aceptación
- [ ] `systemctl is-active usbmuxd` → `active`
- [ ] `systemctl show usbmuxd --property=Environment` muestra `USBMUXD_DEFAULT_DEVICE_MODE=3`
- [ ] Al conectar iPad y ejecutar `ipad-usb-connect`:
  - Se crea interfaz `enx...d0`
  - iPad obtiene IP en rango `10.42.0.x`
  - Host responde a ping desde iPad
- [ ] `nmcli con show iPad-USB-Tethering` muestra estado activated
