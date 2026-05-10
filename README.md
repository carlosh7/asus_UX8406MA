# ASUS Zenbook Duo (2024) Linux Support

Optimización integral de hardware para la **ASUS Zenbook Duo 2024 (UX8406MA)** en Linux. Este proyecto proporciona soporte completo para la gestión de doble pantalla, comportamiento del teclado y rendimiento de audio.

## 🐧 Distribuciones Soportadas
- **Ubuntu 24.04+** (y derivados como Pop!_OS, Mint)
- **Arch Linux** (y derivados como Manjaro, EndeavourOS)
- **Debian 12+**

---

## 🚀 Guía para Principiantes (Paso a Paso)

Si eres nuevo en Linux o quieres una instalación sencilla, sigue estos pasos:

### 1. Abrir la Terminal
Presiona `Ctrl + Alt + T` para abrir tu terminal.

### 2. Descargar el proyecto
Copia y pega el siguiente comando para descargar el código:
```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git
cd asus_UX8406MA
```

### 3. Ejecutar el Instalador
Ejecuta el script de instalación. Te pedirá tu contraseña para instalar las dependencias y configurar el sistema:
```bash
sudo ./install/install.sh
```

### 4. Reiniciar tu equipo
Para que todos los cambios (como las mejoras de audio y el auto-inicio) surtan efecto, por favor reinicia tu laptop.

### 5. Toque Final: Audio
Después de reiniciar, abre la aplicación **EasyEffects** y selecciona el perfil **ZenbookDuo** para obtener la mejor calidad de sonido de tus altavoces.

---

## ✨ Características Principales
- **Gestión de Pantalla Dual**: Apaga/enciende la pantalla inferior automáticamente al acoplar o retirar el teclado.
- **Sincronización de Brillo**: Mantiene ambas pantallas con el mismo nivel de brillo.
- **Retroiluminación Inteligente**: Ajuste basado en luz ambiental e inactividad.
- **Optimización de Audio**: Perfiles de EasyEffects y parches de kernel para el sistema de 4 altavoces.
- **Salud de la Batería**: Configura un límite de carga (por defecto 80%) para prolongar su vida útil.
- **Modo Fn-Lock**: Alterna entre teclas de medios y funciones (F1-F12).

## 📖 Documentación
- [Guía Detallada de Instalación](INSTALL.md)
- [Referencia de Comandos (duo)](USAGE.md)
- [Especificaciones de Hardware](SPEC.md)

## 🤝 Créditos
Basado en el excelente trabajo de:
- `alesya-h`: Scripts originales de gestión de pantalla.
- `valirc`: Daemon en C para detección de teclado.
- `asus-linux.org`: Soporte general para Asus en Linux.