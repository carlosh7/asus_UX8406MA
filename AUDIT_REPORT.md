# AUDIT_REPORT.md — Auditoría del repositorio asus_UX8406MA

**Fecha:** 2026-08-21 · **Alcance:** solo lectura (no se aplicó nada al sistema) · **Commits:** 45 · **Último commit:** 2026-08-19

---

## 1. Inventario (¿qué configura?)

| Área | Componentes |
|------|-------------|
| **Pantallas duales** | `scripts/duo` (CLI principal), `wayland-display-mgr.py`, `auto-display.sh`, `brightness-sync` (`duo watch-backlight`), `adaptive-brightness.sh`, `nightlight.sh`, `oled-protect.sh` |
| **Daemon C** | `daemon/src/main.c` (326 líneas): detecta teclado USB/BT vía sysfs, auto-toggle pantallas, sync de brillo; sin `system()`/`popen()` |
| **Teclas / hotkeys** | `setup-hotkeys.sh`, `fn-lock.py/.sh`, `bt-keyboard-mapper.py`, `bk.py` (retroiluminación) |
| **Retroiluminación teclado** | `kb-backlight-unified.sh` (v4, ALS + inactividad), `zzz-keyboard-light` (hook suspend), `suspend-backlight.sh` |
| **Audio** | Perfiles EasyEffects (`ZenbookDuo.json` + Spatial), `amp-enable.sh` (CS35L41, detección dinámica de tarjeta), `mic-boost.sh`, modprobe `snd-hda-intel model=asus-zenbook` |
| **Energía / batería** | `battery-limit.service` (80%), TLP (`config/tlp/01-zenbook.conf`), powertop `--auto-tune` (creado por installer), reglas udev USB autosuspend, sysctl tuning |
| **Térmico / fans** | `thermal-monitor.sh`: perfiles `platform_profile` (quiet/balanced/performance) vía hwmon ASUS |
| **NPU / GPU** | Instalación driver Intel NPU (GitHub API) + Level Zero (PPA), `xe-gpu-optimize.conf` (FBC/PSR/SAGV) |
| **Entrada / táctil** | `setup-touch-wayland.sh/x11.sh`, `touch-remap.sh`, mapeo dconf tabletas 04f3:425a/b |
| **Diagnóstico** | `zenbook-health-check.sh`, `system-health.sh`, `ssd-health.sh`, `wifi/webcam/audio-diagnose.sh`, `test_hardware.sh`, `thermal-stress-test.sh` |

## 2. Avance real vs docs + % completitud

- SPEC.md declara MVP/Should/Nice **todo ✅ COMPLETE**: verificado mayormente cierto (pantallas, brillo, backlight, batería, servicios, instalación).
- **Honestidad en SPEC:** F10/F11/F12/Fn marcados ❌ correctamente (no soportados aún).
- **Desfases detectados:**
  - `SPEC.md:52` referencia `hotkey_handler.py` — **no existe** en el repo.
  - `SPEC.md:62` paquete `.deb` "future" — no implementado.
  - `STRUCTURE.md` desactualizado: nombra `zzZ-keyboard-light` pero el archivo real es `zzz-keyboard-light`; faltan ~10 scripts presentes y los dirs `config/modprobe|ssh|sysctl|tlp|logrotate`.
  - `README.md:30` promete "sin bloat IA" pero `install/install.sh:82` instala OpenVINO + onnxruntime con `pip3 --break-system-packages`, y apila TLP + powertop + auto-cpufreq (3 gestores de energía a la vez).

**% completitud global estimado: ~85%** (MVP 100%, hotkeys F10–F12/Fn 0%, docs al día ~80%).

## 3. Calidad de configs/scripts

