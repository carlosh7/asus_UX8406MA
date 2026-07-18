# ASUS Zenbook Duo (2024) Linux Support

Optimización integral de hardware para la **ASUS Zenbook Duo 2024 (UX8406MA)** en Linux. Este proyecto proporciona soporte completo para la gestión de doble pantalla, comportamiento del teclado, rendimiento de audio, refrigeración y conectividad.

## Distribuciones Soportadas
- **Ubuntu 24.04+** (y derivados como Pop!_OS, Mint)
- **Arch Linux** (y derivados como Manjaro, EndeavourOS)
- **Debian 12+**

---

## Guía para Principiantes (Paso a Paso)

### 1. Abrir la Terminal
Presiona `Ctrl + Alt + T` para abrir tu terminal.

### 2. Descargar el proyecto
```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git
cd asus_UX8406MA
```

### 3. Ejecutar el Instalador
```bash
sudo ./install/install.sh
```

### 4. Reiniciar tu equipo
Para que todos los cambios surtan efecto.

### 5. Toque Final: Audio
Abre **EasyEffects** y selecciona el perfil **ZenbookDuo**.

---

## Características Principales

### Gestión de Pantallas
- **Pantalla Dual**: Apaga/enciende la pantalla inferior automáticamente al acoplar o retirar el teclado.
- **Soporte Wayland**: Control completo vía DBus de GNOME Mutter.
- **Monitores Externos**: Guarda y restaura posiciones de monitores externos.
- **Sincronización de Brillo**: Mantiene ambas pantallas con el mismo nivel de brillo.

### Audio
- **Perfiles EasyEffects**: Configuración optimizada para el sistema de 4 altavoces.
- **Corrección de Sobre-amplificación**: Previene distorsión y clipping.
- **Soporte CS35L41**: Drivers para amplificadores inteligentes Cirrus Logic.

### Refrigeración
- **Monitoreo Térmico**: Supervisa temperatura del CPU y ajusta automáticamente el perfil de ventilador.
- **Perfiles Adaptativos**: Cambia entre quiet/balanced/performance según la temperatura.

### Brillo
- **Brillo Adaptativo**: Se ajusta según la luz ambiental con calibración predefinida.
- **Pausa Manual**: Si ajustas el brillo manualmente, se mantiene hasta que la luz cambie.
- **Retroiluminación Inteligente**: Se enciende en oscuridad y se apaga con inactividad.

### Conectividad
- **WiFi Optimizado**: Configuración iwlwifi para prevenir soft lockups.
- **Diagnóstico WiFi**: Script completo para verificar hardware, driver, señal y errores.
- **Bluetooth**: Toggle rápido con `F10`.

### Teclado
- **Hotkeys**: Atajos de teclado configurados (`F1-F12`).
- **Fn-Lock**: Alterna entre teclas de medios y funciones.

### Batería
- **Límite de Carga**: Configura un límite (por defecto 80%) para prolongar la vida útil.

---

## Comandos Principales

```bash
# Gestión de pantallas
duo top|bottom|both    # Cambiar modo de pantalla
duo toggle             # Alternar entre top/both
duo status             # Ver estado actual

# Monitores externos
duo ext-position save    # Guardar posiciones
duo ext-position restore # Restaurar posiciones
duo ext-position list    # Ver posiciones actuales

# Batería y brillo
duo bat-limit 80       # Establecer límite de batería
duo set-kb-backlight 2 # Ajustar brillo del teclado

# Diagnóstico
test_hardware.sh       # Test completo del sistema
audio-diagnose.sh      # Diagnóstico de audio
wifi-diagnose.sh       # Diagnóstico de WiFi
```

Para ver todos los comandos: `duo help`

---

## Documentación
- [Guía de Uso y Comandos](USAGE.md)
- [Guía Detallada de Instalación](INSTALL.md)
- [Especificaciones de Hardware](SPEC.md)

---

## Créditos
Basado en el excelente trabajo de:
- `alesya-h`: Scripts originales de gestión de pantalla.
- `valirc`: Daemon en C para detección de teclado.
- `asus-linux.org`: Soporte general para Asus en Linux.
