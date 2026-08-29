# ACTION_PLAN.md — Plan de acción post-auditoría (asus_UX8406MA)

**Prioridad:** P0 = ahora · P1 = corto plazo · P2 = mejora continua
**Score actual: 77/100 → objetivo: 90+**

---

## ✅ FASE 0 EJECUTADA Y VERIFICADA (ago-2026)

Detalle completo en `AUDIT_REPORT.md` §11. Resumen:

| # | Ítem | Estado |
|---|---|---|
| P0-1 | udev HID world-writable → `0660 input` + grupo input | ✅ repo + host vivo (`crw-rw----`) |
| P0-2 | sudoers wildcards (`bk.py *`, `fn-lock.py *`, `evtest *`) eliminados; usuario al grupo input; mapper sin sudo | ✅ |
| P0-3 | SHA256 del tarball NPU vs digest GitHub API; NPU opcional vía `--with-npu` | ✅ |
| P0-4 | Reducir unidades root | ◐ parcial (Fase 1: user units + polkit) |
| B1 | newline final `zenbook-duo.service` | ✅ |
| B2 | batería dinámica BAT* (unit + sudoers + daemon C itera BAT*) | ✅ |
| B3 | installer aborta si INSTALL_USER vacío | ✅ |
| B4 | numeración installer `[1/10]` | ✅ |
| B5 | unidades root vivas documentadas | ◐ parcial (Fase 1) |
| B6 | backlight principal con fallback dinámico en daemon C | ✅ compilado y desplegado al host |
| B7 | duplicación daemon/watch-displays documentada en USAGE.md | ✅ |
| **B8** | **Táctil dual invertido** | ✅ **RESUELTO Y VERIFICADO POR USUARIO** |

### B8 — Táctil dual (bitácora)

- Causa raíz triple: mapeos invertidos en `setup-touch-wayland.sh` (425b→eDP-1), jamás aplicados al dconf del usuario, y `touch-remap.sh` invocado por daemon root sin bus de sesión (silenciosamente inerte)
- Fix: `touch-remap.sh` v2 — drop root→sesión vía loginctl, mapeos dconf explícitos por dispositivo, rama `bottom`, escala/offset dinámicos
- Iteración 1: con la suposición documental (425a=superior) el test físico dio inversión completa
- **Iteración 2 (commit 8f237da): mapeos intercambiados → usuario confirma funcionamiento correcto**
- Lección hardware: el nº de modelo del controlador NO indica posición física — cableado real: **425b = panel superior, 425a = panel inferior**

### Fixes vivos aplicados al host

- Regla udev reemplazada + recarga → nodo teclado `crw-rw---- root input`
- `powertop.service` disabled+stopped (TLP único gestor activo)
- Mapeos táctiles persisten en dconf del usuario (sobrevivieron reinicio)
- Daemon v2 compilado e instalado en `/usr/local/bin`, servicio reiniciado

---

## PENDIENTE

### Fase 1 — Arquitectura
- Daemon v3 event-driven con libudev (absorbe loops bash de light-monitor/adaptive-brightness/kb-backlight)
- User units para las 6 unidades gráficas que hoy corren como root + helper privilegiado polkit
- `display_mgr.py` único (dedupe wayland-display-mgr.py / touch-remap.sh / interno de duo)
- Config centralizada `/etc/zenbook-duo/config.toml`

### Fase 2 — Paridad Windows
- Hotkeys F10/F11/F12/Fn (probar hid-asus del kernel 7.0)
- Night light Wayland-native (gsettings plugins.color) eliminando loop redshift
- Remover snap auto-cpufreq residual (hoy inactivo)
- Empaquetado .deb + CI v2 (gitleaks, shellcheck pineado, bats, build daemon con ASan)

### P2 menor
- Renombrar `test_hardware.sh` → `hardware-test.sh`
- Quitar `sudo` interno del Makefile

---