**Positivo:**
- `bash -n`: **todos** los scripts OK.
- `systemd-analyze verify systemd/*.service`: **exit 0**, unidades sintácticamente válidas.
- CI (`lint.yml`): shellcheck (severidad warning+) + `udevadm verify` + grep anti-hardcoded-user. `.shellcheckrc` razonable.
- `install.sh` usa `set -euo pipefail`, detección de `$SUDO_USER`, sustitución dinámica de usuario (commit cf27bae eliminó hardcodes).
- Daemon C limpio: handler de señales, lectura directa sysfs, `poll_interval` configurable (2 s por defecto).

**Negativo:**
- Numeración de pasos inconsistente en `install.sh` (`[1/9]` en línea 46 vs `[x/10]` después).
- `Makefile` llama `sudo` dentro de `make install` (redundante cuando el installer ya es root; rompe `make install` de usuario normal).
- Mezcla de estilos de nombre: `test_hardware.sh` (snake) vs kebab-case del resto.

## 4. Bugs (archivo:línea)

| # | Ubicación | Bug |
|---|-----------|-----|
| B1 | `systemd/zenbook-duo.service:16` | Sin newline final (`WantedBy=graphical.target` pegado a EOF); POSIX exige `\n` final |
| B2 | `systemd/battery-limit.service:7` | Ruta hardcodeada `BAT0`; falla silenciosa si el equipo expone `BAT1` |
| B3 | `systemd/mic-boost.service:9`, `zenbook-bt-keyboard.service`, `zenbook-light-monitor.service` | `%U` resuelve al UID del servicio; si `INSTALL_USER` queda vacío corren como root → `/run/user/0/bus` no existe |
| B4 | `install/install.sh:46` | `[1/9]` debería ser `[1/10]` |
| B5 | `install/install.sh:381-383` | `sed` inyecta `User=` solo en 3 unidades; `zenbook-adaptive-brightness`, `zenbook-nightlight`, `zenbook-auto-display` y `brightness-sync` quedan como root ejecutando lógica de sesión gráfica (gsettings/dbus) |
| B6 | `daemon/conf/zenbook-duo.conf:9` | `brightness_main=/sys/class/backlight/intel_backlight/...` hardcodeado (frágil si el kernel renombra a `card0-eDP-1`) |
| B7 | `scripts/duo:636-641` (`watch-displays`) | Duplica la función del daemon C; si ambos corren → toggles contradictorios |

No hay `/home/jim` ni usuarios hardcodeados en código de ejecución ✓ (solo URLs de GitHub en README/LICENSE/docs).

## 5. Seguridad

- **gitleaks:** `~/.local/bin/gitleaks detect` sobre 43 commits → **0 fugas**, reporte vacío (`[]`). ✓
- **curl|bash:** no existe ningún patrón curl/wget piped-to-shell. ✓
- **Descargas de .deb** (GitHub API + PPA Intel): HTTPS correcto pero **sin verificación checksum/firma** antes de `dpkg -i` (`install.sh:170-215`) — riesgo supply-chain moderado.
- **Sudoers con wildcards** (`install.sh:365-370`): `NOPASSWD /usr/bin/evtest *` permite al usuario leer eventos de **cualquier** dispositivo de entrada como root (keylogging); ídem `bk.py *` y `fn-lock.py *`. Superficie excesiva.
- **udev inseguro** (`install.sh:328`): `MODE="0666"` para el teclado USB 0b05:1b2c → nodo world-writable (inyección HID por cualquier usuario local). Debería ser `0660 GROUP=input` o tag `uaccess`.
- **Units como root innecesariamente:** 9 de 12 unidades no declaran `User=`; al menos 4 ejecutan tareas de sesión gráfica que no requieren root (ver B5). `brightness-sync` sí necesita root para sysfs backlight.
- **pip3 --break-system-packages** (`install.sh:82`): degrada garantías del gestor de paquetes del sistema.

## 6. Eficiencia daemons

