# STATUS.md — Plan de Implementación Integral

## Resumen del Problema
El proyecto ASUS Zenbook Duo 2024 Linux Support tiene múltiples bugs, servicios faltantes, problemas de seguridad, audio defectuoso, sobrecalentamiento, problemas de WiFi y guardado de monitores externos roto en Wayland. Se requiere una revisión integral del sistema.

## Estado Actual del Sistema
- **Host**: ASUS Zenbook Duo UX8406MA, Ubuntu 24.04, Kernel 6.17
- **Sesión**: Wayland (GNOME)
- **Servicios activos**: Solo `zenbook-duo.service` (daemon C)
- **CPU Temp**: 95-97°C (CRÍTICO)
- **Fan**: 4800 RPM, modo automático
- **Audio**: Perfil EasyEffects roto (plugin Calf no instalado), sobre-amplificación al 153%
- **WiFi**: Señal buena (-45 dBm) pero con soft lockups de iwlwifi
- **Externos**: `duo save-ext` no guarda posiciones correctamente en Wayland, posiciones se pierden al cambiar de modo

---

## FASE 1: Bugs Críticos y Estabilidad [PRIORIDAD ALTA]

### Tarea 1.1: Corregir `duo status` en Wayland
- **Archivo**: `scripts/duo` (función `get-monitor-status`, líneas 166-179)
- **Problema**: Usa `xrandr` que no refleja estado real en Wayland
- **Solución**: Detectar sesión y usar DBus (`org.gnome.Mutter.DisplayConfig`) en Wayland para obtener estado de displays activos. En X11 mantener xrandr.
- **Verificación**: `duo top && duo status` debe retornar "top"

### Tarea 1.2: Corregir `duo model` en Wayland
- **Archivo**: `scripts/duo` (función `detect-model` y `get_resolution`, líneas 33-44)
- **Problema**: xrandr en Wayland muestra resolución escalada (1648x1030) en vez de nativa (2880x1800)
- **Solución**: En Wayland, usar DBus para obtener resolución nativa del monitor, o leer `/sys/class/dmi/id/product_name` para detectar modelo por hardware.
- **Verificación**: `duo model` debe retornar "3k"

### Tarea 1.3: Eliminar hardcoded "carlosh"
- **Archivo**: `scripts/duo` (líneas 146-147)
- **Problema**: `id -u carlosh` hardcodeado
- **Solución**: Reemplazar con `id -u "$USER"` o detectar usuario actual via `/proc/self/status`
- **Verificación**: Funciona con cualquier usuario

### Tarea 1.4: Corregir `sync-backlight` output
- **Archivo**: `scripts/duo` (función `keyboard-is-attached`, línea 182)
- **Problema**: `lsusb | grep` imprime a stdout
- **Solución**: Redirigir salida a `/dev/null` o usar `grep -q`
- **Verificación**: `duo sync-backlight` no muestra basura

### Tarea 1.5: Corregir `duo bottom` en Wayland
- **Archivo**: `scripts/duo` (función `set-display`, línea 160)
- **Problema**: Retorna error explícito "Cannot switch to bottom only"
- **Solución**: Implementar vía DBus para modo bottom-only en Wayland
- **Verificación**: `duo bottom` funciona en Wayland

### Tarea 1.6: Guardado/restauración de posición de monitores externos
- **Archivos**: `scripts/duo` (save-ext/get_external_args), `scripts/wayland-display-mgr.py`
- **Problema**: `duo save-ext` usa xrandr que en Wayland no refleja posiciones lógicas reales. Además, el pipe `while read | sudo tee` vacía el config cuando no hay monitor externo conectado. `wayland-display-mgr.py` ignora las posiciones guardadas y siempre coloca externos a la derecha de eDP-1 con la misma escala. No hay restauración al iniciar sesión.
- **Causa raíz**: 5 sub-problemas:
  1. `save-ext` extrae posición de xrandr (escalada en Wayland), no de DBus
  2. `save-ext` vacía el config si no hay monitor externo (pipe con output vacío)
  3. `get_external_args` aplica posiciones via `xrandr --pos` que no funciona en Wayland
  4. `wayland-display-mgr.py` hardcodea posición de externos (siempre `x_ptr = w1_log`)
  5. `setup-displays.sh` no maneja monitores externos en absoluto
