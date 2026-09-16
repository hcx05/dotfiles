#!/usr/bin/env bash
# Kills any running polybar and (re)launches mainbar (top) + taskbar
# (bottom) on every connected monitor.

killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done

if type "xrandr" >/dev/null 2>&1; then
    for m in $(polybar --list-monitors | cut -d: -f1); do
        MONITOR=$m polybar --reload mainbar -c ~/.config/polybar/config.ini &
        MONITOR=$m polybar --reload taskbar -c ~/.config/polybar/config.ini &
    done
else
    polybar --reload mainbar -c ~/.config/polybar/config.ini &
    polybar --reload taskbar -c ~/.config/polybar/config.ini &
fi
