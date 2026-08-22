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
