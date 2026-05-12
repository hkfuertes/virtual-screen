"""
iPad/iPhone USB NCM Mode Switch — Windows Validation Script

Envía un vendor control transfer al dispositivo Apple para que se
re-enumerate exponiendo interfaces CDC-NCM.

Prerequisitos en Windows:
  1. Zadig → instalar WinUSB en el dispositivo Apple (VID 0x05ac)
  2. libusb-1.0.dll en PATH o junto a este script
  3. pip install pyusb

Uso:
  python mode_switch.py          # modo automático (detecta iOS)
  python mode_switch.py --mode 5 # forzar modo 5 (iOS 17+)
  python mode_switch.py --list   # listar dispositivos USB Apple
"""

import sys
import os
import time

# Explicitly point pyusb to the DLL in the script's directory
# This avoids the "No backend available" error on Windows
DLL_NAME = "libusb-1.0.dll"
script_dir = os.path.dirname(os.path.abspath(__file__))
dll_path = os.path.join(script_dir, DLL_NAME)

import usb.backend.libusb1
_backend = usb.backend.libusb1.get_backend(find_library=lambda _: dll_path if os.path.exists(dll_path) else DLL_NAME)
if _backend is None:
    print(f"❌ No se pudo cargar {DLL_NAME}")
    print(f"   Ruta buscada: {dll_path}")
    print(f"   Existe: {os.path.exists(dll_path)}")
    print()
    print("Soluciones:")
    print("  1. pip install libusb1  (incluye la DLL automáticamente)")
    print("  2. Descarga libusb-1.0.dll desde https://libusb.info")
    print(f"     y cópiala en: {script_dir}")
    sys.exit(1)

import usb.core
import usb.util

VID_APPLE = 0x05AC
PID_IPAD = 0x12AB
PID_IPHONE = 0x12A8

# bmRequestType=0x40, bRequest=0x52, wValue=0x0000
VENDOR_REQUEST = 0x52

# Modos disponibles
MODES = {
    0: "UsbMux solo (todas las versiones)",
    2: "Valeria / QuickTime video (todas)",
    3: "CDC-NCM + tethering (iOS < 17)",
    4: "CDC-NCM + USB Ethernet (iOS 16+)",
    5: "CDC-NCM directo (iOS 17+)",
}

# PIDs que esperamos DESPUÉS del mode switch (pueden variar)
# iPad NCM: suele aparecer como 0x12ab o cambia
# Lo detectamos por clase CDC en las interfaces

N_INTERFACES_POLL = 10  # reintentos
POLL_INTERVAL = 2.0     # segundos entre reintentos


def find_apple_devices():
    """Busca todos los dispositivos Apple conectados."""
    devices = usb.core.find(find_all=True, idVendor=VID_APPLE, backend=_backend)
    return list(devices)


def print_device_info(dev):
    print(f"  Bus {dev.bus:03d} Device {dev.address:03d}: "
          f"{dev.idVendor:#06x}:{dev.idProduct:#06x}")
    try:
        print(f"    Manufacturer: {dev.manufacturer}")
        print(f"    Product:      {dev.product}")
        print(f"    Serial:       {dev.serial_number}")
    except (usb.core.USBError, ValueError):
        pass

    print(f"    Configurations: {dev.bNumConfigurations}")
    for cfg in dev:
        print(f"      Config {cfg.bConfigurationValue}:")
        for iface in cfg:
            print(f"        Interface {iface.bInterfaceNumber}: "
                  f"class={iface.bInterfaceClass:#04x}, "
                  f"subclass={iface.bInterfaceSubClass:#04x}, "
                  f"protocol={iface.bInterfaceProtocol:#04x}")


def detect_mode(dev):
    """
    Intenta detectar el modo recomendado según el PID actual.
    PID 0x12ab (iPad) → probar modo 5 primero (iOS 17+), luego 3/4
    PID 0x12a8 (iPhone) → mismo approach
    """
    print(f"\n📱 Dispositivo detectado: {dev.idVendor:#06x}:{dev.idProduct:#06x}")

    # Por defecto recomendamos modo 5 (iOS 17+) — el más común hoy
    recommended = 5
    print(f"   Modo recomendado: {recommended} ({MODES[recommended]})")
    print(f"   Si no funciona, probar con --mode 4 o --mode 3")
    return recommended


def send_mode_switch(dev, mode):
    """
    Envía el vendor control transfer.
    bmRequestType=0x40 (Host→Device, Vendor, Device recipient)
    bRequest=0x52 (kVendorRequestSelectExtendedFunction)
    wValue=0x0000
    wIndex=mode
    """
    print(f"\n🔧 Enviando mode switch (modo {mode}: {MODES[mode]})...")

    try:
        # Algunos dispositivos necesitan set_configuration antes
        try:
            dev.set_configuration()
        except usb.core.USBError:
            pass  # Puede que ya tenga configuración

        result = dev.ctrl_transfer(
            bmRequestType=0x40,
            bRequest=VENDOR_REQUEST,
            wValue=0x0000,
            wIndex=mode,
            data_or_wLength=None,
            timeout=5000
        )

        if result == 0x00:
            print(f"   ✅ Mode switch exitoso (respuesta: 0x{result:02x})")
            return True
        else:
            print(f"   ⚠️  Respuesta inesperada: 0x{result:02x}")
            print(f"       0x04 = modo no válido, otros = error")
            return False

    except usb.core.USBError as e:
        # Es NORMAL que falle con timeout/error porque el dispositivo
        # se desconecta inmediatamente después de aceptar el comando
        print(f"   ⚠️  USBError tras enviar el comando: {e}")
        print(f"       Esto es NORMAL — el iPad se está re-enumerando")
        return True  # Asumimos éxito

    except Exception as e:
        print(f"   ❌ Error inesperado: {e}")
        return False