- Daemon C: polling 2 s con lecturas sysfs baratas, actúa solo ante cambios → excelente.
- Scripts bash de monitoreo: thermal cada 3 s, adaptive-brightness 5 s, kb-backlight 1 s (off)/3 s (on) → CPU despreciable, bien calibrado (commits 5822161, 27e70f1).
- Mejorable: 5+ loops bash paralelos podrían consolidarse en un solo supervisor; `watch-backlight` (root) y light-monitor (usuario) solapan el monitoreo de backlight.

## 7. Stack requerido vs sistema actual

| Requisito | Necesario | Sistema local | Estado |
|-----------|-----------|---------------|--------|
| Kernel (Meteor Lake, i915/xe) | ≥ 6.17 (SPEC) | **7.0.0-30-generic** | ✓ |
| systemd | ≥ 252 | **259.5** | ✓ |
| gcc/make/python3/wget | sí | presentes | ✓ |
| gitleaks | para esta auditoría | ~/.local/bin/gitleaks | ✓ |
| systemd-analyze | validación | /usr/bin/systemd-analyze | ✓ |
| shellcheck | CI | **no instalado localmente** | ✗ (solo CI) |

## 8. Diseño / organización

- Estructura clara: `install/ scripts/ systemd/ config/ daemon/ docs/` + README/SPEC/USAGE/INSTALL raíz. Buena separación config-vs-lógica.
- Documentación abundante y con badges, créditos MIT, plantillas de issues, CI propio: madurez alta para repo personal.
- Débitos: STRUCTURE.md obsoleto, duplicación INSTALL.md raíz ↔ docs/, scripts de diagnóstico mezclados con scripts de servicio en `scripts/`.

---

## 9. Score final: **77 / 100**

| Criterio | Peso | Puntos |
|----------|------|--------|
| Avance | 20 | 17 (~85% completitud) |
| Calidad configs/scripts | 15 | 13 |
| Bugs | 15 | 10 |
| Seguridad | 20 | 14 |
| Eficiencia daemons | 10 | 8 |
| Stack/kernel | 5 | 4 |
| Diseño/organización | 15 | 11 |
| **Total** | **100** | **77** |

## 10. Validaciones runtime ejecutadas

| Validación | Resultado |
|------------|-----------|
| `bash -n` en todos los `.sh` | ✓ ALL OK |
| `systemd-analyze verify systemd/*.service` | ✓ exit 0 |
| `gitleaks detect` (43 commits) | ✓ 0 fugas |
| `uname -r` vs requisito kernel | ✓ 7.0.0 ≥ 6.17 |
| shellcheck local | ✗ binario ausente (compensado por CI) |
| Aplicación de configs al sistema real | NO realizada (solo lectura) ✓ |

---

## 11. Ejecución Fase 0 (ago-2026)

**Repo** (`git log`: ver commits):
- install.sh: guard de INSTALL_USER (aborta), numeración [1/10], udev `0660 input`, sudoers sin wildcards (bk/fn-lock/evtest fuera), NPU opcional `--with-npu` + SHA256 contra digest de GitHub API, detección dinámica de backlights pendiente migrar a conf (daemon ya lo hace nativo)
- bt-keyboard-mapper.py: sin sudo (grupo input)
- daemon/src/main.c: batería dinámica BAT* + fallback de backlight principal detectado; compilado con make ✓
- systemd: newline final zenbook-duo.service ✓, battery-limit.service itera BAT*
- scripts/touch-remap.sh **v2**: drop root→sesión vía loginctl, mapeos dconf explícitos CORRECTOS (425a→eDP-1, 425b→eDP-2), rama `bottom`, escala/offset dinámicos
- setup-touch-wayland.sh: mapeos invertidos corregidos, delega en touch-remap.sh
- Docs: README (--with-npu), SPEC (fantasma fuera), STRUCTURE.md regenerado, USAGE nota watch-displays

