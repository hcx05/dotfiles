#!/usr/bin/env bash
# Scratchpad restore menu -- gh0stzk's "Show menu to restore hidden
# windows" (ctrl+alt+h), i3-flavored: $mod+Shift+minus/$mod+minus already
# minimize/cycle blindly through the scratchpad; this instead lists every
# window actually sitting in it by title, so you can jump straight to one
# instead of cycling past the others.
set -euo pipefail

mapfile -t ENTRIES < <(i3-msg -t get_tree | python3 -c '
import json, sys

tree = json.load(sys.stdin)
out = []

def first_name(n):
    """The scratchpad_state lives on the floating-container wrapper, whose
    own "name" is always None -- the actual window title is on a
    descendant leaf. Walk down to find it."""
    if n.get("name"):
        return n["name"]
    for c in n.get("nodes", []) + n.get("floating_nodes", []):
        found = first_name(c)
        if found:
            return found
    return None

def walk(n):
    if n.get("scratchpad_state", "none") != "none":
        name = first_name(n)
        if name:
            nid = n["id"]
            out.append(f"{nid}\t{name}")
    for c in n.get("nodes", []) + n.get("floating_nodes", []):
        walk(c)

walk(tree)
print("\n".join(out))
')

if [ "${#ENTRIES[@]}" -eq 0 ]; then
    notify-send "Scratchpad" "Nothing in the scratchpad" 2>/dev/null || true
    exit 0
fi

labels=()
ids=()
for entry in "${ENTRIES[@]}"; do
    ids+=("${entry%%$'\t'*}")
    labels+=("${entry#*$'\t'}")
done

selected=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -p "Scratchpad" \
    -config "$HOME/.config/rofi/config.rasi" \
    -theme-str 'window {width: 480px;}')

[ -z "$selected" ] && exit 0

for i in "${!labels[@]}"; do
    if [ "${labels[$i]}" = "$selected" ]; then
        i3-msg "[con_id=${ids[$i]}] scratchpad show" >/dev/null
        exit 0
    fi
done
