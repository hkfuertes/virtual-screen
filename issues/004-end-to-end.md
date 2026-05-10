# Issue 004: End-to-end — conectar iPad como segundo monitor

## Contexto
Una vez resueltos los issues 001-003, verificar que todo funciona junto:
1. iPad conectado por USB → red NCM funcionando
2. Moonlight instalado en iPad
3. Sunshine corriendo en Linux
4. Virtual display activado dinámicamente al conectar

## Prerequisites
- [ ] Issue 001 completado (usbmuxd NCM + ipad-usb-connect)
- [ ] Issue 002 completado (scripts virtual display para DP-1-1)
- [ ] Issue 003 completado (Sunshine instalado y configurado)

## Tareas

### 1. Preparar la conexión USB
```bash
ipad-usb-connect
# Verificar: nmcli con show iPad-USB-Tethering | grep IP4.ADDRESS
```

### 2. Instalar Moonlight en iPad
Desde App Store: Moonlight Game Streaming

### 3. Emparejar Moonlight con Sunshine
- Añadir servidor manualmente: `10.42.0.1`
- Introducir PIN de emparejamiento

### 4. Verificar resolución dinámica
- Al conectar: DP-1-1 debe configurarse a la resolución del iPad (~2048x1536 o similar 4:3)
- Al desconectar: DP-1-1 debe apagarse

### 5. Verificar rendimiento
- Latencia aceptable (< 20ms idealmente)
- Sin tearing visible
- Uso de GPU Intel VA-API para encoding

## Criterios de aceptación
- [ ] iPad obtiene IP en red 10.42.0.x
- [ ] Moonlight empareja con Sunshine sin errores
- [ ] Desktop se extiende al iPad (no mirror)
- [ ] Resolución del iPad se detecta correctamente (4:3)
- [ ] Al desconectar Moonlight, DP-1-1 se apaga
- [ ] Flujo reproducible: conectar iPad → ejecutar ipad-usb-connect → abrir Moonlight → funciona
