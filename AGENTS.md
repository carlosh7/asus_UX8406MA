# asus_UX8406MA — Guía para agentes

Soporte completo de hardware para el **ASUS Zenbook Duo 2024 (UX8406MA) en Linux**:
gestión de doble pantalla, mapeo táctil, retroiluminación de teclado, brillo adaptativo,
control térmico, audio, protección de batería e instalador único auto-verificante.
Optimizado para **GNOME (X11/Wayland)** en Ubuntu/Debian/Arch; kernel recomendado ≥ 6.8.

## Estructura

- `install/` — instalador (`install.sh`, auto-verificante, un solo comando)
- `daemon/` — daemon de hardware (teclas, backlight, sensores; incluye `zenbook-sendkey`)
- `config/` · `systemd/` — configuraciones y unidades de servicio
- `scripts/` — utilidades de mantenimiento y verificación
- `docs/` — documentación técnica; `SPEC.md` (especificación), `STRUCTURE.md` (mapa del repo)

## Comandos y notas

- Instalación: ver `INSTALL.md` (dependencias por distro + proceso manual detallado).
- Uso post-instalación: `USAGE.md`.
- **Lección de auditoría reciente** (commits `b11cfef`/`0d32607`): las hotkeys muertas tenían
  como causa raíz los *node names reciclados* por udev + `evtest` obsoleto — el mapper debe
  trackear la identidad del dispositivo a través de reconexiones, no confiar en el nombre del nodo.
- Los servicios systemd NO deben depender de `DBUS_SESSION_BUS_ADDRESS` del root (rompe el
  contexto de sesión de usuario).

## Auditoría 2026-08
- `AUDIT_REPORT.md`: estado real, vulnerabilidades y bugs conocidos del proyecto.
- `ACTION_PLAN.md`: plan priorizado P0→P3 pendiente de ejecutar.

Al trabajar en este repo, consulta estos archivos antes de proponer cambios y actualízalos al cerrar hallazgos.
