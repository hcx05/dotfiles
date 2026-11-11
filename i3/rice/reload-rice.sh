#!/usr/bin/env bash
# Shared "apply + relaunch everything live" sequence, factored out of
# switch-theme.sh so bar-selector.sh (new: independent bar-style switch,
# doesn't touch colors) can reuse it instead of duplicating ~60 lines.
# Callers are expected to have already updated whichever state file they
# own (theme.conf symlink for colors, .barstyle for bar layout) BEFORE
# calling this script -- it just re-derives everything from current state
# and makes it live.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"

# Guard against overlapping runs (e.g. switch-theme.sh and bar-selector.sh
# both firing at once, or a double-click) -- without this, two invocations
# can each pkill-then-relaunch polybar/picom/dunst in an interleaved race,
# leaving two of everything running side by side. A second invocation that
# can't get the lock just exits instead of racing. Shared across every
# caller (same lock file as before) since they all touch the same daemons.
LOCK_FILE="/tmp/switch-theme.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Another reload-rice.sh run is already in progress -- ignoring this one." >&2
    exit 0
fi
# IMPORTANT: every backgrounded daemon below closes fd 9 as an inline
# redirection on the command itself (`... 9>&- &`), NOT via a `( subshell )
# & disown` wrapper -- see switch-theme.sh's original comment (git log) for
# why: without closing fd 9 a long-running daemon holds the lock forever,
# and the subshell+disown form was observed to hang the parent script.

# shellcheck source=theme.conf
source "$THEME_DIR/theme.conf"

tmux source-file "$THEME_DIR/tmux-theme.conf" >/dev/null 2>&1 9>&- < /dev/null || true
if command -v kitty >/dev/null 2>&1; then
    kitty_ver=$(kitty --version 2>/dev/null | awk '{print $2}')
    if [ -n "$kitty_ver" ] && [ "$(printf '%s\n' 0.24.0 "$kitty_ver" | sort -V | head -1)" = 0.24.0 ]; then
        pkill -USR1 -u "$UID" -x kitty 2>/dev/null || true
    fi
fi

wait_gone() {
    for _ in $(seq 1 20); do
        pgrep -f "$1" >/dev/null 2>&1 || return 0
        sleep 0.1
    done
}

# Polybar + dock: run launch.sh exactly once, here. NOTE `i3-msg reload`
# does NOT re-run exec_always lines (only a full restart does) -- launch.sh
# alone does killall -> wait until gone -> relaunch, which also mops up any
# bar mid-way through its own --reload self-restart. Never add a second
# polybar kill/relaunch of our own next to this one.
i3-msg reload >/dev/null
bash "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 9>&- < /dev/null

# Restart the window-geometry daemons too -- they read layout.json fresh on
# every window, so this picks up a changed layout (bar style switch) or
# code change. Flock-guarded themselves, so this kill+relaunch is the only
# way to make them re-read a changed layout.json.
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
# Already-open windows keep the geometry they got under the OLD layout --
# re-fit them now.
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
