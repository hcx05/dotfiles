#!/usr/bin/env python3
"""Toggle-maximize for the focused FLOATING window -- fills the usable
screen area below the top polybar bar, WITHOUT covering it (unlike i3's
`fullscreen toggle`, which covers the whole output including that bar).
Press again to restore the previous size and position.

The strips to keep clear (top bar; plus the right-side dock in the mono
theme's "dock" layout) come from reserved_area.py, which reads them from
the active theme's generated ~/.config/rice/layout.json -- so this doesn't
silently drift out of sync if the bar/dock change later. There is no
bottom bar to avoid (the taskbar bar was removed), so the window fills
all the way down to the screen edge.
"""
import i3ipc
import json
import os

from reserved_area import maximized_rect

STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")



def main():
    i3 = i3ipc.Connection()
    tree = i3.get_tree()
    win = tree.find_focused()
    if win is None or not win.floating or "on" not in (win.floating or ""):
        # not a floating window -- nothing sensible to do
        return

    state = {}
    if os.path.exists(STATE_FILE):
        try:
            state = json.load(open(STATE_FILE))
        except Exception:
            state = {}

    wid = str(win.window)
    output = win.workspace().ipc_data if win.workspace() else None
    # find the output rect via the containing workspace's output
    ws = win.workspace()
    out_rect = None
    for o in i3.get_outputs():
        if o.name == ws.ipc_data.get("output"):
            out_rect = o.rect
            break
    if out_rect is None:
        return

    if wid in state:
        # restore
        r = state.pop(wid)
        i3.command(f'[id={win.window}] move position {r["x"]} {r["y"]}')
        i3.command(f'[id={win.window}] resize set {r["width"]} {r["height"]}')
    else:
        # save current geometry, then fill between the bars
        state[wid] = {
            "x": win.rect.x,
            "y": win.rect.y,
            "width": win.rect.width,
            "height": win.rect.height,
        }
        new_x, new_y, new_w, new_h = maximized_rect(out_rect)
        i3.command(f'[id={win.window}] move position {new_x} {new_y}')
        i3.command(f'[id={win.window}] resize set {new_w} {new_h}')

    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


if __name__ == "__main__":
    main()
