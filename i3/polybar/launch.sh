#!/usr/bin/env bash
# Kills any running polybar and (re)launches the top bar on every connected
# monitor -- mainbar for the classic layout (purple/green), monobar for the
# "dock" layout (mono, theme.conf LAYOUT="dock"). Also (re)starts or stops
# the right-side app dock to match, since this is the one script i3 re-runs
# (exec_always) on every reload -- including the reload switch-theme.sh does.

source "$HOME/.config/rice/theme.conf" 2>/dev/null
BAR=mainbar
[ "${LAYOUT:-classic}" = "dock" ] && BAR=monobar

# Re-send the kill on every wait iteration, not just once: when this runs
# from switch-theme.sh, apply-theme.sh has just rewritten colors.ini/
# layout.ini, so each `polybar --reload` bar is re-exec'ing itself in place
# (same PID) right as the first killall lands -- that SIGTERM gets dropped,
# the bar comes back up, and a one-shot killall left this loop waiting
# forever (reproduced with i3 4.23 / polybar 3.7.1).
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; killall -q polybar; done

if type "xrandr" >/dev/null 2>&1; then
    for m in $(polybar --list-monitors | cut -d: -f1); do
        MONITOR=$m polybar --reload "$BAR" -c ~/.config/polybar/config.ini &
    done
else
    polybar --reload "$BAR" -c ~/.config/polybar/config.ini &
fi

DOCK="$HOME/.config/rice/dock/dock.py"
# only python3 processes -- not a shell/grep that merely mentions dock.py
dock_pids() {
    for p in $(pgrep -u "$UID" -f "python3 $DOCK"); do
        case "$(cat "/proc/$p/comm" 2>/dev/null)" in python3*) echo "$p" ;; esac
    done
}
pids=$(dock_pids)
[ -n "$pids" ] && kill $pids 2>/dev/null
for _ in $(seq 1 20); do
    [ -z "$(dock_pids)" ] && break
    sleep 0.1
done
if [ "${LAYOUT:-classic}" = "dock" ]; then
    setsid nohup python3 "$DOCK" >/tmp/rice-dock.log 2>&1 < /dev/null &
fi
