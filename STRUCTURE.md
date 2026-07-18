asus_UX8406MA/
├── install/
│   ├── install.sh              # Script de instalación interactivo (validado)
│   └── uninstall.sh            # Script de desinstalación
├── scripts/
│   ├── duo                     # Script principal de control (X11 + Wayland)
│   ├── wayland-display-mgr.py  # Gestión de pantallas vía DBus (Wayland)
│   ├── bk.py                   # Control retroiluminación teclado (USB + BT)
│   ├── fn-lock.py              # Alternar Fn-Lock (USB HID)
│   ├── thermal-monitor.sh      # Monitoreo térmico y ajuste de perfil
│   ├── kb-backlight-unified.sh # Gestión unificada de retroiluminación
│   ├── adaptive-brightness.sh  # Brillo adaptativo de pantalla
│   ├── audio-diagnose.sh       # Diagnóstico de audio
│   ├── audio-calibrate.sh      # Calibración de audio
│   ├── wifi-diagnose.sh        # Diagnóstico de WiFi
│   ├── test_hardware.sh        # Test completo del hardware
│   ├── webcam-diagnose.sh      # Diagnóstico de cámara
│   ├── webcam-optimize.sh      # Optimización de cámara
│   ├── bt-keyboard-mapper.py   # Mapeo de teclas BT (pendiente)
│   ├── setup-hotkeys.sh        # Configuración de atajos de teclado
│   ├── toggle-bluetooth.sh     # Toggle de Bluetooth
│   ├── start.sh                # Script de inicio en login
│   ├── setup-displays.sh       # Configuración de pantallas al inicio
│   ├── mic-boost.sh            # Boost de micrófono
│   ├── suspend-backlight.sh    # Luz del teclado al despertar
│   ├── nightlight.sh           # Luz nocturna (Redshift)
│   ├── zenbook-config.sh       # Gestor de configuración persistente
│   └── zzZ-keyboard-light      # Hook de suspend para luz del teclado
├── daemon/
│   ├── src/main.c              # Daemon optimizado (sin popen/system)
│   ├── Makefile                # Build system
│   └── conf/
│       └── zenbook-duo.conf    # Configuración del daemon
├── config/
│   ├── 99-touchscreen.conf     # Configuración touchscreen (X11)
│   └── easyeffects/
│       └── output/
│           └── ZenbookDuo.json # Perfil de audio (LSP plugins)
├── systemd/
│   ├── zenbook-duo.service           # Daemon principal
│   ├── brightness-sync.service       # Sincronización de brillo
│   ├── zenbook-auto-display.service  # Auto-detección de teclado
│   ├── zenbook-light-monitor.service # Retroiluminación inteligente
│   ├── zenbook-thermal.service       # Monitoreo térmico
│   ├── zenbook-adaptive-brightness.service # Brillo adaptativo
│   ├── zenbook-config.service        # Restaurar configuración
│   ├── zenbook-nightlight.service    # Luz nocturna
│   ├── zenbook-suspend-backlight.service # Luz en resume
│   └── mic-boost.service             # Boost de micrófono
├── docs/
├── README.md
├── USAGE.md
├── INSTALL.md
├── SPEC.md
├── STRUCTURE.md
└── .gitignore
