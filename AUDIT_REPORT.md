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
