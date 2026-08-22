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
BUILTIN_KEYBOARD_NAME = "AT Translated Set 2 keyboard"   # teclado integrado laptop
RESCAN_EVERY = 10          # segundos entre re-escaneos si hay nodos vivos
IDLE_RESCAN = 2            # segundos si no hay nodos vivos

# Estado global para combo Super+Esc (alternar personalidad de la fila)
_super_down = False

# ABS_MISC value -> función (teclas multimedia por enlace USB)
KEYCODE_MAP = {
    199: "kbd_light",
    16:  "br_down",
    32:  "br_up",
    124: "mic_mute",
}

# EV_KEY code -> función (fila F7/F10/F11; llegan como teclas estándar)
# Solo se procesa en value=1 (pulsación)
EVKEY_MAP = {
    65: "display_toggle",   # KEY_F7  : alternar pantallas
    68: "bt_toggle",        # KEY_F10 : bluetooth
    87: "nightlight",       # KEY_F11 : luz nocturna
}
# Super + posición de fila -> F-tecla REAL vía zenbook-sendkey (uinput)
SUPER_TRANSLATE_EVKEY = {
    121: 59,   # F1 (mute)      -> KEY_F1
    114: 60,   # F2 (vol-)      -> KEY_F2
    115: 61,   # F3 (vol+)      -> KEY_F3
}
SUPER_TRANSLATE_ABS = {
    199: 62,   # F4 (luz kbd)   -> KEY_F4
    16:  63,   # F5 (br-)       -> KEY_F5
    32:  64,   # F6 (br+)       -> KEY_F6
    124: 67,   # F9 (mic)       -> KEY_F9
}
SENDKEY_BIN = "/usr/local/bin/zenbook-sendkey"

F12_CODE = 88
F12_MAX_GAP = 1.0        # segundos máximos entre pulsaciones consecutivas
F12_LOCKOUT = 1.5        # tras alternar, ignora F12 este tiempo (evita deshacer)
f12_presses = []         # timestamps de la ráfaga actual
f12_lockout_until = 0
ZENBOOK_NODES = set()    # nodos event del teclado desacoplable
FNLOCK_MODE_FILE = "/etc/zenbook-duo/fnlock-mode"

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
    # Fallback robusto: loginctl (Wayland no siempre aparece en `who`)
    try:
        out = subprocess.run(["loginctl", "list-sessions", "--no-legend"],
                             capture_output=True, text=True).stdout
        for line in out.splitlines():
            parts = line.split()
            if len(parts) < 3:
                continue
            sid, uid = parts[0], parts[1]
            stype = subprocess.run(["loginctl", "show-session", sid, "-p", "Type", "--value"],
                                   capture_output=True, text=True).stdout.strip()
            if stype in ("wayland", "x11"):
                return parts[2]
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
    """Event nodes del teclado desacoplable + teclado integrado (para combos)."""
    nodes = []
    wanted = (DEVICE_NAME, BUILTIN_KEYBOARD_NAME)
    for name_file in glob.glob("/sys/class/input/input*/name"):
        try:
            name = open(name_file).read()
            if not any(w in name for w in wanted):
                continue
            inp_dir = os.path.dirname(name_file)
            for ev in glob.glob(f"{inp_dir}/event*"):
                dev = f"/dev/input/{os.path.basename(ev)}"
                if os.access(dev, os.R_OK):
                    nodes.append(dev)
        except OSError:
            continue
    return sorted(set(nodes))


def fnlock_toggle_action():
    global _super_down
    _super_down = False   # consumir el combo
    subprocess.Popen(["/usr/local/bin/fnlock-toggle.sh"])
    log("  toggle F1-F12/Multimedia")


def f12_press():
    """Triple pulsación de F12 = alternar modo de la fila."""
    global f12_presses, f12_lockout_until
    now = time.time()
    if now < f12_lockout_until:
        return   # lockout: las pulsaciones sobrantes no deshacen el cambio
    # Si la última pulsación es demasiado antigua, reiniciar ráfaga
    if f12_presses and now - f12_presses[-1] > F12_MAX_GAP:
        f12_presses = []
    f12_presses.append(now)
    log(f"F12 pulsación {len(f12_presses)}")
    if len(f12_presses) >= 3:
        gap_ok = (f12_presses[-1] - f12_presses[0]) <= (F12_MAX_GAP * 2)
        f12_presses = []
        if gap_ok:
            fnlock_toggle_action()
            f12_lockout_until = time.time() + F12_LOCKOUT
            log(f"  lockout F12 hasta +{F12_LOCKOUT}s")
        else:
            log("  ráfaga demasiado lenta, ignorada")


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
    # Feedback visual: consulta el estado resultante y notifica
    time.sleep(0.3)
    r = subprocess.run(
        ["sudo", "-u", find_session_user() or "jim",
         "wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"],
        capture_output=True, text=True,
        env={**os.environ,
             "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
             "XDG_RUNTIME_DIR": "/run/user/1000"})
    state = "silenciado" if "MUTED" in r.stdout else "activo"
    run_as_session_user(
        f"notify-send -t 1200 -a 'Zenbook Duo' 'Micrófono: {state}'")
    log(f"  mic {state}")


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


