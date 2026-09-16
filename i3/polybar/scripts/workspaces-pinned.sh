#!/usr/bin/env bash
# Prints 4 pinned, always-visible, independently-clickable workspace
# buttons (1-4) for polybar, using %{A...} action blocks so each number
# has its own click target regardless of whether i3 currently has that
# workspace instantiated.
#
# Why this exists instead of just using polybar's internal/i3 module:
# i3 auto-destroys a workspace once it has no windows and loses focus
# (verified: switching 1->2->3->4->1 with no windows open leaves only
# "1" in `i3-msg -t get_workspaces`). internal/i3 mirrors that live list,
# so empty workspaces vanish from the bar. This script decouples the
# buttons from i3's actual workspace list so 1-4 always show.

source "$HOME/.config/rice/theme.conf"

render() {
    local current
    current=$(i3-msg -t get_workspaces 2>/dev/null | python3 -c "
import json, sys
try:
    ws = json.load(sys.stdin)
    print([w['name'] for w in ws if w['focused']][0])
except Exception:
    print('')
")
    local out=""
    for n in 1 2 3 4; do
        if [ "$n" = "$current" ]; then
            out+="%{A1:i3-msg workspace number $n:}%{B${ACCENT}}%{F${BACKGROUND}}  ${n}  %{F-}%{B-}%{A} "
        else
            out+="%{A1:i3-msg workspace number $n:}%{B${BACKGROUND_ALT}}%{F${FOREGROUND_ALT}}  ${n}  %{F-}%{B-}%{A} "
        fi
    done
    echo "$out"
}

render
i3-msg -t subscribe -m '["workspace"]' 2>/dev/null | while read -r _line; do
    render
done