**Host vivo**:
- Regla udev aplicada → nodo teclado `crw-rw---- root input` (antes world-writable); jim en grupo `input` (activo tras reinicio)
- powertop.service disabled+stopped (TLP único gestor activo)
- Mapeos táctiles escritos en dconf del usuario y persisten tras reinicio
- Daemon v2 instalado en /usr/local/bin y servicio reiniciado (activo, sync brillo OK)

**Validaciones post-Fase 0**: bash -n todos ✓ · shellcheck archivos nuevos limpio · systemd-analyze verify ✓ · gitleaks 0 fugas · 11/11 unidades activas · 0 failed

**B8 VERIFICADO POR USUARIO ✅**: primer intento resultó en inversión completa → evidencia de que el cableado físico es 425b=panel SUPERIOR, 425a=panel INFERIOR (contrario a los comentarios del health-check original). Mapeos intercambiados y re-testeado: touch inferior responde abajo, superior arriba. Fix definitivo en commit 8f237da.

---

## 12. Ronda 6 (2026-08-28) — Re-análisis completo + validación en vivo del host

**Alcance:** revisión de todo el árbol actual (scripts/, install/, systemd/, daemon/, config/, CI), validaciones estáticas y pruebas sobre el host vivo donde el proyecto está instalado y en control.

### 12.1 Validación en vivo — TODO FUNCIONANDO

| Check | Resultado |
|-------|-----------|
| Servicios | 11/12 activos (suspend-backlight es oneshot de resume), **0 failed**, 0 warnings/errors en 24h de journal |
| `zenbook-health-check.sh` | **ALL CHECKS PASSED** (ALS, dual-touch, fan 4100 RPM, batería 80%/80%, night light, audio, thermal, WiFi, USB autosuspend) |
| Mapeo táctil | dconf correcto y aplicado: `touchscreens/04f3:425b→eDP-1` (sup), `425a→eDP-2` (inf) — coherente con B8 |
| Hotkeys | mapper root con 5 evtest vivos; init de fila cada 60s rc=0; `/etc/zenbook-duo/fnlock-mode=0`; F5/F6/F9 verificados ronda 5 |
| `brightness-sync` | **FUNCIONA con inotify real**: journal muestra eventos `intel_backlight/brightness MODIFY` → i915 llama `sysfs_notify` en este kernel (refuta sospecha teórica de bloqueo) |
| Perfil térmico | auto-switching vivo (performance ↔ balanced según temp) |
| Deriva repo↔host | `make` en daemon reproduce binarios **byte-idénticos** a `/usr/local/bin` (zenbook-duo y zenbook-sendkey) ✓ · scripts idénticos ✓ · unidades solo difieren en las 2 con `User=` inyectado por installer (por diseño) |
| udev host | USB 0b05:1b2c `0660 input` ✓ · hidraw BT 1b2d `0660 input` ✓ |
| Energía | TLP activo+enabled, powertop disabled — **PERO** ver 12.2-M4 |
| Estáticas | `bash -n` ✓ todos · `systemd-analyze verify` exit 0 · `py_compile` ✓ · gitleaks 0 fugas (68 commits) · shellcheck solo info/estilo (SC2086 en listas de paquetes intencionales) |

### 12.2 Hallazgos nuevos (contra el árbol actual)

**Altos**
| # | Ubicación | Hallazgo |
|---|-----------|----------|
| A1 | `install/install.sh:186-235` | Flujo NPU inseguro en `/tmp`: descarga a ruta predecible (`/tmp/linux-npu-driver-*.tar.gz`, además `[ ! -f ]` usa un tarball pre-plantado), extracción como root en /tmp world-writable, e instalación de globs `ls intel-*npu_*.deb` → privesc local clásico. Usar `mktemp -d` + `tar --no-same-owner` |
| A2 | `install/install.sh:199-209` | `basename` de URL del JSON remoto de GitHub interpolado dentro de código Python (`asset_name = '$NPU_ASSET'`) → metadatos remotos ejecutados como root. Pasar el valor por argv/stdin, nunca interpolarlo |

