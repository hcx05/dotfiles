#!/usr/bin/env bash
# Swap between the rice's color presets: purple.conf / green.conf.
# theme.conf is a symlink to whichever preset is "active"; this script
# repoints that symlink, regenerates every consumer via apply-theme.sh,
# and reloads/restarts the running WM pieces so it takes effect immediately.
set -euo pipefail

# Guard against overlapping runs (e.g. a double-click on the power-menu
# entry, or the menu action firing twice) -- without this, two invocations
# can each pkill-then-relaunch polybar/picom/dunst in an interleaved race,
# leaving two of everything running side by side (observed: both bars and
# the taskbar module duplicated after switching themes). A second
# invocation that can't get the lock just exits instead of racing.
LOCK_FILE="/tmp/switch-theme.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Another switch-theme.sh run is already in progress -- ignoring this one." >&2
    exit 0
fi
# IMPORTANT: every backgrounded daemon below closes fd 9 as an inline
# redirection on the command itself (`... 9>&- &`), NOT via a `( subshell )
# & disown` wrapper. Two reasons:
#   1. Without closing fd 9, the daemon inherits the lock fd, and since
#      these are long-running processes the lock would never release --
#      every run after the first would see it as still taken and no-op.
#   2. The `( exec 9>&-; setsid nohup CMD ) & disown` form (tried first)
#      turned out to leave switch-theme.sh itself hanging in the kernel's
#      do_wait state on the mainbar job specifically -- disown didn't
#      reliably detach that subshell job, and the parent script blocked
#      until it was killed, which is also what let the OLD mainbar survive
#      alongside a newly-launched one (the pkill/relaunch for taskbar right
#      after it in the same loop iteration ran fine independently). A plain
#      `CMD 9>&- & ` with no subshell and no disown doesn't hit this --
#      nohup + setsid + full stream redirection is already a complete,
#      self-sufficient way to detach a daemon; it was never disown's job.

THEME_DIR="$HOME/.config/rice"
NAME="${1:-}"

usage() {
    echo "Usage: $0 <purple|green>"
    echo "Available presets:"
    for f in "$THEME_DIR"/theme-*.conf; do
        base="$(basename "$f")"
        echo "  ${base#theme-}" | sed 's/\.conf$//'
    done
    exit 1
}

[ -z "$NAME" ] && usage
PRESET="$THEME_DIR/theme-$NAME.conf"
[ -f "$PRESET" ] || { echo "No such preset: $PRESET"; usage; }

ln -sf "theme-$NAME.conf" "$THEME_DIR/theme.conf"
echo "theme.conf -> theme-$NAME.conf"

# fastfetch dragon logo follows the preset too, if a matching recolor
# exists (dragon-purple.png / dragon-green.png) -- silently left alone for
# presets that don't have their own dragon variant yet.
FASTFETCH_DIR="$HOME/.config/fastfetch"
DRAGON_VARIANT="$FASTFETCH_DIR/dragon-$NAME.png"
if [ -f "$DRAGON_VARIANT" ]; then
    ln -sf "dragon-$NAME.png" "$FASTFETCH_DIR/dragon.png"
    echo "dragon.png -> dragon-$NAME.png"
fi

"$THEME_DIR/apply-theme.sh"

# Repaint everything live instead of making the user log out/in.
#
# Polybar is deliberately NOT handled here. ~/.config/i3/config has
# `exec_always --no-startup-id ~/.config/polybar/launch.sh`, which i3 runs
# automatically on every `i3-msg reload` below -- and launch.sh already
# does a full killall-polybar-then-wait-then-relaunch (both bars, every
# monitor). An earlier version of this script ALSO pkilled/relaunched
# polybar itself, racing launch.sh's own kill/relaunch on every reload --
# confirmed by reproducing it repeatedly: mainbar ended up duplicated
# (sometimes taskbar instead, depending on scheduling) because both this
# script and launch.sh were independently killing and recreating the same
# processes at the same time. Trust the exec_always path instead of
# duplicating it.
i3-msg reload >/dev/null
bash "$HOME/.config/i3/set-wallpaper.sh" 9>&- &

# Wait for a pkill'd pattern to actually be gone (up to ~2s) instead of a
# blind sleep -- a killed process isn't guaranteed reaped by the time the
# next line runs, and relaunching too early is exactly what produces
# duplicates.
wait_gone() {
    for _ in $(seq 1 20); do
        pgrep -f "$1" >/dev/null 2>&1 || return 0
        sleep 0.1
    done
}

pkill picom 2>/dev/null || true
wait_gone "picom --config"
setsid nohup picom --config "$HOME/.config/picom/picom.conf" \
    >/tmp/picom.log 2>&1 9>&- < /dev/null &

pkill -x dunst 2>/dev/null || true
for _ in $(seq 1 20); do
    pgrep -x dunst >/dev/null 2>&1 || break
    sleep 0.1
done
setsid nohup dunst >/tmp/dunst.log 2>&1 9>&- < /dev/null &

echo "Switched to '$NAME'. If anything looks stale, Mod+Shift+r or a full logout/login will fully reset it."
