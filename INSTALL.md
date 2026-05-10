# Guía de Instalación Detallada

Esta guía explica los pormenores técnicos del proceso de instalación para las diferentes distribuciones soportadas.

## 📋 Requisitos Previos
- **Kernel**: Se recomienda la versión 6.8 o superior para un mejor soporte de los drivers de Asus.
- **Entorno de Escritorio**: Optimizado para GNOME (X11 o Wayland).
- **Acceso Root**: Es necesario el uso de `sudo`.

## 📦 Dependencias por Distribución

El instalador automático (`install.sh`) gestionará esto por ti, pero aquí tienes la lista si prefieres hacerlo manualmente:

### Ubuntu / Debian / Pop!_OS
```bash
sudo apt install python3 python3-usb inotify-tools lm-sensors iio-sensor-proxy easyeffects lsp-plugins usbutils build-essential gcc make pkg-config libusb-1.0-0-dev libglib2.0-dev
```

### Arch Linux / Manjaro
```bash
sudo pacman -S python python-pyusb inotify-tools lm_sensors iio-sensor-proxy easyeffects lsp-plugins usbutils base-devel libusb glib2
```

## 🛠 Proceso de Instalación Manual

Si no deseas usar el script automático, estos son los pasos que realiza:

1. **Compilación del Daemon**:
   ```bash
   cd daemon
   make
   sudo make install
   ```
   *El daemon se encarga de monitorear la conexión del teclado USB/Bluetooth.*

2. **Instalación de Scripts**:
   Los scripts se copian a `/usr/local/bin` para que estén disponibles en todo el sistema.

3. **Configuración de Audio**:
   - Se añade un archivo en `/etc/modprobe.d/` para forzar el modelo de audio de Asus.
   - Se copia el perfil de EasyEffects a tu carpeta personal.

4. **Permisos Sudoers**:
   Se crea un archivo en `/etc/sudoers.d/` para permitir que los scripts de brillo y batería funcionen sin pedir contraseña cada vez.

## 🔍 Solución de Problemas Comunes

### El teclado no se detecta automáticamente
Asegúrate de que el daemon esté corriendo:
```bash
ps aux | grep zenbook-duo
```
Si no aparece, intenta ejecutarlo manualmente para ver si hay errores: `sudo zenbook-duo daemon`.

### El brillo no se sincroniza
Verifica que `inotify-tools` esté instalado correctamente. El script `duo watch-backlight` depende de esto para detectar cambios en tiempo real.

### No hay sonido o suena muy bajo
1. Verifica que el perfil de EasyEffects esté activo.
2. Ejecuta `alsamixer` y asegúrate de que todos los canales (especialmente "Speaker") estén al máximo.