- **Solución**:
  - Crear `scripts/external-monitor-mgr.py` que use DBus (`org.gnome.Mutter.DisplayConfig`) para:
    - **save**: Leer posiciones lógicas actuales de todos los monitores externos, guardar a `/etc/zenbook-duo/external_layout.conf` en formato JSON: `{"connectors": [{"name": "HDMI-1", "x": 1648, "y": 0, "scale": 1.0, "mode_id": "xxx"}]}`
    - **restore**: Leer config y aplicar via `ApplyMonitorsConfig` con Method=2 (persistent)
    - **list**: Mostrar posiciones actuales de todos los monitores
  - Actualizar `duo save-ext` para llamar a `external-monitor-mgr.py save`
  - Actualizar `duo` para que en Wayland, al cambiar de modo (top/both), preserve las posiciones de monitores externos guardadas
  - Agregar `duo ext-position save|restore|list` como comandos dedicados
  - Integrar restauración automática en `start.sh` o servicio systemd
- **Formato nuevo del config** (reemplaza el formato actual de texto plano):
  ```json
  {
    "version": 2,
    "external_monitors": [
      {
        "connector": "HDMI-1",
        "x": 1648, "y": 0,
        "scale": 1.0,
        "mode_id": "34",
        "transform": 0
      }
    ]
  }
  ```
- **Verificación**:
  1. Conecto monitor externo, lo posiciono a la izquierda en Configuración de Pantallas
  2. `duo ext-position save` guarda la posición
  3. `duo top` → `duo both` → monitor externo mantiene posición
  4. Login → posición se restaura automáticamente
  5. Sin monitor externo → `duo ext-position save` no vacía el config

---

## FASE 2: Servicios Systemd y Seguridad [PRIORIDAD ALTA]

### Tarea 2.1: Instalar todos los servicios systemd
- **Archivos**: `systemd/*.service`, `install/install.sh`
- **Problema**: Solo 1 de 5 servicios se instala. Los demás tienen paths hardcoded incorrectos.
- **Solución**:
  - Corregir paths en `.service` files (usar `/usr/local/bin/` en vez de paths absolutos del repo)
  - Actualizar `install.sh` para copiar Y habilitar TODOS los servicios
  - Corregir `mic-boost.service` para que apunte a `/usr/local/bin/mic-boost.sh`
- **Archivos a modificar**:
  - `systemd/brightness-sync.service`
  - `systemd/zenbook-auto-display.service`
  - `systemd/zenbook-light-monitor.service`
  - `systemd/mic-boost.service`
  - `install/install.sh`
- **Verificación**: `systemctl list-units | grep zenbook` muestra todos los servicios

### Tarea 2.2: Restringir sudoers
- **Archivo**: `install/install.sh` (línea 98)
- **Problema**: `$SUDO_USER ALL=(ALL) NOPASSWD: ALL` otorga acceso total
- **Solución**: Reemplazar con comandos específicos:
  ```
  carlosh ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT0/*, /usr/bin/tee /sys/class/backlight/*, /usr/local/bin/bk.py, /usr/local/bin/fn-lock.py
  ```
- **Verificación**: `sudo -n bk.py 2` funciona, `sudo -n rm /test` falla

### Tarea 2.3: Validación de dependencias en install.sh
- **Archivo**: `install/install.sh`
- **Problema**: `apt-get ... || true` silencia errores
- **Solución**: Validar cada paso, reportar errores, abortar si dependencia crítica falla
- **Verificación**: Instalación falla limpiamente si falta gcc

---

## FASE 3: Audio — Sonido de Calidad [PRIORIDAD ALTA]

### Tarea 3.1: Reparar perfil EasyEffects
- **Archivo**: `config/easyeffects/output/ZenbookDuo.json`
- **Problema**: Plugin `BassEnhancer` de Calf no existe (calf no instalado). El plugin no se carga, generando warnings.
- **Solución**: Reescribir el perfil usando plugins de LSP (que SÍ están instalados):
  - Reemplazar `bass_enhancer#0` con `multiband_compressor#0` de LSP o ecualizador
  - Reducir `loudness#0 input-gain` de 3.0 a 0.0
  - Desactivar `clipping` en loudness
  - Ajustar compressor para no sobre-comprimir