def poll_for_ncm_interfaces():
    """
    Tras el mode switch, busca nuevas interfaces CDC-NCM.
    CDC-NCM = class 0x02 (Communications) o 0x0a (CDC Data)
    """
    print(f"\n🔍 Escaneando bus USB en busca de interfaces NCM "
          f"({N_INTERFACES_POLL} intentos, {POLL_INTERVAL}s entre cada uno)...")

    for attempt in range(1, N_INTERFACES_POLL + 1):
        time.sleep(POLL_INTERVAL)
        print(f"   Intento {attempt}/{N_INTERFACES_POLL}...", end=" ")

        devices = find_apple_devices()
        if not devices:
            print("no hay dispositivos Apple")
            continue

        found_ncm = False
        for dev in devices:
            try:
                for cfg in dev:
                    for iface in cfg:
                        # CDC Communications class = 0x02
                        # CDC Data class = 0x0a
                        if iface.bInterfaceClass in (0x02, 0x0a):
                            found_ncm = True
                            print(f"✅ Encontrado!")
                            print()
                            print(f"   Dispositivo: {dev.idVendor:#06x}:{dev.idProduct:#06x}")
                            try:
                                print(f"   Product: {dev.product}")
                            except (usb.core.USBError, ValueError):
                                pass
                            print_device_info(dev)
                            return True

            except (usb.core.USBError, ValueError):
                pass

        if not found_ncm:
            pids = [f"{d.idVendor:#06x}:{d.idProduct:#06x}" for d in devices]
            print(f"dispositivos Apple: {', '.join(pids)} (sin interfaces CDC aún)")

    print()
    print("❌ No se detectaron interfaces NCM tras el scan completo.")
    print()
    print("   Posibles causas:")
    print("   1. El iPad no aceptó el mode switch → probar otro modo (--mode 3, 4)")
    print("   2. WinUSB no instalado correctamente con Zadig")
    print("   3. El iPad no confía en este PC → desbloquear y aceptar 'Confiar'")
    print("   4. iOS < 17 necesita modo 3 o 4, no modo 5")
    return False


def main():
    # Parse args
    mode = None
    list_only = False

    args = sys.argv[1:]
    for arg in args:
        if arg == "--list":
            list_only = True
        elif arg == "--mode":
            idx = args.index("--mode") + 1
            if idx < len(args):
                mode = int(args[idx])
            else:
                print("Error: --mode necesita un valor numérico")
                sys.exit(1)
        elif arg.startswith("--mode="):
            mode = int(arg.split("=")[1])

    if list_only:
        print("Dispositivos Apple conectados:\n")
        devices = find_apple_devices()
        if not devices:
            print("  ❌ Ningún dispositivo Apple encontrado.")
            print()
            print("  Pasos previos:")
            print("  1. Conecta el iPad/iPhone por USB")
            print("  2. Desbloquéalo y acepta 'Confiar en este equipo'")
            print("  3. Usa Zadig para instalar WinUSB en el dispositivo Apple")
            sys.exit(1)

        for dev in devices:
            print_device_info(dev)
            print()
        sys.exit(0)

    # Modo normal: encontrar dispositivo y hacer mode switch
    print("=" * 60)
    print("  iPad/iPhone USB NCM Mode Switch — Windows Validation")
    print("=" * 60)

    devices = find_apple_devices()
    if not devices:
        print("\n❌ No se encontró ningún dispositivo Apple (VID 0x05ac)")
        print()
        print("Pasos previos:")
        print("  1. Conecta el iPad/iPhone por USB")
        print("  2. Desbloquéalo y acepta 'Confiar en este equipo'")
        print("  3. Usa Zadig para instalar WinUSB:")
        print("     - Abre Zadig")
        print("     - Options → List All Devices")
        print("     - Selecciona el iPad/iPhone (Apple Mobile Device)")
        print("     - Driver: WinUSB")
        print("     - Click 'Replace Driver'")
        print()
        print("Ejecuta 'python mode_switch.py --list' para verificar")
        sys.exit(1)

    if len(devices) > 1:
        print(f"\n⚠️  Múltiples dispositivos Apple encontrados: {len(devices)}")
        print("   Usando el primero...")
        print()

    dev = devices[0]
    print_device_info(dev)

    # Detectar modo
    if mode is None:
        mode = detect_mode(dev)
    elif mode not in MODES:
        print(f"\n❌ Modo {mode} no válido. Modos disponibles:")
        for m, desc in MODES.items():
            print(f"   {m}: {desc}")
        sys.exit(1)

    print(f"\n📋 Modo seleccionado: {mode} ({MODES[mode]})")

    # Enviar mode switch
    success = send_mode_switch(dev, mode)
    if not success:
        print("\n❌ Mode switch falló. Prueba con otro modo.")
        sys.exit(1)

    # Esperar re-enumeración y buscar NCM
    print("\n⏳ Esperando re-enumeración del dispositivo...")
    time.sleep(3)  # primera pausa larga para que se reconecte

    found = poll_for_ncm_interfaces()

    print()
    print("=" * 60)
    if found:
        print("  ✅ ¡ÉXITO! Interfaces NCM detectadas.")
        print("  Siguiente paso: investigar driver NCM en Windows.")
    else:
        print("  ❌ No se detectaron interfaces NCM.")
        print("  Prueba con otro modo: --mode 4 o --mode 3")
    print("=" * 60)

    sys.exit(0 if found else 1)


if __name__ == "__main__":
    main()
