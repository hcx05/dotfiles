#!/usr/bin/env python3
"""Re-snaps already-"maximized" floating windows (see default-size.py /
maximize-toggle.py) back to filling the usable area below the top polybar
bar whenever i3 reports an output change.

Why this exists: resuming the VM from suspend makes the virtual display
re-probe its mode over RandR, even when the resulting resolution is
unchanged. i3 has its own built-in logic to keep floating windows within
the (possibly new) output bounds when that happens, but that built-in
logic knows nothing about polybar's reserved top strip -- it just clamps
to the raw output rect. Observed result: a floating terminal that was
sitting correctly below the bar ends up re-clamped to the top of the
screen (covering the bar), with a bar-height gap left at the bottom,
and nothing afterwards ever puts it back -- only window::new
(default-size.py) and the F11 toggle (maximize-toggle.py) ever apply the
"below the bar" geometry, and neither fires on an output event. Confirmed
by hand (dragging the window back down fixes it) -- this daemon automates
that drag.

Only touches windows i3-maximize-state.json already knows about -- i.e.
windows that are CURRENTLY in the "maximized below the bar" state (both
default-size.py and maximize-toggle.py's "maximize" branch record an
entry there while a window is in that state, keyed by X window ID, and
pop it on restore). Windows the user deliberately resized/moved to
something else are untouched, since the catch-all for_window-floating
default has nothing to do with this beyond making the window floating in
the first place.

Run persistently (started via exec_always, like alt-tab.py's daemon mode
-- see the flock guard in main() below) -- subscribes to i3's "output"
event. Debounced/retried a few times after firing: RandR can emit more
than one output event in a burst around a resume, and polybar's own
exec_always-triggered relaunch (~/.config/polybar/launch.sh) may still be
mid-restart at the first one -- harmless to re-apply the same geometry
more than once, so just retry instead of trying to land on the single
"right" moment.
"""
import fcntl
import i3ipc
import json
import os
import re
import sys
import threading
import time

STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")
POLYBAR_CONF = os.path.expanduser("~/.config/polybar/config.ini")
LOCK_FILE = os.path.expanduser("~/.cache/i3-fix-output-daemon.lock")
MARGIN = 4  # matches theme's gaps outer, same constant default-size.py/maximize-toggle.py use
RETRY_DELAYS = [0.3, 1.0, 2.0]  # seconds after an output event to re-apply


def bar_height(section):
    in_section = False
    with open(POLYBAR_CONF) as f:
        for line in f:
            line = line.strip()
            if line == f"[{section}]":
                in_section = True
                continue
            if in_section and line.startswith("["):
                break
            if in_section:
                m = re.match(r"^height\s*=\s*(\d+)", line)
                if m:
                    return int(m.group(1))
    return 30


def fix_maximized_windows(i3):
    if not os.path.exists(STATE_FILE):
        return
    try:
        state = json.load(open(STATE_FILE))
    except Exception:
        return
    if not state:
        return

    tree = i3.get_tree()
    outputs = i3.get_outputs()
    top = bar_height("bar/mainbar")
    bottom = 0  # no bottom bar to avoid anymore

    for wid_str in state:
        try:
            wid = int(wid_str)
        except ValueError:
            continue
        win = tree.find_by_id(wid) or next(
            (w for w in tree.leaves() if w.window == wid), None
        )
        if win is None or not win.floating or "on" not in (win.floating or ""):
            continue
        ws = win.workspace()
        if ws is None:
            continue
        out_rect = None
        for o in outputs:
            if o.name == ws.ipc_data.get("output"):
                out_rect = o.rect
                break
        if out_rect is None:
            continue

        max_x = out_rect.x + MARGIN
        max_y = out_rect.y + top + MARGIN
        max_w = out_rect.width - 2 * MARGIN
        max_h = out_rect.height - top - bottom - 2 * MARGIN

        i3.command(f'[id={win.window}] move position {max_x} {max_y}')
        i3.command(f'[id={win.window}] resize set {max_w} {max_h}')


_fixing = threading.Lock()


def _retry_fix(i3):
    # Runs off the ipc event thread (in a plain background thread, below)
    # so the few seconds of sleeping here don't stall i3ipc's event loop
    # and make it miss a second output event arriving in the same burst.
    if not _fixing.acquire(blocking=False):
        return  # a previous burst's retries are still in flight
    try:
        for delay in RETRY_DELAYS:
            time.sleep(delay)
            try:
                fix_maximized_windows(i3)
            except Exception:
                pass
    finally:
        _fixing.release()


def on_output(i3, _event):
    threading.Thread(target=_retry_fix, args=(i3,), daemon=True).start()


def main():
    # Single-instance guard (same pattern as clipd.py/alt-tab.py/
    # default-size.py): started via exec_always, so i3 re-runs this line on
    # every reload/restart, not just the first startup -- without this,
    # each one would stack another daemon on top instead of replacing it.
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)  # another instance is already running -- quietly exit

    i3 = i3ipc.Connection()
    i3.on("output", on_output)
    i3.main()


if __name__ == "__main__":
    main()
