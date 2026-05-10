# Issue 003: Instalar y configurar Sunshine

## Contexto
Sunshine no está instalado en el sistema. Necesitamos instalarlo en Linux Mint 22.3 y configurarlo para usar el virtual display DP-1-1 con encoding por Intel UHD (VA-API/QSV).

## Hardware
- **GPU**: Intel UHD Graphics CometLake-U GT2 (primaria)
- **NVIDIA MX250**: no usar (segundaria, sin displays)
- **Session**: X11
- **Display principal**: eDP-1 (1920x1080)
- **Display virtual**: DP-1-1 (dummy plug, resolución dinámica)

## Tareas

### 1. Instalar Sunshine
Opciones:
- PPA oficial de LizardByte
- AppImage (más portable, no requiere PPA)
- .deb del release

**Recomendación**: AppImage o .deb oficial — más limpio, sin dependencias de PPA externas.

### 2. Configurar Sunshine
Editar `~/.config/sunshine/sunshine.conf` (o usar Web UI en `https://localhost:47990`):
```ini
output_name = DP-1-1
encoder = vaapi
global_prep_cmd = /opt/sunshine-virtual-display/activate-virtual-display.sh
global_undo_cmd = /opt/sunshine-virtual-display/deactivate-virtual-display.sh
```

### 3. Configurar firewall
Abrir puertos Sunshine (UDP 47998-48000, TCP 47984, 47989, 47990, 48010).

### 4. Verificar encoder VA-API
```bash
vainfo  # confirmar que Intel VA-API funciona
```

### 5. Script helper
Opcional: crear `install-sunshine.sh` que automatice la instalación y configuración básica.

## Criterios de aceptación
- [ ] `sunshine --version` funciona
- [ ] Sunshine arranca sin errores
- [ ] Web UI accesible en `https://localhost:47990`
- [ ] Encoder configurado como VA-API (Intel)
- [ ] `output_name = DP-1-1` configurado
- [ ] prep_cmd y undo_cmd apuntan a los scripts del Issue 002
