#!/usr/bin/env python3
"""Passive desktop right-click watcher for the i3 rice.

Replaces xbindkeys (`b:3`): xbindkeys uses XGrabButton with GrabModeAsync
and never replays the pointer event, which globally swallows every
right-click across all applications (Burp Suite, Firefox, terminals, ...).

Instead, this daemon listens to XInput2 XI_RawButtonPress on the root
window -- a 100% passive notification with NO X11 grab, so applications
always receive button-3 events directly and untouched. Only when the
pointer is directly over bare desktop background (root.query_pointer().child
== 0) does it launch ~/.config/i3/desktop-menu.sh.

Single-instance per DISPLAY via flock (same pattern as clipd.py / alt-tab.py).
"""
import fcntl
import os
import select
import signal
import struct
import subprocess
import sys

from Xlib import X, display
from Xlib.ext import xinput

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "rice")
MENU_SCRIPT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "desktop-menu.sh")


def acquire_lock():
    os.makedirs(CACHE_DIR, exist_ok=True)
    disp = os.environ.get("DISPLAY", ":0")
    safe = "".join(c if c.isalnum() else "_" for c in disp)
    lock_path = os.path.join(CACHE_DIR, f"desktop-menu-{safe}.lock")
    fp = open(lock_path, "w", encoding="utf-8")
    try:
        fcntl.flock(fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)
    fp.write(f"{os.getpid()}\n")
    fp.flush()
    return fp


def rofi_running():
    res = subprocess.run(
        ["pgrep", "-u", str(os.getuid()), "-x", "rofi"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return res.returncode == 0


def main():
    _lock_fp = acquire_lock()

    dpy = display.Display()
    if not dpy.has_extension("XInputExtension"):
        sys.exit(1)
    dpy.xinput_query_version()

    root = dpy.screen().root
    root.xinput_select_events([(xinput.AllMasterDevices, xinput.RawButtonPressMask)])
    dpy.flush()

    stop = False

    def on_stop(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, on_stop)
    signal.signal(signal.SIGINT, on_stop)

    xfd = dpy.fileno()
    while not stop:
        try:
            r, _, _ = select.select([xfd], [], [], 1.0)
        except InterruptedError:
            continue
        if not r:
            continue
        try:
            while dpy.pending_events():
                ev = dpy.next_event()
                if ev.type != dpy.extension_event.GenericEvent:
                    continue
                if ev.evtype != xinput.RawButtonPress:
                    continue
                if isinstance(ev.data, (bytes, bytearray)) and len(ev.data) >= 10:
                    detail = struct.unpack_from("<HII", ev.data, 0)[2]
                elif isinstance(ev.data, dict):
                    detail = ev.data.get("detail")
                else:
                    detail = getattr(ev.data, "detail", None)
                if detail != 3:
                    continue
                qp = root.query_pointer()
                if qp.child != 0:
                    continue
                if rofi_running():
                    continue
                subprocess.Popen(
                    ["bash", MENU_SCRIPT],
                    cwd=HOME,
                    start_new_session=True,
                    close_fds=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
        except Exception:
            break

    try:
        dpy.close()
    except Exception:
        pass


if __name__ == "__main__":
    main()
