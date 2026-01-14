Sí, absolutamente. 💡

Tu flujo puede ser completamente automatizado porque **Sunshine detecta los monitores al iniciar**, y la configuración `output_name` solo necesita apuntar al **índice de monitor correcto**. Así que el applet o script puede:

1. Activar el HDMI (root)
2. Esperar a que X11 lo liste como conectado (`xrandr`)
3. Determinar el índice de monitor que Sunshine verá
4. Escribir ese índice dinámicamente en `sunshine.conf`
5. Reiniciar el servicio Sunshine para que use ese monitor

---

### Ejemplo de cómo obtener el índice de la pantalla

```bash
# HDMI activo
OUTPUT_NAME="HDMI-1"

# Obtener el índice según xrandr para Sunshine
INDEX=$(xrandr --listactivemonitors | grep "$OUTPUT_NAME" | awk '{print $1}' | tr -d ':')

echo "Monitor $OUTPUT_NAME tiene índice $INDEX"
```

* `xrandr --listactivemonitors` muestra algo como:

```
Monitors: 2
 0: +eDP-1 1920/309x1080/174+0+0  eDP-1
 1: +HDMI-1 1920/477x1080/268+1920+0  HDMI-1
```

* Ahí `1` es el índice que Sunshine usará para `output_name`.

---

### Actualizar `sunshine.conf` dinámicamente

```bash
SUNSHINE_CONF="$HOME/.config/Sunshine/sunshine.conf"

# Reemplazar output_name
sed -i "s/^output_name *= *.*/output_name = $INDEX/" "$SUNSHINE_CONF"
```

* Si `output_name` no existe, puedes añadirlo al final:

```bash
grep -q "^output_name" "$SUNSHINE_CONF" || echo "output_name = $INDEX" >> "$SUNSHINE_CONF"
```

---

### Flujo completo automatizado

```bash
#!/bin/bash

# 1. Encender HDMI
echo on | sudo tee /sys/class/drm/card1-HDMI-A-1/force >/dev/null

# 2. Esperar un segundo para que X11 registre la pantalla
sleep 1

# 3. Obtener índice para Sunshine
OUTPUT_NAME="HDMI-1"
INDEX=$(xrandr --listactivemonitors | grep "$OUTPUT_NAME" | awk '{print $1}' | tr -d ':')

# 4. Actualizar sunshine.conf
SUNSHINE_CONF="$HOME/.config/Sunshine/sunshine.conf"
grep -q "^output_name" "$SUNSHINE_CONF" && \
    sed -i "s/^output_name *= *.*/output_name = $INDEX/" "$SUNSHINE_CONF" || \
    echo "output_name = $INDEX" >> "$SUNSHINE_CONF"

# 5. Reiniciar Sunshine
systemctl --user restart sunshine

# Igual estaria bien dejar sunshine deshabilitado con arranque y parado manual...
```

✅ Con esto, tu applet puede **activar HDMI y hacer que Sunshine use esa pantalla automáticamente** sin intervención manual.

---

Si quieres, puedo escribir **una versión lista para applet Cinnamon** que haga esto al presionar un botón “ON HDMI”, y otro botón “OFF HDMI” que apague la pantalla y deje el sistema limpio. Esto integraría todo en tu `virtual-screen-manager@hkfuertes`.

¿Quieres que haga eso?
