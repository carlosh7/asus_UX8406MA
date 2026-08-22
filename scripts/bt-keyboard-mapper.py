#!/usr/bin/env python3
"""
Zenbook Duo - Keyboard Hotkey Mapper v2
Monitorea ABS_MISC del teclado ASUS en TODOS sus nodos de evento
(USB y Bluetooth), con re-enumeración periódica para hotplug.

Corrección ago-2026 (v2): la v1 solo monitoreaba el PRIMER nodo que
encontraba al arrancar; por Bluetooth los eventos llegan por otro nodo
y además los nodos cambian de número en cada reconexión → hotkeys muertas.
"""

import subprocess
import glob
import os
import time
import select

DEVICE_NAME = "ASUS Zenbook Duo Keyboard"
RESCAN_EVERY = 10          # segundos entre re-escaneos si hay nodos vivos
IDLE_RESCAN = 2            # segundos si no hay nodos vivos

# ABS_MISC value -> función (teclas multimedia por enlace USB)
KEYCODE_MAP = {
    199: "kbd_light",
    16:  "br_down",
    32:  "br_up",
    124: "mic_mute",
}

# EV_KEY code -> función (fila F7/F10-F12; llegan como teclas estándar)
# Solo se procesa en value=1 (pulsación)
EVKEY_MAP = {
    65: "display_toggle",   # KEY_F7  : alternar pantallas
    68: "bt_toggle",        # KEY_F10 : bluetooth
    87: "nightlight",       # KEY_F11 : luz nocturna
    88: "status_osd",       # KEY_F12 : estado en pantalla
}

BACKLIGHT = "/sys/class/backlight/intel_backlight"


def log(msg):
    print(msg, flush=True)


def find_session_user():
    """Usuario con sesión gráfica activa (para wpctl/notify-send)."""
    u = os.environ.get("SUDO_USER", "")
    if u:
        return u
    try:
        out = subprocess.run(["who"], capture_output=True, text=True).stdout
        for line in out.splitlines():
            if "(:" in line or "seat0" in line:
                return line.split()[0]
    except Exception:
        pass
    return ""


def run_as_session_user(cmd):
    user = find_session_user()
    if not user:
        log("  ERROR: sin sesión gráfica para ejecutar acción de usuario")
        return
    uid = os.popen(f"id -u {user}").read().strip()
    env = f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus XDG_RUNTIME_DIR=/run/user/{uid}"
    subprocess.run(f"sudo -u {user} env {env} {cmd}", shell=True,
                   capture_output=True, text=True)


def find_event_nodes():
    """Todos los event nodes cuyo input name sea el teclado ASUS."""
    nodes = []
    for name_file in glob.glob("/sys/class/input/input*/name"):
        try:
            if DEVICE_NAME not in open(name_file).read():
                continue
            inp_dir = os.path.dirname(name_file)
            for ev in glob.glob(f"{inp_dir}/event*"):
                dev = f"/dev/input/{os.path.basename(ev)}"
                if os.access(dev, os.R_OK):
                    nodes.append(dev)
        except OSError:
            continue
    return sorted(set(nodes))


