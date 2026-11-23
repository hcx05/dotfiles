#!/usr/bin/env python3
"""Minimal XSETTINGS manager for the rice autoscale system.

Publishes Xft/DPI, cursor size, and the user's GTK settings (from
~/.config/gtk-3.0/settings.ini) on the X11 _XSETTINGS_S0 selection so
toolkits that ignore xrdb's Xft.dpi -- notably Chromium / Electron apps
(Chromium, Obsidian, VS Code) and GTK's live-update path -- follow
autoscale cleanly and update on the fly when the screen changes.

Gdk/WindowScalingFactor is deliberately kept at 1 so GTK apps (including
rice's own dock.py, which scales its pixel CSS directly from layout.json)
do not double-scale, while Xft/DPI carries the exact fractional scale.

Signals:
  SIGUSR1 / SIGHUP  re-read ~/.cache/rice/scale.env, scale.conf, and
                    gtk-3.0/settings.ini, then republish with a bumped serial.
  SIGTERM / SIGINT  exit cleanly.

Single-instance per DISPLAY via flock (same pattern as autoscale watch).
"""
import configparser
import fcntl
import os
import select
import signal
import struct
import sys

from Xlib import X, display, protocol

XSETTINGS_TYPE_INTEGER = 0
XSETTINGS_TYPE_STRING = 1

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "rice")
STATE_FILE = os.path.join(CACHE_DIR, "scale.env")
SCALE_CONF = os.path.join(os.path.dirname(os.path.realpath(__file__)), "scale.conf")
GTK3_INI = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "gtk-3.0", "settings.ini")


def parse_kv_file(path):
    out = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                v = v.split("#", 1)[0].strip().strip('"').strip("'")
                out[k.strip()] = v
    except OSError:
        pass
    return out


def read_gtk3_settings():
    cfg = configparser.ConfigParser(interpolation=None)
    try:
        cfg.read(GTK3_INI, encoding="utf-8")
    except (OSError, configparser.Error):
        return {}
    if not cfg.has_section("Settings"):
        return {}
    return dict(cfg.items("Settings"))


def build_settings():
    state = parse_kv_file(STATE_FILE)
    conf = parse_kv_file(SCALE_CONF)
    gtk = read_gtk3_settings()

    try:
        dpi = int(float(state.get("RICE_DPI", "96")))
    except ValueError:
        dpi = 96
    try:
        scale = float(state.get("RICE_SCALE", "1"))
    except ValueError:
        scale = 1.0
    try:
        base_cursor = float(conf.get("CURSOR_SIZE", "24"))
    except ValueError:
        base_cursor = 24.0

    cursor_size = max(1, int(base_cursor * scale + 0.5))
    xft_dpi = dpi * 1024

    def gtk_int(key, default):
        try:
            return int(gtk.get(key, default))
        except ValueError:
            return default

    settings = {
        "Gdk/UnscaledDPI": xft_dpi,
        "Gdk/WindowScalingFactor": 1,
        "Gtk/CursorThemeSize": cursor_size,
        "Xft/Antialias": gtk_int("gtk-xft-antialias", 1),
        "Xft/DPI": xft_dpi,
        "Xft/HintStyle": gtk.get("gtk-xft-hintstyle", "hintslight"),
        "Xft/Hinting": gtk_int("gtk-xft-hinting", 1),
        "Xft/RGBA": gtk.get("gtk-xft-rgba", "rgb"),
    }

    passthrough_strings = (
        ("gtk-theme-name", "Net/ThemeName"),
        ("gtk-icon-theme-name", "Net/IconThemeName"),
        ("gtk-font-name", "Gtk/FontName"),
        ("gtk-cursor-theme-name", "Gtk/CursorThemeName"),
    )
    for gtk_key, xs_key in passthrough_strings:
        val = gtk.get(gtk_key, "").strip()
        if val:
            settings[xs_key] = val

    return settings


