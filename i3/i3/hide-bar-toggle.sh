#!/usr/bin/env bash
# Hide/show the taskbar -- single toggle combining gh0stzk's separate
# "HideBar -h" / "HideBar -u" into one key ($mod+Shift+u), since i3 can
# just ask each piece whether it's currently visible instead of tracking
# hidden/shown as separate explicit actions. Hides/shows whichever top bar
# is actually running (mainbar or monobar, via polybar's own IPC) and the
# right-side app dock if the active bar style has one.
polybar-msg cmd toggle >/dev/null 2>&1 || true
pkill -USR1 -f "python3 .*/rice/dock/dock.py" 2>/dev/null || true
