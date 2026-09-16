#!/usr/bin/env bash
# Sets the i3 session wallpaper from ~/.config/rice/theme.conf (WALLPAPER=...).
# Change the WALLPAPER path in theme.conf, no need to touch this script.
source "$HOME/.config/rice/theme.conf"

set_bg() {
    if [ -f "$WALLPAPER" ]; then
        feh --bg-fill "$WALLPAPER"
    else
        feh --bg-fill /usr/share/backgrounds/kali/kali-tiles-16x9.jpg
    fi
}

# Run once immediately (avoids a long blank period at login), then again
# after a short delay. On this VM, feh run too early at i3 startup (right
# as glamor/DRI is still finishing initialization -- worse since 3D
# acceleration was enabled) has been observed to only paint PART of the
# screen (bottom ~140px stayed black). Re-running once the session has
# settled reliably fixes it, and is more robust than guessing a fixed
# startup delay.
set_bg
( sleep 2; set_bg ) &