**Medios**
| # | Ubicación | Hallazgo |
|---|-----------|----------|
| M1 | `scripts/setup-hotkeys.sh:51`, host | `<Super>Esc` apunta a `/usr/local/bin/fnlock-toggle.sh` que **existe en el host pero no está en el repo ni lo instala install.sh** → roto en reinstalación limpia. Commit del script + añadirlo al installer |
| M2 | `install/install.sh:465-476`, host | `~/.config/autostart` creado como root → **confirmado en host: `drwxr-xr-x root root`**; el usuario no puede gestionar su autostart. `chown` recursivo o `install -d -o user` |
| M3 | `scripts/duo:371,462,521`, `wayland-display-mgr.py:16` | `is-current` leído en `mode_info[5]`; Mutter actual lo expone en `[6]` (touch-remap.sh ya corregido a `[6]` con `len>=7`) → selección de modo cae silenciosamente al primer modo; funciona hoy por coincidencia (primer modo = activo) |
| M4 | host, `install.sh:524` | **auto-cpufreq snap ACTIVO junto a TLP** (dos gestores de energía compitiendo). El ACTION_PLAN asumía "hoy inactivo" — falso. Remover snap y la línea del installer |
| M5 | `scripts/bt-keyboard-mapper.py:168-173` | Hardcodea `"jim"` y `/run/user/1000` como fallback de mic-mute (funciona en este host, rompe portabilidad; viola la regla anti-hardcode). El grep de CI (`lint.yml:41`) **no escanea `.py`** → agujero en el check |
| M6 | `kb-light-cycle.sh:21`, `duo:715`, `toggle-bluetooth.sh:7,10` | Desajuste script↔sudoers: los primeros llaman `sudo bk.py` (fuera de sudoers desde Fase 0 → prompt bajo keybinding de usuario); toggle-bluetooth llama `rfkill` sin sudo (sudoers solo concede `rfkill … bluetooth`). En este host funcionan porque pasan por el mapper root; la vía de bindings GNOME (custom0-2) está rota silenciosamente |
| M7 | `systemd/zenbook-duo` + `zenbook-auto-display` | Duplicación activa: el daemon C y auto-display.sh monitorean el teclado y ambos aplican `duo top/both` (carrera posible). B7 cubría watch-displays; este par no |
| M8 | `install/uninstall.sh:89,146` | No elimina `99-zenbook-keyboard-bt.rules` (ni regla NPU); el `gsettings reset` del mapeo táctil tiene sintaxis inválida (schema relocatable requiere `schema:path`) → desinstalación incompleta |

**Bajos (selección)**
- Zombies: `daemon/src/main.c` `exec_cmd()` hace `waitpid(WNOHANG)` y no reap — 2 zombies confirmados hijos del daemon (`[bash]`, `[sudo]` desde el boot).
- `daemon/src/main.c:165-171` `toggle_bluetooth()` es código muerto y con bug latente (`rfkill block` sin tipo fallaría; con bloqueo global mataría WiFi).
- `daemon/zenbook-sendkey` (binario) está **trackeado en git**; `make clean` lo borra y deja el repo dirty. `git rm --cached` + `.gitignore`.
- `scripts/thermal-monitor.sh:129-131`: rama `quiet→performance` inalcanzable (BAL_TEMP 68 captura todo ≥68) → enfría a máx con un paso extra de 30s.
- `scripts/zenbook-health-check.sh:220-221`: etiquetas Top/Bottom **intercambiadas** (Top=425A) contradiciendo B8/código real; :53 no lista `zenbook-suspend-backlight`.
- `scripts/mic-boost.sh:14`: gain 10.0 (1000%) sin reintento si PipeWire no subió en 3s (y riesgo de clipping).
- `scripts/zenbook-config.sh`: `restore` depende de un archivo de modo que el installer nunca crea; `duo none` no es un comando válido.
- `SPEC.md:36-38`: F10/F11 marcadas ❌ pero el mapper v2 ya las implementa (BT toggle / nightlight) — doc desactualizada.
- `setup-hotkeys.sh` invocado desde installer sin bus de sesión → bindings pueden no aplicarse en instalación limpia (en este host ya persisten en dconf).
- Sudoers escrito sin `visudo -cf` previo; nightlight X11 depende de `redshift` que el installer no instala; `duo:34` busca `Xauthority` en vez de `.mutter-Xwaylandauth-*`.

