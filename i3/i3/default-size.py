#!/usr/bin/env python3
"""Makes new floating windows map already filling the usable screen area
below the top polybar bar -- the same geometry ~/.config/i3/maximize-toggle.py's
"maximize" toggles a window to -- instead of the small fixed-size window
the old `for_window` default used to set. This is deliberately NOT i3's
own `fullscreen toggle` ($mod+f), which covers the top bar too; that stays
a separate, more-than-this state.

The old default (1400x900, centered) is kept as the "restore" size: it's
written into maximize-toggle.py's own state file as if the window had just
been maximized from that size, so pressing F11/$mod+m on a freshly-opened
window shrinks it back down to a normal size instead of being a no-op.

Run persistently (started via exec_always, like alt-tab.py's daemon mode,
so it also survives an i3 reload/restart -- see the flock guard in main()
below) -- subscribes to window::new and acts once per new floating window.
Relies on i3 having already applied the config's `for_window floating
enable` rules by the time this IPC event fires (it runs as part of mapping
the window, before i3 notifies subscribers).
"""
import fcntl
import i3ipc
import json
import os
import sys

from reserved_area import maximized_rect

STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")
LOCK_FILE = os.path.expanduser("~/.cache/i3-default-size-daemon.lock")
NORMAL_W, NORMAL_H = 1920, 1080  # the toggle's "restore" size (1920x1080)



def on_new_window(i3, event):
    # event.container is a detached snapshot (not linked into the live
    # tree), so .workspace()/.parent walks on it come back None -- look the
    # same window up in a freshly fetched tree instead, same as
    # maximize-toggle.py does via tree.find_focused().
    event_win = event.container
    if event_win.window is None or not event_win.floating or "on" not in (event_win.floating or ""):
        return

    win = i3.get_tree().find_by_id(event_win.id)
    if win is None:
        return
    if getattr(win, "window_role", None) == "pop-up" or getattr(win, "window_class", None) == "RiceAudioPopup":
        return
    ws = win.workspace()
    if ws is None:
        return
    out_rect = None
    for o in i3.get_outputs():
        if o.name == ws.ipc_data.get("output"):
            out_rect = o.rect
            break
    if out_rect is None:
        return

    max_x, max_y, max_w, max_h = maximized_rect(out_rect)

    normal_x = out_rect.x + (out_rect.width - NORMAL_W) // 2
    normal_y = out_rect.y + (out_rect.height - NORMAL_H) // 2

    state = {}
    if os.path.exists(STATE_FILE):
        try:
            state = json.load(open(STATE_FILE))
        except Exception:
            state = {}
    state[str(win.window)] = {
        "x": normal_x, "y": normal_y, "width": NORMAL_W, "height": NORMAL_H,
    }
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

    i3.command(f'[id={win.window}] move position {max_x} {max_y}')
    i3.command(f'[id={win.window}] resize set {max_w} {max_h}')


def main():
    # Single-instance guard (same pattern as clipd.py/alt-tab.py): started
    # via exec_always, so i3 re-runs this line on every reload/restart, not
    # just the first startup -- without this, each one would stack another
    # daemon on top instead of replacing it.
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)  # another instance is already running -- quietly exit

    i3 = i3ipc.Connection()
    i3.on("window::new", on_new_window)
    i3.main()


if __name__ == "__main__":
    main()
