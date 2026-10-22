#!/usr/bin/env bash
# Swap between the rice's presets: theme-purple.conf / theme-green.conf /
# theme-mono.conf (mono also switches the layout -- floating top bar + dock).
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
    echo "Usage: $0 <purple|green|mono>"
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
# exists (dragon-purple.png / dragon-green.png / dragon-mono.png) -- silently left alone for
# presets that don't have their own dragon variant yet.
FASTFETCH_DIR="$HOME/.config/fastfetch"
DRAGON_VARIANT="$FASTFETCH_DIR/dragon-$NAME.png"
if [ -f "$DRAGON_VARIANT" ]; then
    ln -sf "dragon-$NAME.png" "$FASTFETCH_DIR/dragon.png"
    echo "dragon.png -> dragon-$NAME.png"
fi

"$THEME_DIR/apply-theme.sh"

# Terminal apps that are already open. zsh needs nothing here: its prompt
# re-reads terminal-style before every prompt (terminal/zsh/rice-theme.zsh).
# tmux: status-style comes from the generated tmux-theme.conf (the status
# script itself re-reads terminal-style every second). No server = no-op.
tmux source-file "$THEME_DIR/tmux-theme.conf" >/dev/null 2>&1 9>&- < /dev/null || true
# nvim: every running instance listens on a socket (nvim 0.9+ default path,
# with or without XDG_RUNTIME_DIR) -- ask each one to re-apply its colors.
# timeout: a socket left behind by a crashed nvim must not hang the switch.
if command -v nvim >/dev/null 2>&1; then
    for sock in "${XDG_RUNTIME_DIR:-/nonexistent}"/nvim.*.0 /tmp/nvim."${USER:-$(id -un)}"/*/nvim.*.0; do
        [ -S "$sock" ] || continue
        timeout 2 nvim --server "$sock" \
            --remote-expr 'luaeval("pcall(function() require(\"rice_theme\").apply() end)")' \
            >/dev/null 2>&1 9>&- < /dev/null || true
    done
fi
# kitty: SIGUSR1 = reload kitty.conf (and the colors.conf it includes).
# Only kitty >= 0.24 handles that signal -- older ones would be KILLED by it.
if command -v kitty >/dev/null 2>&1; then
    kitty_ver=$(kitty --version 2>/dev/null | awk '{print $2}')
    if [ -n "$kitty_ver" ] && [ "$(printf '%s\n' 0.24.0 "$kitty_ver" | sort -V | head -1)" = 0.24.0 ]; then
        pkill -USR1 -u "$UID" -x kitty 2>/dev/null || true
    fi
fi

# Repaint everything live instead of making the user log out/in.
#
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

# Polybar + dock: run launch.sh exactly once, here. NOTE `i3-msg reload`
# does NOT re-run exec_always lines (only a full restart does -- verified
# on i3 4.23: polybar's PID is unchanged across a reload). Color-only
# switches (purple <-> green) used to look fine without this because
# `polybar --reload` re-reads its own config when apply-theme.sh rewrites
# colors.ini -- but mono swaps to a different bar (monobar) and starts/
# stops the right-side dock, which only launch.sh does.
# Never add a second polybar kill/relaunch of our own next to this one: an
# earlier version that pkilled/relaunched polybar separately ended up with
# duplicated bars from two kill/relaunch sequences interleaving. launch.sh
# alone does killall -> wait until gone -> relaunch, which also mops up
# any bar mid-way through its own --reload self-restart.
i3-msg reload >/dev/null
bash "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 9>&- < /dev/null
# Restart the window-geometry daemons too. They're flock-guarded, so neither
# a reload nor $mod+Shift+r replaces a running one -- after a `git pull`
# the OLD code kept sizing new windows (observed: full-width windows under
# mono's dock until the next logout). They read layout.json fresh on every
# window, so this is only about picking up code changes.
# PIDs of python3 processes (only -- not e.g. a shell or grep whose command
# line merely mentions the script) whose command line matches $1.
python_pids() {
    for p in $(pgrep -u "$UID" -f "$1"); do
        case "$(cat "/proc/$p/comm" 2>/dev/null)" in python3*) echo "$p" ;; esac
    done
}
for daemon in default-size.py fix-maximized-on-output-change.py; do
    pattern="/\.config/i3/$daemon daemon"
    pids=$(python_pids "$pattern")
    [ -n "$pids" ] && { kill $pids 2>/dev/null || true; }
    for _ in $(seq 1 20); do
        [ -z "$(python_pids "$pattern")" ] && break
        sleep 0.1
    done
    setsid nohup python3 "$HOME/.config/i3/$daemon" daemon \
        >/dev/null 2>&1 9>&- < /dev/null &
done
# Already-open windows keep the geometry they got under the OLD layout (e.g.
# full width from green/purple, now under mono's dock) -- re-fit them.
python3 "$HOME/.config/i3/fix-maximized-on-output-change.py" once >/dev/null 2>&1 9>&- < /dev/null || true
bash "$HOME/.config/i3/set-wallpaper.sh" 9>&- &


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
