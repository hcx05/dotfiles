#!/usr/bin/env bash
# Pinned, always-visible, independently-clickable workspace pill for polybar,
# styled after hcx05/ArchDotfiles (bar07 Pacman/Ghost/Dot workspace icons inside
# a rounded pill ...).
#   - Focused workspace:  󰮯 (0xF0BAF) in $ACCENT
#   - Urgent workspace:   󰊠 (0xF02A0) in $URGENT
#   - Occupied workspace: 󰊠 (0xF02A0) in $ACCENT_ALT
#   - Empty workspace:    󰑊 (0xF044A) in $FOREGROUND_ALT
# Subscribes to both "workspace" and "window" i3 events so opening/closing
# a window immediately updates occupied vs empty icons.

source "$HOME/.config/rice/theme.conf"

render() {
    python3 - "$BACKGROUND" "$BACKGROUND_ALT" "$FOREGROUND" "$FOREGROUND_ALT" "$ACCENT" "$ACCENT_ALT" "$URGENT" <<'PY'
import json, subprocess, sys

bg, bg_alt, fg, fg_alt, accent, accent_alt, urgent = sys.argv[1:8]

PILL_L = chr(0xE0B6)   # 
PILL_R = chr(0xE0B4)   # 
ICO_FOCUSED  = chr(0xF0BAF)  # 󰮯 Pacman
ICO_OCCUPIED = chr(0xF02A0)  # 󰊠 Ghost
ICO_EMPTY    = chr(0xF044A)  # 󰑊 Dot

focused_ws = "1"
occupied = set()
urgent_ws = set()

try:
    ws_list = json.loads(subprocess.check_output(["i3-msg", "-t", "get_workspaces"], stderr=subprocess.DEVNULL))
    for w in ws_list:
        name = str(w.get("name", ""))
        if w.get("focused"):
            focused_ws = name
        else:
            # In i3, an unfocused workspace only exists in get_workspaces if it has windows
            occupied.add(name)
        if w.get("urgent"):
            urgent_ws.add(name)
except Exception:
    pass

try:
    tree = json.loads(subprocess.check_output(["i3-msg", "-t", "get_tree"], stderr=subprocess.DEVNULL))
    def check_ws(node):
        if node.get("type") == "workspace":
            name = str(node.get("name", ""))
            if name and name != "__i3_scratch":
                has_win = False
                stack = list(node.get("nodes", [])) + list(node.get("floating_nodes", []))
                while stack:
                    cur = stack.pop()
                    if cur.get("window") is not None:
                        has_win = True
                        break
                    stack.extend(cur.get("nodes", []))
                    stack.extend(cur.get("floating_nodes", []))
                if has_win:
                    occupied.add(name)
            return
        for c in node.get("nodes", []):
            check_ws(c)
    check_ws(tree)
except Exception:
    pass

slots = ["1", "2", "3", "4", "5"]
for extra in sorted(occupied | {focused_ws}, key=lambda x: int(x) if x.isdigit() else 99):
    if extra not in slots and extra != "__i3_scratch":
        slots.append(extra)

parts = [f"%{{T4}}%{{F{bg_alt}}}{PILL_L}%{{F-}}%{{T-}}%{{B{bg_alt}}}"]
for n in slots:
    if n == focused_ws:
        color, ico = accent, ICO_FOCUSED
    elif n in urgent_ws:
        color, ico = urgent, ICO_OCCUPIED
    elif n in occupied:
        color, ico = accent_alt, ICO_OCCUPIED
    else:
        color, ico = fg_alt, ICO_EMPTY
    parts.append(f"%{{A1:i3-msg workspace number {n}:}}%{{T3}}%{{F{color}}} {ico} %{{F-}}%{{T-}}%{{A}}")
parts.append(f"%{{B-}}%{{T4}}%{{F{bg_alt}}}{PILL_R}%{{F-}}%{{T-}}")
print("".join(parts), flush=True)
PY
}

render
i3-msg -t subscribe -m '["workspace", "window"]' 2>/dev/null | while read -r _line; do
    render
done