def br_step(direction):
    """Paso de brillo de pantalla vía sysfs (sudoers: tee NOPASSWD) + feedback OSD."""
    try:
        cur = int(open(f"{BACKLIGHT}/brightness").read())
        mx = int(open(f"{BACKLIGHT}/max_brightness").read())
        step = max(mx // 10, 1)
        target = min(mx, max(1, cur + direction * step))
        r = subprocess.run(
            ["sudo", "-n", "tee", f"{BACKLIGHT}/brightness"],
            input=f"{target}\n", capture_output=True, text=True)
        if r.returncode == 0:
            pct = round(target * 100 / mx)
            log(f"  brillo -> {target}/{mx} ({pct}%)")
            # Feedback visual (el OSD nativo de GNOME no aparece al escribir sysfs)
            run_as_session_user(
                f"notify-send -h int:value:{pct} -t 800 "
                f"-a 'Zenbook Duo' -i display-brightness 'Brillo {pct}%'")
        else:
            log(f"  ERROR brillo: {r.stderr.strip()}")
    except Exception as e:
        log(f"  ERROR brillo: {e}")


def mic_mute_toggle():
    # wpctl debe correr como el usuario dueño del servidor PipeWire
    run_as_session_user("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    log("  mic toggle enviado")


def display_toggle():
    subprocess.Popen(["/usr/local/bin/duo", "toggle"])
    log("  duo toggle")


def bt_toggle():
    r = subprocess.run(["/usr/local/bin/toggle-bluetooth.sh"],
                       capture_output=True, text=True)
    log(f"  bluetooth: {r.stdout.strip() or r.stderr.strip()}")


def nightlight():
    run_as_session_user("/usr/local/bin/nightlight.sh toggle")
    log("  night light toggle")


def status_osd():
    try:
        st = subprocess.run(["/usr/local/bin/duo", "status"],
                            capture_output=True, text=True, timeout=10)
        summary = " | ".join(st.stdout.splitlines()[:2]) or "Zenbook Duo"
    except Exception:
        summary = "Zenbook Duo"
    run_as_session_user(
        "notify-send -t 1500 -a 'Zenbook Duo' 'Estado' \"" + summary.replace('"', "'") + "\"")
    log("  status OSD")


def execute(action):
    if action == "kbd_light":
        subprocess.Popen(["/usr/local/bin/kb-light-cycle.sh"])
        log("  kbd-light cycle")
    elif action == "br_down":
        br_step(-1)
    elif action == "br_up":
        br_step(+1)
    elif action == "mic_mute":
        mic_mute_toggle()
    elif action == "display_toggle":
        display_toggle()
    elif action == "bt_toggle":
        bt_toggle()
    elif action == "nightlight":
        nightlight()
    elif action == "status_osd":
        status_osd()


def parse_line(line, proc_map):
    # Teclas multimedia (USB): eventos ABS_MISC del fabricante
    if "ABS_MISC" in line and "value" in line:
        try:
            value = int(line.split("value")[1].strip())
        except ValueError:
            return
        if value > 0 and value in KEYCODE_MAP:
            key = KEYCODE_MAP[value]
            log(f"ABS_MISC {value} -> {key}")
            execute(key)
        return
    # Fila de función: EV_KEY estándar (F7/F10/F11/F12) en pulsación
    if "EV_KEY" in line and "value 1" in line:
        for code, action in EVKEY_MAP.items():
            if f"code {code} (" in line:
                log(f"EV_KEY {code} -> {action}")
                execute(action)
                return


def main():
    if os.geteuid() != 0 and not os.access("/dev/input/event0", os.R_OK):
        log("AVISO: sin acceso a /dev/input (¿grupo input?)")

    procs = {}   # Popen -> node
    last_scan = 0

    while True:
        # Re-escaneo: cuando no hay procesos o venció el intervalo
        now = time.time()
        alive_nodes = {n for n, p in procs.items() if p.poll() is None}
        if not procs or (not alive_nodes and now - last_scan >= IDLE_RESCAN) \
           or (now - last_scan >= RESCAN_EVERY and len(procs) < 8):
            nodes = [n for n in find_event_nodes() if n not in alive_nodes]
            for node in nodes:
                try:
                    p = subprocess.Popen(["evtest", node],
                                         stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL,
                                         text=True)
                    procs[node] = p
                    log(f"Monitoring {node}")
                except Exception as e:
                    log(f"No se pudo abrir {node}: {e}")
            last_scan = now
            # Limpieza de procesos muertos
            procs = {n: p for n, p in procs.items() if p.poll() is None}

        if not procs:
            time.sleep(IDLE_RESCAN)
            continue

        # Multiplexar stdout de todos los evtest vivos
        fds = {p.stdout.fileno(): n for n, p in procs.items() if p.poll() is None}
        if not fds:
            time.sleep(0.5)
            continue
        readable, _, _ = select.select(list(fds.keys()), [], [], 1.0)
        for fd in readable:
            node = fds[fd]
            line = procs[node].stdout.readline()
            if not line:
                continue   # proceso morirá; se detectará en próximo scan
            parse_line(line, procs)


if __name__ == "__main__":
    main()