### 12.3 Score recalibrado: **79 / 100** (antes 77)

Sube por hotkeys implementadas (rondas 2-5) y validación integral en vivo verde; baja en seguridad por A1/A2 y en bugs por los nuevos hallazgos. El proyecto **funciona de verdad en el host** — los hallazgos son de robustez, reproducibilidad e higiene, no de operación diaria.

---

## 13. Ronda 6c (2026-08-28) — Auditoría del HOST en vivo

**Alcance:** estado real del equipo (energía, térmico, audio, display, GPU/NPU, journal 7d). Lecturas no privilegiadas + 2 diálogos pkexec autorizados por el usuario.

### 13.1 Fix aplicado y verificado en vivo

| Item | Resultado |
|------|-----------|
| **Brillo adaptable v3** desplegado a `/usr/local/bin` y reiniciado | `19:40:02 MANUAL: adoptado BR=170 (sesgo 138 vs curva 32)` — el valor del usuario **persiste** ✓. Causa v2 documentada en ACTION_PLAN Ronda 6b. Commits `0c20e01` (fix+tests 13/13) y `3b6f05e` (docs) |

### 13.2 Descalibrado encontrado (priorizado)

| # | Severidad | Hallazgo | Evidencia | Fix |
|---|-----------|----------|-----------|-----|
| H1 | **Alta** | **logrotate muerto por config del propio proyecto**: `/etc/logrotate.d/zenbook-duo.conf` quedó con modo 0664 → logrotate lo rechaza y el servicio **falla a diario** (5×/7d) → rotación de TODOS los logs del sistema parada | journal logrotate "dangerous mode 0664" | `chmod 644` en host + installer con `install -m 644` |
| H2 | **Alta** | **Doble gestor de energía**: TLP (enabled, aplica su política) + snap **auto-cpufreq ACTIVO** compiten. En vivo: EPP=`default` en AC cuando TLP pide `performance`; TLP además pisa sysctl del repo (`vm.dirty_writeback_centisecs` 1500 real vs 500 del repo) | snap services + sysctl -n vs config | `snap remove auto-cpufreq` + quitar `install.sh:524` (Fase 2) |
| H3 | Media | **Hotkeys de usuario con sudo sin NOPASSWD**: 39 eventos "sudo:auth conversation failed" en 7d — el binding F4 llama `sudo bk.py` y el sudoers lo excluyó desde Fase 0 (hallazgo M6 confirmado en vivo). Las vías root (mapper) sí funcionan | journal sudo ×39 | alinear scripts↔sudoers (bk.py directo por grupo input) |
| H4 | Media | **CS35L41 PUP_DONE timeouts** (16×/7d, último hoy 12:08 ≈ resume) + sumidero analógico enrutado a puerto "Headphones" aunque el **puerto Speaker físico existe** (`Speaker:playback_FR`, physical=true). Si no hay auriculares conectados, jack-detection o el resume deja los speakers sin enrutar | journal cs35l41 + wpctl inspect 68 | probar selección de puerto tras resume; vigilar |
| H5 | Media | Micrófono **MUTED** (vol 1.00 MUTED en default source) — posiblemente intencional vía F9, pero conviene saberlo | wpctl | `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0` si no es intencional |
| H6 | Baja | **sysctl 99-performance.conf parcialmente inefectivo**: TLP sobrescribe dirty_writeback; `log_martians` 0 vs 1. (tcp_rmem/wmem OK — falso positivo por tabs) | sysctl -n vs repo | decidir autoridad: TLP o repo |
| H7 | Baja | **DRM "Atomic update failure" pipe A** 108×/7d (+pipe B 4×) — flicker potencial en dual OLED 120Hz; sin impacto funcional medible | journal kernel | monitor; reportar upstream si hay flicker visible |
| H8 | Baja | **BT HOG set_report errors** 43×/7d — teclado BT; puede degradar fn-lock/reports tras reconexiones | journal bluetoothd | monitor (mapper v2 ya re-inicializa fila cada 60s) |
| H9 | Baja | `smartctl` no instalado → `ssd-health.sh` del proyecto no puede funcionar | which smartctl | `apt install smartmontools` o quitar dependencia |
| H10 | Info | Teclado BT detectado por upower es un **Logitech K850 externo** (100%), no el desacoplable (que estaba en USB) | upower | — |