def encode_xsettings(settings, serial):
    # XSETTINGS 0.5 wire format (little-endian):
    #   byte_order (0 = LSBFirst), pad[3], serial (CARD32), n_settings (CARD32)
    items = sorted(settings.items())
    buf = bytearray(struct.pack("<B3xII", 0, serial, len(items)))
    for name, val in items:
        name_b = name.encode("utf-8")
        name_pad = (4 - (len(name_b) % 4)) % 4
        if isinstance(val, int):
            buf += struct.pack("<BxH", XSETTINGS_TYPE_INTEGER, len(name_b))
            buf += name_b + (b"\x00" * name_pad)
            buf += struct.pack("<Ii", serial, val)
        else:
            val_b = str(val).encode("utf-8")
            val_pad = (4 - (len(val_b) % 4)) % 4
            buf += struct.pack("<BxH", XSETTINGS_TYPE_STRING, len(name_b))
            buf += name_b + (b"\x00" * name_pad)
            buf += struct.pack("<II", serial, len(val_b))
            buf += val_b + (b"\x00" * val_pad)
    return bytes(buf)


def acquire_lock():
    os.makedirs(CACHE_DIR, exist_ok=True)
    disp = os.environ.get("DISPLAY", ":0")
    safe = "".join(c if c.isalnum() else "_" for c in disp)
    lock_path = os.path.join(CACHE_DIR, f"xsettingsd-{safe}.lock")
    fp = open(lock_path, "w", encoding="utf-8")
    try:
        fcntl.flock(fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)
    fp.write(f"{os.getpid()}\n")
    fp.flush()
    return fp


def main():
    _lock_fp = acquire_lock()

    dpy = display.Display()
    screen = dpy.screen()
    root = screen.root
    screen_num = dpy.get_default_screen()

    sel_atom = dpy.intern_atom(f"_XSETTINGS_S{screen_num}")
    prop_atom = dpy.intern_atom("_XSETTINGS_SETTINGS")
    manager_atom = dpy.intern_atom("MANAGER")

    win = root.create_window(0, 0, 1, 1, 0, X.CopyFromParent)
    serial = 1

    def publish():
        nonlocal serial
        data = encode_xsettings(build_settings(), serial)
        win.change_property(prop_atom, prop_atom, 8, data)
        dpy.flush()
        serial += 1

    publish()
    win.set_selection_owner(sel_atom, X.CurrentTime)
    if dpy.get_selection_owner(sel_atom) != win:
        sys.exit(1)

    # Announce MANAGER ownership to root so interested clients re-query.
    ev = protocol.event.ClientMessage(
        window=root,
        client_type=manager_atom,
        data=(32, [X.CurrentTime, sel_atom, win.id, 0, 0]),
    )
    root.send_event(ev, event_mask=X.StructureNotifyMask)
    dpy.flush()

    reload_flag = False
    stop_flag = False

    def on_reload(_signum, _frame):
        nonlocal reload_flag
        reload_flag = True

    def on_stop(_signum, _frame):
        nonlocal stop_flag
        stop_flag = True

    signal.signal(signal.SIGUSR1, on_reload)
    signal.signal(signal.SIGHUP, on_reload)
    signal.signal(signal.SIGTERM, on_stop)
    signal.signal(signal.SIGINT, on_stop)

    xfd = dpy.fileno()
    while not stop_flag:
        if reload_flag:
            reload_flag = False
            publish()
        try:
            r, _, _ = select.select([xfd], [], [], 1.0)
        except InterruptedError:
            continue
        if r:
            try:
                while dpy.pending_events():
                    ev = dpy.next_event()
                    if ev.type == X.SelectionClear and ev.atom == sel_atom:
                        stop_flag = True
                        break
            except Exception:
                break

    try:
        win.destroy()
        dpy.close()
    except Exception:
        pass


if __name__ == "__main__":
    main()
