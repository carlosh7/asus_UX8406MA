# Guía de Uso y Comandos

La herramienta principal de este proyecto es el comando `duo`. A continuación, se detallan sus funciones.

## Gestión de Pantallas

Controla el estado de las dos pantallas OLED de tu Zenbook:

- `duo top`: Mantiene encendida solo la pantalla principal (superior).
- `duo bottom`: Enciende solo la pantalla inferior.
- `duo both`: Enciende ambas pantallas (modo extendido).
- `duo toggle`: Cambia rápidamente entre el modo de una pantalla y el de dos.
- `duo status`: Muestra el estado actual de las pantallas.
- `duo status-full`: Muestra información detallada de monitores (incluyendo externos).
- `duo watch-displays`: Inicia el monitoreo automático del teclado USB.

## Monitores Externos

Gestiona la posición de monitores externos en Wayland:

- `duo ext-position save`: Guarda las posiciones actuales de monitores externos.
- `duo ext-position restore`: Restaura posiciones guardadas al conectar un monitor.
- `duo ext-position list`: Muestra las posiciones actuales de todos los monitores.
- `duo save-ext`: Alias para `ext-position save`.

## Brillo y Retroiluminación

- `duo sync-backlight`: Sincroniza el brillo de la pantalla inferior con la superior.
- `duo watch-backlight`: Activa el modo de sincronización automática en tiempo real.
- `duo set-kb-backlight <0-3>`: Ajusta el brillo del teclado (0=apagado, 3=máximo).

## Batería y Energía

- `duo bat-limit [n]`: Establece un límite de carga para proteger la batería (por defecto: 80%).

## Sistema

- `duo model`: Muestra el modelo detectado (3k/1080p).
- `duo session-type`: Muestra si estás en X11 o Wayland.
- `duo help`: Muestra la ayuda completa.

---

## Herramientas de Diagnóstico

### Audio
```bash
audio-diagnose.sh    # Diagnóstico completo de audio
audio-calibrate.sh   # Calibración de audio y amplificadores
```

### WiFi
```bash
wifi-diagnose.sh     # Diagnóstico completo de WiFi
```

### Refrigeración
```bash
thermal-monitor.sh   # Monitoreo térmico (se ejecuta como servicio)
```

### Hardware Completo
```bash
test_hardware.sh     # Test completo del sistema
```

### Cámara
```bash
webcam-diagnose.sh   # Diagnóstico de cámara
webcam-optimize.sh   # Optimización de cámara
```

### Brillo Adaptativo
```bash
adaptive-brightness.sh  # Control de brillo automático (se ejecuta como servicio)
```

---

## Servicios Systemd

El sistema instala varios servicios que corren en segundo plano:

| Servicio | Función |
|----------|---------|
| `zenbook-duo` | Daemon principal: monitorea teclado USB |
| `brightness-sync` | Sincroniza brillo entre pantallas |
| `zenbook-auto-display` | Auto-detección de teclado |
| `zenbook-light-monitor` | Ajusta retroiluminación según luz ambiental |
| `zenbook-thermal` | Monitorea temperatura y ajusta perfil de ventilador |
| `zenbook-adaptive-brightness` | Brillo adaptativo de pantalla |
| `zenbook-config` | Restaurar configuración al inicio |
| `zenbook-suspend-backlight` | Luz del teclado al despertar |

**Comandos útiles:**
```bash
systemctl status zenbook-duo           # Ver estado del daemon
journalctl -u zenbook-duo -f           # Ver logs en tiempo real
sudo systemctl restart zenbook-duo     # Reiniciar daemon
```

---

## Atajos de Teclado

Si has ejecutado el script de hotkeys, tendrás estos atajos disponibles:
- `F1`: Volume Mute
- `F2`: Volume Down
- `F3`: Volume Up
- `F4`: Keyboard Backlight
- `F5`: Brightness Down
- `F6`: Brightness Up
- `F7`: Toggle Display
- `F9`: Mic Mute
- `F10`: Toggle Bluetooth

**Fn + F1-F12**: Teclas de función (F1-F12)

---

## Calibración Automática

El sistema incluye calibraciones predefinidas:

- **Brillo adaptativo**: Calibrado para 4 condiciones de luz (ventana, escritorio, artificial, oscuro)
- **Luz del teclado**: Se enciende solo en condiciones oscuras (<2500 raw)
- **Refrigeración**: Perfiles automático (quiet/balanced/performance)

---

## Solución de Problemas Comunes

### El teclado no se detecta automáticamente
```bash
zenbook-duo status    # Verificar estado del teclado
systemctl status zenbook-duo  # Verificar que el daemon esté corriendo
```

### El brillo no se sincroniza
```bash
duo sync-backlight    # Sincronizar manualmente
inotifywait --help    # Verificar que inotify-tools está instalado
```

### El sonido suena mal
```bash
audio-diagnose.sh     # Diagnosticar problemas de audio
audio-calibrate.sh    # Calibrar audio y amplificadores
wpctl status          # Verificar niveles de volumen
```

### La laptop se calienta
```bash
zenbook-duo thermal   # Ver temperatura actual
journalctl -u zenbook-thermal -f  # Ver logs del monitoreo térmico
```

### WiFi inestable
```bash
wifi-diagnose.sh      # Diagnosticar problemas de WiFi
```

### Touch no funciona
```bash
# En Wayland: touch funciona automáticamente
# En X11: ejecutar setup-hotkeys.sh para configurar
```