### 13.3 Bien calibrado (verificado OK)

- **Batería**: salud **89.4%** (67.1/75.1 Wh, 151 ciclos), límite 80% activo — "Not charging" clavada en 80% es el comportamiento correcto.
- **Térmico**: pkg 66°C, fan ~3500 RPM, perfil `balanced` acorde a la curva del thermal-monitor (auto-switching vivo); sin throttling.
- **NPU**: `/dev/accel0` presente (root:render, ACL para jim) ✓.
- **Night light**: activa a 3700K ✓. **Touch dual** ✓ (confirmado por usuario con teclado puesto y retirado).
- **0 unidades fallidas**, 0 segfaults en 7d, disco 57% usado, TLP enabled (los errores "not enabled" son del momento de instalación, ago-22 09:00).
- Governor performance en AC = correcto según TLP; perfil ACPI dinámico funcionando.

### 13.4 Mediciones obtenidas (deploy.sh --diag, 2026-08-28 23:49)

| Medición | Resultado |
|----------|-----------|
| **xe params** | `enable_fbc=1, enable_psr=1, enable_psr2_sel_fetch=Y, enable_sagv=Y, enable_ips=Y, enable_dc=-1, enable_panel_replay=-1` — **todas las optimizaciones GPU activas** (el conf de modprobe sí aplica) |
| **NVMe SMART** | `critical_warning=0, percentage_used=3% (97% vida), media_errors=0`, unsafe_shutdowns=57 (contador informativo) — **SSD sano** |
| **sudoers** | `visudo -cf`: parsed OK |
| **EPP=default en AC** | **No es bug**: con governor=performance (TLP on-AC) intel_pstate ignora el EPP; solo es relevante en powersave/batería. Sin PPD ni auto-cpufreq: TLP + thermal-monitor coherentes |
| **Backlights** | `intel_backlight 51/400` y `card1-eDP-2 51/400` — **sync de brillo verificado en vivo en modo dual** |
| **Doctor 1ª pasada** | Activa, reparó `suspend-backlight` (falso positivo corregido en `aeab137`) y dejó el RESUMEN en su log |
| **v5 kb-backlight** | Self-check `Idle OK (bus=/run/user/1000/bus)` — detección de idle funcional por primera vez |

### 13.5 Cierre (ronda 7, commits 17df257…aeab137)

Backlog P0/P1/P2 de §12 y §13 **resuelto en el repo** y desplegado al host vía
`scripts/deploy.sh`: NPU /tmp hardening (A1/A2), autostart (M2), fnlock-toggle en
repo (M1), índice Mutter (M3), hardcodes+CI (M5), sudo hotkeys (M6), desduplicación
daemon/auto-display (M7), uninstall sincronizado (M8), zombies+toggle_bluetooth,
health-check/SPEC/thermal/nightlight/sysctl, y la capa nueva **zenbook-doctor**
(auto-validación/reparación cada 15 min) + **deploy.sh** (despliegue repo→host en
un comando). Smartmontools instalado (H9). Score final del proyecto: **88/100**.
