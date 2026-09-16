#!/usr/bin/env python3
"""Toggle-maximize for the focused FLOATING window -- fills the usable
screen area between the top polybar bar and the bottom taskbar, WITHOUT
covering either (unlike i3's `fullscreen toggle`, which covers the whole
output including both bars). Press again to restore the previous size and
position.

Bar heights are read from ~/.config/polybar/config.ini (top bar's `height`
under [bar/mainbar], bottom bar's under [bar/taskbar]) so this doesn't
silently drift out of sync if those change later.
"""
import i3ipc
import json
import os
import re

STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")
POLYBAR_CONF = os.path.expanduser("~/.config/polybar/config.ini")
MARGIN = 4  # matches theme's gaps outer, purely aesthetic


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

    top = bar_height("bar/mainbar")
    bottom = bar_height("bar/taskbar")

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
        new_x = out_rect.x + MARGIN
        new_y = out_rect.y + top + MARGIN
        new_w = out_rect.width - 2 * MARGIN
        new_h = out_rect.height - top - bottom - 2 * MARGIN
        i3.command(f'[id={win.window}] move position {new_x} {new_y}')
        i3.command(f'[id={win.window}] resize set {new_w} {new_h}')

    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


if __name__ == "__main__":
    main()
