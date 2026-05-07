# Guía de Instalación para Principiantes

Esta guía te ayudará a configurar tu ASUS Zenbook Duo 2024 en Linux paso a paso.

## 📋 Requisitos Previos

1.  **Sistema Operativo**: Recomendamos **Ubuntu 24.04 LTS** o superior, o **Debian 12**.
2.  **Entorno de Escritorio**: Esta guía está diseñada para **GNOME** (el escritorio por defecto de Ubuntu).
3.  **Conexión a Internet**: Necesaria para descargar dependencias.

---

## 🛠️ Paso 1: Abrir la Terminal

Presiona `Ctrl + Alt + T` en tu teclado para abrir una ventana de terminal. Aquí es donde escribiremos los comandos.

## 🛠️ Paso 2: Descargar el Código

Copia y pega el siguiente comando en la terminal y presiona `Enter`:

```bash
git clone https://github.com/carlosh7/asus_UX8406MA.git
```

Este comando descargará todos los archivos necesarios a una carpeta llamada `asus_UX8406MA` en tu equipo.

## 🛠️ Paso 3: Entrar en la Carpeta

Escribe lo siguiente:

```bash
cd asus_UX8406MA/zenbook-duo-linux
```

## 🛠️ Paso 4: Ejecutar el Instalador

Ahora vamos a ejecutar el script que instala todo automáticamente. Te pedirá tu contraseña (es normal que no se vean asteriscos mientras escribes).

```bash
sudo ./install/install.sh
```

**¿Qué hace este script?**
- Instala programas necesarios (drivers de USB, sensores de luz, etc.).
- Configura el sistema para que el brillo se sincronice solo.
- Instala el "demonio" (un programa que corre de fondo) para detectar el teclado.

## 🛠️ Paso 5: Configurar los Atajos de Teclado (Opcional pero recomendado)

Para que las teclas F1-F12 funcionen como teclas de función normales y puedas usar `Super (Windows) + Fx` para el volumen/brillo, ejecuta:

```bash
setup-hotkeys.sh
```

## 🛠️ Paso 6: Reiniciar

Para que todos los cambios surtan efecto (especialmente la detección del teclado y el límite de batería), reinicia tu computadora.

---

## ✅ ¿Cómo saber si funcionó?

1.  **Segunda Pantalla**: Al despegar el teclado físico, la pantalla inferior debería encenderse sola. Al ponerlo encima, debería apagarse.
2.  **Brillo**: Si cambias el brillo de la pantalla principal, la de abajo debería cambiar igual.
3.  **Teclado**: Prueba presionar `Super (Windows) + F3`. Debería subir el volumen.

¡Felicidades! Ya tienes tu Zenbook Duo optimizada para Linux.