# Manual de Uso y Funciones

Esta guía detalla todas las capacidades de las herramientas instaladas para tu ASUS Zenbook Duo.

## Pantallas (Comando `duo`)

El comando `duo` es el centro de control para tus pantallas.

```bash
duo top              # Solo pantalla principal
duo both             # Ambas pantallas (extendido)
duo toggle           # Cambiar modo
duo status           # Estado del teclado y pantallas
```

## Brillo y Retroiluminacion

### Sincronizacion Automatica
El sistema vigila la pantalla principal. Si subes o bajas el brillo, la pantalla inferior se ajustara automaticamente.

### Retroiluminacion del Teclado (v4)
Sistema inteligente con las siguientes caracteristicas:

1. **Ajuste por Luz**: En oscuridad, se enciende al nivel 1 (minimo). Con luz brillante, se apaga.
2. **Inactividad**: Si no tocas el teclado por 30 segundos, se apaga. Al tocarlo, vuelve a encenderse en menos de 1 segundo.
3. **Debounce**: No cambia de nivel mas de una vez cada 10 segundos (evita parpadeo).
4. **Estado fijo**: Siempre nivel 1 cuando esta encendido en oscuridad (sin oscilacion).

```bash
# Ver estado actual
cat /tmp/zenbook-kb-backlight.state

# Ver log de transiciones
tail -f /var/log/zenbook-kb-backlight.log
```

## Teclado Avanzado (F1-F12)

Por defecto, el teclado esta en **Modo Funcion**.

- **F1..F12**: Funcionan como teclas estandar
- **Super + Fx**:
    - `Super + F1`: Silencio
    - `Super + F2/F3`: Bajar/Subir Volumen
    - `Super + F4`: Cambiar nivel de luz del teclado
    - `Super + F5/F6`: Bajar/Subir Brillo
    - `Super + F7`: Intercambiar pantallas
    - `Super + F10`: Activar/Desactivar Bluetooth

### Fn Lock
```bash
fn-lock.sh           # Ver estado del fn-lock
# Fn+Esc para alternar (combinacion de hardware)
```

## Bateria

Limite de carga configurado al **80%** por defecto (prolonga vida util).

```bash
cat /sys/class/power_supply/BAT0/charge_control_end_threshold  # Ver limite actual
echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold  # Cambiar
```

## Sonido

1. **Ecualizacion**: Perfil "ZenbookDuo" para EasyEffects
2. **Niveles Hardware**: ALSA al 100% automaticamente
3. **4 Parlantes**: Parametros del kernel para Harman Kardon

---

## Monitoreo del Sistema

### Dashboard de Salud
```bash
sudo system-health.sh
```
Muestra: CPU, memoria, disco, Docker, seguridad, servicios.

### Salud del SSD
```bash
sudo ssd-health.sh
```
Muestra: temperatura, wear level, errores, ciclos de energia.

### Monitor de Disco
```bash
# Se ejecuta automaticamente cada hora
# Alerta si disco > 80% (warning) o > 90% (critico)
cat /var/log/disk-monitor.log
```

---

## Mantenimiento Automatico

### Limpieza Semanal
```bash
# Se ejecuta automaticamente los domingos a las 3 AM
# Limpia: Docker, snaps viejos, journal, temporales, APT cache

# Ejecutar manualmente:
sudo weekly-maintenance.sh
```

### Logs
```bash
# Rotacion automatica: diaria, 7 dias, max 1MB
ls /var/log/zenbook-*.log
journalctl --disk-usage  # Tamanio del journal
```

---

## Seguridad

### Firewall (UFW)
```bash
sudo ufw status numbered
```

### SSH
- Solo autenticacion por clave (sin passwords)
- Root login deshabilitado
- Max 3 intentos de autenticacion

### Actualizaciones
- Actualizaciones de seguridad: automaticas
- Reboot automatico: 02:00 AM (si se requiere)

```bash
# Ver updates pendientes
apt list --upgradable
```

---

## Servicios Systemd

| Servicio | Descripcion |
|----------|-------------|
| `zenbook-duo` | Daemon principal (pantallas, teclado) |
| `zenbook-light-monitor` | Retroiluminacion del teclado (v4) |
| `zenbook-thermal` | Control de ventilador automatico |
| `zenbook-adaptive-brightness` | Brillo adaptativo de pantalla |
| `brightness-sync` | Sincronizacion de brillo dual |
| `zenbook-config` | Restaurar configuracion al boot |
| `battery-limit` | Limitar carga de bateria a 80% |

```bash
# Ver estado de todos
systemctl list-units --type=service | grep zenbook

# Ver logs de un servicio
journalctl -u zenbook-light-monitor -f
```