## ✅ RONDA 2 ago-2026 — hotkeys BT, ALS, luz teclado, night light, fn-lock

| Issue | Causa raíz | Fix | Estado |
|---|---|---|---|
| Hotkeys muertas por BT | mapper solo monitoreaba el PRIMER event node; ABS_MISC llega por otro nodo; sin re-escaneo en reconexiones | mapper v2: monitorea TODOS los nodos del teclado, multiplexa con select(), re-escanea cada 10s/2s (hotplug) | ✅ desplegado, 5 nodos monitoreados |
| ALS baja brillo y nunca sube | durante PAUSED la referencia LAST_ALS se deslizaba cada ciclo → una subida gradual nunca acumulaba umbral de reanudación | referencia fija PAUSE_ALS al pausar + reanudación por Δ desde pausa o timeout MAX_PAUSE_SEC=600s; configurable en /etc/zenbook-duo/adaptive-brightness.conf | ✅ desplegado |
| Luz teclado: tiempo de reposo | hardcodeado 30s | configurable vía /etc/zenbook-duo/kb-backlight.conf → aplicado 45s | ✅ |
| Night light no activable | `sudo -u user gsettings` SIN bus de sesión → store fantasma | env DBUS_SESSION_BUS_ADDRESS/XDG_RUNTIME_DIR inyectados + temperatura 3700K | ✅ probado on/toggle/status |
| F1-F12 vs multimedia por BT | fn-lock.py solo hablaba USB (pyusb) | v2: auto-detección USB/BT; BT via feature report hidraw (HIDIOCSFEATURE) + regla udev hidraw grupo input | ✅ probado ambas vías |

Validaciones: bash -n ✓ · py_compile ✓ · shellcheck limpio en nuevos ✓

### Ronda 3b ago-2026
- Mic F9: el mute SÍ aplicaba pero era invisible → ahora notifica "Micrófono: silenciado/activo"
- Brillo F5/F6: notificación OSD con % también por BT
- Nuevo: **<Super>Esc** alterna Multimedia ↔ F1-F12 con notificación y persistencia automática (custom3)

### Ronda 3c ago-2026 — comportamiento verificado del hardware
- Captura evtest en modo función: F5 emite KEY_F5 (63) real, SIN ABS_MISC → fn-lock del firmware SÍ funciona
- El brillo que el usuario notó al pulsar F5 venía del ALS/ajuste residual, no de la tecla
- Mapper ahora IGNORA códigos vendor ABS_MISC (16/32/124/199) cuando fnlock-mode=1 → modo función = fila 100% limpia
- Triple-F12 verificado funcionando (2 toggles detectados en journal)

### Ronda 4 ago-2026 — verificación con captura evtest
- **Hallazgo clave**: con fnlock-mode=1 el firmware emite las F-teclas REALES nativamente (F5→KEY_F5 code 63 capturado), con o sin modificadores
- El "Super+F5 no hace nada" era correcto: en modo función NO se necesita Super; el navegador recibe Super+F5 (sin acción) además de F5
- Bonus conservado: en modo multimedia, Super+posición inyecta la F-tecla vía uinput
- Interruptor definitivo: triple-F12 (con lockout anti-deshacer)

### Ronda 5 ago-2026 — ROOT CAUSE definitivo de hotkeys BT muertas
- **Causa**: los números de nodo (/dev/input/eventN) se RECICLAN al reconectar el teclado; el evtest viejo quedaba sordo sobre la instancia muerta y el re-escaneo lo consideraba "ya monitoreado" (mismo path) → nunca re-enganchaba. Además evtest sin line-buffering retenía eventos en pipe de 4KB.
- **Fix**: el mapper rastrea la IDENTIDAD física del dispositivo (ruta sysfs del input); si cambia bajo el mismo event node → mata el evtest viejo, lo re-engancha y reinicializa la fila. Todo con stdbuf -oL.
- **Verificado en vivo por BT**: F5/F6/F9 instantáneos con feedback visual (brillo %, mic).

