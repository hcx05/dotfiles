#!/usr/bin/env bash
# Toggles ibus between English (xkb) and the first non-xkb engine in your
# preload-engines list (e.g. chewing/pinyin). Bound to $mod+space in i3
# because ibus's own global hotkey grab is unreliable under bare i3 (no
# full desktop shell managing the IBus panel) -- this calls the ibus D-Bus
# API directly instead, which is reliable.

CURRENT=$(ibus engine 2>/dev/null)

# first engine in preload-engines that isn't an xkb:* one
CJK_ENGINE=$(gsettings get org.freedesktop.ibus.general preload-engines 2>/dev/null \
    | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//' | grep -v '^xkb:' | head -1)

if [ -z "$CJK_ENGINE" ]; then
    notify-send -a "ibus" "No CJK engine configured" "Check ibus-setup preload engines"
    exit 1
fi

if [ "$CURRENT" = "$CJK_ENGINE" ]; then
    ibus engine xkb:us::eng
else
    ibus engine "$CJK_ENGINE"
fi