- **Verificación**: `easyeffects` carga perfil sin warnings, sonido limpio sin distorsión

### Tarea 3.2: Corregir sobre-amplificación
- **Archivo**: `config/easyeffects/output/ZenbookDuo.json` + verificación de PipeWire
- **Problema**: wpctl muestra `vol: 1.53` (153%) en el sink principal, causando clipping
- **Solución**: 
  - En el perfil EasyEffects, poner output-gain a 0.0
  - Crear script `audio-fix.sh` que ajuste volumen a 100%
  - Verificar que el kernel module options no cause amplificación excesiva
- **Verificación**: `wpctl inspect 58 | grep volume` muestra <= 1.0

### Tarea 3.3: Verificar opciones de kernel para audio
- **Archivo**: `/etc/modprobe.d/zenbook-duo-audio.conf`
- **Problema**: `snd-hda-intel model=asus-zenbook` y `snd-sof-intel-hda-common hda_model=asus-zenbook` pueden no ser correctos para Meteor Lake
- **Solución**: Investigar opciones correctas para Meteor Lake + Realtek ALC294 + CS35L41. Probar sin opciones o con `model=asus-zenbook-pro` 
- **Verificación**: Sonido claro en altavoces y auriculares

### Tarea 3.4: Script de diagnóstico de audio
- **Archivo**: Nuevo `scripts/audio-diagnose.sh`
- **Contenido**: Script que verifica:
  - Estado de PipeWire/WirePlumber
  - Perfil EasyEffects activo
  - Volumen por sink
  - Errores en journalctl de audio
  - Estado de módulos de kernel de sonido
- **Verificación**: `audio-diagnose.sh` reporta estado completo

---

## FASE 4: Refrigeración y Gestión Térmica [PRIORIDAD ALTA]

### Tarea 4.1: Script de monitoreo térmico
- **Archivo**: Nuevo `scripts/thermal-monitor.sh`
- **Problema**: CPU a 95-97°C sin gestión activa. No hay forma de monitorear o controlar.
- **Solución**: Script que:
  - Lee temperaturas de `/sys/class/thermal/thermal_zone*/temp`
  - Lee velocidad del fan de `/sys/class/hwmon/hwmon7/fan1_input`
  - Cambia `platform-profile` entre quiet/balanced/performance según temperatura
  - Muestra alertas cuando >85°C
  - Logging a `/var/log/zenbook-thermal.log`
- **Verificación**: Script detecta temperatura y ajusta perfil

### Tarea 4.2: Servicio systemd de monitoreo térmico
- **Archivo**: Nuevo `systemd/zenbook-thermal.service`
- **Contenido**: Servicio que ejecuta `thermal-monitor.sh` en loop
- **Instalación**: Copiar en `install.sh`
- **Verificación**: `systemctl status zenbook-thermal` activo

### Tarea 4.3: Integrar thermal en CLI `duo`
- **Archivo**: `scripts/duo` (nuevos comandos)
- **Comandos a agregar**:
  - `duo thermal` — muestra temperatura actual de CPU, GPU, fan speed
  - `duo thermal-profile [quiet|balanced|performance]` — cambia perfil
  - `duo fan-speed` — muestra RPM del ventilador
- **Verificación**: `duo thermal` muestra datos en tiempo real

### Tarea 4.4: Configurar fan curve agresiva
- **Archivo**: `scripts/thermal-monitor.sh`
- **Problema**: Fan a 4800 RPM pero CPU sigue a 97°C
- **Solución**: 
  - Ajustar `throttle_thermal_policy` dinámicamente
  - Cuando >85°C: cambiar a "quiet" (prioriza enfriamiento sobre rendimiento)
  - Cuando >90°C: considerar throttling activo
- **Verificación**: Temperatura baja de 97°C a <85°C bajo carga

---

## FASE 5: WiFi y Conectividad [PRIORIDAD MEDIA]

### Tarea 5.1: Diagnosticar y solucionar soft lockups de iwlwifi
- **Archivo**: Nuevo script `scripts/wifi-diagnose.sh` + configuración
- **Problema**: `irq/184-iwlwifi` stuck for 23s en kernel logs
- **Solución**:
  - Instalar `iw` como dependencia
  - Crear script de diagnóstico WiFi que verifique: señal, canales, potencia, errores
  - Verificar si el problema persiste con `iwlwifi` param `power_save=0` (ya está)
  - Investigar si es bug conocido de iwlwifi + Meteor Lake
  - Considerar firmware update