---

## 🔎 RONDA 6 (2026-08-28) — re-auditoría completa + validación en vivo

Detalle en `AUDIT_REPORT.md` §12. **El proyecto está operativo y validado en el host** (health-check ALL PASSED, 0 servicios fallidos, sin deriva repo↔host, sync de brillo y hotkeys verificados). Pendiente de estos hallazgos:

### P0 — seguridad / coherencia del host (próxima sesión)
1. **A1+A2 installer NPU**: reescribir flujo con `mktemp -d`, `tar --no-same-owner`, instalación por nombres exactos (no globs) y pasar `asset_name` a Python por argv (nunca interpolar JSON remoto en código).
2. **M4 auto-cpufreq**: está ACTIVO junto a TLP (contradice este plan). `sudo snap remove auto-cpufreq` + quitar `install.sh:524`.
3. **M2 autostart root-owned**: `sudo chown -R jim:jim /home/jim/.config/autostart` + arreglar installer (`install -d -o "$INSTALL_USER"`).

### P1 — reproducibilidad / portabilidad
- M1: commit de `fnlock-toggle.sh` al repo + instalarlo en install.sh (hoy solo existe en el host).
- M3: corregir `mode_info[5]→[6]` en `duo` (3 sitios) y `wayland-display-mgr.py` (igual que touch-remap).
- M5: quitar hardcode `"jim"`/`run/user/1000` del mapper; añadir `*.py` al grep anti-hardcode de CI.
- M6: alinear hotkeys de usuario con sudoers (bk.py directo por grupo input sin sudo; toggle-bluetooth con `sudo -n rfkill … bluetooth` o vía polkit) y registrar fallo visible en vez de `|| true`.
- M7: desduplicar daemon C vs auto-display.sh (decidir un único controlador de attach/detach).
- M8: sincronizar uninstall.sh (regla BT hidraw, regla NPU, reset táctil con sintaxis correcta).

### P2 — higiene
- `git rm --cached daemon/zenbook-sendkey` + `.gitignore` (artefacto de build trackeado; `make clean` deja el repo dirty).
- Zombies del daemon: handler SIGCHLD (o `waitpid` loop) en main.c; borrar `toggle_bluetooth()` muerto.
- health-check: intercambiar etiquetas Top/Bottom (alinearlo con B8) y añadir `zenbook-suspend-backlight` a la lista de servicios.
- SPEC.md: marcar F10/F11 como implementadas (mapper v2); notas de F12/Fn siguen válidas.
- thermal-monitor: corregir rama `quiet→performance` (saltar directo a performance ≥82°C).
- mic-boost: reintento si PipeWire no está arriba + gain razonable con boost separado.
- `visudo -cf` tras escribir sudoers; commit del archivo de modo que zenbook-config espera, o crearlo en install.

---

## ✅ Ronda 6b (2026-08-28) — Fix brillo adaptable v3 (reportado por usuario)

**Reporte**: el brillo cambiaba constantemente con la luz del día y, al ajustarlo manualmente, el sistema lo sobreescribía en ~5s. El log del host lo confirma: `18:22:19 Brightness: 400 -> 32` y `18:23:36 Brightness: 400 -> 32` (dos intentos del usuario aplastados).

**Causa raíz** (v2): el contador de estabilidad `_manual_hits` se REINICIABA en el ciclo en que el brillo dejaba de cambiar (rama else de `adaptive-brightness.sh:157`), así que tras asentarse el ajuste manual el loop caía a STEP 3 y re-aplicaba la curva. Además `MAX_PAUSE_SEC=180` limitaba la pausa a 3 min y no existía histéresis frente al ruido del ALS (medido: ±7% jitter).

