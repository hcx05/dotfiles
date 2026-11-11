#!/usr/bin/env python3
"""Toggle between maximized (filling usable area below top bar / dock, NOT
fullscreen) and 1920x1080 centered for the focused window.
Works even if the window was in tiled mode (automatically enables floating).
Bound to Super+Shift+m (and Super+m / F11).
"""
import json
import os

import i3ipc
from reserved_area import maximized_rect

STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")
NORMAL_W, NORMAL_H = 1920, 1080


def main():
    i3 = i3ipc.Connection()
    tree = i3.get_tree()
    win = tree.find_focused()
    if win is None or win.window is None:
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

    # Center the 1920x1080 window within the usable area (clamped if screen is smaller)
    shrunk_w = min(NORMAL_W, max_w)
    shrunk_h = min(NORMAL_H, max_h)
    shrunk_x = max_x + (max_w - shrunk_w) // 2
    shrunk_y = max_y + (max_h - shrunk_h) // 2

    state = {}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE) as f:
                state = json.load(f)
        except Exception:
            state = {}

    wid = str(win.window)
    is_maximized = (
        abs(win.rect.width - max_w) <= 24 and abs(win.rect.height - max_h) <= 24
    )

    if is_maximized:
        # Currently maximized (or single-tiled full area) -> shrink to 1920x1080 centered
        state.pop(wid, None)
        i3.command(
            f"[id={win.window}] floating enable, "
            f"resize set {shrunk_w} px {shrunk_h} px, "
            f"move position {shrunk_x} px {shrunk_y} px"
        )
    else:
        # Currently 1920x1080 (or smaller) -> maximize to usable area below top bar
        state[wid] = {
            "x": shrunk_x,
            "y": shrunk_y,
            "width": shrunk_w,
            "height": shrunk_h,
        }
        i3.command(
            f"[id={win.window}] floating enable, "
            f"resize set {max_w} px {max_h} px, "
            f"move position {max_x} px {max_y} px"
        )

    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


if __name__ == "__main__":
    main()