- **Verificación**: No más soft lockups en `journalctl -k | grep iwlwifi`

### Tarea 5.2: Optimizar parámetros WiFi
- **Archivo**: Nuevo `/etc/modprobe.d/iwlwifi-zenbook.conf`
- **Parámetros a configurar**:
  - `power_save=0` (ya activo)
  - `bt_coex_active=1` (para Bluetooth coexistence)
  - `led_mode=0` (default)
- **Instalación**: Agregar a `install.sh`
- **Verificación**: Conexión estable sin interrupciones

### Tarea 5.3: Agregar comando WiFi a `duo`
- **Archivo**: `scripts/duo` (nuevos comandos)
- **Comandos**:
  - `duo wifi` — muestra status: SSID, señal, velocidad, canal
  - `duo wifi-scan` — lista redes disponibles
- **Verificación**: `duo wifi` muestra info completa

---

## FASE 6: Consolidación de Scripts de Backlight [PRIORIDAD MEDIA]

### Tarea 6.1: Unificar 3 scripts en uno
- **Archivos**: `scripts/light-monitor.sh`, `scripts/kb-backlight-mgr.sh`, `scripts/keyboard-inactivity.sh`
- **Problema**: 3 scripts compiten por control del backlight con escalas opuestas
- **Solución**: Crear `scripts/kb-backlight-unified.sh` que combine:
  - Monitoreo de luz ambiental (de light-monitor.sh)
  - Detección de inactividad (de keyboard-inactivity.sh)
  - Umbrales unificados y correctos
  - Estado persistente en `/tmp/`
- **Umbrales unificados** (valores raw ALS del sensor):
  - `>5000`: brillante → level 0 (apagado)
  - `>1500`: normal → level 1
  - `>500`: oscuro → level 2
  - `<=500`: muy oscuro → level 3
- **Verificación**: Solo un proceso de backlight corriendo

### Tarea 6.2: Eliminar scripts obsoletos
- **Archivos**: Los 3 scripts anteriores
- **Acción**: Mantener como legacy con warning de deprecación, o eliminar
- **Verificación**: No hay procesos duplicados

---

## FASE 7: Daemon C — Optimización [PRIORIDAD MEDIA]

### Tarea 7.1: Eliminar popen/system calls
- **Archivo**: `daemon/src/main.c`
- **Problema**: `keyboard_attached_usb()` usa `popen("lsusb")` cada 2 segundos. `set_battery_limit()` usa `system()`.
- **Solución**:
  - Reemplazar `popen("lsusb")` con lectura directa de `/sys/bus/usb/devices/` o uso de libusb
  - Reemplazar `system("duo ...")` con llamadas directas a funciones
  - Reemplazar `system("echo N | sudo tee ...")` con escritura directa a sysfs
- **Archivos a modificar**: `daemon/src/main.c`, `daemon/Makefile`
- **Verificación**: Daemon usa menos CPU y memoria

### Tarea 7.2: Leer config completo del daemon
- **Archivo**: `daemon/src/main.c`
- **Problema**: Daemon ignora campos del config (display paths, brightness paths, etc.)
- **Solución**: Extender `load_config()` para leer TODOS los campos y usarlos en las funciones correspondientes
- **Verificación**: El daemon usa las rutas del config en vez de hardcodear

### Tarea 7.3: Logging adecuado
- **Archivo**: `daemon/src/main.c`
- **Problema**: `journalctl -u zenbook-duo` no muestra entries recientes
- **Solución**: Usar `syslog()` o `fprintf(stderr)` con timestamps para que systemd journal capture la salida
- **Verificación**: `journalctl -u zenbook-duo -f` muestra logs en tiempo real

---

## FASE 8: Instalador y Uninstaller [PRIORIDAD MEDIA]

