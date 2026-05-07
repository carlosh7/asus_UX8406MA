zenbook-duo-linux/
├── install/
│   ├── install.sh          # Script de instalación interactivo
│   └── uninstall.sh        # Script de desinstalación
├── scripts/
│   ├── duo                 # Script principal (de alesya-h)
│   ├── bk.py               # Control teclado retroiluminado
│   └── duo-status-for-argos.3s.sh  # Widget para ArgOS
├── daemon/
│   ├── src/                # Código fuente C
│   ├── bin/                # Binarios compilados
│   ├── Makefile            # Build system
│   └── conf/               # Archivos de configuración
├── systemd/
│   ├── brightness-sync.service
│   ├── zbd.service         # Daemon principal
│   └── zbd-autostart.desktop
├── README.md
└── LICENSE