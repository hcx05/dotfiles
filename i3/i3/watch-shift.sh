#!/usr/bin/env bash
# Diagnostic watcher for the "terminal jumps up by one bar-height" bug.
# Polls window geometry, screen resolution, and polybar's PID every 2s;
# only logs a line when any of those actually CHANGE, so the log stays
# small even run for hours. Run in background, then when the glitch is
# next seen, check the tail of the log for what changed right before it.
#
# Usage:
#   nohup ~/.config/i3/watch-shift.sh > ~/.cache/shift-watch.log 2>&1 &
# Stop it with:
#   pkill -f watch-shift.sh

WIN="${1:-}"
if [ -z "$WIN" ]; then
    WIN=$(xdotool getactivewindow 2>/dev/null)
fi
echo "watching window id=$WIN (pass a different id as \$1 to track another window)"

last=""
while true; do
    geo=$(xdotool getwindowgeometry --shell "$WIN" 2>/dev/null | tr '\n' ' ')
    res=$(xrandr --current 2>/dev/null | grep -oP '(?<=current )[0-9]+ x [0-9]+')
    pbar=$(pgrep -x polybar | tr '\n' ',')
    line="$(date '+%H:%M:%S.%3N') geo=[$geo] res=[$res] polybar_pid=[$pbar]"
    if [ "$geo$res$pbar" != "$last" ]; then
        echo "$line"
        last="$geo$res$pbar"
    fi
    sleep 1
done
