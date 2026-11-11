#!/usr/bin/env bash
# Launches (or toggles closed) the themed GTK3 Audio Control slider popup.

set -u

if pgrep -f "audio-popup.py" >/dev/null 2>&1; then
    pkill -f "audio-popup.py"
    exit 0
fi

exec python3 "$HOME/.config/polybar/scripts/audio-popup.py"