def send_fkey(code):
    r = subprocess.run([SENDKEY_BIN, str(code)], capture_output=True, text=True)
    log(f"  Super+fila -> KEY code {code} " + ("ok" if r.returncode == 0 else f"ERROR {r.stderr.strip()}"))


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


def current_fnlock_mode():
    """0 = multimedia, 1 = función. Default 0."""
    try:
        m = open(FNLOCK_MODE_FILE).read().strip()
        return m if m in ("0", "1") else "0"
    except OSError:
        return "0"


def parse_line(line, node):
    global _super_down
    zenbook_node = node in ZENBOOK_NODES

    # Tracking de Super (cualquier teclado)
    if "EV_KEY" in line and ("code 125 (" in line or "code 126 (" in line):
        _super_down = ("value 1" in line)

    # Teclas multimedia (USB/BT): eventos ABS_MISC del fabricante
    if zenbook_node and "ABS_MISC" in line and "value" in line:
        try:
            value = int(line.split("value")[1].strip())
        except ValueError:
            return
        if value > 0:
            if _super_down and value in SUPER_TRANSLATE_ABS:
                log(f"Super+ABS_MISC {value} -> F{SUPER_TRANSLATE_ABS[value] - 58}")
                send_fkey(SUPER_TRANSLATE_ABS[value])
                return
            if value in KEYCODE_MAP:
                key = KEYCODE_MAP[value]
                if current_fnlock_mode() == "1":
                    log(f"ABS_MISC {value} ignorado (modo función)")
                else:
                    log(f"ABS_MISC {value} -> {key}")
                    execute(key)
        return

    # Fila de función: EV_KEY estándar en pulsación (solo teclado desacoplable)
    if zenbook_node and "EV_KEY" in line and "value 1" in line:
        for tcode, fkey in SUPER_TRANSLATE_EVKEY.items():
            if _super_down and f"code {tcode} (" in line:
                log(f"Super+EV_KEY {tcode} -> F{fkey - 58}")
                send_fkey(fkey)
                return
        if f"code {F12_CODE} (" in line:
            f12_press()
            return
        for code, action in EVKEY_MAP.items():
            if f"code {code} (" in line:
                log(f"EV_KEY {code} -> {action}")
                execute(action)
                return


def apply_saved_fnlock():
    """Reaplica el modo Fn guardado al (re)conectar el teclado."""
    try:
        mode = open(FNLOCK_MODE_FILE).read().strip()
        if mode in ("0", "1"):
            r = subprocess.run(["/usr/local/bin/fn-lock.py", mode],
                               capture_output=True, text=True, timeout=10)
            log(f"  fnlock-mode={mode} reaplicado ({r.stdout.strip() or r.stderr.strip()})")
    except FileNotFoundError:
        pass
    except Exception as e:
        log(f"  ERROR aplicando fnlock: {e}")


def main():
    if os.geteuid() != 0 and not os.access("/dev/input/event0", os.R_OK):
        log("AVISO: sin acceso a /dev/input (¿grupo input?)")

    procs = {}   # Popen -> node
    last_scan = 0
    known_nodes = set()
    apply_saved_fnlock()          # modo Fn guardado al arrancar el servicio

    while True:
        # Re-escaneo: cuando no hay procesos o venció el intervalo
        now = time.time()
        alive_nodes = {n for n, p in procs.items() if p.poll() is None}
        if not procs or (not alive_nodes and now - last_scan >= IDLE_RESCAN) \
           or (now - last_scan >= RESCAN_EVERY and len(procs) < 8):
            nodes = [n for n in find_event_nodes() if n not in alive_nodes]
            new_nodes = [n for n in nodes if n not in known_nodes]
            if known_nodes and new_nodes:
                # Aparecieron nodos nuevos = teclado (re)conectado
                log("Teclado conectado: reaplicando modo Fn guardado")
                apply_saved_fnlock()
            for node in nodes:
                try:
                    p = subprocess.Popen(["evtest", node],
                                         stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL,
                                         text=True)
                    procs[node] = p
                    known_nodes.add(node)
                    nf = f"/sys/class/input/{node.split('/')[-1].replace('event','input')}/name"
                    try:
                        if DEVICE_NAME in open(nf).read():
                            ZENBOOK_NODES.add(node)
                    except OSError:
                        pass
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
