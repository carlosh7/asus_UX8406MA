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

# ABS_MISC value -> función
KEYCODE_MAP = {
    199: "kbd_light",
    16:  "br_down",
    32:  "br_up",
    124: "mic_mute",
}

BACKLIGHT = "/sys/class/backlight/intel_backlight"


def log(msg):
    print(msg, flush=True)


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
    """Paso de brillo de pantalla vía sysfs (sudoers: tee NOPASSWD)."""
    try:
        cur = int(open(f"{BACKLIGHT}/brightness").read())
        mx = int(open(f"{BACKLIGHT}/max_brightness").read())
        step = max(mx // 10, 1)
        target = min(mx, max(1, cur + direction * step))
        r = subprocess.run(
            ["sudo", "-n", "tee", f"{BACKLIGHT}/brightness"],
            input=f"{target}\n", capture_output=True, text=True)
        if r.returncode == 0:
            log(f"  brillo -> {target}/{mx}")
        else:
            log(f"  ERROR brillo: {r.stderr.strip()}")
    except Exception as e:
        log(f"  ERROR brillo: {e}")


def mic_mute_toggle():
    r = subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"],
                       capture_output=True, text=True)
    log("  mic toggle " + "ok" if r.returncode == 0 else f"  ERROR mic: {r.stderr.strip()}")


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


def parse_line(line, proc_map):
    if "ABS_MISC" not in line or "value" not in line:
        return
    try:
        value = int(line.split("value")[1].strip())
    except ValueError:
        return
    if value > 0 and value in KEYCODE_MAP:
        key = KEYCODE_MAP[value]
        log(f"ABS_MISC {value} -> {key}")
        execute(key)


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
