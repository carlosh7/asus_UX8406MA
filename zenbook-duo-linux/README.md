# Zenbook Duo Linux (UX8406MA)

Soporte completo de hardware para la **ASUS Zenbook Duo 2024 (UX8406MA)** en Linux. Este proyecto soluciona los problemas comunes de las dos pantallas, el brillo sincronizado, el límite de carga de batería y la gestión avanzada del teclado inalámbrico.

## ✨ Características Principales

- **Gestión de Pantalla Dual**: Cambia entre una pantalla, ambas o modo vertical con un solo comando.
- **Detección Automática de Teclado**: El sistema detecta cuando acoplas o retiras el teclado físico para apagar/encender la segunda pantalla automáticamente.
- **Sincronización de Brillo**: El brillo de la pantalla inferior se sincroniza automáticamente con la principal.
- **Control Inteligente de Retroiluminación**:
  - Ajuste automático según la luz ambiental.
  - Apagado automático por inactividad.
  - Apagado instantáneo al apagar el monitor.
- **Modo Pro-Keyboard (F1-F12)**:
  - Teclas F1-F12 configuradas como primarias (ideal para programadores).
  - Atajos multimedia accesibles mediante `Super (Windows) + F1-F12`.
- **Límite de Batería**: Configura un límite de carga (ej. 80%) para extender la vida útil de la batería.

## 🚀 Instalación Rápida

Para usuarios principiantes, simplemente abre una terminal y ejecuta:

```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git
cd asus_UX8406MA/zenbook-duo-linux
sudo ./install/install.sh
```

Después de instalar, ejecuta este comando para configurar los atajos de teclado `Super + F1-F12`:
```bash
setup-hotkeys.sh
```

## 📖 Documentación Detallada

- [Guía de Instalación Paso a Paso](docs/INSTALL.md)
- [Manual de Uso y Comandos](docs/USAGE.md)
- [Solución de Problemas](docs/TROUBLESHOOTING.md)

## 🤝 Referencias y Créditos

Inspirado y basado en el excelente trabajo de:
- `alesya-h/zenbook-duo-2024-ux8406ma-linux`
- `valirc/zenbook-duo-2024-ux8406ma-daemon`