# ACTION_PLAN.md — Plan de acción post-auditoría (asus_UX8406MA)

**Prioridad:** P0 = ahora · P1 = corto plazo · P2 = mejora continua
**Score actual: 77/100 → objetivo: 90+**

## ✅ FASE 0 EJECUTADA (ago-2026) — ver detalle en AUDIT_REPORT.md §11

---

## P0 — Seguridad (impacto alto, esfuerzo bajo)

1. ~~**Cerrar el nodo HID world-writable**~~ ✅ **Ejecutado**: regla → `MODE="0660", GROUP="input"` + `usermod -aG input`. Aplicado TAMBIÉN al host vivo (nodo ahora `crw-rw---- root input`).
2. ~~**Recortar sudoers con wildcards**~~ ✅ **Ejecutado**: eliminadas líneas `bk.py *`, `fn-lock.py *` (sin consumidores) y `evtest *`; el usuario va al grupo `input` y `bt-keyboard-mapper.py` ya no usa sudo.
3. ~~**Verificar integridad de descargas**~~ ✅ **Ejecutado**: SHA256 del tarball NPU contra el campo `digest` de la API de GitHub; sección NPU ahora opcional tras flag `--with-npu`.
4. ◐ **Reducir unidades root**: pendiente migración completa a user units (Fase 1). Live: documentado que 6 unidades corren como root.

## P1 — Bugs funcionales

5. ~~newline final zenbook-duo.service~~ ✅
6. ~~BAT0 dinámico~~ ✅ (unit + sudoers + daemon C itera BAT*)
7. ◐ `%U` fallback: installer ahora ABORTA si INSTALL_USER vacío; unidades existentes sin revisar
8. ~~brightness_main dinámico~~ ✅ daemon detecta raw≠bottom si default no existe
9. ~~Duplicación daemon vs watch-displays~~ ✅ documentado en USAGE.md (solo con auto_display=0)

## P1 — Coherencia docs ↔ código

10. ~~STRUCTURE.md regenerado~~ ✅ desde árbol real
11. ~~SPEC.md fantasma hotkey_handler.py~~ ✅ reemplazado por touch-remap.sh
12. ~~README vs OpenVINO~~ ✅ NPU opcional vía --with-npu; README actualizado
13. ◐ Un solo gestor de energía: **powertop.service desactivado en host vivo**; auto-cpufreq snap sigue instalado pero inactivo — removerlo del sistema queda pendiente

## P2 — Calidad y CI

14–18: Pendientes (numeración installer ya corregida de paso: [1/10] ✓)

### B8 NUEVO (táctil dual) — ✅ RESUELTO
- Causa raíz: mapeos invertidos en setup-touch-wayland.sh (425b→eDP-1) + jamás aplicados al dconf del usuario + touch-remap.sh invocado por daemon root sin bus de sesión (silenciosamente inerte)
- Fix: touch-remap.sh v2 (drop root→sesión vía loginctl, mapeos dconf explícitos correctos, rama bottom, escala dinámica); setup-touch-wayland.sh delega
- **Pendiente: test físico del usuario** (desacoplar teclado → tocar pantalla inferior → debe responder abajo)

---

## P0 — Seguridad (impacto alto, esfuerzo bajo)

1. **Cerrar el nodo HID world-writable** (`install/install.sh:328`)
   - Cambiar `MODE="0666", GROUP="plugdev"` → `MODE="0660", GROUP="input"` (o `TAG+="uaccess"`).
   - Verificar que `bk.py`/`fn-lock.py` siguen funcionando vía sudoers ya existente.
2. **Recortar sudoers con wildcards** (`install/install.sh:369`)
   - Eliminar `NOPASSWD /usr/bin/evtest *` (habilita keylogging como root). Sustituir por un wrapper propio que solo lea los dispositivos del Zenbook, o quitarlo.
   - Acotar `bk.py *` y `fn-lock.py *` a subcomandos concretos (`bk.py set`, `fn-lock.py toggle`) en lugar de `*`.
3. **Verificar integridad de descargas** (`install/install.sh:170-215`)
   - Comparar SHA256 de los .deb del driver NPU y de `libze1` contra los assets `.sha256sum` publicados en la release antes de `dpkg -i`.
4. **Reducir unidades root** (B5)
   - Añadir `User=%i`-style inyección también a `zenbook-adaptive-brightness`, `zenbook-nightlight`, `zenbook-auto-display`, o mejor: convertirlas a **user units** en `~/.config/systemd/user/` + `WantedBy=graphical-session.target`.
   - Dejar solo como root las que escriben sysfs (`battery-limit`, `brightness-sync`, `zenbook-suspend-backlight`).

## P1 — Bugs funcionales

5. **`systemd/zenbook-duo.service`:16** — añadir newline final al archivo.
6. **`systemd/battery-limit.service`:7** — resolver batería dinámicamente:
   `ExecStart=/bin/sh -c 'echo 80 > /sys/class/power_supply/BAT*/charge_control_end_threshold'` o detección en installer.
7. **Fallback `%U`→root** (B3): si `INSTALL_USER` está vacío, abortar instalación con error claro en vez de dejar unidades rotas apuntando a `/run/user/0/bus`.
8. **`daemon/conf/zenbook-duo.conf`:9** — detectar `brightness_main` dinámicamente igual que ya se hace para la tarjeta de audio (`amp-enable.sh`).
9. **Eliminar duplicación daemon vs `duo watch-displays`** (`scripts/duo:636`) — eliminar el modo o documentar que es exclusivo cuando `auto_display=0`.

## P1 — Coherencia docs ↔ código

10. **Regenerar STRUCTURE.md** (script o manual): corregir `zzZ-keyboard-light`→`zzz-keyboard-light`, añadir los ~10 scripts y dirs faltantes (`config/modprobe|ssh|sysctl|tlp|logrotate`).
11. **SPEC.md:** borrar `hotkey_handler.py` o implementarlo; mover `.deb` a "Roadmap".
12. **README.md vs install.sh:** decidir la postura sobre IA/NPU; si se mantiene OpenVINO (`install.sh:82`), quitar el "no AI bloat" del README; idealmente hacer los paquetes IA opcionales con flag `--with-npu`.
13. **Un solo gestor de energía:** TLP + powertop auto-tune + auto-cpufreq compiten. Recomendado: TLP como único gestor; eliminar el unit powertop.service y el snap auto-cpufreq.

## P2 — Calidad y CI

14. **Numeración installer:** `[1/9]` → `[1/10]` (`install.sh:46`); extraer pasos repetidos en funciones.
15. **Makefile:** quitar `sudo` interno de `install:`; exigir root fuera del Makefile.
16. **CI:** añadir job con `gitleaks` y fijar versión de action-shellcheck (evitar `@master`); añadir `shellcheck` binario al entorno local de desarrollo.
17. **Consolidar loops bash** de monitoreo (thermal/brightness/backlight) en un supervisor único si se busca bajar contexto de despertar; hoy el coste es aceptable.
18. **Renombrar `test_hardware.sh` → `hardware-test.sh`** para consistencia kebab-case (actualizar referencias en installer y README).

---

### Criterio de aceptación
- [ ] Sin nodos udev world-writable ni sudoers con wildcards abiertos.
- [ ] Todas las units gráficas con usuario explícito (o convertidas a user units).
- [ ] `bash -n`, `systemd-analyze verify`, `udevadm verify` y shellcheck limpios en CI.
- [ ] STRUCTURE.md y SPEC.md sin referencias fantasma.
- [ ] Descargas .deb verificadas por checksum.
