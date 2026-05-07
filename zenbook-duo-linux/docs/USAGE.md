# Manual de Uso y Funciones

Esta guía detalla todas las capacidades de las herramientas instaladas para tu ASUS Zenbook Duo.

## 🖥️ Gestión de Pantallas (Comando `duo`)

El comando `duo` es el centro de control para tus pantallas.

- `duo top`: Apaga la pantalla inferior y deja solo la principal.
- `duo both`: Enciende ambas pantallas (modo extendido).
- `duo toggle`: Cambia rápidamente entre usar una o ambas pantallas.
- `duo status`: Te dice si el teclado está conectado por USB o Bluetooth.

## 🔆 Brillo y Retroiluminación

### Sincronización Automática
El sistema vigila la pantalla principal. Si subes o bajas el brillo, la pantalla inferior se ajustará automáticamente para coincidir.

### Retroiluminación del Teclado
Hemos implementado un sistema inteligente que ahorra batería y cuida tu vista:
1.  **Ajuste por Luz**: Si hay mucha luz en la habitación, el teclado se apaga solo.
2.  **Inactividad**: Si no tocas el teclado por 30 segundos, se apaga. Al tocarlo, vuelve a encenderse.
3.  **Ahorro**: Si el monitor se apaga, el teclado se apaga instantáneamente.

## ⌨️ Teclado Avanzado (F1-F12)

Por defecto, hemos configurado el teclado en **Modo Función**.

- **F1..F12**: Funcionan como teclas estándar (útil para F5 en el navegador, Alt+F4 para cerrar, etc.).
- **Combinación Super (Windows) + Fx**:
    - `Super + F1`: Silencio (Mute)
    - `Super + F2/F3`: Bajar/Subir Volumen
    - `Super + F4`: Cambiar nivel de luz del teclado (Ciclo)
    - `Super + F5/F6`: Bajar/Subir Brillo
    - `Super + F7`: Intercambiar pantallas
    - `Super + F10`: Activar/Desactivar Bluetooth

### Cambiar Modo de Hardware
Si prefieres el modo original (Multimedia por defecto), puedes usar:
- `fn-lock.py 0`: Vuelve al modo multimedia original.
- `fn-lock.py 1`: Activa el modo de teclas de función (F1-F12).

## 🔋 Límite de Carga de Batería

Para proteger la batería si siempre usas el equipo conectado a la corriente:
- `duo bat-limit 80`: Limita la carga al 80%.
- `duo bat-limit 100`: Permite la carga completa.

---

## 🛠️ Procesos en Segundo Plano (Daemons)

El sistema instala dos servicios que funcionan siempre:
1.  **`zenbook-duo`**: Vigila el teclado. Si lo quitas de encima de la pantalla inferior, esta se enciende automáticamente.
2.  **`zenbook-light-monitor`**: Gestiona la luz del teclado basándose en la luz ambiental y el estado del monitor.