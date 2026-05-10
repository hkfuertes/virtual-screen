# Issue 002: Adaptar scripts de virtual display para DP-1-1

## Contexto
Los scripts originales usan un conector HDMI forzado via sysfs. En nuestro hardware:
- **No hay HDMI** en ninguna GPU
- El dummy plug aparece como **`DP-1-1`** en xrandr (vía dock Lenovo)
- El conector **ya está despierto** — no necesita sysfs forcing
- GPU principal: Intel UHD (card0), DP-1-1 pertenece a card1 pero xrandr lo maneja como modesetting

## Cambios necesarios

### `init-virtual-display.sh` → ELIMINAR o simplificar al máximo
- ~~Forzar connector via sysfs~~ (no aplica)
- No hay systemd service que mantener
- Si se mantiene: solo verificar que DP-1-1 aparece en xrandr

### `activate-virtual-display.sh` → REESCRIBIR
- Buscar `DP-1-1` en lugar de `HDMI-*`
- Leer `SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS` de variables de entorno
- Generar modeline con `cvt`
- Aplicar modo a DP-1-1 con `--left-of eDP-1`
- Log a `/var/log/virtual-display.log`

### `deactivate-virtual-display.sh` → REESCRIBIR
- Apagar DP-1-1 con `xrandr --output DP-1-1 --off`
- Limpiar modos custom

### `install-virtual-display.sh` → ACTUALIZAR
- Instalar en `/opt/sunshine-virtual-display/`
- **No** instalar systemd service (ya no hace falta)
- No detectar HDMI connector

### `systemd/virtual-display-init.service` → ELIMINAR
Ya no es necesario porque el dummy plug siempre está despierto.

## Criterios de aceptación
- [ ] `activate-virtual-display.sh` con `SUNSHINE_CLIENT_WIDTH=2048 SUNSHINE_CLIENT_HEIGHT=1536` configura DP-1-1 a esa resolución
- [ ] `deactivate-virtual-display.sh` apaga DP-1-1 y limpia modos
- [ ] No hay referencias a HDMI ni sysfs en ningún script
- [ ] `install-virtual-display.sh` funciona sin errores
- [ ] No se instala systemd service
