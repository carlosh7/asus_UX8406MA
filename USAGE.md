# Guía de Uso y Comandos

La herramienta principal de este proyecto es el comando `duo`. A continuación, se detallan sus funciones.

## 🖥 Gestión de Pantallas

Controla el estado de las dos pantallas OLED de tu Zenbook:

- `duo top`: Mantiene encendida solo la pantalla principal (superior).
- `duo bottom`: Enciende solo la pantalla inferior.
- `duo both`: Enciende ambas pantallas (modo extendido).
- `duo toggle`: Cambia rápidamente entre el modo de una pantalla y el de dos.
- `duo watch-displays`: Inicia el monitoreo automático. Si acoplas el teclado, se apaga la pantalla inferior; si lo retiras, se enciende.

## 🔋 Batería y Energía

- `duo bat-limit [n]`: Establece un límite de carga para proteger la batería. Ej: `duo bat-limit 80`.

## ⌨️ Teclado y Retroiluminación

- `duo set-kb-backlight [0-3]`: Ajusta el brillo del teclado (0 es apagado, 3 es máximo).
- `duo sync-backlight`: Sincroniza manualmente el brillo de la pantalla inferior con la superior.
- `duo watch-backlight`: Activa el modo de sincronización automática en tiempo real.

## 🌡 Sensores y Monitoreo (Próximamente)

Estamos trabajando en integrar el monitoreo de ventiladores y temperaturas directamente en `duo`. Por ahora puedes usar:
- `sensors`: Para ver las temperaturas.
- `cat /sys/class/hwmon/hwmon7/fan1_input`: Para ver las RPM del ventilador.

## ⚙️ Daemon de Detección

El sistema instala un servicio que corre en segundo plano llamado `zenbook-duo`.
- **Estado**: `zenbook-duo status`
- **Manual**: `zenbook-duo daemon` (para ver logs en tiempo real).

---

## ⌨️ Atajos de Teclado Recomendados

Si has ejecutado el script de hotkeys, tendrás estos atajos disponibles:
- `Super + F7`: Cambiar modo de pantalla (Duo toggle).
- `Super + F4`: Ciclar brillo del teclado.
- `Super + F1/F2/F3`: Control de audio global.