### Tarea 8.1: Crear uninstall.sh
- **Archivo**: Nuevo `install/uninstall.sh`
- **Contenido**:
  - Detener y deshabilitar servicios systemd
  - Remover binarios de `/usr/local/bin/`
  - Remover servicios systemd
  - Remover config de `/etc/zenbook-duo/`
  - Remover sudoers entry
  - Remover modprobe config
  - Remover autostart desktop entry
  - Preguntar si mantener EasyEffects profile
- **Verificación**: `sudo ./install/uninstall.sh` limpia todo

### Tarea 8.2: Mejorar install.sh con validación
- **Archivo**: `install/install.sh`
- **Cambios**:
  - Validar que cada dependencia se instaló correctamente
  - Si falla algo crítico, abortar con mensaje claro
  - Ofrecer modo `--force` para ignorar errores
  - Agregar `--uninstall` como alias de `uninstall.sh`
  - Instalar TODOS los servicios systemd
  - Instalar dependencias faltantes: `iw`, `xdotool`, `inotify-tools`
- **Verificación**: Instalación limpia y validada

---

## FASE 9: UX y Experiencia de Usuario [PRIORIDAD BAJA]

### Tarea 9.1: Mejorar `duo help`
- **Archivo**: `scripts/duo` (case help)
- **Agregar**: `model`, `thermal`, `wifi`, `thermal-profile`, `fan-speed`
- **Verificación**: `duo help` muestra todos los comandos disponibles

### Tarea 9.2: Actualizar documentación
- **Archivos**: `README.md`, `USAGE.md`, `INSTALL.md`, `STRUCTURE.md`
- **Cambios**:
  - Documentar todos los comandos nuevos
  - Actualizar estructura de archivos
  - Agregar sección de troubleshooting para audio, térmico, WiFi
  - Agregar nota de que `uninstall.sh` existe
- **Verificación**: Documentación refleja estado actual

### Tarea 9.3: Script de diagnóstico completo
- **Archivo**: Reescribir `scripts/test_hardware.sh`
- **Agregar tests**: audio, térmico, WiFi, servicios, permisos
- **Verificación**: `test_hardware.sh` reporta estado de TODO

---

## Orden de Ejecución
1. Fase 1 (Bugs críticos + monitores externos) — base
2. Fase 2 (Servicios + Seguridad) — base
3. Fase 3 (Audio) — experiencia de usuario
4. Fase 4 (Refrigeración) — protección de hardware
5. Fase 5 (WiFi) — conectividad
6. Fase 6 (Consolidación backlight) — limpieza
7. Fase 7 (Daemon optimization) — rendimiento
8. Fase 8 (Installer) — instalación
9. Fase 9 (UX) — pulido final

## Dependencias entre Fases
- Fase 1 → Fase 2 (servicios dependen de scripts corregidos)
- Fase 1.6 (externos) → Fase 2 (nuevo servicio de restauración)
- Fase 2 → Fase 3 (install.sh actualizado para audio)
- Fase 3 → Fase 4 (mismo install.sh)
- Fase 7 puede ejecutarse en paralelo con 3-6
- Fase 9 es la última

## Archivos a Crear
- `scripts/external-monitor-mgr.py` — Guardado/restauración de monitores externos vía DBus
- `scripts/kb-backlight-unified.sh`
- `scripts/thermal-monitor.sh`
- `scripts/audio-diagnose.sh`
- `scripts/wifi-diagnose.sh`
- `systemd/zenbook-thermal.service`
- `systemd/zenbook-external-restore.service` — Restaurar posiciones externos al login
- `/etc/modprobe.d/iwlwifi-zenbook.conf`
- `install/uninstall.sh`

## Archivos a Modificar
- `scripts/duo` (bug fixes + save-ext vía DBus + nuevos comandos)
- `scripts/wayland-display-mgr.py` (leer posiciones guardadas en vez de hardcodear)
- `scripts/start.sh` (agregar restauración de externos)
- `daemon/src/main.c` (optimización)
- `daemon/Makefile` (flags)
- `install/install.sh` (validación + servicios + instalar `iw`, `xdotool`, `inotify-tools`)
- `systemd/*.service` (paths corregidos)
- `config/easyeffects/output/ZenbookDuo.json` (perfil reparado)
- `/etc/modprobe.d/zenbook-duo-audio.conf` (opciones correctas)
- `README.md`, `USAGE.md`, `INSTALL.md`, `STRUCTURE.md`