**Fix** — `scripts/adaptive-brightness.sh` v3:
- El ajuste manual se ADOPTA como preferencia (sesgo = brillo_usuario − curva) tras estabilizar; nunca se sobreescribe mientras dure.
- Re-adapta solo con cambio real de luz (ΔALS ≥50% relativo o ≥40k raw) — descarta el sesgo — o tras `MANUAL_HOLD_SEC=3600` conservando el sesgo.
- Modo auto con histéresis (ΔALS ≥25%, ≥60s entre aplicaciones) + EMA(4) del sensor → sin oscilación.
- Rutas sobreescribibles por env (`ZB_*`) para test con sysfs simulado.

**Validación**: `scripts/test-adaptive-brightness.sh` (nuevo) — 13/13 PASS: ruido sin efecto, manual persistente, fluctuación pequeña no reanuda, cambio real re-adapta, timeout conserva sesgo, pasos F5/F6 adoptan solo el valor final, ajuste manual reiterado actualiza sesgo. bash -n ✓ shellcheck limpio ✓.

**Pendiente de despliegue al host** (requiere sudo del usuario):
```
sudo cp scripts/adaptive-brightness.sh /usr/local/bin/adaptive-brightness.sh
sudo systemctl restart zenbook-adaptive-brightness
```

**Confirmación de usuario (Ronda 6)**: el mapeo táctil de ambas pantallas funciona bien con teclado puesto y retirado ✓ (B8 re-verificado en uso diario).

---

## 🔎 Ronda 6c (2026-08-28) — Auditoría del host en vivo

Detalle completo en `AUDIT_REPORT.md` §13. **Brillo v3 desplegado, confirmado por usuario y commiteado** (`0c20e01`). Descalibrados priorizados:

### P0 — aplicar al host (una sola sesión de sudo)
1. ~~**H1 logrotate**~~ ✅ **HECHO (ago-28)**: chmod 644 + restart por el usuario; logrotate ya acepta el config. Fix de origen en installer commiteado (`c5a751e`).
2. ~~**H2 energía**~~ ✅ **HECHO (ago-28)**: snap auto-cpufreq removido. Pendiente menor: `sudo tlp start` para re-aplicar EPP (quedó `default` tras remover el snap; se corrige solo en el próximo evento de energía).
3. ~~**H5 mic**~~ ✅ **HECHO (ago-28)**: desmuteado (vol 1.00 sin MUTED).
4. **Nuevo (derivado de c5a751e)**: los demás configs instalados por la versión vieja siguen 0664 en el host:
```bash
sudo chmod 644 /etc/systemd/system/zenbook*.service /etc/systemd/system/{brightness-sync,battery-limit,mic-boost}.service /etc/modprobe.d/xe-gpu-optimize.conf /etc/sysctl.d/99-performance.conf /etc/tlp.d/01-zenbook.conf /etc/udev/rules.d/*zenbook*.rules /etc/udev/rules.d/50-usb-power-management.rules
sudo systemctl daemon-reload
```

### P1
- **H3**: quitar `sudo` de `kb-light-cycle.sh`/`duo set-kb-backlight` (grupo input ya da acceso) — elimina 39 fallos sudo/7d.
- **H4**: verificar ruta de altavoces tras resume (puerto Speaker existe; enrutado a Headphones + PUP_DONE timeouts). Probar: reproducir audio tras un suspend/resume y mirar `wpctl status`.
- **H9**: `sudo apt install smartmontools` para que `ssd-health.sh` funcione.

### P2
- H6 decidir autoridad sysctl (TLP vs repo); H7 monitorear flicker DRM pipe A; H8 monitorear errores HOG BT.

### Medición pendiente (1 diálogo pkexec; cancelado por timeout de usuario)
```bash
pkexec bash -c 'for p in /sys/module/xe/parameters/{enable_fbc,enable_psr,enable_dc,enable_panel_replay}; do echo "$p=$(cat $p 2>/dev/null)"; done; tlp-stat -s | head -20; visudo -cf /etc/sudoers.d/zenbook-duo; ls -la /etc/logrotate.d/zenbook-duo.conf'
```
