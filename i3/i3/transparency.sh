#!/usr/bin/env bash
# Per-window transparency adjust (Ctrl+Alt+Plus/Minus/t) -- reimplements
# the small slice of picom-trans's job needed here, rather than calling
# picom-trans itself: picom-trans's "-c"/"-w" active-window detection
# walks `xwininfo -root -tree` looking for a direct child of the root
# window, which is the right model under simpler WMs (openbox, bspwm) but
# NOT under i3 -- i3 reparents every client several container levels deep,
# so that heuristic silently resolves to the wrong (often invisible,
# 1x1) window and sets opacity on it instead. Verified live: picom-trans
# -c/-w both landed on an unrelated ibus helper window, never the actually
# focused one. i3's own IPC tree already knows the real X11 window id of
# the focused container directly -- no heuristic needed.
set -euo pipefail

ACTION="${1:-}"

WIN_ID=$(i3-msg -t get_tree | python3 -c '
import json, sys

tree = json.load(sys.stdin)

def find_focused(n):
    if n.get("focused"):
        return n
    for c in n.get("nodes", []) + n.get("floating_nodes", []):
        found = find_focused(c)
        if found:
            return found
    return None

node = find_focused(tree)
if node and node.get("window"):
    print(node["window"])
')

[ -z "$WIN_ID" ] && exit 0

case "$ACTION" in
    reset)
        xprop -id "$WIN_ID" -remove _NET_WM_WINDOW_OPACITY
        exit 0
        ;;
    inc) DELTA=5 ;;
    dec) DELTA=-5 ;;
    *) echo "usage: ${0##*/} inc|dec|reset" >&2; exit 1 ;;
esac

# _NET_WM_WINDOW_OPACITY is a uint32 fraction of 0xFFFFFFFF (0 = fully
# transparent, 0xFFFFFFFF = fully opaque / unset = same as fully opaque).
CUR_RAW=$(xprop -id "$WIN_ID" -notype -f _NET_WM_WINDOW_OPACITY 32c ' $0' _NET_WM_WINDOW_OPACITY 2>/dev/null \
    | awk '{print $NF}')
if [ -z "$CUR_RAW" ] || [ "$CUR_RAW" = "_NET_WM_WINDOW_OPACITY" ] || ! [[ "$CUR_RAW" =~ ^[0-9]+$ ]]; then
    CUR_PCT=100
else
    CUR_PCT=$(( (CUR_RAW * 100 + 2147483647) / 4294967295 ))
fi

NEW_PCT=$(( CUR_PCT + DELTA ))
[ "$NEW_PCT" -lt 10 ] && NEW_PCT=10   # never go fully invisible -- unrecoverable without this same key
[ "$NEW_PCT" -gt 100 ] && NEW_PCT=100

if [ "$NEW_PCT" -ge 100 ]; then
    xprop -id "$WIN_ID" -remove _NET_WM_WINDOW_OPACITY
else
    NEW_RAW=$(( NEW_PCT * 42949672 ))
    xprop -id "$WIN_ID" -f _NET_WM_WINDOW_OPACITY 32c -set _NET_WM_WINDOW_OPACITY "$NEW_RAW"
fi
